-------------------------------------------------------------------------------
-- File       : SaciConfigCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-01
-- Last update: 2018-01-08
-------------------------------------------------------------------------------
-- Description: SaciConfigCore.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.SaciMasterPkg.all;

entity SaciConfigCore is
   generic (
      TPD_G             : time               := 1 ns;
      AXI_BASE_ADDR_G   : slv(31 downto 0)   := (others => '0');
      SACI_CLK_PERIOD_G : real               := 1.00E-6;
      AXI_CLK_FREQ_G    : real               := 100.00E+6;
      SIM_SPEEDUP_G     : boolean            := false
   );
   port (
      -- clock and reset
      sysClk            : in  sl;
      sysRst            : in  sl;
      -- SACI interface
      saciClk           : out slv(3 downto 0);
      saciCmd           : out slv(3 downto 0);
      saciSelL          : out slv(15 downto 0);
      saciRsp           : in  slv(3 downto 0);
      -- AXI-Lite Matrix Configuration Interface
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AXI-Lite Register Interfaces
      axilReadMasters   : in  AxiLiteReadMasterArray(3 downto 0);
      axilReadSlaves    : out AxiLiteReadSlaveArray(3 downto 0);
      axilWriteMasters  : in  AxiLiteWriteMasterArray(3 downto 0);
      axilWriteSlaves   : out AxiLiteWriteSlaveArray(3 downto 0)
   );
end SaciConfigCore;

architecture rtl of SaciConfigCore is
   
   constant NUM_AXI_MASTERS_C : natural := 17;
   constant AXI_CONFIG_C      : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 19);

   signal axilCbWriteMasters  : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilCbWriteSlaves   : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilCbReadMasters   : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilCbReadSlaves    : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   type StateType is (
      REG_ACC_S,
      REG_WAIT_S,
      CON_ACC_S
   );
   
   type StateTypeArray is array (natural range <>) of StateType;
   
   type RegType is record
      state                : StateTypeArray(3 downto 0);
      regSaciBusGr         : slv(3 downto 0);
      conSaciBusGr         : slv(3 downto 0);
      confWrReq            : sl;
      confRdReq            : sl;
      confSel              : slv(15 downto 0);
      axilWriteSlave       : AxiLiteWriteSlaveType;
      axilReadSlave        : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state                => (others=>REG_ACC_S),
      regSaciBusGr         => (others=>'0'),
      conSaciBusGr         => (others=>'0'),
      confWrReq            => '0',
      confRdReq            => '0',
      confSel              => (others=>'0'),
      axilWriteSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave        => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   
   signal confDone      : slv(3 downto 0);
   signal confDoneAll   : sl;
   signal confFail      : slv(15 downto 0);
   
   signal regSaciClk    : slv(3 downto 0);
   signal regSaciCmd    : slv(3 downto 0);
   signal regSaciSelL   : slv(15 downto 0);
   signal regSaciBusReq : slv(3 downto 0);
   
   signal conSaciClk    : slv(3 downto 0);
   signal conSaciCmd    : slv(3 downto 0);
   signal conSaciSelL   : slv(15 downto 0);
   signal conSaciBusReq : slv(3 downto 0);
   
   signal memAddr       : Slv13Array(15 downto 0);
   signal memDout       : Slv32Array(15 downto 0);
   signal memDin        : Slv32Array(15 downto 0);
   signal memWr         : slv(15 downto 0);
   
   
begin
   
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVE_SLOTS_G    => 1,
         NUM_MASTER_SLOTS_G   => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G     => AXI_CONFIG_C
      )
      port map (
         axiClk               => sysClk,
         axiClkRst            => sysRst,
         sAxiWriteMasters(0)  => axilWriteMaster,
         sAxiWriteSlaves(0)   => axilWriteSlave,
         sAxiReadMasters(0)   => axilReadMaster,
         sAxiReadSlaves(0)    => axilReadSlave,

         mAxiWriteMasters     => axilCbWriteMasters,
         mAxiWriteSlaves      => axilCbWriteSlaves,
         mAxiReadMasters      => axilCbReadMasters,
         mAxiReadSlaves       => axilCbReadSlaves
      );
   

   comb : process (sysRst, r, axilCbReadMasters(16), axilCbWriteMasters(16), 
      confDone, confDoneAll, confFail, regSaciBusReq, conSaciBusReq) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;
      
      v.confWrReq := '0';
      v.confRdReq := '0';
      
      --------------------------------------------------
      -- AXI Lite register logic
      --------------------------------------------------
      
      -- Determine the AXI-Lite transaction
      v.axilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, axilCbWriteMasters(16), axilCbReadMasters(16), v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.confWrReq         );
      axiSlaveRegister (regCon, x"004", 0, v.confRdReq         );
      axiSlaveRegister (regCon, x"008", 0, v.confSel           );
      axiSlaveRegisterR(regCon, x"00C", 0, confDoneAll         );
      axiSlaveRegisterR(regCon, x"010", 0, confFail            );
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);
      
      --------------------------------------------------
      -- SACI arbiter FSMs
      --------------------------------------------------
      for i in 3 downto 0 loop
         case (r.state(i)) is
            
            when REG_ACC_S =>
               -- register acces at startup
               v.regSaciBusGr(i) := '1';
               v.conSaciBusGr(i) := '0';
               if conSaciBusReq(i) = '1' then
                  v.state(i) := REG_WAIT_S;
               end if;
            
            when REG_WAIT_S =>
               -- wait for register access to terminate
               if regSaciBusReq(i) = '0' then
                  v.regSaciBusGr(i) := '0';
                  v.conSaciBusGr(i) := '1';
                  v.state(i) := CON_ACC_S;
               end if;
               
            when CON_ACC_S =>
               -- return to register access mode when config done
               if confDone(i) = '1' then
                  v.state(i) := REG_ACC_S;
               end if;
            
            when others =>
               v.state(i) := REG_ACC_S;
            
         end case;
      end loop;
      
      
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilCbWriteSlaves(16) <= r.axilWriteSlave;
      axilCbReadSlaves(16)  <= r.axilReadSlave;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   
   GEN_SACI : for i in 3 downto 0 generate
      
      ----------------------------------------------------
      -- 4 x 4 ASICs SACI Registers Interfaces
      -- Wide address space (has to be at the top level)
      ----------------------------------------------------
      U_AxiLiteSaciMaster : entity work.AxiLiteSaciMaster
         generic map (
            TPD_G              => TPD_G,
            AXIL_CLK_PERIOD_G  => (1.0/AXI_CLK_FREQ_G),
            AXIL_TIMEOUT_G     => 1.0E-3,
            SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
            SACI_CLK_FREERUN_G => false,
            SACI_RSP_BUSSED_G  => true,
            SACI_NUM_CHIPS_G   => 4
         )
         port map (
            -- SACI interface
            saciClk           => regSaciClk(i),
            saciCmd           => regSaciCmd(i),
            saciSelL          => regSaciSelL(i*4+3 downto i*4),
            saciRsp(0)        => saciRsp(i),
            -- bus arbitration
            saciBusReq        => regSaciBusReq(i),
            saciBusGr         => r.regSaciBusGr(i),
            -- AXI-Lite Register Interface
            axilClk           => sysClk,
            axilRst           => sysRst,
            axilReadMaster    => axilReadMasters(i),
            axilReadSlave     => axilReadSlaves(i),
            axilWriteMaster   => axilWriteMasters(i),
            axilWriteSlave    => axilWriteSlaves(i)
         );
   
      ----------------------------------------------------
      -- Matrix Configurators
      ----------------------------------------------------
      U_Epix10kMatrixConfig : entity work.Epix10kMatrixConfig
         generic map (
            TPD_G              => TPD_G,
            AXIL_CLK_PERIOD_G  => (1.0/AXI_CLK_FREQ_G),
            AXIL_TIMEOUT_G     => 1.0E-3,
            SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
            SACI_CLK_FREERUN_G => false,
            SACI_RSP_BUSSED_G  => true,
            SACI_NUM_CHIPS_G   => 4,
            SIM_SPEEDUP_G      => SIM_SPEEDUP_G
         )
         port map (
            -- SACI interface
            saciClk        => conSaciClk(i),
            saciCmd        => conSaciCmd(i),
            saciSelL       => conSaciSelL(i*4+3 downto i*4),
            saciRsp(0)     => saciRsp(i),
            -- bus arbitration
            saciBusReq     => conSaciBusReq(i),
            saciBusGr      => r.conSaciBusGr(i),
            -- Matrix Config Interface
            clk            => sysClk,
            rst            => sysRst,
            confWrReq      => r.confWrReq,
            confRdReq      => r.confRdReq,
            confSel        => r.confSel(i*4+3 downto i*4),
            confDone       => confDone(i),
            confFail       => confFail(i*4+3 downto i*4),
            memAddr        => memAddr(i*4+3 downto i*4),
            memDout        => memDout(i*4+3 downto i*4),
            memDin         => memDin(i*4+3 downto i*4),
            memWr          => memWr(i*4+3 downto i*4)
         );
      
      ----------------------------------------------------
      -- SACI bus mux
      ----------------------------------------------------
      saciClk(i)  <= 
         regSaciClk(i)                 when r.regSaciBusGr(i) = '1' else 
         conSaciClk(i);
      saciCmd(i)  <= 
         regSaciCmd(i)                 when r.regSaciBusGr(i) = '1' else 
         conSaciCmd(i);
      saciSelL(i*4+3 downto i*4) <= 
         regSaciSelL(i*4+3 downto i*4) when r.regSaciBusGr(i) = '1' else 
         conSaciSelL(i*4+3 downto i*4);
      
   end generate GEN_SACI;
   
   confDoneAll <= confDone(3) and confDone(2) and confDone(1) and confDone(0);
   
   ----------------------------------------------------
   -- Generate Configuration Memories
   ----------------------------------------------------
   GEN_MEM : for i in 15 downto 0 generate
      U_AxiDualPortRam : entity work.AxiDualPortRam
         generic map (
            TPD_G            => TPD_G,
            BRAM_EN_G        => true,
            REG_EN_G         => true,
            MODE_G           => "read-first",
            AXI_WR_EN_G      => true,
            SYS_WR_EN_G      => true,
            SYS_BYTE_WR_EN_G => false,
            COMMON_CLK_G     => true,
            ADDR_WIDTH_G     => 13,
            DATA_WIDTH_G     => 32
         )
         port map (
            axiClk         => sysClk,
            axiRst         => sysRst,
            axiReadMaster  => axilCbReadMasters(i),
            axiReadSlave   => axilCbReadSlaves(i),
            axiWriteMaster => axilCbWriteMasters(i),
            axiWriteSlave  => axilCbWriteSlaves(i),
            clk            => sysClk,
            we             => memWr(i),
            rst            => sysRst,
            addr           => memAddr(i),
            din            => memDin(i),
            dout           => memDout(i)
         );
         
   end generate GEN_MEM;
   
end rtl;

