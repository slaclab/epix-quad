-------------------------------------------------------------------------------
-- Title      : DoutDeserializer
-- Project    : Epix10ka Detector
-------------------------------------------------------------------------------
-- File       : DoutDeserializer.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Deserializes EPIX10KA digital outputs. The ASIC has one output per 
-- 4 banks therefore 4 readout clock cycles are needed to output digital data.
-- It takes 10 roClk cycles before first valid data appears (verified with chipscope)
-- and the rdoClkDelay should be set correspondingly for valid image readout.
-- Dout FIFOs mapping:
-- doutOut(15): ASIC3_BANK3
-- doutOut(14): ASIC3_BANK2
-- doutOut(13): ASIC3_BANK1
-- doutOut(12): ASIC3_BANK0
-- doutOut(11): ASIC2_BANK3
-- doutOut(10): ASIC2_BANK2
-- doutOut(9):  ASIC2_BANK1
-- doutOut(8):  ASIC2_BANK0
-- doutOut(7):  ASIC1_BANK3
-- doutOut(6):  ASIC1_BANK2
-- doutOut(5):  ASIC1_BANK1
-- doutOut(4):  ASIC1_BANK0
-- doutOut(3):  ASIC0_BANK3
-- doutOut(2):  ASIC0_BANK2
-- doutOut(1):  ASIC0_BANK1
-- doutOut(0):  ASIC0_BANK0
-------------------------------------------------------------------------------
-- This file is part of 'Epix Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity DoutDeserializer is 
   generic (
      TPD_G             : time             := 1 ns;
      AXIL_ERR_RESP_G   : slv(1 downto 0)  := AXI_RESP_DECERR_C;
      BANK_COLS_G       : natural          := 48;
      RD_ORDER_INIT_G   : slv(15 downto 0) := x"0FF0";
      FOUR_BIT_OUT_G      : boolean          := false
   );
   port ( 
      clk         : in  sl;
      rst         : in  sl;
      asicDout    : in  slv(3 downto 0);
      asicRoClk   : in  sl;
      doutOut     : out Slv2Array(15 downto 0); -- must keep this for backward compatibility
      doutOut4    : out Slv4Array(15 downto 0);
      doutRd      : in  slv(15 downto 0);
      doutValid   : out slv(15 downto 0);
      doutCount   : out Slv8Array(15 downto 0);
      
      -- Acquisition state machine handshake
      acqBusy     : in  sl;
      roClkTail   : out slv(7 downto 0);
      
      
      -- AXI lite slave port for register access
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType
   );
end DoutDeserializer;


-- Define architecture
architecture RTL of DoutDeserializer is
   
   constant BANK_COLS_C    : natural   := BANK_COLS_G - 1;
   constant COLS_BITS_C    : natural   := log2(BANK_COLS_G);
   
   constant FIFO_OUT_WIDTH : natural := ite(FOUR_BIT_OUT_G, 4, 2);
   
   type BuffVectorArray is array (natural range<>, natural range<>) of slv(BANK_COLS_G-1 downto 0);
   
   type StateType is (IDLE_S, WAIT_S, STORE_S);
   
   type FsmType is record
      state             : StateType;
      asicDout          : slv(3 downto 0);
      stCnt             : slv(31 downto 0);
      asicRoClk         : sl;
      acqBusy           : sl;
      fifoIn            : Slv1Array(15 downto 0);
      fifoWr            : slv(15 downto 0);
      fifoWrDly         : slv(15 downto 0);
      fifoRst           : sl;
      rowBuff           : BuffVectorArray(1 downto 0, 15 downto 0);
      rowBuffRdy        : sl;
      rowBuffAct        : natural;
      copyReq           : sl;
      copyCnt           : natural range 0 to BANK_COLS_C;
      rdOrder           : slv(15 downto 0);
      rdoClkDelay       : slv(7 downto 0);
      sysClkDelay       : slv(7 downto 0);
      roClkRising       : slv(255 downto 0);
      sAxilWriteSlave   : AxiLiteWriteSlaveType;
      sAxilReadSlave    : AxiLiteReadSlaveType;
   end record;

   constant FSM_INIT_C : FsmType := (
      state             => IDLE_S,
      asicDout          => (others=>'0'),
      stCnt             => (others=>'0'),
      asicRoClk         => '0',
      acqBusy           => '0',
      fifoIn            => (others=>(others=>'0')),
      fifoWr            => (others=>'0'),
      fifoWrDly         => (others=>'0'),
      fifoRst           => '1',
      rowBuff           => (others=>(others=>(others=>'0'))),
      rowBuffRdy        => '0',
      rowBuffAct        => 0,
      copyReq           => '0',
      copyCnt           => 0,
      rdOrder           => RD_ORDER_INIT_G,
      rdoClkDelay       => x"0A",
      sysClkDelay       => (others=>'0'),
      roClkRising       => (others=>'0'),
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C
   );
   
   signal f   : FsmType := FSM_INIT_C;
   signal fin : FsmType;
   
   attribute keep : string;
   attribute keep of f : signal is "true";
   
begin
   
   comb : process (rst, f, asicDout, asicRoClk, acqBusy, sAxilWriteMaster, sAxilReadMaster) is
      variable fv             : FsmType;
      variable acqBusyRising  : sl;
      variable rowBuffCopy    : natural;
      variable regCon         : AxiLiteEndPointType;
   begin
      fv := f;
      
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, fv.sAxilWriteSlave, fv.sAxilReadSlave);
      
      axiSlaveRegister (regCon, x"00",  0, fv.rdoClkDelay);
      axiSlaveRegister (regCon, x"04",  0, fv.sysClkDelay);
      axiSlaveRegister (regCon, x"08",  0, fv.rdOrder);
      
      axiSlaveDefault(regCon, fv.sAxilWriteSlave, fv.sAxilReadSlave, AXIL_ERR_RESP_G);
      
      -- sync      
      fv.asicRoClk := asicRoClk;
      fv.acqBusy := acqBusy;
      fv.asicDout := asicDout;
      -- delay FIFO write strobe
      fv.fifoWrDly := f.fifoWr;
      
      -- detect rising edge
      if f.asicRoClk = '0' and asicRoClk = '1' then
         fv.roClkRising(255 downto 1)  := (others=>'0');
         fv.roClkRising(0)             := '1';
      else 
         fv.roClkRising := f.roClkRising(254 downto 0) & '0';
      end if;
      
      -- detect rising edge
      if f.acqBusy = '0' and acqBusy = '1' then
         acqBusyRising := '1';
      else 
         acqBusyRising := '0';
      end if;
      
      case f.state is
         when IDLE_S =>
            fv.fifoRst := '1';
            fv.stCnt := (others=>'0');
            fv.copyReq := '0';
            fv.copyCnt := 0;
            fv.rowBuffAct := 0;
            fv.rowBuffRdy := '0';
            fv.fifoIn := (others=>(others=>'0'));
            if f.rdoClkDelay > 0 then
               fv.state := WAIT_S;
            else
               fv.state := STORE_S;
            end if;
         
         when WAIT_S =>
            -- wait configured roClk cycles
            -- before deserializing
            fv.fifoRst := '0';
            if f.roClkRising(0) = '1' then
               fv.stCnt := f.stCnt + 1;
            end if;
            if f.stCnt >= f.rdoClkDelay then
               fv.stCnt := (others=>'0');
               fv.state := STORE_S;
            end if;
         
         when STORE_S =>
            fv.fifoRst := '0';
            fv.rowBuffRdy := '0';
            if f.roClkRising(conv_integer(f.sysClkDelay)) = '1' then
               -- write douts to appropriate row buffer on every roClkRising edge
               fv.rowBuff(f.rowBuffAct, 0 +conv_integer(f.stCnt(1 downto 0)))(conv_integer(f.stCnt(COLS_BITS_C+1 downto 2))) := f.asicDout(0);
               fv.rowBuff(f.rowBuffAct, 4 +conv_integer(f.stCnt(1 downto 0)))(conv_integer(f.stCnt(COLS_BITS_C+1 downto 2))) := f.asicDout(1);
               fv.rowBuff(f.rowBuffAct, 8 +conv_integer(f.stCnt(1 downto 0)))(conv_integer(f.stCnt(COLS_BITS_C+1 downto 2))) := f.asicDout(2);
               fv.rowBuff(f.rowBuffAct, 12+conv_integer(f.stCnt(1 downto 0)))(conv_integer(f.stCnt(COLS_BITS_C+1 downto 2))) := f.asicDout(3);

               -- count rising edges of roClk
               fv.stCnt := f.stCnt + 1;
               
               -- change row buffer and trigger copy logic
               if conv_integer(f.stCnt(COLS_BITS_C+1 downto 2)) = BANK_COLS_C and f.stCnt(1 downto 0) = "11" then
                  fv.rowBuffRdy := '1';
                  fv.stCnt := (others=>'0');
                  fv.fifoWr := (others=>'1');
                  if f.rowBuffAct = 0 then
                     fv.rowBuffAct := 1;
                  else
                     fv.rowBuffAct := 0;
                  end if;
               end if;
            
            end if;
         
         when others =>
            fv.state := IDLE_S;
         
      end case;
      
      -- copy row buffer to FIFO in requested order
      if f.rowBuffRdy = '1' or f.copyReq = '1' then
         -- copy done
         if f.copyCnt = BANK_COLS_C then
            fv.copyReq := '0';
            fv.copyCnt := 0;
            fv.fifoWr := (others=>'0');
         else
            fv.copyReq := '1';
            fv.copyCnt := f.copyCnt + 1;
         end if;
      end if;
      -- pick completed row buffer
      if f.rowBuffAct = 0 then
         rowBuffCopy := 1;
      else
         rowBuffCopy := 0;
      end if;
      -- write FIFOs
      for i in 0 to 15 loop
         if f.rdOrder(i) = '0' then
            fv.fifoIn(i)(0) := f.rowBuff(rowBuffCopy, i)(f.copyCnt);
         else
            fv.fifoIn(i)(0) := f.rowBuff(rowBuffCopy, i)(BANK_COLS_C - f.copyCnt);
         end if;
      end loop;
      
      -- reset FSM when acquisition start is detected
      if acqBusyRising = '1' then
         fv.state := IDLE_S;
      end if;
      
      -- reset logic
      
      if (rst = '1') then
         fv := FSM_INIT_C;
      end if;

      -- outputs
      fin               <= fv;
      sAxilWriteSlave   <= f.sAxilWriteSlave;
      sAxilReadSlave    <= f.sAxilReadSlave;
      -- Acquisition FSM must continue ASIC roClk until all Douts arre captured
      roClkTail         <= f.rdoClkDelay;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         f <= fin after TPD_G;
      end if;
   end process seq;
   
   
   G_TWO_BIT_OUT : if FOUR_BIT_OUT_G = false generate
      -- data out FIFOs
      G_DoutFifos : for i in 0 to 15 generate
         DoutFifo_U : entity surf.FifoMux
         generic map (
            WR_DATA_WIDTH_G   => 1,
            RD_DATA_WIDTH_G   => FIFO_OUT_WIDTH,
            GEN_SYNC_FIFO_G   => true,
            ADDR_WIDTH_G      => 8,
            FWFT_EN_G         => true,
            LITTLE_ENDIAN_G   => true,
            SYNTH_MODE_G      => "xpm"
         )
         port map (
            rst               => f.fifoRst,
            wr_clk            => clk,
            wr_en             => f.fifoWrDly(i),
            din               => f.fifoIn(i),
            rd_clk            => clk,
            rd_en             => doutRd(i),
            dout              => doutOut(i),
            valid             => doutValid(i),
            rd_data_count     => doutCount(i)
         );
      end generate;
      doutOut4    <= (others=>(others=>'0'));
   end generate;
   
   G_FOUR_BIT_OUT : if FOUR_BIT_OUT_G = true generate
      -- data out FIFOs
      G_DoutFifos : for i in 0 to 15 generate
         DoutFifo_U : entity surf.FifoMux
         generic map (
            WR_DATA_WIDTH_G   => 1,
            RD_DATA_WIDTH_G   => FIFO_OUT_WIDTH,
            GEN_SYNC_FIFO_G   => true,
            ADDR_WIDTH_G      => 8,
            FWFT_EN_G         => true,
            LITTLE_ENDIAN_G   => true,
            SYNTH_MODE_G      => "xpm"
         )
         port map (
            rst               => f.fifoRst,
            wr_clk            => clk,
            wr_en             => f.fifoWrDly(i),
            din               => f.fifoIn(i),
            rd_clk            => clk,
            rd_en             => doutRd(i),
            dout              => doutOut4(i),
            valid             => doutValid(i),
            rd_data_count     => doutCount(i)
         );
      end generate;
      doutOut     <= (others=>(others=>'0'));
   end generate;

end RTL;

