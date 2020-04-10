-------------------------------------------------------------------------------
-- File       : AdcPhyTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity AdcPhyTop is
   generic (
      TPD_G             : time := 1 ns;
      CLK_PERIOD_G      : real := 10.0e-9;
      IDELAYCTRL_FREQ_G : real := 200.0;
      AXI_BASE_ADDR_G   : slv(31 downto 0) := (others => '0');
      ADC0_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC1_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC2_INVERT_CH    : slv(7 downto 0) := "00000000";
      IODELAY_GROUP_G   : string          := "DEFAULT_GROUP"
   );
   port (
      -- Clocks and reset
      coreClk             : in  sl;
      coreRst             : in  sl;
      delayCtrlClk        : in  sl;
      delayCtrlRst        : in  sl;
      delayCtrlRdy        : out sl;
      adcCardPowerUp      : in  sl;
      -- AXI Lite Bus
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiDataIn        : in  sl;
      adcSpiDataOut       : out sl;
      adcSpiDataEn        : out sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn             : out slv(2 downto 0);
      -- Fast ADC readoutCh
      adcFClkP            : in  slv( 2 downto 0);
      adcFClkN            : in  slv( 2 downto 0);
      adcDClkP            : in  slv( 2 downto 0);
      adcDClkN            : in  slv( 2 downto 0);
      adcChP              : in  slv(19 downto 0);
      adcChN              : in  slv(19 downto 0);
      -- ADC data output
      adcStreams          : out AxiStreamMasterArray(19 downto 0)
   );
end AdcPhyTop;

architecture rtl of AdcPhyTop is
   
   constant NUM_AXI_MASTER_SLOTS_C : natural := 5;
   
   constant ADCTEST_AXI_INDEX_C     : natural := 0;
   constant ADC0_RD_AXI_INDEX_C     : natural := 1;
   constant ADC1_RD_AXI_INDEX_C     : natural := 2;
   constant ADC2_RD_AXI_INDEX_C     : natural := 3;
   constant ADC_CFG_AXI_INDEX_C     : natural := 4;
   
   constant ADCTEST_AXI_BASE_ADDR_C   : slv(31 downto 0) := AXI_BASE_ADDR_G + X"00000000";
   constant ADC0_RD_AXI_BASE_ADDR_C   : slv(31 downto 0) := AXI_BASE_ADDR_G + X"00100000";
   constant ADC1_RD_AXI_BASE_ADDR_C   : slv(31 downto 0) := AXI_BASE_ADDR_G + X"00200000";
   constant ADC2_RD_AXI_BASE_ADDR_C   : slv(31 downto 0) := AXI_BASE_ADDR_G + X"00300000";
   constant ADC_CFG_AXI_BASE_ADDR_C   : slv(31 downto 0) := AXI_BASE_ADDR_G + X"00400000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      ADCTEST_AXI_INDEX_C     => (
         baseAddr             => ADCTEST_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      ADC0_RD_AXI_INDEX_C     => (
         baseAddr             => ADC0_RD_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      ADC1_RD_AXI_INDEX_C      => (
         baseAddr             => ADC1_RD_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      ADC2_RD_AXI_INDEX_C     => (
         baseAddr             => ADC2_RD_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      ADC_CFG_AXI_INDEX_C     => (
         baseAddr             => ADC_CFG_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF")
   );
   
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   
   -- ADC signals
   signal iAdcStreams       : AxiStreamMasterArray(19 downto 0);
   
   -- Power up reset to SERDES block
   signal adcCardPowerUpEdge : sl;
   signal serdesReset        : sl;
   
   signal monAdc     : Ad9249SerialGroupType;
   signal asicAdc    : Ad9249SerialGroupArray(1 downto 0);
   
   signal iAdcSpiCsb : slv(3 downto 0);
   signal iAdcPdwn   : slv(3 downto 0);
   
   
   constant ADC_INVERT_CH_C : Slv8Array(1 downto 0) := (
      0 => ADC0_INVERT_CH,
      1 => ADC1_INVERT_CH
   );
   
   attribute IODELAY_GROUP : string;
   attribute IODELAY_GROUP of U_IDelayCtrl : label is IODELAY_GROUP_G;
   
begin
   
   --------------------------------------------
   -- AXI Lite Crossbar 
   --------------------------------------------
   
   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
   generic map (
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTER_SLOTS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
   port map (
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves(0)  => axilWriteSlave,
      sAxiReadMasters(0)  => axilReadMaster,
      sAxiReadSlaves(0)   => axilReadSlave,
      mAxiWriteMasters    => mAxiWriteMasters,
      mAxiWriteSlaves     => mAxiWriteSlaves,
      mAxiReadMasters     => mAxiReadMasters,
      mAxiReadSlaves      => mAxiReadSlaves,
      axiClk              => coreClk,
      axiClkRst           => coreRst
   );
   
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   -- Tap delay calibration  
   U_IDelayCtrl : IDELAYCTRL
   port map (
      REFCLK => delayCtrlClk,
      RST    => delayCtrlRst,
      RDY    => delayCtrlRdy
   );
   
   G_AdcReadout : for i in 0 to 1 generate 
   
      asicAdc(i).fClkP <= adcFClkP(i);
      asicAdc(i).fClkN <= adcFClkN(i);
      asicAdc(i).dClkP <= adcDClkP(i);
      asicAdc(i).dClkN <= adcDClkN(i);
      asicAdc(i).chP   <= adcChP((i*8)+7 downto i*8);
      asicAdc(i).chN   <= adcChN((i*8)+7 downto i*8);
      
      U_AdcReadout : entity surf.Ad9249ReadoutGroup
      generic map (
         TPD_G             => TPD_G,
         NUM_CHANNELS_G    => 8,
         IODELAY_GROUP_G   => IODELAY_GROUP_G,
         IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G,
         ADC_INVERT_CH_G   => ADC_INVERT_CH_C(i)
      )
      port map (
         -- Master system clock, 125Mhz
         axilClk           => coreClk,
         axilRst           => coreRst,
         
         -- Axi Interface
         axilReadMaster    => mAxiReadMasters(ADC0_RD_AXI_INDEX_C+i),
         axilReadSlave     => mAxiReadSlaves(ADC0_RD_AXI_INDEX_C+i),
         axilWriteMaster   => mAxiWriteMasters(ADC0_RD_AXI_INDEX_C+i),
         axilWriteSlave    => mAxiWriteSlaves(ADC0_RD_AXI_INDEX_C+i),

         -- Reset for adc deserializer
         adcClkRst         => serdesReset,

         -- Serial Data from ADC
         adcSerial         => asicAdc(i),

         -- Deserialized ADC Data
         adcStreamClk      => coreClk,
         adcStreams        => iAdcStreams((i*8)+7 downto i*8)
      );
      
   end generate;
   
   
   monAdc.fClkP <= adcFClkP(2);
   monAdc.fClkN <= adcFClkN(2);
   monAdc.dClkP <= adcDClkP(2);
   monAdc.dClkN <= adcDClkN(2);
   monAdc.chP(3 downto 0) <= adcChP(19 downto 16);
   monAdc.chN(3 downto 0) <= adcChN(19 downto 16);
      
   U_MonAdcReadout : entity surf.Ad9249ReadoutGroup
   generic map (
      TPD_G             => TPD_G,
      NUM_CHANNELS_G    => 4,
      IODELAY_GROUP_G   => IODELAY_GROUP_G,
      IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G,
      ADC_INVERT_CH_G   => ADC2_INVERT_CH
   )
   port map (
      -- Master system clock, 125Mhz
      axilClk           => coreClk,
      axilRst           => coreRst,
      
      -- Axi Interface
      axilReadMaster    => mAxiReadMasters(ADC2_RD_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(ADC2_RD_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(ADC2_RD_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(ADC2_RD_AXI_INDEX_C),

      -- Reset for adc deserializer
      adcClkRst         => serdesReset,

      -- Serial Data from ADC
      adcSerial         => monAdc,

      -- Deserialized ADC Data
      adcStreamClk      => coreClk,
      adcStreams        => iAdcStreams(19 downto 16)
   );

   -- Give a special reset to the SERDES blocks when power
   -- is turned on to ADC card.
   U_AdcCardPowerUpRisingEdge : entity surf.SynchronizerEdge
   generic map (
      TPD_G       => TPD_G)
   port map (
      clk         => coreClk,
      dataIn      => adcCardPowerUp,
      risingEdge  => adcCardPowerUpEdge
   );
   U_AdcCardPowerUpReset : entity surf.RstSync
   generic map (
      TPD_G           => TPD_G,
      RELEASE_DELAY_G => 50
   )
   port map (
      clk      => coreClk,
      asyncRst => adcCardPowerUpEdge,
      syncRst  => serdesReset
   );
   
   --------------------------------------------
   -- ADC stream pattern tester              --
   --------------------------------------------
   
   U_AdcTester : entity surf.StreamPatternTester
   generic map (
      TPD_G             => TPD_G,
      NUM_CHANNELS_G    => 20
   )
   port map ( 
      -- Master system clock
      clk               => coreClk,
      rst               => coreRst,
      -- ADC data stream inputs
      adcStreams        => iAdcStreams,
      -- Axi Interface
      axilReadMaster  => mAxiReadMasters(ADCTEST_AXI_INDEX_C),
      axilReadSlave   => mAxiReadSlaves(ADCTEST_AXI_INDEX_C),
      axilWriteMaster => mAxiWriteMasters(ADCTEST_AXI_INDEX_C),
      axilWriteSlave  => mAxiWriteSlaves(ADCTEST_AXI_INDEX_C)
   );
   
   --------------------------------------------
   --     Fast ADC Config                    --
   --------------------------------------------
      
   U_AdcConf : entity surf.Ad9249ConfigNoPullup
   generic map (
      TPD_G             => TPD_G,
      CLK_PERIOD_G      => CLK_PERIOD_G,
      CLK_EN_PERIOD_G   => 20.0e-9,
      NUM_CHIPS_G       => 2
   )
   port map (
      axilClk           => coreClk,
      axilRst           => coreRst,
      
      axilReadMaster    => mAxiReadMasters(ADC_CFG_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(ADC_CFG_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(ADC_CFG_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(ADC_CFG_AXI_INDEX_C),
      
      adcSClk           => adcSpiClk,
      adcSDin           => adcSpiDataIn,
      adcSDout          => adcSpiDataOut,
      adcSDEn           => adcSpiDataEn,
      adcCsb            => iAdcSpiCsb,
      adcPdwn           => iAdcPdwn(1 downto 0)
   );
   
   adcSpiCsb <= iAdcSpiCsb(2 downto 0);
   adcPdwn <= iAdcPdwn(2 downto 0);
   
   adcStreams <= iAdcStreams;
   
   
end rtl;
