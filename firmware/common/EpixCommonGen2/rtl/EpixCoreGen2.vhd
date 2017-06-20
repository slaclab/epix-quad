-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixCoreGen2.vhd
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
use work.EpixPkgGen2.all;
use work.ScopeTypes.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixCoreGen2 is
   generic (
      TPD_G             : time := 1 ns;
      ASIC_TYPE_G       : AsicType;
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
      -- Guard ring DAC
      vGuardDacSclk       : out sl;
      vGuardDacDin        : out sl;
      vGuardDacCsb        : out sl;
      vGuardDacClrb       : out sl;
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
      -- SACI (allow for point-to-point interfaces)
      saciClk             : out sl;
      saciSelL            : out slv(3 downto 0);
      saciCmd             : out sl;
      saciRsp             : in  sl;
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiDataIn        : in  sl;
      adcSpiDataOut       : out sl;
      adcSpiDataEn        : out sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn             : out slv(2 downto 0);
      -- Fast ADC readoutCh
      adcClkP             : out slv( 2 downto 0);
      adcClkN             : out slv( 2 downto 0);
      adcFClkP            : in  slv( 2 downto 0);
      adcFClkN            : in  slv( 2 downto 0);
      adcDClkP            : in  slv( 2 downto 0);
      adcDClkN            : in  slv( 2 downto 0);
      adcChP              : in  slv(19 downto 0);
      adcChN              : in  slv(19 downto 0);
      -- ASIC Control
      asicR0              : out sl;
      asicPpmat           : out sl;
      asicPpbe            : out sl;
      asicGrst            : out sl;
      asicAcq             : out sl;
      asic0Dm2            : in  sl;
      asic0Dm1            : in  sl;
      asicRoClk           : out sl;
      asicSync            : out sl;
      -- ASIC digital data
      asicDout            : in  slv(3 downto 0) := "0000";
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
--      -- DDR pins
--      ddr3_dq             : inout slv(31 downto 0);
--      ddr3_dqs_n          : inout slv(3 downto 0);
--      ddr3_dqs_p          : inout slv(3 downto 0);
--      ddr3_addr           : out   slv(14 downto 0);
--      ddr3_ba             : out   slv(2 downto 0);
--      ddr3_ras_n          : out   sl;
--      ddr3_cas_n          : out   sl;
--      ddr3_we_n           : out   sl;
--      ddr3_reset_n        : out   sl;
--      ddr3_ck_p           : out   slv(0 to 0);
--      ddr3_ck_n           : out   slv(0 to 0);
--      ddr3_cke            : out   slv(0 to 0);
--      ddr3_cs_n           : out   slv(0 to 0);
--      ddr3_dm             : out   slv(3 downto 0);
--      ddr3_odt            : out   slv(0 to 0)
   );
end EpixCoreGen2;

architecture top_level of EpixCoreGen2 is

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
   signal dataAxisMaster      : AxiStreamMasterType;
   signal dataAxisSlave       : AxiStreamSlaveType;
   signal scopeAxisMaster     : AxiStreamMasterType;
   signal scopeAxisSlave      : AxiStreamSlaveType;
   signal monitorAxisMaster   : AxiStreamMasterType;
   signal monitorAxisSlave    : AxiStreamSlaveType;
   signal monEnAxisMaster     : AxiStreamMasterType;
   
   
   -- Command interface
   signal ssiCmd           : SsiCmdMasterType;
   
   -- Configuration and status
   signal epixStatus       : EpixStatusType;
   signal epixConfig       : EpixConfigType;
   signal scopeConfig      : ScopeConfigType;
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
   signal iAsicAcq   : sl;
   signal iAsicR0    : sl;
   signal iAsicPpmat : sl;
   signal iAsicPpbe  : sl;
   signal iAsicGrst  : sl;
   signal iAsicRoClk : sl;
   signal iAsicSync  : sl;
   
   signal fpgaReload : sl;
   signal bootSck    : sl;
   
   signal iSaciSelL  : slv(3 downto 0);
   signal iSaciClk   : sl;
   signal iSaciCmd   : sl;
   signal iSaciRsp   : sl;
   
   signal slowAdcData : Slv24Array(8 downto 0);
   
   signal monAdc     : Ad9249SerialGroupType;
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
   
   attribute keep : boolean;
   attribute keep of coreClk : signal is true;
   attribute keep of acqBusy : signal is true;
   attribute keep of acqStart : signal is true;
   attribute keep of dataSend : signal is true;
   attribute keep of iSaciClk : signal is true;
   attribute keep of iSaciCmd : signal is true;
   attribute keep of iSaciSelL : signal is true;
   attribute keep of iSaciRsp : signal is true;
   
   attribute IODELAY_GROUP : string;
   attribute IODELAY_GROUP of U_IDelayCtrl : label is IODELAY_GROUP_G;
   
begin

   -- Map out power enables
   digitalPowerEn <= epixConfig.powerEnable(0);
   analogPowerEn  <= epixConfig.powerEnable(1);
   fpgaOutputEn   <= epixConfig.powerEnable(2);
   ledEn          <= epixConfig.powerEnable(3);
   -- Fixed state logic signals
   sfpDisable     <= '0';
   -- Triggers in
   iRunTrigger    <= runTrigger;
   iDaqTrigger    <= daqTrigger;
   -- Triggers out
   triggerOut     <= iAsicAcq;
   mpsOut         <= pgpOpCodeOneShot;
   -- ASIC signals
   asicR0         <= iAsicR0;
   asicPpmat      <= iAsicPpmat;
   asicPpbe       <= iAsicPpbe;
   asicGrst       <= iAsicGrst;
   asicAcq        <= iAsicAcq;
   asicRoClk      <= iAsicRoClk;
   asicSync       <= iAsicSync;
   -- SACI signals
   saciSelL       <= iSaciSelL;
   saciClk        <= iSaciClk;
   saciCmd        <= iSaciCmd;
   iSaciRsp       <= saciRsp;
  

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
   U_CoreClockGen : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 1,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 5,
      CLKFBOUT_MULT_F_G    => 32.0,
      CLKOUT0_DIVIDE_F_G   => 10.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => coreClk,
      rstOut(0) => coreClkRst,
      locked    => open
   );
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 200.00 MHz IDELAYCTRL clock
   U_CalClockGen : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 1,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 1,
      --CLKFBOUT_MULT_F_G    => 6.0,
      CLKFBOUT_MULT_F_G    => 4.0,
      CLKOUT0_DIVIDE_F_G   => 3.125,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5,
      CLKOUT0_RST_HOLD_G   => 32
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => iDelayCtrlClk,
      rstOut(0) => iDelayCtrlRst,
      locked    => open
   );
   
   ---------------------
   -- Diagnostic LEDs --
   ---------------------
   led(3) <= epixConfig.powerEnable(0) and epixConfig.powerEnable(1) and epixConfig.powerEnable(2);
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
      ssiCmd              => ssiCmd,
      -- Sideband interface
      pgpRxOut            => pgpRxOut
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
      interrupt(7 downto 2)   => "000000",
      interrupt(1)            => epixConfig.requestConfDump,
      interrupt(0)            => epixConfig.requestStartupCal,
      -- Clock and Reset
      clk              => coreClk,
      rst              => axiRst
   );
   
   ---------------------------------------------
   -- SACI multipixel configurator Master     --
   ---------------------------------------------
   U_SaciMultiPixel : entity work.SaciMultiPixel
   port map (
      axilClk           => coreClk,
      axilRst           => axiRst,
      
      -- AXI lite slave port
      sAxilWriteMaster => mAxiWriteMasters(MULTIPIX_AXI_INDEX_C),
      sAxilWriteSlave  => mAxiWriteSlaves(MULTIPIX_AXI_INDEX_C),
      sAxilReadMaster  => mAxiReadMasters(MULTIPIX_AXI_INDEX_C),
      sAxilReadSlave   => mAxiReadSlaves(MULTIPIX_AXI_INDEX_C),
      
      -- AXI lite master port
      mAxilWriteMaster  => sAxiWriteMaster(2),
      mAxilWriteSlave   => sAxiWriteSlave(2),
      mAxilReadMaster   => sAxiReadMaster(2),
      mAxilReadSlave    => sAxiReadSlave(2)
   );
   
   ---------------------------------------------
   -- SACI prepare for readout command Master --
   ---------------------------------------------
   U_SaciPrepRdout : entity work.SaciPrepRdout
   port map (
      
      axilClk           => coreClk,
      axilRst           => axiRst,
      
      -- Prepare for readout req/ack
      prepRdoutReq      => saciPrepReadoutReq,
      prepRdoutAck      => saciPrepReadoutAck,
      
      -- Optional AXI lite slave port for status readout
      sAxilWriteMaster => mAxiWriteMasters(PREPRDOUT_AXI_INDEX_C),
      sAxilWriteSlave  => mAxiWriteSlaves(PREPRDOUT_AXI_INDEX_C),
      sAxilReadMaster  => mAxiReadMasters(PREPRDOUT_AXI_INDEX_C),
      sAxilReadSlave   => mAxiReadSlaves(PREPRDOUT_AXI_INDEX_C),
      
      -- AXI lite master port
      mAxilWriteMaster  => sAxiWriteMaster(3),
      mAxilWriteSlave   => sAxiWriteSlave(3),
      mAxilReadMaster   => sAxiReadMaster(3),
      mAxilReadSlave    => sAxiReadSlave(3)
   );
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control
   -- Master 0 : PGP front end controller
   -- Master 1 : Microblaze startup controller
   -- Master 2 : SACI multipixel controller
   -- Master 3 : SACI prepare rdout command controller
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
   U_RegControl : entity work.RegControl
   generic map (
      TPD_G                => TPD_G,
      FPGA_BASE_CLOCK_G    => FPGA_BASE_CLOCK_G,
      BUILD_INFO_G         => BUILD_INFO_G,
      CLK_PERIOD_G         => 10.0e-9
   )
   port map (
      axiClk         => coreClk,
      axiRst         => axiRst,
      sysRst         => sysRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(EPIXREGS_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(EPIXREGS_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(EPIXREGS_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(EPIXREGS_AXI_INDEX_C),
      -- Monitoring enable command incoming stream
      monEnAxisMaster => monEnAxisMaster,
      -- Register Inputs/Outputs (axiClk domain)
      epixStatus     => epixStatus,
      epixConfig     => epixConfig,
      scopeConfig    => scopeConfig,
      -- Guard ring DAC interfaces
      dacSclk        => vGuardDacSclk,
      dacDin         => vGuardDacDin,
      dacCsb         => vGuardDacCsb,
      dacClrb        => vGuardDacClrb,
      -- 1-wire board ID interfaces
      serialIdIo     => serialIdIo
   );
   
   --------------------------------------------
   -- SACI interface controller              --
   -------------------------------------------- 
   U_AxiLiteSaciMaster : entity work.AxiLiteSaciMaster
   generic map (
      AXIL_CLK_PERIOD_G  => 10.0E-9, -- In units of seconds
      AXIL_TIMEOUT_G     => 1.0E-3,  -- In units of seconds
      SACI_CLK_PERIOD_G  => 0.25E-6, -- In units of seconds
      SACI_CLK_FREERUN_G => false,
      SACI_RSP_BUSSED_G  => true,
      SACI_NUM_CHIPS_G   => 4)
   port map (
      -- SACI interface
      saciClk           => iSaciClk,
      saciCmd           => iSaciCmd,
      saciSelL          => iSaciSelL,
      saciRsp(0)        => iSaciRsp,
      -- AXI-Lite Register Interface
      axilClk           => coreClk,
      axilRst           => axiRst,
      axilReadMaster    => mAxiReadMasters(SACIREGS_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(SACIREGS_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(SACIREGS_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(SACIREGS_AXI_INDEX_C)
   );

   ---------------------
   -- Trig control    --
   ---------------------
   U_TrigControl : entity work.TrigControl 
   port map ( 
      -- Core clock, reset
      sysClk         => coreClk,
      sysClkRst      => axiRst,
      -- PGP clock, reset
      pgpClk         => pgpClk,
      pgpClkRst      => sysRst,
      -- TTL triggers in 
      runTrigger     => iRunTrigger,
      daqTrigger     => iDaqTrigger,
      -- SW trigger in (from VC)
      ssiCmd         => ssiCmd,
      -- PGP RxOutType (to trigger from sideband)
      pgpRxOut       => pgpRxOut,
      -- Opcode associated with this trigger
      opCodeOut      => opCode,
      -- Configuration
      epixConfig     => epixConfig,
      -- Status output
      acqCount       => epixStatus.acqCount,
      -- Interface to other blocks
      acqStart       => acqStart,
      dataSend       => dataSend
   );   
   
   ---------------------------------------------------------------
   -- Digital output deserializer only for EPIX10KA
   --------------------- ------------------------------------------
   G_DOUT_EPIX10KA : if ASIC_TYPE_G = EPIX10KA_C generate
   
      U_DoutDeser : entity work.DoutDeserializer
      port map ( 
         clk         => coreClk,
         rst         => axiRst,
         acqBusy     => acqBusy,
         asicDout    => asicDout,
         asicRoClk   => iAsicRoClk,
         asicLatency => epixConfig.doutPipelineDelay,
         doutOut     => doutOut,
         doutRd      => doutRd,
         doutValid   => doutValid
      );
      
   end generate;
   G_DOUT_NONE : if ASIC_TYPE_G /= EPIX10KA_C generate
      doutOut <= (others=>(others=>'0'));
      doutValid <= (others=>'1');
   end generate;
   ---------------------
   -- Acq control     --
   ---------------------      
   U_AcqControl : entity work.AcqControl
   generic map (
      ASIC_TYPE_G     => ASIC_TYPE_G
   )
   port map (
      sysClk          => coreClk,
      sysClkRst       => axiRst,
      acqStart        => acqStart,
      acqBusy         => acqBusy,
      readDone        => readDone,
      readValidA0     => readValidA0,
      readValidA1     => readValidA1,
      readValidA2     => readValidA2,
      readValidA3     => readValidA3,
      adcClkP         => adcClkP,
      adcClkM         => adcClkN,
      adcPulse        => adcPulse,
      readTps         => readTps,
      epixConfig      => epixConfig,
      saciReadoutReq  => saciPrepReadoutReq,
      saciReadoutAck  => saciPrepReadoutAck,
      asicR0          => iAsicR0,
      asicPpmat       => iAsicPpmat,
      asicPpbe        => iAsicPpbe,
      asicGlblRst     => iAsicGrst,
      asicAcq         => iAsicAcq,
      asicSync        => iAsicSync,
      asicRoClk       => iAsicRoClk
   );
 
   ---------------------
   -- Readout control --
   ---------------------      
   U_ReadoutControl : entity work.ReadoutControl
   generic map (
     TPD_G                      => TPD_G,
     ASIC_TYPE_G                => ASIC_TYPE_G,
     MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)
   )
   port map (
      sysClk         => coreClk,
      sysClkRst      => axiRst,
      epixConfig     => epixConfig,
      acqCount       => epixStatus.acqCount,
      seqCount       => epixStatus.seqCount,
      opCode         => opCode,
      acqStart       => acqStart,
      readValidA0    => readValidA0,
      readValidA1    => readValidA1,
      readValidA2    => readValidA2,
      readValidA3    => readValidA3,
      readDone       => readDone,
      acqBusy        => acqBusy,
      dataSend       => dataSend,
      readTps        => readTps,
      adcPulse       => adcPulse,
      adcValid       => adcValid,
      adcData        => adcData,
      envData        => epixStatus.envData,
      mAxisMaster    => dataAxisMaster,
      mAxisSlave     => dataAxisSlave,
      mpsOut         => open,
      doutOut        => doutOut,
      doutRd         => doutRd,
      doutValid      => doutValid
   );
   
   GenAdcStr : for i in 0 to 19 generate 
      adcData(i)  <= adcStreams(i).tData(15 downto 0);
      adcValid(i) <= adcStreams(i).tValid;
   end generate;
   
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   -- Tap delay calibration  
   U_IDelayCtrl : IDELAYCTRL
   port map (
      REFCLK => iDelayCtrlClk,
      RST    => iDelayCtrlRst,
      RDY    => epixStatus.iDelayCtrlRdy
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
         adcStreamClk => coreClk,
         adcStreams        => adcStreams((i*8)+7 downto i*8)
      );
      
   end generate;
   
   
   monAdc.fClkP <= adcFClkP(2);
   monAdc.fClkN <= adcFClkN(2);
   monAdc.dClkP <= adcDClkP(2);
   monAdc.dClkN <= adcDClkN(2);
   monAdc.chP   <= adcChP(19 downto 16);
   monAdc.chN   <= adcChN(19 downto 16);
      
   U_MonAdcReadout : entity work.Ad9249ReadoutGroup
   generic map (
      TPD_G             => TPD_G,
      NUM_CHANNELS_G    => 4,
      IODELAY_GROUP_G   => IODELAY_GROUP_G,
      IDELAYCTRL_FREQ_G => 200.0,
      ADC_INVERT_CH_G   => ADC2_INVERT_CH
   )
   port map (
      -- Master system clock, 125Mhz
      axilClk           => coreClk,
      axilRst           => axiRst,
      
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
      adcStreamClk => coreClk,
      adcStreams        => adcStreams(19 downto 16)
   );

   -- Give a special reset to the SERDES blocks when power
   -- is turned on to ADC card.
   adcCardPowerUp <= epixConfig.powerEnable(0) and epixConfig.powerEnable(1) and epixConfig.powerEnable(2);
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
      NUM_CHANNELS_G    => 20
   )
   port map ( 
      -- Master system clock
      clk               => coreClk,
      rst               => axiRst,
      -- ADC data stream inputs
      adcStreams        => adcStreams,
      -- Axi Interface
      axilReadMaster  => mAxiReadMasters(ADCTEST_AXI_INDEX_C),
      axilReadSlave   => mAxiReadSlaves(ADCTEST_AXI_INDEX_C),
      axilWriteMaster => mAxiWriteMasters(ADCTEST_AXI_INDEX_C),
      axilWriteSlave  => mAxiWriteSlaves(ADCTEST_AXI_INDEX_C)
   );
   
   --------------------------------------------
   --     Fast ADC Config                    --
   --------------------------------------------
      
   U_AdcConf : entity work.Ad9249ConfigNoPullup
   generic map (
      TPD_G             => TPD_G,
      CLK_PERIOD_G      => 10.0e-9,
      CLK_EN_PERIOD_G   => 20.0e-9,
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
      
      adcSClk           => adcSpiClk,
      adcSDin           => adcSpiDataIn,
      adcSDout          => adcSpiDataOut,
      adcSDEn           => adcSpiDataEn,
      adcCsb            => iAdcSpiCsb,
      adcPdwn           => iAdcPdwn(1 downto 0)
   );
   
   adcSpiCsb <= iAdcSpiCsb(2 downto 0);
   adcPdwn <= iAdcPdwn(2 downto 0);
   
   --------------------------------------------
   --     Slow ADC Readout ADC gen 2         --
   -------------------------------------------- 
     
   U_AdcCntrl : entity work.SlowAdcCntrl
   generic map (
      SYS_CLK_PERIOD_G  => 10.0E-9,	   -- 100MHz
      ADC_CLK_PERIOD_G  => 200.0E-9,	-- 5MHz
      SPI_SCLK_PERIOD_G => 2.0E-6  	   -- 500kHz
   )
   port map ( 
      -- Master system clock
      sysClk        => coreClk,
      sysClkRst     => axiRst,

      -- Operation Control
      adcStart      => readDone,
      adcData       => slowAdcData,
      allChRd       => open,

      -- ADC Control Signals
      adcRefClk     => slowAdcRefClk,
      adcDrdy       => slowAdcDrdy,
      adcSclk       => slowAdcSclk,
      adcDout       => slowAdcDout,
      adcCsL        => slowAdcCsb,
      adcDin        => slowAdcDin
   );
   
   --------------------------------------------
   --    Environmental data convertion LUTs  --
   -------------------------------------------- 
   
   U_AdcEnv : entity work.SlowAdcLUT
   port map ( 
      -- Master system clock
      sysClk        => coreClk,
      sysClkRst     => axiRst,
      
      -- ADC raw data inputs
      adcData       => slowAdcData,

      -- Converted data outputs
      outEnvData    => epixStatus.envData
   );
   
   --------------------------------------------
   --    Environmental data streamer         --
   --------------------------------------------
   U_AdcStrm: entity work.SlowAdcStream
   port map ( 
      sysClk          => coreClk,
      sysRst          => axiRst,
      acqCount        => epixStatus.acqCount,
      seqCount        => epixStatus.seqCount,
      trig            => monitorTrig,
      dataIn          => epixStatus.envData,
      mAxisMaster     => monitorAxisMaster,
      mAxisSlave      => monitorAxisSlave
      
   );
   
   -- trigger monitor data stream at 1Hz
   P_MonStrTrig: process (coreClk)
   begin
      if rising_edge(coreClk) then
         if axiRst = '1' or monitorTrig = '1' then
            monTrigCnt <= 0;
         elsif epixConfig.monitorEnable = '1' then
            monTrigCnt <= monTrigCnt + 1;
         end if;
      end if;   
   end process;
   monitorTrig <= '1' when monTrigCnt >= 99999999 else '0';
   
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
   U_PseudoScope : entity work.PseudoScope
   generic map (
     TPD_G                      => TPD_G,
     MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)      
   )
   port map (
      sysClk         => coreClk,
      sysClkRst      => axiRst,
      adcData        => adcData,
      adcValid       => adcValid,
      arm            => acqStart,
      acqStart       => acqStart,
      asicAcq        => iAsicAcq,
      asicR0         => iAsicR0,
      asicPpmat      => iAsicPpmat,
      asicPpbe       => iAsicPpbe,
      asicSync       => iAsicSync,
      asicGr         => iAsicGrst,
      asicRoClk      => iAsicRoClk,
      asicSaciSel    => iSaciSelL,
      scopeConfig    => scopeConfig,
      acqCount       => epixStatus.acqCount,
      seqCount       => epixStatus.seqCount,
      mAxisMaster    => scopeAxisMaster,
      mAxisSlave     => scopeAxisSlave
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
   
   
--   --------------------
--   -- DDR memory controller
--   --------------------
--   U_AxiDdrControllerWrapper : entity work.AxiDdrControllerWrapper
--   port map ( 
--      -- AXI Slave     
--      axiReadMaster     => axiReadMaster,
--      axiReadSlave      => axiReadSlave,
--      axiWriteMaster    => axiWriteMaster,
--      axiWriteSlave     => axiWriteSlave,
--      
--      -- DDR PHY Ref clk
--      sysClk            => refClk,
--      dlyClk            => iDelayCtrlClk,
--      
--      -- DDR clock from the DDR controller core
--      ddrClk            => ddrClk,
--      ddrRst            => ddrRst,
--
--      -- DRR Memory interface ports
--      ddr3_dq           => ddr3_dq,
--      ddr3_dqs_n        => ddr3_dqs_n,
--      ddr3_dqs_p        => ddr3_dqs_p,
--      ddr3_addr         => ddr3_addr,
--      ddr3_ba           => ddr3_ba,
--      ddr3_ras_n        => ddr3_ras_n,
--      ddr3_cas_n        => ddr3_cas_n,
--      ddr3_we_n         => ddr3_we_n,
--      ddr3_reset_n      => ddr3_reset_n,
--      ddr3_ck_p         => ddr3_ck_p,
--      ddr3_ck_n         => ddr3_ck_n,
--      ddr3_cke          => ddr3_cke,
--      ddr3_cs_n         => ddr3_cs_n,
--      ddr3_dm           => ddr3_dm,
--      ddr3_odt          => ddr3_odt,
--      calibComplete     => calibComplete
--   );
--   
--   U_AxiMemTester : entity work.AxiMemTester
--   generic map (
--      TPD_G            => TPD_G,
--      START_ADDR_G     => START_ADDR_C,
--      STOP_ADDR_G      => STOP_ADDR_C,
--      AXI_CONFIG_G     => DDR_AXI_CONFIG_C
--   )
--   port map (
--      -- AXI-Lite Interface
--      axilClk         => coreClk,
--      axilRst         => axiRst,
--      axilReadMaster  => mAxiReadMasters(TESTMEM_AXI_INDEX_C),
--      axilReadSlave   => mAxiReadSlaves(TESTMEM_AXI_INDEX_C),
--      axilWriteMaster => mAxiWriteMasters(TESTMEM_AXI_INDEX_C),
--      axilWriteSlave  => mAxiWriteSlaves(TESTMEM_AXI_INDEX_C),
--      memReady        => open,
--      memError        => open,
--      -- DDR Memory Interface
--      axiClk          => ddrClk,
--      axiRst          => ddrRst,
--      start           => calibComplete,
--      axiWriteMaster  => axiWriteMaster,
--      axiWriteSlave   => axiWriteSlave,
--      axiReadMaster   => axiReadMaster,
--      axiReadSlave    => axiReadSlave
--   );
   
end top_level;
