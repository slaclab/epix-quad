-------------------------------------------------------------------------------
-- File       : AdcCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-10
-------------------------------------------------------------------------------
-- Description: EPIX Quad Target's Top Level
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Ad9249Pkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AdcCore is
   generic (
      TPD_G                : time             := 1 ns;
      AXI_CLK_FREQ_G       : real             := 100.00E+6;
      SIMULATION_G         : boolean          := false;
      SIM_SPEEDUP_G        : boolean          := false;
      AXI_BASE_ADDR_G      : slv(31 downto 0) := (others => '0')
   );
   port (
      -- Clock and Reset
      sysClk               : in    sl;
      sysRst               : in    sl;
      -- ADC ISERDESE reset
      adcClkRst            : in    slv(9 downto 0);
      -- AXI-Lite Register Interface (sysClk domain)
      mAxilReadMaster      : in    AxiLiteReadMasterType;
      mAxilReadSlave       : out   AxiLiteReadSlaveType;
      mAxilWriteMaster     : in    AxiLiteWriteMasterType;
      mAxilWriteSlave      : out   AxiLiteWriteSlaveType;
      -- Fast ADC Config SPI
      adcSclk              : out   slv(2 downto 0);
      adcSdio              : inout slv(2 downto 0);
      adcCsb               : out   slv(9 downto 0);
      -- Fast ADC Signals
      adcFClkP             : in    slv(9 downto 0);
      adcFClkN             : in    slv(9 downto 0);
      adcDClkP             : in    slv(9 downto 0);
      adcDClkN             : in    slv(9 downto 0);
      adcChP               : in    Slv8Array(9 downto 0);
      adcChN               : in    Slv8Array(9 downto 0);
      -- ADC Output Streams
      adcStream            : out AxiStreamMasterArray(79 downto 0)
   );
end AdcCore;

architecture top_level of AdcCore is

   constant NUM_AXI_MASTERS_C    : natural := 14;

   constant ADC0_RDOUT_INDEX_C   : natural := 0;
   constant ADC1_RDOUT_INDEX_C   : natural := 1;
   constant ADC2_RDOUT_INDEX_C   : natural := 2;
   constant ADC3_RDOUT_INDEX_C   : natural := 3;
   constant ADC4_RDOUT_INDEX_C   : natural := 4;
   constant ADC5_RDOUT_INDEX_C   : natural := 5;
   constant ADC6_RDOUT_INDEX_C   : natural := 6;
   constant ADC7_RDOUT_INDEX_C   : natural := 7;
   constant ADC8_RDOUT_INDEX_C   : natural := 8;
   constant ADC9_RDOUT_INDEX_C   : natural := 9;
   constant ADC0_CFG_INDEX_C     : natural := 10;
   constant ADC1_CFG_INDEX_C     : natural := 11;
   constant MON_CFG_INDEX_C      : natural := 12;
   constant ADC_TEST_INDEX_C     : natural := 13;

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal asicAdc          : Ad9249SerialGroupArray(9 downto 0);
   signal iAdcStream       : AxiStreamMasterArray(79 downto 0);

begin
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => mAxilWriteMaster,
         sAxiWriteSlaves(0)  => mAxilWriteSlave,
         sAxiReadMasters(0)  => mAxilReadMaster,
         sAxiReadSlaves(0)   => mAxilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);
   
   
   ------------------------------------------------
   -- ADC Readout Modules
   ------------------------------------------------
   G_AdcReadout : for i in 0 to 9 generate 
      
      asicAdc(i).fClkP <= adcFClkP(i);
      asicAdc(i).fClkN <= adcFClkN(i);
      asicAdc(i).dClkP <= adcDClkP(i);
      asicAdc(i).dClkN <= adcDClkN(i);
      asicAdc(i).chP   <= adcChP(i);
      asicAdc(i).chN   <= adcChN(i);
      
      U_AdcReadout : entity work.Ad9249ReadoutGroup
      generic map (
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
         F_DELAY_CASCADE_G => false,
         D_DELAY_CASCADE_G => false
      )
      port map (
         axilClk           => sysClk,
         axilRst           => sysRst,
         axilReadMaster    => axilReadMasters(ADC0_RDOUT_INDEX_C+i),
         axilReadSlave     => axilReadSlaves(ADC0_RDOUT_INDEX_C+i),
         axilWriteMaster   => axilWriteMasters(ADC0_RDOUT_INDEX_C+i),
         axilWriteSlave    => axilWriteSlaves(ADC0_RDOUT_INDEX_C+i),
         adcClkRst         => adcClkRst(i),
         adcSerial         => asicAdc(i),
         adcStreamClk      => sysClk,
         adcStreams        => iAdcStream((i*8)+7 downto i*8)
      );
      
   end generate;
   
   G_AdcConf : for i in 0 to 1 generate 
      U_AdcConf : entity work.Ad9249Config
         generic map (
            TPD_G             => TPD_G,
            AXIL_CLK_PERIOD_G => (1.0/AXI_CLK_FREQ_G),
            SCLK_PERIOD_G     => 1.0e-6,
            NUM_CHIPS_G       => 2
         )
         port map (
            axilClk           => sysClk,
            axilRst           => sysRst,
            axilReadMaster    => axilReadMasters(ADC0_CFG_INDEX_C+i),
            axilReadSlave     => axilReadSlaves(ADC0_CFG_INDEX_C+i),
            axilWriteMaster   => axilWriteMasters(ADC0_CFG_INDEX_C+i),
            axilWriteSlave    => axilWriteSlaves(ADC0_CFG_INDEX_C+i),
            adcPdwn           => open,
            adcSclk           => adcSclk(i),
            adcSdio           => adcSdio(i),
            adcCsb            => adcCsb(3+i*4 downto i*4)
         );
   end generate;
   
   U_MonConf : entity work.Ad9249Config
      generic map (
         TPD_G             => TPD_G,
         AXIL_CLK_PERIOD_G => (1.0/AXI_CLK_FREQ_G),
         SCLK_PERIOD_G     => 1.0e-6,
         NUM_CHIPS_G       => 1
      )
      port map (
         axilClk           => sysClk,
         axilRst           => sysRst,
         axilReadMaster    => axilReadMasters(MON_CFG_INDEX_C),
         axilReadSlave     => axilReadSlaves(MON_CFG_INDEX_C),
         axilWriteMaster   => axilWriteMasters(MON_CFG_INDEX_C),
         axilWriteSlave    => axilWriteSlaves(MON_CFG_INDEX_C),
         adcPdwn           => open,
         adcSclk           => adcSclk(2),
         adcSdio           => adcSdio(2),
         adcCsb            => adcCsb(9 downto 8)
      );
      
   U_AdcTester : entity work.StreamPatternTester
   generic map (
      TPD_G             => TPD_G,
      NUM_CHANNELS_G    => 80
   )
   port map ( 
      -- Master system clock
      clk               => sysClk,
      rst               => sysRst,
      -- ADC data stream inputs
      adcStreams        => iAdcStream,
      -- Axi Interface
      axilReadMaster    => axilReadMasters(ADC_TEST_INDEX_C),
      axilReadSlave     => axilReadSlaves(ADC_TEST_INDEX_C),
      axilWriteMaster   => axilWriteMasters(ADC_TEST_INDEX_C),
      axilWriteSlave    => axilWriteSlaves(ADC_TEST_INDEX_C)
   );
   
   adcStream <= iAdcStream;
   

end top_level;
