-------------------------------------------------------------------------------
-- Title      : Tixel Detector Readout System Core
-------------------------------------------------------------------------------
-- File       : TixelCore.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 03/02/2016
-- Last update: 03/02/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
use work.TixelPkg.all;
use work.ScopeTypes.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.Version.all;
use work.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity TixelCore is
   generic (
      TPD_G             : time := 1 ns;
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
      saciRsp             : in  slv(3 downto 0);
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiDataOut       : out sl;
      adcSpiDataIn        : in  sl;
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
      asic01DM1           : in sl;
      asic01DM2           : in sl;
      asicPPbe            : out sl;
      asicPpmat           : out sl;
      asicTpulse          : out sl;
      asicStart           : out sl;
      asicR0              : out sl;
      asicGlblRst         : out sl;
      asicSync            : out sl;
      asicAcq             : out sl;
      asicDoutP           : in  slv(1 downto 0);
      asicDoutM           : in  slv(1 downto 0);
      asicRefClk          : out slv(1 downto 0);
      asicRoClk           : out slv(1 downto 0);
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
   );
end TixelCore;

architecture top_level of TixelCore is
   
   attribute keep : string;
   
   -- ASIC signals
   signal iAsic01DM1           : sl;
   signal iAsic01DM2           : sl;
   signal iAsicTpulse          : sl;
   signal iAsicStart           : sl;
   signal iAsicPPbe            : sl;
   signal iAsicPpmat           : sl;
   signal iAsicR0              : sl;
   signal iAsicSync            : sl;
   signal iAsicAcq             : sl;
   signal iAsicGrst            : sl;
   
   attribute keep of iAsic01DM1    : signal is "true";
   attribute keep of iAsic01DM2    : signal is "true";
   attribute keep of iAsicPPbe     : signal is "true";
   attribute keep of iAsicPpmat    : signal is "true";
   attribute keep of iAsicR0       : signal is "true";
   attribute keep of iAsicGrst     : signal is "true";
   attribute keep of iAsicSync     : signal is "true";
   attribute keep of iAsicAcq      : signal is "true";
   attribute keep of iAsicStart    : signal is "true";
   attribute keep of iAsicTpulse   : signal is "true";
   
   signal coreClk     : sl;
   signal coreClkRst  : sl;
   signal pgpClk      : sl;
   signal sysRst      : sl;
   signal axiRst      : sl;
   signal heartBeat   : sl;
   signal txLinkReady : sl;
   signal rxLinkReady : sl;
   
   signal asicRfClk     : sl;
   signal asicRfClkRst  : sl;
   signal asicRdClk     : sl;
   signal asicRdClkRst  : sl;
   signal bitClk        : sl;
   signal bitClkRst     : sl;
   signal byteClk       : sl;
   signal byteClkRst    : sl;
   signal iDelayCtrlClk : sl;
   signal iDelayCtrlRst : sl;
   signal powerBad      : sl;
   
   signal pgpRxOut      : Pgp2bRxOutType;
   
   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterArray(TIXEL_NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiReadSlave   : AxiLiteReadSlaveArray(TIXEL_NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteMaster : AxiLiteWriteMasterArray(TIXEL_NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteSlave  : AxiLiteWriteSlaveArray(TIXEL_NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(TIXEL_NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(TIXEL_NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(TIXEL_NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(TIXEL_NUM_AXI_MASTER_SLOTS_C-1 downto 0); 

   -- AXI-Stream signals
   signal framerAxisMaster    : AxiStreamMasterArray(NUMBER_OF_ASICS-1 downto 0);
   signal framerAxisSlave     : AxiStreamSlaveArray(NUMBER_OF_ASICS-1 downto 0);
   signal userAxisMaster      : AxiStreamMasterType;
   signal userAxisSlave       : AxiStreamSlaveType;
   signal scopeAxisMaster     : AxiStreamMasterType;
   signal scopeAxisSlave      : AxiStreamSlaveType;
   signal deserAxisMaster     : AxiStreamMasterArray(NUMBER_OF_ASICS-1 downto 0);
   signal monitorAxisMaster   : AxiStreamMasterType;
   signal monitorAxisSlave    : AxiStreamSlaveType;
   signal monEnAxisMaster     : AxiStreamMasterType;
   
   -- Command interface
   signal ssiCmd           : SsiCmdMasterType;
   
   -- Configuration and status
   signal epixStatus       : EpixStatusType;
   signal epixConfig       : EpixConfigType;
   signal tixelStatus       : TixelStatusType;
   signal tixelConfig       : TixelConfigType;
   signal scopeConfig      : ScopeConfigType;
   signal rxReady          : sl;
   signal txReady          : sl;
   
   -- ADC signals
   signal adcValid         : slv(19 downto 0);
   signal adcData          : Slv16Array(19 downto 0);
   signal adcStreams       : AxiStreamMasterArray(19 downto 0) := (others=>AXI_STREAM_MASTER_INIT_C);
   
   -- Triggers and associated signals
   signal iDaqTrigger      : sl;
   signal iRunTrigger      : sl;
   signal opCode           : slv(7 downto 0);
   signal pgpOpCodeOneShot : sl;
   
   -- Interfaces between blocks
   signal cntAcquisition  : std_logic_vector(31 downto 0);
   signal cntSequence     : std_logic_vector(31 downto 0);
   signal cntReadout      : std_logic_vector( 3 downto 0);
   signal frameReq        : std_logic;
   signal frameAck        : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal frameErr        : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal headerAck       : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal timeoutReq      : std_logic;
   
   signal acqStart           : sl;
   signal dataSend           : sl;
   signal saciPrepReadoutReq : sl;
   signal saciPrepReadoutAck : sl;
   
   -- Power up reset to SERDES block
   signal adcCardPowerUp     : sl;
   signal adcCardPowerUpEdge : sl;
   signal serdesReset        : sl;
   
   signal iSaciSelL        : slv(3 downto 0);
   signal iSaciClk         : sl;
   signal iSaciCmd         : sl;
   
   signal tgOutMux         : sl;
   
   signal adcClk           : std_logic := '0';
   signal adcCnt           : unsigned(31 downto 0) := (others => '0');
   
   signal inSync           : slv(NUMBER_OF_ASICS-1 downto 0);
   
   signal monitorTrig   : sl;
   signal monTrigCnt    : integer;
   signal slowAdcData   : Slv24Array(8 downto 0);
   signal monAdc        : Ad9249SerialGroupType;
   
   signal fpgaReload : sl;
   signal bootSck    : sl;
   
   attribute IODELAY_GROUP : string;
   attribute IODELAY_GROUP of U_IDelayCtrl : label is IODELAY_GROUP_G;
   
   attribute keep of coreClk : signal is "true";
   attribute keep of byteClk : signal is "true";
   attribute keep of asicRfClk : signal is "true";
   attribute keep of acqStart : signal is "true";
   attribute keep of mAxiWriteMasters : signal is "true";
   attribute keep of sAxiWriteMaster : signal is "true";
   attribute keep of adcData : signal is "true";
   attribute keep of adcValid : signal is "true";
   attribute keep of saciPrepReadoutReq : signal is "true";
   attribute keep of saciPrepReadoutAck : signal is "true";
   attribute keep of cntReadout : signal is "true";
   attribute keep of frameErr : signal is "true";
   attribute keep of timeoutReq : signal is "true";
   
   
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
   --triggerOut     <= iAsicAcq;
   --mpsOut         <= pgpOpCodeOneShot;
   triggerOut     <= tgOutMux;
   mpsOut         <= iAsic01DM2;
   -- SACI signals
   saciSelL       <= iSaciSelL;
   saciClk        <= iSaciClk;
   saciCmd        <= iSaciCmd;
   
   
   tgOutMux <= 
      iAsic01DM1                       when tixelConfig.tixelDebug = "00000" else
      iAsic01DM1 and not iAsicSync     when tixelConfig.tixelDebug = "00001" else
      iAsic01DM1 and not iAsicStart    when tixelConfig.tixelDebug = "00010" else
      iAsic01DM1 and not iAsicAcq      when tixelConfig.tixelDebug = "00011" else
      iAsic01DM1 and not iAsicTpulse   when tixelConfig.tixelDebug = "00100" else
      iAsic01DM1 and iAsicR0           when tixelConfig.tixelDebug = "00101" else
      iAsicSync                        when tixelConfig.tixelDebug = "00110" else
      iAsicStart                       when tixelConfig.tixelDebug = "00111" else
      iAsicAcq                         when tixelConfig.tixelDebug = "01000" else
      iAsicTpulse                      when tixelConfig.tixelDebug = "01001" else
      iAsicR0                          when tixelConfig.tixelDebug = "01010" else
      iSaciClk                         when tixelConfig.tixelDebug = "01011" else
      iSaciCmd                         when tixelConfig.tixelDebug = "01100" else
      asicRdClk                        when tixelConfig.tixelDebug = "01101" else
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
         dataOut => pgpOpCodeOneShot);

   
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
         powerBad    => powerBad,
         -- Output reset
         pgpRst      => sysRst,
         -- Output status
         rxLinkReady => rxReady,
         txLinkReady => txReady,
         -- Output clocking
         pgpClk      => pgpClk,
         -- AXI clocking
         axiClk     => coreClk,
         axiRst     => axiRst,
         -- Axi Master Interface - Registers (axiClk domain)
         mAxiLiteReadMaster  => sAxiReadMaster(0),
         mAxiLiteReadSlave   => sAxiReadSlave(0),
         mAxiLiteWriteMaster => sAxiWriteMaster(0),
         mAxiLiteWriteSlave  => sAxiWriteSlave(0),
         -- Streaming data Links (axiClk domain)      
         dataAxisMaster    => userAxisMaster,
         dataAxisSlave     => userAxisSlave,
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
   
   powerBad <= not powerGood;

   ------------------------------------------
   -- Generate clocks from 156.25 MHz PGP  --
   ------------------------------------------
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 160 MHz serial data bit clock
   -- clkOut(1) : 100.00 MHz system clock
   -- clkOut(2) : 8 MHz ASIC readout clock
   -- clkOut(3) : 20 MHz ASIC reference clock
   U_CoreClockGen : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 4,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 10,
      CLKFBOUT_MULT_F_G    => 38.4,
      
      CLKOUT0_DIVIDE_F_G   => 3.75,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5,
      
      CLKOUT1_DIVIDE_G     => 6,
      CLKOUT1_PHASE_G      => 0.0,
      CLKOUT1_DUTY_CYCLE_G => 0.5,
      
      CLKOUT2_DIVIDE_G     => 75,
      CLKOUT2_PHASE_G      => 0.0,
      CLKOUT2_DUTY_CYCLE_G => 0.5,
      
      CLKOUT3_DIVIDE_G     => 30,
      CLKOUT3_PHASE_G      => 0.0,
      CLKOUT3_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => bitClk,
      clkOut(1) => coreClk,
      clkOut(2) => asicRdClk,
      clkOut(3) => asicRfClk,
      rstOut(0) => bitClkRst,
      rstOut(1) => coreClkRst,
      rstOut(2) => asicRdClkRst,
      rstOut(3) => asicRfClkRst,
      locked    => open
   );
   
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 200 MHz Idelaye2 calibration clock
   U_CoreClockGen2 : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 1,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 5,
      CLKFBOUT_MULT_F_G    => 32.0,
      
      CLKOUT0_DIVIDE_F_G   => 5.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => iDelayCtrlClk,
      rstOut(0) => iDelayCtrlRst,
      locked    => open
   );

   U_BUFR : BUFR
   generic map (
      SIM_DEVICE  => "7SERIES",
      BUFR_DIVIDE => "5"
   )
   port map (
      I   => bitClk,
      O   => byteClk,
      CE  => '1',
      CLR => '0'
   );
   
   U_RdPwrUpRst : entity work.PwrUpRst
   generic map (
      DURATION_G => 20000000
   )
   port map (
      clk      => byteClk,
      rstOut   => byteClkRst
   );
   
   roClk0Ddr_i : ODDR 
   port map ( 
      Q  => asicRoClk(0),
      C  => asicRdClk,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0'
   );
   
   roClk1Ddr_i : ODDR 
   port map ( 
      Q  => asicRoClk(1),
      C  => asicRdClk,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0'
   );
   
   refClk0Ddr_i : ODDR 
   port map ( 
      Q  => asicRefClk(0),
      C  => asicRfClk,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0'
   );
   
   refClk1Ddr_i : ODDR 
   port map ( 
      Q  => asicRefClk(1),
      C  => asicRfClk,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0'
   );
   
   G_ASIC : for i in 0 to NUMBER_OF_ASICS-1 generate 
   
      -------------------------------------------------------
      -- ASIC deserializers
      -------------------------------------------------------
      U_AsicDeser : entity work.Deserializer
      generic map (
         IODELAY_GROUP_G => IODELAY_GROUP_G
      )
      port map ( 
         bitClk         => bitClk,
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         
         -- serial data in
         asicDoutP      => asicDoutP(i),
         asicDoutM      => asicDoutM(i),
         
         -- status
         inSync         => inSync(i),
         
         -- control
         resync         => tixelConfig.doutResync(i),
         delay          => tixelConfig.doutDelay(i),
         
         -- decoded data Stream Master Port (byteClk)
         mAxisMaster    => deserAxisMaster(i)
      );
      
      -------------------------------------------------------
      -- ASIC AXI stream framers
      -------------------------------------------------------
      
      -- replace with standard framer when the 8b10b 
      -- error information is not needed in the stream
      
      U_ASIC_Framer : entity work.FramerExtended
      generic map(
         ASIC_NUMBER_G  => std_logic_vector(to_unsigned(i, 4))
      )
      port map(
         -- global signals
         sysClk         => coreClk,
         sysRst         => axiRst,
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         
         -- control/status signals (byteClk)
         forceFrameRead => tixelConfig.forceFrameRead,
         cntAcquisition => cntAcquisition,
         cntSequence    => cntSequence,
         cntReadout     => cntReadout,
         frameReq       => frameReq     ,
         frameAck       => frameAck(i)     ,
         frameErr       => frameErr(i)     ,
         headerAck      => headerAck(i)    ,
         timeoutReq     => timeoutReq   ,
         cntFrameDone   => tixelStatus.tixelFramesGood(i) ,
         cntFrameError  => tixelStatus.tixelFrameErr(i),
         cntCodeError   => tixelStatus.tixelCodeErr(i) ,
         cntToutError   => tixelStatus.tixelTimeoutErr(i) ,
         cntReset       => tixelConfig.tixelErrorRst,
         epixConfig     => epixConfig,
         
         -- decoded data input stream (byteClk)
         sAxisMaster    => deserAxisMaster(i),
         
         -- AXI Stream Master Port (sysClk)
         mAxisMaster    => framerAxisMaster(i),
         mAxisSlave     => framerAxisSlave(i)
      );
   
   end generate;
   
   tixelStatus.tixelAsicInSync <= inSync;
   
   -------------------------------------------------------
   -- AXI stream mux
   -------------------------------------------------------
   U_AxiStreamMux : entity work.AxiStreamMux
   generic map(
      NUM_SLAVES_G   => NUMBER_OF_ASICS
   )
   port map(
      -- Clock and reset
      axisClk        => coreClk,
      axisRst        => axiRst,
      -- Slaves
      sAxisMasters   => framerAxisMaster,
      sAxisSlaves    => framerAxisSlave,
      -- Master
      mAxisMaster    => userAxisMaster,
      mAxisSlave     => userAxisSlave
      
   );
   
   ------------------------------------------
   -- Common ASIC acquisition control            --
   ------------------------------------------      
   U_ASIC_Acquisition : entity work.TixelAcquisition
   generic map(
      NUMBER_OF_ASICS   => NUMBER_OF_ASICS
   )
   port map(
   
      -- global signals
      sysClk            => coreClk,
      sysClkRst         => axiRst,
   
      -- trigger
      acqStart          => acqStart,
      
      -- control/status signals (byteClk)
      cntAcquisition    => cntAcquisition,
      cntSequence       => cntSequence,
      cntReadout        => cntReadout,
      frameReq          => frameReq,
      frameAck          => frameAck,
      frameErr          => frameErr,
      headerAck         => headerAck,
      timeoutReq        => timeoutReq,
      
      epixConfig        => epixConfig,
      tixelConfig        => tixelConfig,
      saciReadoutReq    => saciPrepReadoutReq,
      saciReadoutAck    => saciPrepReadoutAck,
      
      -- ASICs signals
      asicPPbe          => iAsicPpbe,
      asicPpmat         => iAsicPpmat,
      asicTpulse        => iAsicTpulse,
      asicStart         => iAsicStart,
      asicR0            => iAsicR0,
      asicGlblRst       => iAsicGrst,
      asicSync          => iAsicSync,
      asicAcq           => iAsicAcq
      
   );
   
   asicAcq        <= iAsicAcq;
   asicR0         <= iAsicR0;
   asicPpmat      <= iAsicPpmat;
   asicPPbe       <= iAsicPpbe;
   asicSync       <= iAsicSync;
   asicGlblRst    <= iAsicGrst;
   
   iAsic01DM1     <= asic01DM1;
   iAsic01DM2     <= asic01DM2;
   
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   -- Master 0 : PGP register controller     --
   -- Master 1 : Microblaze reg controller    --
   --------------------------------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => TIXEL_NUM_AXI_SLAVE_SLOTS_C,
         NUM_MASTER_SLOTS_G => TIXEL_NUM_AXI_MASTER_SLOTS_C,
         MASTERS_CONFIG_G   => TIXEL_AXI_CROSSBAR_MASTERS_CONFIG_C)
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
         axiClkRst           => axiRst);
   
   --------------------------------------------
   --     Master Register Controllers        --
   --------------------------------------------   
   
   -- reuse part of the Epix specific registers
   
   U_RegControl : entity work.RegControlGen2
   generic map (
      TPD_G                => TPD_G,
      NUM_ASICS_G          => NUM_ASICS_C,
      CLK_PERIOD_G         => 10.0e-9
   )
   port map (
      axiClk         => coreClk,
      axiRst         => axiRst,
      sysRst         => sysRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(EPIX_REG_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(EPIX_REG_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(EPIX_REG_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(EPIX_REG_AXI_INDEX_C),
      -- Monitoring enable command incoming stream
      monEnAxisMaster => monEnAxisMaster,
      -- Register Inputs/Outputs (axiClk domain)
      epixStatus     => epixStatus,
      epixConfig     => epixConfig,
      scopeConfig    => scopeConfig,
      -- SACI prep-for-readout command request
      saciReadoutReq => saciPrepReadoutReq,
      saciReadoutAck => saciPrepReadoutAck,
      -- SACI interfaces to ASIC(s)
      saciClk        => iSaciClk,
      saciSelL       => iSaciSelL,
      saciCmd        => iSaciCmd,
      saciRsp        => saciRsp,
      -- SACI 
      -- Guard ring DAC interfaces
      dacSclk        => vGuardDacSclk,
      dacDin         => vGuardDacDin,
      dacCsb         => vGuardDacCsb,
      dacClrb        => vGuardDacClrb,
      -- 1-wire board ID interfaces
      serialIdIo     => serialIdIo
   );
   
   -- define new Tixel specific register set
   
   U_RegControlTixel : entity work.RegControlTixel
   generic map (
      TPD_G          => TPD_G
   )
   port map (
      axiClk         => coreClk,
      axiRst         => axiRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(TIXEL_REG_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(TIXEL_REG_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(TIXEL_REG_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(TIXEL_REG_AXI_INDEX_C),
      -- Register Inputs/Outputs (axiClk domain)
      tixelStatus     => tixelStatus,
      tixelConfig     => tixelConfig
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
   
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   -- ADC Clock outputs
   U_AdcClk2 : OBUFDS port map ( I => adcClk, O => adcClkP(2), OB => adcClkN(2) );
   
   process(coreClk) begin
      if rising_edge(coreClk) then
         if adcCnt >= unsigned(epixConfig.adcClkHalfT)-1 then
            adcClk <= not adcClk       after TPD_G;
            adcCnt <= (others => '0')  after TPD_G;
         else
            adcCnt <= adcCnt + 1       after TPD_G;
         end if;
      end if;
   end process;
   
   -- Tap delay calibration  
   U_IDelayCtrl : IDELAYCTRL
   port map (
      REFCLK => iDelayCtrlClk,
      RST    => iDelayCtrlRst,
      RDY    => epixStatus.iDelayCtrlRdy
   );   
   
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
      
      adcSClk              => adcSpiClk,
      adcSDin              => adcSpiDataIn,
      adcSDout             => adcSpiDataOut,
      adcSDEn              => adcSpiDataEn,
      adcCsb(2 downto 0)   => adcSpiCsb,
      adcCsb(3)            => open,
      adcPdwn(2 downto 0)  => adcPdwn,
      adcPdwn(3)           => open
   );
   
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
      adcStart      => acqStart,
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
      -- Clock and Reset
      clk              => coreClk,
      rst              => axiRst
   );
   
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
      asicRoClk      => asicRdClk,
      asicSaciSel    => iSaciSelL,
      scopeConfig    => scopeConfig,
      acqCount       => epixStatus.acqCount,
      seqCount       => epixStatus.seqCount,
      mAxisMaster    => scopeAxisMaster,
      mAxisSlave     => scopeAxisSlave
   );
   
   GenAdcStr : for i in 0 to 19 generate 
      adcData(i)  <= adcStreams(i).tData(15 downto 0);
      adcValid(i) <= adcStreams(i).tValid;
   end generate;
   
   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
   generic map (
      TPD_G           => TPD_G,
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
      PIPE_STAGES_G  => 1,
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
      -- AXI Streaming Interface (Optional)
      mAxisMaster    => open,
      mAxisSlave     => AXI_STREAM_SLAVE_FORCE_C,
      sAxisMaster    => AXI_STREAM_MASTER_INIT_C,
      sAxisSlave     => open,
      -- Clocks and Resets
      axiClk         => coreClk,
      axiRst         => axiRst
   );   
   
end top_level;

