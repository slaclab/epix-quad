-------------------------------------------------------------------------------
-- File       : TB_Ad9249ConfigNoPullup.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Test-bench of TB_Ad9249ConfigNoPullup Unit
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SsiCmdMasterPkg.all;
use surf.Ad9249Pkg.all;
use surf.AxiPkg.all;

use work.EpixPkgGen2.all;
use work.ScopeTypes.all;

entity TB_Ad9249ConfigNoPullup is 

end TB_Ad9249ConfigNoPullup;


-- Define architecture
architecture beh of TB_Ad9249ConfigNoPullup is

   signal sysClk           :  sl;
   signal sysRst           :  sl;
   
   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiReadSlave   : AxiLiteReadSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteMaster : AxiLiteWriteMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteSlave  : AxiLiteWriteSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (others=> AXI_LITE_WRITE_SLAVE_INIT_C); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (others=> AXI_LITE_READ_SLAVE_INIT_C); 
   
   signal pgpAxiReadMaster  : AxiReadMasterType;
   signal pgpAxiReadSlave   : AxiReadSlaveType;
   signal pgpAxiWriteMaster : AxiWriteMasterType;
   signal pgpAxiWriteSlave  : AxiWriteSlaveType;
   
   signal adcSpiClk        : std_logic;
   signal adcSpiDataIn     : std_logic;
   signal adcSpiDataOut    : std_logic;
   signal adcSpiDataEn     : std_logic;
   signal adcSpiCsb        : std_logic_vector(2 downto 0);
   signal adcPdwn          : std_logic_vector(2 downto 0);
   
   constant TPD_C : time := 1 ns;

begin
   
   -- clocks and resets
   
   process
   begin
      sysClk <= '0';
      wait for 5 ns;
      sysClk <= '1';
      wait for 5 ns;
   end process;
   
   process
   begin
      sysRst <= '1';
      wait for 10 ns;
      sysRst <= '0';
      wait;
   end process;
   
   
   U_AxiToAxiLite : entity surf.AxiToAxiLite
   port map (
      -- Clocks & Reset
      axiClk             => sysClk,
      axiClkRst          => sysRst,
      -- AXI Slave 
      axiReadMaster      => pgpAxiReadMaster,
      axiReadSlave       => pgpAxiReadSlave,
      axiWriteMaster     => pgpAxiWriteMaster,
      axiWriteSlave      => pgpAxiWriteSlave,
      -- AXI Lite
      axilReadMaster     => sAxiReadMaster(0),
      axilReadSlave      => sAxiReadSlave(0),
      axilWriteMaster    => sAxiWriteMaster(0),
      axilWriteSlave     => sAxiWriteSlave(0)
   );

   U_AxiSimMasterWrap : entity surf.AxiSimMasterWrap
   port map (
      -- AXI Clock/Rst
      axiClk            => sysClk,
      -- Master
      mstAxiReadMaster  => pgpAxiReadMaster,
      mstAxiReadSlave   => pgpAxiReadSlave,
      mstAxiWriteMaster => pgpAxiWriteMaster,
      mstAxiWriteSlave  => pgpAxiWriteSlave
   );
   
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   -- Master 0 : PGP register controller     --
   -- Master 1 : Microblaze reg controller    --
   --------------------------------------------
   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => NUM_AXI_SLAVE_SLOTS_C,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTER_SLOTS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         sAxiWriteMasters    => sAxiWriteMaster,
         sAxiWriteSlaves     => sAxiWriteSlave,
         sAxiReadMasters     => sAxiReadMaster,
         sAxiReadSlaves      => sAxiReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves,
         axiClk              => sysClk,
         axiClkRst           => sysRst);
   
   -- no Picoblaze master in the test
   sAxiWriteMaster(1) <= AXI_LITE_WRITE_MASTER_INIT_C;
   sAxiReadMaster(1) <= AXI_LITE_READ_MASTER_INIT_C;
   
   U_AdcConf : entity surf.Ad9249ConfigNoPullup
   generic map (
      TPD_G             => TPD_C,
      CLK_PERIOD_G      => 10.0e-9,
      CLK_EN_PERIOD_G   => 20.0e-9,
      NUM_CHIPS_G       => 2,
      AXIL_ERR_RESP_G   => AXI_RESP_OK_C
   )
   port map (
      axilClk           => sysClk,
      axilRst           => sysRst,
      
      axilReadMaster    => mAxiReadMasters(ADC_CFG_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(ADC_CFG_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(ADC_CFG_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(ADC_CFG_AXI_INDEX_C),
      
      adcSClk              => adcSpiClk,
      adcSDin              => adcSpiDataIn,
      adcSDout             => adcSpiDataOut,
      adcSDEn              => adcSpiDataEn,
      adcCsb(2 downto 0)   => adcSpiCsb,
      adcCsb(3)            => open,
      adcPdwn(2 downto 0)  => adcPdwn,
      adcPdwn(3)           => open
   );
   

end beh;

