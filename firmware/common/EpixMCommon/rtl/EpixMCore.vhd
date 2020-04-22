-------------------------------------------------------------------------------
-- File       : EpixMCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SsiCmdMasterPkg.all;
use surf.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixMCore is
   generic (
      TPD_G             : time := 1 ns;
      PGP_VER           : string          := "PGP2B";       -- "PGP2B" or "PGP3"
      BUILD_INFO_G      : BuildInfoType;
      ADC0_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC1_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC2_INVERT_CH    : slv(7 downto 0) := "00000000";
      IODELAY_GROUP_G   : string          := "DEFAULT_GROUP";
      SIMULATION_G      : boolean         := false
   );
   port (
      -- Debugging IOs
      led                 : out slv(3 downto 0);
      -- Power enables
      digitalPowerEn      : out sl;
      analogPowerEn       : out sl;
      fpgaOutputEn        : out sl;
      ledEn               : out sl;
      -- Clocks and reset
      powerGood           : in  sl;
      gtRefClk0P          : in  sl;
      gtRefClk0N          : in  sl;
      -- SFP interfaces
      sfpDisable          : out sl;
      -- SFP TX/RX
      gtDataRxP           : in  sl;
      gtDataRxN           : in  sl;
      gtDataTxP           : out sl;
      gtDataTxN           : out sl;
      -- DAC
      dacSclk             : out sl;
      dacDin              : out sl;
      dacCs               : out slv(1 downto 0);
      -- External Signals
      runTrigger          : in  sl;
      daqTrigger          : in  sl;
      mpsOut              : out sl;
      triggerOut          : out sl;
      -- Slow ADC
      slowAdcRefClk       : out sl;
      slowAdcSclk         : out sl;
      slowAdcDin          : out sl;
      slowAdcCsb          : out sl;
      slowAdcDout         : in  sl;
      slowAdcDrdy         : in  sl;
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiDataIn        : in  sl;
      adcSpiDataOut       : out sl;
      adcSpiDataEn        : out sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn             : out slv(2 downto 0);
      -- Fast ADC readoutCh
      adcClk              : out sl;
      adcFClkP            : in  slv( 2 downto 0);
      adcFClkN            : in  slv( 2 downto 0);
      adcDClkP            : in  slv( 2 downto 0);
      adcDClkN            : in  slv( 2 downto 0);
      adcChP              : in  slv(19 downto 0);
      adcChN              : in  slv(19 downto 0);
      -- ASIC Control
      asicGR              : out sl;
      asicCk              : out sl;
      asicRst             : out sl;
      asicCdsBline        : out sl;
      asicRstComp         : out sl;
      asicSampleN         : out sl;
      asicDinjEn          : out sl;
      asicCKinjEn         : out sl;
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
   );
end EpixMCore;

architecture top_level of EpixMCore is
   
   constant AXI_CLK_FREQ_C : real := 100.000E+6;
   
   constant NUM_AXI_MASTERS_C    : natural := 7;

   constant AXI_VER_INDEX_C      : natural := 0;
   constant ASIC_INDEX_C         : natural := 1;
   constant PGPSTAT_INDEX_C      : natural := 2;
   constant MONADC_REG_INDEX_C   : natural := 3;
   constant ADC_INDEX_C          : natural := 4;
   constant BOOTMEM_INDEX_C      : natural := 5;
   constant MEM_LOG_INDEX_C      : natural := 6;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"00000000", 31, 24);

   signal sysClk      : sl;
   signal sysRst      : sl;
   signal pgpClk      : sl;
   signal pgpRst      : sl;
   
   signal iDelayCtrlClk : sl;
   signal iDelayCtrlRst : sl;
   
   -- AXI Signals
   signal axiReadMaster   : AxiReadMasterType;
   signal axiReadSlave    : AxiReadSlaveType;
   signal axiWriteMaster  : AxiWriteMasterType;
   signal axiWriteSlave   : AxiWriteSlaveType;
   
   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterArray(2 downto 0);
   signal sAxiReadSlave   : AxiLiteReadSlaveArray(2 downto 0);
   signal sAxiWriteMaster : AxiLiteWriteMasterArray(2 downto 0);
   signal sAxiWriteSlave  : AxiLiteWriteSlaveArray(2 downto 0);
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 

   -- AXI-Stream signals
   signal dataAxisMaster      : AxiStreamMasterType;
   signal dataAxisSlave       : AxiStreamSlaveType;
   signal scopeAxisMaster     : AxiStreamMasterType;
   signal scopeAxisSlave      : AxiStreamSlaveType;
   signal monitorAxisMaster   : AxiStreamMasterType;
   signal monitorAxisSlave    : AxiStreamSlaveType;
   signal monEnAxisMaster     : AxiStreamMasterType;
   
   signal envData             : Slv32Array(8 downto 0);
   
   
   -- Command interface
   signal swRun               : sl;
   signal pgpOpCode           : slv(7 downto 0);
   signal pgpOpCodeEn         : sl;
   
   signal delayCtrlRdy     : sl;
   
   -- Power up reset to SERDES block
   signal adcCardPowerUp     : sl;
   signal requestStartupCal  : sl;
   
   signal fpgaReload : sl;
   signal bootSck    : sl;
   
   signal slowAdcData : Slv24Array(8 downto 0);
   
   signal acqStart   : sl;
   
   signal mbRst    : sl;
   signal powerBad : sl;
   
   signal adcStreams          : AxiStreamMasterArray(19 downto 0);
   
   attribute keep : boolean;
   attribute keep of sysClk : signal is true;
   
begin

   
   -- Fixed state logic signals
   sfpDisable     <= '0';
   
   ------------------------------------------
   -- Generate clocks from 156.25 MHz PGP  --
   ------------------------------------------
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 100.00 MHz system clock (Modify AXI_CLK_FREQ_C when changed)
   U_CoreClockGen0 : entity surf.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 1,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 5,
      CLKFBOUT_MULT_F_G    => 32.0,    -- base 1000.0MHz
      CLKOUT0_DIVIDE_F_G   => 10.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => pgpRst,
      clkOut(0) => sysClk,
      rstOut(0) => sysRst,
      locked    => open
   );
   
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 200.0 MHz IDELAYCTRL clock
   U_CoreClockGen1 : entity surf.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 1,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 5,
      CLKFBOUT_MULT_F_G    => 32.0,    -- base 1000.0MHz
      CLKOUT0_DIVIDE_F_G   => 5.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => pgpRst,
      clkOut(0) => iDelayCtrlClk,
      rstOut(0) => iDelayCtrlRst,
      locked    => open
   );
   
   ---------------------
   -- Diagnostic LEDs --
   ---------------------
   led <= "0000";

   ---------------------
   -- PGP Front end   --
   ---------------------
   
   G_PGP2B : if PGP_VER = "PGP2B" generate
   
      U_PgpFrontEnd : entity work.PgpFrontEnd
      generic map (
         TPD_G          => TPD_G,
         SIMULATION_G   => SIMULATION_G
      )
      port map (
         -- GTX 7 Ports
         gtClkP      => gtRefClk0P,
         gtClkN      => gtRefClk0N,
         gtRxP       => gtDataRxP,
         gtRxN       => gtDataRxN,
         gtTxP       => gtDataTxP,
         gtTxN       => gtDataTxN,
         -- Input power status
         powerBad    => powerBad,
         -- Output reset
         pgpRst      => pgpRst,
         -- Output clocking
         pgpClk      => pgpClk,
         -- AXI clocking
         axiClk     => sysClk,
         axiRst     => sysRst,
         -- Axi Master Interface - Registers (axiClk domain)
         mAxiLiteReadMaster  => sAxiReadMaster(0),
         mAxiLiteReadSlave   => sAxiReadSlave(0),
         mAxiLiteWriteMaster => sAxiWriteMaster(0),
         mAxiLiteWriteSlave  => sAxiWriteSlave(0),
         -- Axi Slave Interface - PGP Status Registers (axiClk domain)
         sAxiLiteReadMaster  => mAxiReadMasters(PGPSTAT_INDEX_C),
         sAxiLiteReadSlave   => mAxiReadSlaves(PGPSTAT_INDEX_C),
         sAxiLiteWriteMaster => mAxiWriteMasters(PGPSTAT_INDEX_C),
         sAxiLiteWriteSlave  => mAxiWriteSlaves(PGPSTAT_INDEX_C),
         -- Streaming data Links (axiClk domain)      
         dataAxisMaster    => dataAxisMaster,
         dataAxisSlave     => dataAxisSlave,
         scopeAxisMaster   => scopeAxisMaster,
         scopeAxisSlave    => scopeAxisSlave,
         monitorAxisMaster => monitorAxisMaster,
         monitorAxisSlave  => monitorAxisSlave,
         -- Monitoring enable command incoming stream
         monEnAxisMaster   => monEnAxisMaster,
         -- Command interface
         swRun             => swRun,
         -- To access sideband commands
         pgpOpCode         => pgpOpCode,
         pgpOpCodeEn       => pgpOpCodeEn
      );
      powerBad <= not powerGood;
   
   end generate;
   
   G_PGP3 : if PGP_VER = "PGP3" generate
      
      U_Pgp3FrontEnd : entity work.Pgp3FrontEnd
      generic map (
         TPD_G             => TPD_G,
         SIMULATION_G      => SIMULATION_G,
         AXI_CLK_FREQ_G    => AXI_CLK_FREQ_C,
         AXI_BASE_ADDR_G   => AXI_CONFIG_C(PGPSTAT_INDEX_C).baseAddr
      )
      port map (
         -- GTX 7 Ports
         gtClkP      => gtRefClk0P,
         gtClkN      => gtRefClk0N,
         gtRxP       => gtDataRxP,
         gtRxN       => gtDataRxN,
         gtTxP       => gtDataTxP,
         gtTxN       => gtDataTxN,
         -- Input power status
         powerBad    => powerBad,
         -- Output reset
         pgpRst      => pgpRst,
         -- Output clocking
         pgpClk      => pgpClk,
         -- AXI clocking
         axiClk     => sysClk,
         axiRst     => sysRst,
         -- Axi Master Interface - Registers (axiClk domain)
         mAxiLiteReadMaster  => sAxiReadMaster(0),
         mAxiLiteReadSlave   => sAxiReadSlave(0),
         mAxiLiteWriteMaster => sAxiWriteMaster(0),
         mAxiLiteWriteSlave  => sAxiWriteSlave(0),
         -- Axi Slave Interface - PGP Status Registers (axiClk domain)
         sAxiLiteReadMaster  => mAxiReadMasters(PGPSTAT_INDEX_C),
         sAxiLiteReadSlave   => mAxiReadSlaves(PGPSTAT_INDEX_C),
         sAxiLiteWriteMaster => mAxiWriteMasters(PGPSTAT_INDEX_C),
         sAxiLiteWriteSlave  => mAxiWriteSlaves(PGPSTAT_INDEX_C),
         -- Streaming data Links (axiClk domain)      
         dataAxisMaster    => dataAxisMaster,
         dataAxisSlave     => dataAxisSlave,
         scopeAxisMaster   => scopeAxisMaster,
         scopeAxisSlave    => scopeAxisSlave,
         monitorAxisMaster => monitorAxisMaster,
         monitorAxisSlave  => monitorAxisSlave,
         -- Monitoring enable command incoming stream
         monEnAxisMaster   => monEnAxisMaster,
         -- Command interface
         swRun             => swRun,
         -- To access sideband commands
         pgpOpCode         => pgpOpCode,
         pgpOpCodeEn       => pgpOpCodeEn
      );
      powerBad <= not powerGood;
   
   end generate;
   
   ---------------------------------------------
   -- Microblaze based ePix Startup Sequencer --
   ---------------------------------------------
   U_MbRst : entity surf.PwrUpRst
      port map (
         clk      => sysClk,
         arst     => sysRst,
         rstOut   => mbRst
      ); 
   
   U_CPU : entity surf.MicroblazeBasicCoreWrapper
   generic map (
      TPD_G            => TPD_G)
   port map (
      -- Master AXI-Lite Interface: [0x00000000:0x7FFFFFFF]
      mAxilWriteMaster => sAxiWriteMaster(1),
      mAxilWriteSlave  => sAxiWriteSlave(1),
      mAxilReadMaster  => sAxiReadMaster(1),
      mAxilReadSlave   => sAxiReadSlave(1),
      -- Interrupt Interface
      interrupt(7 downto 2)   => "000000",
      interrupt(1)            => acqStart,
      interrupt(0)            => requestStartupCal,
      -- Clock and Reset
      clk              => sysClk,
      rst              => mbRst
   );
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control
   -- Master 0 : PGP front end controller
   -- Master 1 : Microblaze startup controller
   -- Master 2 : SACI multipixel controller
   --------------------------------------------
   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
   generic map (
      NUM_SLAVE_SLOTS_G  => 3,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CONFIG_C)
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
      axiClkRst           => sysRst
   );
   
   --------------------------------------------
   --     ASIC Core                          --
   --------------------------------------------
   U_AsicCore : entity work.AsicCore
   generic map (
      TPD_G                => TPD_G,
      FPGA_BASE_CLOCK_G    => std_logic_vector(to_unsigned(natural(round(AXI_CLK_FREQ_C)), 32)),
      AXI_CLK_FREQ_G       => AXI_CLK_FREQ_C,
      AXI_BASE_ADDR_G      => AXI_CONFIG_C(ASIC_INDEX_C).baseAddr
   )
   port map (
      -- Clock and Reset
      sysClk               => sysClk,
      sysRst               => sysRst,
      -- ADC signals
      adcStreams(0)        => adcStreams(3),    -- ASIC output
      adcStreams(1)        => adcStreams(8),    -- ASIC comparator
      -- AXI-Lite Register Interface (sysClk domain)
      mAxilReadMaster      => mAxiReadMasters(ASIC_INDEX_C),
      mAxilReadSlave       => mAxiReadSlaves(ASIC_INDEX_C),
      mAxilWriteMaster     => mAxiWriteMasters(ASIC_INDEX_C),
      mAxilWriteSlave      => mAxiWriteSlaves(ASIC_INDEX_C),
      -- ASIC Control
      asicGR               => asicGR      ,
      asicCk               => asicCk      ,
      asicRst              => asicRst     ,
      asicCdsBline         => asicCdsBline,
      asicRstComp          => asicRstComp ,
      asicSampleN          => asicSampleN ,
      asicDinjEn           => asicDinjEn  ,
      asicCKinjEn          => asicCKinjEn ,
      -- ADC clock
      adcClk               => adcClk,
      -- DACs
      dacSclk             => dacSclk,
      dacDin              => dacDin ,
      dacCs               => dacCs  ,
      -- External Signals
      runTrigger           => runTrigger,
      daqTrigger           => daqTrigger,
      mpsOut               => mpsOut    ,
      triggerOut           => triggerOut,
      -- SW and fiber trigger
      swRun                => swRun,
      pgpOpCode            => pgpOpCode,
      pgpOpCodeEn          => pgpOpCodeEn,
      -- Power enables
      digitalPowerEn       => digitalPowerEn   ,
      analogPowerEn        => analogPowerEn    ,
      fpgaOutputEn         => fpgaOutputEn     ,
      ledEn                => ledEn            ,
      adcCardPowerUp       => adcCardPowerUp   ,
      delayCtrlRdy         => delayCtrlRdy     ,
      requestStartupCal    => requestStartupCal,
      acqStartOut          => acqStart,
      -- env data
      envData              => envData,
      -- Image Data Stream
      dataAxisMaster       => dataAxisMaster,
      dataAxisSlave        => dataAxisSlave ,
      -- Scope Data Stream
      scopeAxisMaster      => scopeAxisMaster,
      scopeAxisSlave       => scopeAxisSlave
   );
   
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   U_AdcPhyTop : entity work.AdcPhyTop
   generic map (
      TPD_G               => TPD_G,
      CLK_PERIOD_G        => 1.0/AXI_CLK_FREQ_C,
      IDELAYCTRL_FREQ_G   => 200.0,
      AXI_BASE_ADDR_G     => AXI_CONFIG_C(ADC_INDEX_C).baseAddr,
      ADC0_INVERT_CH      => ADC0_INVERT_CH,
      ADC1_INVERT_CH      => ADC1_INVERT_CH,
      ADC2_INVERT_CH      => ADC2_INVERT_CH,
      IODELAY_GROUP_G     => IODELAY_GROUP_G
   )
   port map (
      -- Clocks and reset
      coreClk             => sysClk,
      coreRst             => sysRst,
      delayCtrlClk        => iDelayCtrlClk,
      delayCtrlRst        => iDelayCtrlRst,
      delayCtrlRdy        => delayCtrlRdy,
      adcCardPowerUp      => adcCardPowerUp,
      -- AXI Lite Bus
      axilReadMaster      => mAxiReadMasters(ADC_INDEX_C),
      axilReadSlave       => mAxiReadSlaves(ADC_INDEX_C),
      axilWriteMaster     => mAxiWriteMasters(ADC_INDEX_C),
      axilWriteSlave      => mAxiWriteSlaves(ADC_INDEX_C),
      -- Fast ADC Control
      adcSpiClk           => adcSpiClk,
      adcSpiDataIn        => adcSpiDataIn,
      adcSpiDataOut       => adcSpiDataOut,
      adcSpiDataEn        => adcSpiDataEn,
      adcSpiCsb           => adcSpiCsb,
      adcPdwn             => adcPdwn,
      -- Fast ADC readoutCh
      adcFClkP            => adcFClkP,
      adcFClkN            => adcFClkN,
      adcDClkP            => adcDClkP,
      adcDClkN            => adcDClkN,
      adcChP              => adcChP,
      adcChN              => adcChN,
      -- ADC data output
      adcStreams          => adcStreams
   );
   
   
   --------------------------------------------
   --     Slow ADC Readout ADC gen 2         --
   -------------------------------------------- 
   U_AdcCntrl: entity work.SlowAdcCntrlAxi
   generic map (
      SYS_CLK_PERIOD_G  => 1.0/AXI_CLK_FREQ_C,	   -- 100MHz
      ADC_CLK_PERIOD_G  => 200.0E-9,	-- 5MHz
      SPI_SCLK_PERIOD_G => 2.0E-6  	   -- 500kHz
   )
   port map ( 
      -- Master system clock
      sysClk            => sysClk,
      sysClkRst         => sysRst,
      
      -- Trigger Control
      adcStart          => acqStart,
      
      -- Monitoring enable command incoming stream
      monEnAxisMaster   => monEnAxisMaster,
      
      -- Env data outputs
      envData           => envData,
      
      -- AXI lite slave port for register access
      axilClk           => sysClk,
      axilRst           => sysRst,
      sAxilWriteMaster  => mAxiWriteMasters(MONADC_REG_INDEX_C),
      sAxilWriteSlave   => mAxiWriteSlaves(MONADC_REG_INDEX_C),
      sAxilReadMaster   => mAxiReadMasters(MONADC_REG_INDEX_C),
      sAxilReadSlave    => mAxiReadSlaves(MONADC_REG_INDEX_C),
      
      -- AXI stream output
      axisClk           => sysClk,
      axisRst           => sysRst,
      mAxisMaster       => monitorAxisMaster,
      mAxisSlave        => monitorAxisSlave,

      -- ADC Control Signals
      adcRefClk         => slowAdcRefClk,
      adcDrdy           => slowAdcDrdy,
      adcSclk           => slowAdcSclk,
      adcDout           => slowAdcDout,
      adcCsL            => slowAdcCsb,
      adcDin            => slowAdcDin
   );
   
   ---------------------------------------------
   -- Microblaze log memory                   --
   ---------------------------------------------
   U_LogMem : entity surf.AxiDualPortRam
   generic map (
      TPD_G            => TPD_G,
      ADDR_WIDTH_G     => 10,
      DATA_WIDTH_G     => 32
   )
   port map (
      axiClk         => sysClk,
      axiRst         => sysRst,
      axiReadMaster  => mAxiReadMasters(MEM_LOG_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(MEM_LOG_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(MEM_LOG_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(MEM_LOG_INDEX_C),
      clk            => '0',
      en             => '1',
      we             => '0',
      weByte         => (others => '0'),
      rst            => '0',
      addr           => (others => '0'),
      din            => (others => '0'),
      dout           => open,
      axiWrValid     => open,
      axiWrStrobe    => open,
      axiWrAddr      => open,
      axiWrData      => open
   );
   
   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity surf.AxiVersion
   generic map (
      TPD_G           => TPD_G,
      BUILD_INFO_G    => BUILD_INFO_G,
      EN_DEVICE_DNA_G => false)   
   port map (
      fpgaReload     => fpgaReload,
      -- AXI-Lite Register Interface
      axiReadMaster  => mAxiReadMasters(AXI_VER_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(AXI_VER_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(AXI_VER_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(AXI_VER_INDEX_C),
      -- Clocks and Resets
      axiClk         => sysClk,
      axiRst         => sysRst
   );

   ---------------------
   -- FPGA Reboot Module
   ---------------------
   U_Iprog7Series : entity surf.Iprog7Series
   generic map (
      TPD_G => TPD_G)   
   port map (
      clk         => sysClk,
      rst         => sysRst,
      start       => fpgaReload,
      bootAddress => X"00000000"
   );
   
   -----------------------------------------------------
   -- Using the STARTUPE2 to access the FPGA's CCLK port
   -----------------------------------------------------
   U_STARTUPE2 : STARTUPE2
   port map (
      CFGCLK    => open,             -- 1-bit output: Configuration main clock output
      CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
      EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ      => open,             -- 1-bit output: PROGRAM request to fabric output
      CLK       => '0',              -- 1-bit input: User start-up clock input
      GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK      => '0',              -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO  => bootSck,          -- 1-bit input: User CCLK input
      USRCCLKTS => '0',              -- 1-bit input: User CCLK 3-state enable input
      USRDONEO  => '1',              -- 1-bit input: User DONE pin output control
      USRDONETS => '1'               -- 1-bit input: User DONE 3-state enable output            
   );
   
   --------------------
   -- Boot Flash Module
   --------------------
   U_AxiMicronN25QCore : entity surf.AxiMicronN25QCore
   generic map (
      TPD_G          => TPD_G,
      AXI_CLK_FREQ_G => AXI_CLK_FREQ_C,   -- units of Hz
      SPI_CLK_FREQ_G => 25.0E+6     -- units of Hz
   )
   port map (
      -- FLASH Memory Ports
      csL            => bootCsL,
      sck            => bootSck,
      mosi           => bootMosi,
      miso           => bootMiso,
      -- AXI-Lite Register Interface
      axiReadMaster  => mAxiReadMasters(BOOTMEM_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(BOOTMEM_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(BOOTMEM_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(BOOTMEM_INDEX_C),
      -- Clocks and Resets
      axiClk         => sysClk,
      axiRst         => sysRst
   );
   
end top_level;
