-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixM32ArrayCore.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-17
-- Last update: 2016-08-07
-- Platform   : Vivado 2016.1
-- Standard   : VHDL'93/02
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

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixM32ArrayCore is
   generic (
      TPD_G             : time := 1 ns;
      FPGA_BASE_CLOCK_G : slv(31 downto 0);
      BUILD_INFO_G      : BuildInfoType;
      ADC0_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC1_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC2_INVERT_CH    : slv(7 downto 0) := "00000000";
      IODELAY_GROUP_G   : string          := "DEFAULT_GROUP"
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
      -- External Signals
      runTrigger          : in  sl;
      daqTrigger          : in  sl;
      mpsOut              : out sl;
      triggerOut          : out sl;
      -- Board IDs
      serialIdIo          : inout slv(1 downto 0) := "00";
      -- Slow ADC
      slowAdcRefClk       : out sl;
      slowAdcSclk         : out sl;
      slowAdcDin          : out sl;
      slowAdcCsb          : out sl;
      slowAdcDout         : in  sl;
      slowAdcDrdy         : in  sl;
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiData          : inout sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn             : out slv(2 downto 0);
      -- Fast ADC readoutCh
      adcClkP             : out slv( 0 downto 0);
      adcClkN             : out slv( 0 downto 0);
      adcFClkP            : in  slv( 1 downto 0);
      adcFClkN            : in  slv( 1 downto 0);
      adcDClkP            : in  slv( 1 downto 0);
      adcDClkN            : in  slv( 1 downto 0);
      adcChP              : in  slv(15 downto 0);
      adcChN              : in  slv(15 downto 0);
      -- ASIC Control
      asicGlblRst         : out sl;   -- to ASIC
      asicR1              : out sl;   -- to ASIC
      asicR2              : out sl;   -- to ASIC
      asicR3              : out sl;   -- to ASIC
      asicClk             : out sl;   -- to ASIC
      -- ASIC digital data
      asicDout            : in  slv(3 downto 0) := "0000";
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
   );
end EpixM32ArrayCore;

architecture top_level of EpixM32ArrayCore is

   signal coreClk     : sl;
   signal coreClkRst  : sl;
   signal pgpClk      : sl;
   signal sysRst      : sl;
   signal axiRst      : sl;
   signal heartBeat   : sl;
   signal txLinkReady : sl;
   signal rxLinkReady : sl;
   signal monitorTrig : sl;

   signal adcClk      : sl := '0';
   
   signal iDelayCtrlClk : sl;
   signal iDelayCtrlRst : sl;
   
   signal pgpRxOut      : Pgp2bRxOutType;
   
   -- AXI Signals
   signal axiReadMaster   : AxiReadMasterType;
   signal axiReadSlave    : AxiReadSlaveType;
   signal axiWriteMaster  : AxiWriteMasterType;
   signal axiWriteSlave   : AxiWriteSlaveType;
   
   
   constant NUM_AXI_MASTER_SLOTS_C : natural := 12;
   constant NUM_AXI_SLAVE_SLOTS_C : natural := 2;
   
   constant VERSION_AXI_INDEX_C     : natural := 0;
   constant REG_AXI_INDEX_C         : natural := 1;
   constant TRIG_REG_AXI_INDEX_C    : natural := 2;
   constant MONADC_REG_AXI_INDEX_C  : natural := 3;
   constant PGPSTAT_AXI_INDEX_C     : natural := 4;
   constant BOOTMEM_AXI_INDEX_C     : natural := 5;
   constant ADCTEST_AXI_INDEX_C     : natural := 6;
   constant ADC0_RD_AXI_INDEX_C     : natural := 7;
   constant ADC1_RD_AXI_INDEX_C     : natural := 8;
   constant ADC_CFG_AXI_INDEX_C     : natural := 9;
   constant MEM_LOG_AXI_INDEX_C     : natural := 10;
   constant SCOPE_REG_AXI_INDEX_C   : natural := 11;
   
   constant VERSION_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00000000";
   constant REG_AXI_BASE_ADDR_C        : slv(31 downto 0) := X"01000000";
   constant TRIG_REG_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"02000000";
   constant MONADC_REG_AXI_BASE_ADDR_C : slv(31 downto 0) := X"03000000";
   constant PGPSTAT_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"04000000";
   constant BOOTMEM_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"05000000";
   constant ADCTEST_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"06000000";
   constant ADC0_RD_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"07000000";
   constant ADC1_RD_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"08000000";
   constant ADC_CFG_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"09000000";
   constant MEM_LOG_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"0A000000";
   constant SCOPE_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"0B000000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      VERSION_AXI_INDEX_C      => (
         baseAddr             => VERSION_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      REG_AXI_INDEX_C      => ( 
         baseAddr             => REG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      TRIG_REG_AXI_INDEX_C      => ( 
         baseAddr             => TRIG_REG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      MONADC_REG_AXI_INDEX_C      => ( 
         baseAddr             => MONADC_REG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      PGPSTAT_AXI_INDEX_C     => (
         baseAddr             => PGPSTAT_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      BOOTMEM_AXI_INDEX_C      => ( 
         baseAddr             => BOOTMEM_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADCTEST_AXI_INDEX_C      => ( 
         baseAddr             => ADCTEST_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADC0_RD_AXI_INDEX_C      => ( 
         baseAddr             => ADC0_RD_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADC1_RD_AXI_INDEX_C      => ( 
         baseAddr             => ADC1_RD_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADC_CFG_AXI_INDEX_C      => ( 
         baseAddr             => ADC_CFG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      MEM_LOG_AXI_INDEX_C      => ( 
         baseAddr             => MEM_LOG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      SCOPE_REG_AXI_INDEX_C      => ( 
         baseAddr             => SCOPE_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF")
   );
   
   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiReadSlave   : AxiLiteReadSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteMaster : AxiLiteWriteMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteSlave  : AxiLiteWriteSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 

   -- AXI-Stream signals
   signal doutAxisMaster      : AxiStreamMasterArray(1 downto 0);
   signal doutAxisSlave       : AxiStreamSlaveArray(1 downto 0);
   signal dataAxisMaster      : AxiStreamMasterType;
   signal dataAxisSlave       : AxiStreamSlaveType;
   signal scopeAxisMaster     : AxiStreamMasterType;
   signal scopeAxisSlave      : AxiStreamSlaveType;
   signal monitorAxisMaster   : AxiStreamMasterType;
   signal monitorAxisSlave    : AxiStreamSlaveType;
   signal monEnAxisMaster     : AxiStreamMasterType;
   
   
   -- Command interface
   signal ssiCmd           : SsiCmdMasterType;
   
   signal rxReady          : sl;
   signal txReady          : sl;
   
   -- ADC signals
   signal adcValid         : slv(19 downto 0);
   signal adcData          : Slv16Array(19 downto 0);
   signal adcStreams       : AxiStreamMasterArray(19 downto 0);
   
   -- Triggers and associated signals
   signal iDaqTrigger      : sl;
   signal iRunTrigger      : sl;
   signal opCode           : slv(7 downto 0);
   signal pgpOpCodeOneShot : sl;
   
   -- Interfaces between blocks
   signal acqStart           : sl;
   signal acqBusy            : sl;
   signal dataSend           : sl;
   signal readDone           : sl;
   signal readValidA0        : sl;
   signal readValidA1        : sl;
   signal readValidA2        : sl;
   signal readValidA3        : sl;
   signal adcPulse           : sl;
   signal readTps            : sl;
   signal saciPrepReadoutReq : sl;
   signal saciPrepReadoutAck : sl;
   
   -- Power up reset to SERDES block
   signal adcCardPowerUp     : sl;
   signal adcCardPowerUpEdge : sl;
   signal serdesReset        : sl;
   
   -- ASIC signals
   signal iAsicGlblRst    : sl;
   signal iAsicR1         : sl;
   signal iAsicR2         : sl;
   signal iAsicR3         : sl;
   signal iAsicClk        : sl;
   signal iAsicStart      : sl;
   signal iAsicSample     : sl;
   signal iAsicReady      : sl;
   signal iAsicReady0     : sl;
   signal iAsicReady1     : sl;
   
   signal fpgaReload : sl;
   signal bootSck    : sl;
   
   signal slowAdcData : Slv24Array(8 downto 0);
   
   signal asicAdc    : Ad9249SerialGroupArray(1 downto 0);
   
   signal monTrigCnt : integer;
   
   signal refClk     : sl;
   signal ddrClk     : sl;
   signal ddrRst     : sl;
   signal calibComplete : sl;
   
   signal iAdcSpiCsb : slv(3 downto 0);
   signal iAdcPdwn   : slv(3 downto 0);
   
   signal doutOut    : Slv2Array(15 downto 0);
   signal doutRd     : slv(15 downto 0);
   signal doutValid  : slv(15 downto 0);
   
   constant DDR_AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 30,
      DATA_BYTES_C => 16,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);
   
   constant START_ADDR_C : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');
   
   constant ADC_INVERT_CH_C : Slv8Array(1 downto 0) := (
      0 => ADC0_INVERT_CH,
      1 => ADC1_INVERT_CH
   );
   
   signal tgOutMux         : sl;
   signal mpsOutMux        : sl;
   
   signal powerEnable      : slv(2 downto 0);
   signal tixelDbgSel1     : slv(4 downto 0);
   signal tixelDbgSel2     : slv(4 downto 0);
   
   attribute keep : boolean;
   attribute keep of coreClk : signal is true;
   attribute keep of acqStart : signal is true;
   attribute keep of dataSend : signal is true;
   
   attribute IODELAY_GROUP : string;
   attribute IODELAY_GROUP of U_IDelayCtrl : label is IODELAY_GROUP_G;
   
begin

   -- Map out power enables
   digitalPowerEn <= powerEnable(0);
   analogPowerEn  <= powerEnable(1);
   fpgaOutputEn   <= powerEnable(2);
   ledEn          <= '0';
   -- Fixed state logic signals
   sfpDisable     <= '0';
   -- Triggers in
   iRunTrigger    <= runTrigger;
   iDaqTrigger    <= daqTrigger;
   -- Triggers out
   triggerOut     <= tgOutMux;
   mpsOut         <= mpsOutMux;
   -- ASIC signals
   asicGlblRst <= iAsicGlblRst;
   asicR1      <= iAsicR1;
   asicR2      <= iAsicR2;
   asicR3      <= iAsicR3;
   asicClk     <= iAsicClk;
   
   tgOutMux <= 
      acqStart          when tixelDbgSel1 = "00000" else
      adcClk            when tixelDbgSel1 = "00001" else
      iAsicGlblRst      when tixelDbgSel1 = "00010" else
      iAsicR1           when tixelDbgSel1 = "00011" else
      iAsicR2           when tixelDbgSel1 = "00100" else
      iAsicR3           when tixelDbgSel1 = "00101" else
      iAsicClk          when tixelDbgSel1 = "00110" else
      iAsicStart        when tixelDbgSel1 = "00111" else
      iAsicSample       when tixelDbgSel1 = "01000" else
      iAsicReady        when tixelDbgSel1 = "01001" else
      '0';   
   
   mpsOutMux <=
      acqStart          when tixelDbgSel2 = "00000" else
      adcClk            when tixelDbgSel2 = "00001" else
      iAsicGlblRst      when tixelDbgSel2 = "00010" else
      iAsicR1           when tixelDbgSel2 = "00011" else
      iAsicR2           when tixelDbgSel2 = "00100" else
      iAsicR3           when tixelDbgSel2 = "00101" else
      iAsicClk          when tixelDbgSel2 = "00110" else
      iAsicStart        when tixelDbgSel2 = "00111" else
      iAsicSample       when tixelDbgSel2 = "01000" else
      iAsicReady        when tixelDbgSel1 = "01001" else
      '0';   
   

   -- Temporary one-shot for grabbing PGP op code
   U_OpCodeEnOneShot : entity work.SynchronizerOneShot
   generic map (
      TPD_G           => TPD_G,
      RST_POLARITY_G  => '1',
      RST_ASYNC_G     => false,
      BYPASS_SYNC_G   => true,
      RELEASE_DELAY_G => 10,
      IN_POLARITY_G   => '1',
      OUT_POLARITY_G  => '1')
   port map (
      clk     => pgpClk,
      rst     => '0',
      dataIn  => pgpRxOut.opCodeEn,
      dataOut => pgpOpCodeOneShot
   );
   
   ------------------------------------------
   -- Generate clocks from 156.25 MHz PGP  --
   ------------------------------------------
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 100.00 MHz system clock
   -- clkOut(1) : 200.00 MHz IDELAYCTRL clock
   U_CoreClockGen : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 2,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 5,
      CLKFBOUT_MULT_F_G    => 32.0,
      CLKOUT0_DIVIDE_F_G   => 10.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5,
      CLKOUT1_DIVIDE_G     => 5,
      CLKOUT1_PHASE_G      => 0.0,
      CLKOUT1_DUTY_CYCLE_G => 0.5,
      CLKOUT1_RST_HOLD_G   => 32
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => coreClk,
      clkOut(1) => iDelayCtrlClk,
      rstOut(0) => coreClkRst,
      rstOut(1) => iDelayCtrlRst,
      locked    => open
   );
   
   ---------------------
   -- Diagnostic LEDs --
   ---------------------
   led(3) <= powerEnable(0) and powerEnable(1) and powerEnable(2);
   led(2) <= rxReady;
   led(1) <= txReady;
   led(0) <= heartBeat;
   ---------------------
   -- Heart beat LED  --
   ---------------------
   U_Heartbeat : entity work.Heartbeat
   generic map(
      PERIOD_IN_G => 10.0E-9
   )   
   port map (
      clk => coreClk,
      o   => heartBeat
   );

   ---------------------
   -- PGP Front end   --
   ---------------------
   U_PgpFrontEnd : entity work.PgpFrontEnd
   port map (
      -- GTX 7 Ports
      gtClkP      => gtRefClk0P,
      gtClkN      => gtRefClk0N,
      gtRxP       => gtDataRxP,
      gtRxN       => gtDataRxN,
      gtTxP       => gtDataTxP,
      gtTxN       => gtDataTxN,
      -- Input power status
      powerBad    => not(powerGood),
      -- Output reset
      pgpRst      => sysRst,
      -- Output status
      rxLinkReady => rxReady,
      txLinkReady => txReady,
      -- Output clocking
      pgpClk      => pgpClk,
      refClk      => refClk,
      -- AXI clocking
      axiClk     => coreClk,
      axiRst     => axiRst,
      -- Axi Master Interface - Registers (axiClk domain)
      mAxiLiteReadMaster  => sAxiReadMaster(0),
      mAxiLiteReadSlave   => sAxiReadSlave(0),
      mAxiLiteWriteMaster => sAxiWriteMaster(0),
      mAxiLiteWriteSlave  => sAxiWriteSlave(0),
      -- Axi Slave Interface - PGP Status Registers (axiClk domain)
      sAxiLiteReadMaster  => mAxiReadMasters(PGPSTAT_AXI_INDEX_C),
      sAxiLiteReadSlave   => mAxiReadSlaves(PGPSTAT_AXI_INDEX_C),
      sAxiLiteWriteMaster => mAxiWriteMasters(PGPSTAT_AXI_INDEX_C),
      sAxiLiteWriteSlave  => mAxiWriteSlaves(PGPSTAT_AXI_INDEX_C),
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
      ssiCmd            => ssiCmd,
      -- Sideband interface
      pgpRxOut          => pgpRxOut
   );
   
   ---------------------------------------------
   -- Microblaze based ePix Startup Sequencer --
   ---------------------------------------------
   U_CPU : entity work.MicroblazeBasicCoreWrapper
   generic map (
      TPD_G            => TPD_G)
   port map (
      -- Master AXI-Lite Interface: [0x00000000:0x7FFFFFFF]
      mAxilWriteMaster => sAxiWriteMaster(1),
      mAxilWriteSlave  => sAxiWriteSlave(1),
      mAxilReadMaster  => sAxiReadMaster(1),
      mAxilReadSlave   => sAxiReadSlave(1),
      -- Interrupt Interface
      interrupt(7 downto 0)   => "00000000",
      -- Clock and Reset
      clk              => coreClk,
      rst              => axiRst
   );
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control
   -- Master 0 : PGP front end controller
   -- Master 1 : Microblaze startup controller
   --------------------------------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
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
      axiClk              => coreClk,
      axiClkRst           => axiRst
   );
   
   --------------------------------------------
   --     Master Register Controller         --
   --------------------------------------------   
   
   U_RegControlM : entity work.RegControlM
   generic map (
      TPD_G                => TPD_G,
      BUILD_INFO_G         => BUILD_INFO_G,
      CLK_PERIOD_G         => 10.0e-9
   )
   port map (
      axiClk         => coreClk,
      axiRst         => axiRst,
      sysRst         => sysRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(REG_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(REG_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(REG_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(REG_AXI_INDEX_C),
      -- Register Inputs/Outputs (axiClk domain)
      powerEn        => powerEnable,
      dbgSel1        => tixelDbgSel1,
      dbgSel2        => tixelDbgSel2,
      -- 1-wire board ID interfaces
      serialIdIo     => serialIdIo,
      -- fast ADC clock
      adcClk         => adcClk,
      -- ASICs acquisition signals
      acqStart       => acqStart,
      asicGlblRst    => iAsicGlblRst,
      asicR1         => iAsicR1,
      asicR2         => iAsicR2,
      asicR3         => iAsicR3,
      asicClk        => iAsicClk,
      asicStart      => iAsicStart,
      asicSample     => iAsicSample,
      asicReady      => iAsicReady
   );
   
   ---------------------
   -- Acquisition control    --
   ---------------------
   U_Acq0ControlM : entity work.AcqControlM
   generic map (
      CHANNEL_G      => "0000"
   )
   port map (
      clk            => coreClk,
      rst            => axiRst,
      adcData        => adcData(3),
      adcValid       => adcValid(3),
      asicStart      => iAsicStart,
      asicSample     => iAsicSample,
      asicReady      => iAsicReady0,
      asicGlblRst    => iAsicGlblRst,
      axisClk        => coreClk,
      axisRst        => axiRst,
      axisMaster     => doutAxisMaster(0),
      axisSlave      => doutAxisSlave(0)
   );
   
   U_Acq1ControlM : entity work.AcqControlM
   generic map (
      CHANNEL_G      => "0001"
   )
   port map (
      clk            => coreClk,
      rst            => axiRst,
      adcData        => adcData(8),
      adcValid       => adcValid(8),
      asicStart      => iAsicStart,
      asicSample     => iAsicSample,
      asicReady      => iAsicReady1,
      asicGlblRst    => iAsicGlblRst,
      axisClk        => coreClk,
      axisRst        => axiRst,
      axisMaster     => doutAxisMaster(1),
      axisSlave      => doutAxisSlave(1)
   );
   
   iAsicReady <= iAsicReady0 and iAsicReady1;
   
   U_AxiStreamMux : entity work.AxiStreamMux
   generic map(
      NUM_SLAVES_G   => 2
   )
   port map(
      -- Clock and reset
      axisClk        => coreClk,
      axisRst        => axiRst,
      -- Slaves
      sAxisMasters   => doutAxisMaster,
      sAxisSlaves    => doutAxisSlave,
      -- Master
      mAxisMaster    => dataAxisMaster,
      mAxisSlave     => dataAxisSlave
      
   );

   ---------------------
   -- Trig control    --
   ---------------------
   U_TrigControl : entity work.TrigControlAxi
   port map (
      -- Trigger outputs
      sysClk         => coreClk,
      sysRst         => axiRst,
      acqStart       => acqStart,
      dataSend       => dataSend,
      
      -- External trigger inputs
      runTrigger     => iRunTrigger,
      daqTrigger     => iDaqTrigger,
      
      -- PGP clocks and reset
      pgpClk         => pgpClk,
      pgpClkRst      => sysRst,
      -- SW trigger in (from VC)
      ssiCmd         => ssiCmd,
      -- PGP RxOutType (to trigger from sideband)
      pgpRxOut       => pgpRxOut,
      -- Opcode associated with this trigger
      opCodeOut      => opCode,
      
      -- AXI lite slave port for register access
      axilClk           => coreClk,
      axilRst           => axiRst,
      sAxilWriteMaster  => mAxiWriteMasters(TRIG_REG_AXI_INDEX_C),
      sAxilWriteSlave   => mAxiWriteSlaves(TRIG_REG_AXI_INDEX_C),
      sAxilReadMaster   => mAxiReadMasters(TRIG_REG_AXI_INDEX_C),
      sAxilReadSlave    => mAxiReadSlaves(TRIG_REG_AXI_INDEX_C)
   );
   
   
   
   GenAdcStr : for i in 0 to 19 generate 
      adcData(i)  <= adcStreams(i).tData(15 downto 0);
      adcValid(i) <= adcStreams(i).tValid;
   end generate;
   
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   -- ADC Clock outputs
   U_AdcClk0 : OBUFDS port map ( I => adcClk, O => adcClkP(0), OB => adcClkN(0) );
   
   -- Tap delay calibration  
   U_IDelayCtrl : IDELAYCTRL
   port map (
      REFCLK => iDelayCtrlClk,
      RST    => iDelayCtrlRst,
      RDY    => open
   );
   
   G_AdcReadout : for i in 0 to 1 generate 
   
      asicAdc(i).fClkP <= adcFClkP(i);
      asicAdc(i).fClkN <= adcFClkN(i);
      asicAdc(i).dClkP <= adcDClkP(i);
      asicAdc(i).dClkN <= adcDClkN(i);
      asicAdc(i).chP   <= adcChP((i*8)+7 downto i*8);
      asicAdc(i).chN   <= adcChN((i*8)+7 downto i*8);
      
      U_AdcReadout : entity work.Ad9249ReadoutGroup
      generic map (
         TPD_G             => TPD_G,
         NUM_CHANNELS_G    => 8,
         IODELAY_GROUP_G   => IODELAY_GROUP_G,
         IDELAYCTRL_FREQ_G => 200.0,
         ADC_INVERT_CH_G   => ADC_INVERT_CH_C(i)
      )
      port map (
         -- Master system clock, 125Mhz
         axilClk           => coreClk,
         axilRst           => axiRst,
         
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
         adcStreams        => adcStreams((i*8)+7 downto i*8)
      );
      
   end generate;
   -- monitoring ADC not used
   adcStreams(19 downto 16) <= (others=>AXI_STREAM_MASTER_INIT_C);

   -- Give a special reset to the SERDES blocks when power
   -- is turned on to ADC card.
   adcCardPowerUp <= powerEnable(0) and powerEnable(1) and powerEnable(2);
   U_AdcCardPowerUpRisingEdge : entity work.SynchronizerEdge
   generic map (
      TPD_G       => TPD_G)
   port map (
      clk         => coreClk,
      dataIn      => adcCardPowerUp,
      risingEdge  => adcCardPowerUpEdge
   );
   U_AdcCardPowerUpReset : entity work.RstSync
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
   
   U_AdcTester : entity work.StreamPatternTester
   generic map (
      TPD_G             => TPD_G,
      NUM_CHANNELS_G    => 16
   )
   port map ( 
      -- Master system clock
      clk               => coreClk,
      rst               => axiRst,
      -- ADC data stream inputs
      adcStreams        => adcStreams(15 downto 0),
      -- Axi Interface
      axilReadMaster  => mAxiReadMasters(ADCTEST_AXI_INDEX_C),
      axilReadSlave   => mAxiReadSlaves(ADCTEST_AXI_INDEX_C),
      axilWriteMaster => mAxiWriteMasters(ADCTEST_AXI_INDEX_C),
      axilWriteSlave  => mAxiWriteSlaves(ADCTEST_AXI_INDEX_C)
   );
   
   --------------------------------------------
   --     Fast ADC Config                    --
   --------------------------------------------
      
   U_AdcConf : entity work.Ad9249Config
   generic map (
      TPD_G             => TPD_G,
      AXIL_CLK_PERIOD_G => 10.0e-9,
      NUM_CHIPS_G       => 2,
      AXIL_ERR_RESP_G   => AXI_RESP_OK_C
   )
   port map (
      axilClk           => coreClk,
      axilRst           => axiRst,
      
      axilReadMaster    => mAxiReadMasters(ADC_CFG_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(ADC_CFG_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(ADC_CFG_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(ADC_CFG_AXI_INDEX_C),

      adcPdwn           => iAdcPdwn(1 downto 0),
      adcSclk           => adcSpiClk,
      adcSdio           => adcSpiData,
      adcCsb            => iAdcSpiCsb

      );
   
   adcSpiCsb <= iAdcSpiCsb(2 downto 0);
   adcPdwn <= iAdcPdwn(2 downto 0);
   
   --------------------------------------------
   --     Slow ADC Readout ADC gen 2         --
   -------------------------------------------- 
     
   U_AdcCntrl: entity work.SlowAdcCntrlAxi
   generic map (
      SYS_CLK_PERIOD_G  => 10.0E-9,	   -- 100MHz
      ADC_CLK_PERIOD_G  => 200.0E-9,	-- 5MHz
      SPI_SCLK_PERIOD_G => 2.0E-6  	   -- 500kHz
   )
   port map ( 
      -- Master system clock
      sysClk            => coreClk,
      sysClkRst         => axiRst,
      
      -- Trigger Control
      adcStart          => acqStart,
      
      -- AXI lite slave port for register access
      axilClk           => coreClk,
      axilRst           => axiRst,
      sAxilWriteMaster  => mAxiWriteMasters(MONADC_REG_AXI_INDEX_C),
      sAxilWriteSlave   => mAxiWriteSlaves(MONADC_REG_AXI_INDEX_C),
      sAxilReadMaster   => mAxiReadMasters(MONADC_REG_AXI_INDEX_C),
      sAxilReadSlave    => mAxiReadSlaves(MONADC_REG_AXI_INDEX_C),
      
      -- AXI stream output
      axisClk           => coreClk,
      axisRst           => axiRst,
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
   U_LogMem : entity work.AxiDualPortRam
   generic map (
      TPD_G            => TPD_G,
      ADDR_WIDTH_G     => 10,
      DATA_WIDTH_G     => 32
   )
   port map (
      axiClk         => coreClk,
      axiRst         => axiRst,
      axiReadMaster  => mAxiReadMasters(MEM_LOG_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(MEM_LOG_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(MEM_LOG_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(MEM_LOG_AXI_INDEX_C),
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

   --------------------------------------------
   -- Virtual oscilloscope                   --
   --------------------------------------------
   
   U_PseudoScope : entity work.PseudoScopeAxiM
   generic map (
     TPD_G                      => TPD_G,
     MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)      
   )
   port map ( 
      
      sysClk         => coreClk,
      sysClkRst      => axiRst,
      adcData        => adcData,
      adcValid       => adcValid,
      adcMarker      => (others=>iAsicSample),
      arm            => acqStart,
      acqStart       => acqStart,
      asicAcq        => acqStart,
      asicR0         => iAsicR1,
      asicPpmat      => iAsicR2,
      asicPpbe       => iAsicR3,
      asicSync       => iAsicStart,
      asicGr         => iAsicSample,
      asicRoClk      => iAsicClk,
      asicSaciSel(1 downto 0) => "00",
      asicSaciSel(3 downto 2) => "00",
      mAxisMaster    => scopeAxisMaster,
      mAxisSlave     => scopeAxisSlave,
      -- AXI lite slave port for register access
      axilClk           => coreClk,
      axilRst           => axiRst,
      sAxilWriteMaster  => mAxiWriteMasters(SCOPE_REG_AXI_INDEX_C),
      sAxilWriteSlave   => mAxiWriteSlaves(SCOPE_REG_AXI_INDEX_C),
      sAxilReadMaster   => mAxiReadMasters(SCOPE_REG_AXI_INDEX_C),
      sAxilReadSlave    => mAxiReadSlaves(SCOPE_REG_AXI_INDEX_C)

   );
   
   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
   generic map (
      TPD_G           => TPD_G,
      BUILD_INFO_G    => BUILD_INFO_G,
      EN_DEVICE_DNA_G => false)   
   port map (
      fpgaReload     => fpgaReload,
      -- AXI-Lite Register Interface
      axiReadMaster  => mAxiReadMasters(VERSION_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(VERSION_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(VERSION_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(VERSION_AXI_INDEX_C),
      -- Clocks and Resets
      axiClk         => coreClk,
      axiRst         => axiRst
   );

   ---------------------
   -- FPGA Reboot Module
   ---------------------
   U_Iprog7Series : entity work.Iprog7Series
   generic map (
      TPD_G => TPD_G)   
   port map (
      clk         => coreClk,
      rst         => axiRst,
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
   U_AxiMicronN25QCore : entity work.AxiMicronN25QCore
   generic map (
      TPD_G          => TPD_G,
      AXI_CLK_FREQ_G => 100.0E+6,   -- units of Hz
      SPI_CLK_FREQ_G => 25.0E+6     -- units of Hz
   )
   port map (
      -- FLASH Memory Ports
      csL            => bootCsL,
      sck            => bootSck,
      mosi           => bootMosi,
      miso           => bootMiso,
      -- AXI-Lite Register Interface
      axiReadMaster  => mAxiReadMasters(BOOTMEM_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(BOOTMEM_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(BOOTMEM_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(BOOTMEM_AXI_INDEX_C),
      -- Clocks and Resets
      axiClk         => coreClk,
      axiRst         => axiRst
   );
   
   
   
end top_level;
