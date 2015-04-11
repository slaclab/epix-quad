-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiCommonReg.vhd
-- Author     : Kurtis Nishimura  <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-04
-- Last update: 2014-02-04
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

use work.CommonPkg.all;
use work.SsiCmdMasterPkg.all;

entity AxiCommonReg is
   generic (
      TPD_G              : time                  := 1 ns;
      STATUS_CNT_WIDTH_G : natural range 1 to 32 := 32;
      AXI_ERROR_RESP_G   : slv(1 downto 0)       := AXI_RESP_SLVERR_C);
   port (
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Command interface in
      ssiCmd         : in  SsiCmdMasterType;
      -- Register Inputs/Outputs (axiClk domain)
      status         : in  CommonStatusType;
      config         : out CommonConfigType;
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : out sl;
      sysRst         : in  sl);      
end AxiCommonReg;

architecture rtl of AxiCommonReg is

   constant STATUS_SIZE_C     : positive := 2;

   type RegType is record
      cntRst        : sl;
      rollOverEn    : slv(STATUS_SIZE_C-1 downto 0);
      regOut        : CommonConfigType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      COMMON_CONFIG_INIT_C,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regIn  : CommonStatusType := COMMON_STATUS_INIT_C;
   signal regOut : CommonConfigType := COMMON_CONFIG_INIT_C;

   signal cntRst,
      usrRst,
      reset,
      axiReset : sl;
   signal rollOverEn : slv(STATUS_SIZE_C-1 downto 0);
   signal cntOut  : SlVectorArray(STATUS_SIZE_C-1 downto 0, STATUS_CNT_WIDTH_G-1 downto 0);

   signal txReadyCnt,
      rxReadyCnt : slv(STATUS_CNT_WIDTH_G-1 downto 0);
   
begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiReset, axiWriteMaster,
                   r, rxReadyCnt, txReadyCnt, status, regIn) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.cntRst                := '0';
      v.regOut.eventTrigger   := '0';
      
      -----------------------------------
      -- REGISTER WRITES
      -----------------------------------
      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when x"20" => v.regOut.packetSize     := axiWriteMaster.wdata(31 downto 0);
            when x"21" => v.regOut.chToRead       := axiWriteMaster.wdata(4 downto 0);
            when x"80" => v.regOut.enAutoTrigger  := axiWriteMaster.wdata(0);
            when x"81" => v.regOut.autoTrigPeriod := axiWriteMaster.wdata(31 downto 0);
            when x"AA" => v.regOut.eventTrigger   := '1';
            when x"F0" => v.rolloverEn            := axiWriteMaster.wdata(STATUS_SIZE_C-1 downto 0);
            when x"FF" => v.cntRst                := '1';
            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      -----------------------------------
      -- REGISTER READS
      -----------------------------------      
      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data
         v.axiReadSlave.rdata := (others => '0');
         case (axiReadMaster.araddr(9 downto 2)) is
            when x"13" => v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := rxReadyCnt;
            when x"14" => v.axiReadSlave.rdata(STATUS_CNT_WIDTH_G-1 downto 0) := txReadyCnt;
            when x"20" => v.axiReadSlave.rdata(31 downto 0)                   := r.regOut.packetSize;
            when x"21" => v.axiReadSlave.rdata(4 downto 0)                    := r.regOut.chToRead;
            when x"70" => v.axiReadSlave.rdata(0)                             := regIn.txReady;
                          v.axiReadSlave.rdata(1)                             := regIn.rxReady; 
            when x"80" => v.axiReadSlave.rdata(0)                             := r.regOut.enAutoTrigger;
            when x"81" => v.axiReadSlave.rdata                                := r.regOut.autoTrigPeriod;
            when x"F0" => v.axiReadSlave.rdata(STATUS_SIZE_C-1 downto 0)      := r.rolloverEn;
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send Axi Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- Synchronous Reset
      if axiReset = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      regOut <= r.regOut;

      cntRst     <= r.cntRst;
      rollOverEn <= r.rollOverEn;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -------------------------------            
   -- Synchronization: Outputs
   -------------------------------
   config <= regOut;
   
   U_CmdRst : entity work.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)   
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"FF",
         -- output pulse to sync module
         syncPulse   => usrRst,
         -- Local clock and reset
         locClk      => axiClk,
         locRst      => axiReset);

   reset <= usrRst or sysRst;

   SyncOut_Reset : entity work.RstSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk      => axiClk,
         asyncRst => reset,
         syncRst  => axiReset); 

   axiRst <= axiReset;
   
   
   -------------------------------
   -- Synchronization: Inputs
   ------------------------------- 
   SyncStatusVec_Inst : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         COMMON_CLK_G   => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_G,
         WIDTH_G        => STATUS_SIZE_C)     
      port map (
         -- Input Status bit Signals (wrClk domain) 
         statusIn(1)             => status.rxReady,  
         statusIn(0)             => status.txReady,
         -- Output Status bit Signals (rdClk domain) 
         statusOut(1)            => regIn.txReady,
         statusOut(0)            => regIn.rxReady, 
         -- Status Bit Counters Signals (rdClk domain) 
         cntRstIn              => cntRst,
         rollOverEnIn          => rollOverEn,
         cntOut                => cntOut,
         -- Clocks and Reset Ports
         wrClk                 => axiClk,
         rdClk                 => axiClk);
         
   txReadyCnt           <= muxSlVectorArray(cntOut, 1);
   rxReadyCnt           <= muxSlVectorArray(cntOut, 0);
   
end rtl;
