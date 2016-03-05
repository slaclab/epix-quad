-------------------------------------------------------------------------------
-- Title      : Cpix Detector Readout System Core
-------------------------------------------------------------------------------
-- File       : CpixCore.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 03/02/2016
-- Last update: 03/02/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
use work.ScopeTypes.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.Version.all;

library unisim;
use unisim.vcomponents.all;

entity CpixCore is
   generic (
      TPD_G             : time := 1 ns;
      ADC0_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC1_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC2_INVERT_CH    : slv(7 downto 0) := "00000000"
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
      asicEnA             : out sl;
      asicEnB             : out sl;
      asicVid             : out sl;
      asicPPbe            : out slv(1 downto 0);
      asicPpmat           : out slv(1 downto 0);
      asicR0              : out sl;
      asicSRO             : out sl;
      asicGlblRst         : out sl;
      asicSync            : out sl;
      asicAcq             : out sl;
      asicDoutP           : in  slv(1 downto 0);
      asicDoutM           : in  slv(1 downto 0);
      asicRoClk           : out slv(1 downto 0)
   );
end CpixCore;

architecture top_level of CpixCore is

   signal coreClk     : sl;
   signal coreClkRst  : sl;
   signal pgpClk      : sl;
   signal sysRst      : sl;
   signal axiRst      : sl;
   signal heartBeat   : sl;
   signal txLinkReady : sl;
   signal rxLinkReady : sl;
   
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
   signal userAxisMaster   : AxiStreamMasterType;
   signal userAxisSlave    : AxiStreamSlaveType;
   signal scopeAxisMaster  : AxiStreamMasterType;
   signal scopeAxisSlave   : AxiStreamSlaveType;
   
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
   signal readValidA0        : slv(MAX_OVERSAMPLE_C-1 downto 0);
   signal readValidA1        : slv(MAX_OVERSAMPLE_C-1 downto 0);
   signal readValidA2        : slv(MAX_OVERSAMPLE_C-1 downto 0);
   signal readValidA3        : slv(MAX_OVERSAMPLE_C-1 downto 0);
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
   signal iAsicSync  : sl;
   signal iAsicGrst  : sl;
   
   signal iSaciSelL  : slv(3 downto 0);
   
   signal adcClk             : std_logic := '0';
   signal adcClk0            : std_logic;
   signal adcClk1            : std_logic;
   signal adcClk2            : std_logic;
   signal adcCnt             : unsigned(31 downto 0) := (others => '0');
   signal iAdcPdwn           : slv(2 downto 0);
   
   signal dataOut    : Slv8Array(1 downto 0);
   signal dataKOut   : slv(1 downto 0);
   signal codeErr    : slv(1 downto 0);
   signal dispErr    : slv(1 downto 0);
   signal inSync     : slv(1 downto 0);
   
   attribute keep : boolean;
   attribute keep of coreClk : signal is true;
   attribute keep of acqBusy : signal is true;
   attribute keep of acqStart : signal is true;
   
   
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
   -- SACI signals
   saciSelL       <= iSaciSelL;

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
         userAxisMaster      => userAxisMaster,
         userAxisSlave       => userAxisSlave,
         -- Scope streaming data (axiClk domain)
         scopeAxisMaster     => scopeAxisMaster,
         scopeAxisSlave      => scopeAxisSlave,
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
   -- clkOut(0) : 100.00 MHz system clock
   -- clkOut(1) : 200 MHz Idelaye2 calibration clock
   -- clkOut(2) : 100 MHz serial data bit clock
   -- clkOut(3) : 5 MHz ASIC readout clock
   U_CoreClockGen : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 4,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 10,
      CLKFBOUT_MULT_F_G    => 38.4,
      
      CLKOUT0_DIVIDE_F_G   => 6.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5,
      
      CLKOUT1_DIVIDE_G     => 3,
      CLKOUT1_PHASE_G      => 0.0,
      CLKOUT1_DUTY_CYCLE_G => 0.5,
      
      CLKOUT2_DIVIDE_G     => 6,
      CLKOUT2_PHASE_G      => 90.0,
      CLKOUT2_DUTY_CYCLE_G => 0.5,
      
      CLKOUT3_DIVIDE_G     => 120,
      CLKOUT3_PHASE_G      => 0.0,
      CLKOUT3_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => coreClk,
      clkOut(1) => iDelayCtrlClk,
      clkOut(2) => bitClk,
      clkOut(3) => asicRdClk,
      rstOut(0) => coreClkRst,
      rstOut(1) => iDelayCtrlRst,
      rstOut(2) => bitClkRst,
      rstOut(3) => asicRdClkRst,
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
   
   -------------------------------------------------------
   -- ASIC deserializers
   -------------------------------------------------------
   G_ASIC : for i in 0 to 1 generate 
      
      U_AsicDeser : entity work.Deserializer
      port map ( 
         bitClk         => bitClk,
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         
         -- serial data in
         asicDoutP      => asicDoutP(i),
         asicDoutM      => asicDoutM(i),
         
         -- status
         patternCnt     => open,
         testDone       => open,
         inSync         => inSync(i),
         
         -- decoded data out
         dataOut        => dataOut(i),
         dataKOut       => dataKOut(i),
         codeErr        => codeErr(i),
         dispErr        => dispErr(i),
         
         -- control
         resync         => '0',
         delay          => "00000"
      );
   
   end generate;
      
   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   -- Master 0 : PGP register controller     --
   -- Master 1 : Picoblaze reg controller    --
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
         axiClkRst           => axiRst);
   
   --------------------------------------------
   --     Master Register Controller         --
   --------------------------------------------   
   U_RegControl : entity work.RegControlGen2
      generic map (
         TPD_G                => TPD_G,
         NUM_ASICS_G          => NUM_ASICS_C,
         NUM_FAST_ADCS_G      => NUM_FAST_ADCS_C,
         CLK_PERIOD_G         => 10.0e-9
      )
      port map (
         axiClk         => coreClk,
         axiRst         => axiRst,
         sysRst         => sysRst,
         -- AXI-Lite Register Interface (axiClk domain)
         axiReadMaster  => mAxiReadMasters(COMMON_AXI_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(COMMON_AXI_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(COMMON_AXI_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(COMMON_AXI_INDEX_C),
         -- Register Inputs/Outputs (axiClk domain)
         epixStatus     => epixStatus,
         epixConfig     => epixConfig,
         scopeConfig    => scopeConfig,
         -- SACI prep-for-readout command request
         saciReadoutReq => saciPrepReadoutReq,
         saciReadoutAck => saciPrepReadoutAck,
         -- SACI interfaces to ASIC(s)
         saciClk        => saciClk,
         saciSelL       => iSaciSelL,
         saciCmd        => saciCmd,
         saciRsp        => saciRsp,
         -- SACI 
         -- Guard ring DAC interfaces
         dacSclk        => vGuardDacSclk,
         dacDin         => vGuardDacDin,
         dacCsb         => vGuardDacCsb,
         dacClrb        => vGuardDacClrb,
         -- 1-wire board ID interfaces
         serialIdIo     => serialIdIo,
         -- Fast ADC control 
         adcSpiClk      => adcSpiClk,
         adcSpiDataOut  => adcSpiDataOut,
         adcSpiDataIn   => adcSpiDataIn,
         adcSpiDataEn   => adcSpiDataEn,
         adcSpiCsb      => adcSpiCsb,
         adcPdwn        => iAdcPdwn
      );
   
   adcPdwn <= iAdcPdwn;

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

   ---------------------
   -- Acq control     --
   ---------------------      
   U_AcqControl : entity work.CpixAcqControl
      port map (
         sysClk          => coreClk,
         sysClkRst       => axiRst,
         
         acqStart        => acqStart,
         
         acqBusy         => acqBusy,
         readDone        => readDone,
         
         epixConfig      => epixConfig,
         
         saciReadoutReq  => saciPrepReadoutReq,
         saciReadoutAck  => saciPrepReadoutAck,
         
         asicEnA         => asicEnA,
         asicEnB         => asicEnB,
         asicVid         => asicVid,
         asicPPbe        => iAsicPpbe,
         asicPpmat       => iAsicPpmat,
         asicR0          => iAsicR0,
         asicSRO         => asicSRO,
         asicGlblRst     => iAsicGrst,
         asicSync        => iAsicSync,
         asicAcq         => iAsicAcq
   );
   
   asicAcq        <= iAsicAcq;
   asicR0         <= iAsicR0;
   asicPpmat(0)   <= iAsicPpmat;
   asicPpmat(1)   <= iAsicPpmat;
   asicPPbe(0)    <= iAsicPpbe;
   asicPPbe(1)    <= iAsicPpbe;
   asicSync       <= iAsicSync;
   asicGlblRst    <= iAsicGrst;
 
   ---------------------
   -- Readout control --
   ---------------------      
   U_ReadoutControl : entity work.CpixReadoutControl
      generic map (
        TPD_G                      => TPD_G,
        MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)
      )
      port map (
         sysClk         => coreClk,
         sysClkRst      => axiRst,
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         
         acqStart       => acqStart,
         dataSend       => dataSend,
         
         readDone       => readDone,
         acqBusy        => acqBusy,
         
         inSync         => inSync,
         dataOut        => dataOut,
         dataKOut       => dataKOut,
         codeErr        => codeErr,
         dispErr        => dispErr,
         
         epixConfig     => epixConfig,   -- total pixels to read
         acqCount       => epixStatus.acqCount,
         seqCount       => epixStatus.seqCount,
         envData        => epixStatus.envData,
         
         mAxisMaster    => userAxisMaster,
         mAxisSlave     => userAxisSlave
      );
         
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   -- ADC Clock outputs
   U_AdcClk0 : OBUFDS port map ( I => adcClk0, O => adcClkP(0), OB => adcClkN(0) );
   U_AdcClk1 : OBUFDS port map ( I => adcClk1, O => adcClkP(1), OB => adcClkN(1) );
   U_AdcClk2 : OBUFDS port map ( I => adcClk2, O => adcClkP(2), OB => adcClkN(2) );
   
   adcClk0 <= adcClk when iAdcPdwn(0) = '0' else '0';
   adcClk1 <= adcClk when iAdcPdwn(1) = '0' else '0';
   adcClk2 <= adcClk when iAdcPdwn(2) = '0' else '0';
   
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
   
   U_AdcReadout3x : entity work.AdcReadout3x
      generic map (
         TPD_G             => TPD_G,
         --IDELAYCTRL_FREQ_G => 300.0,
         IDELAYCTRL_FREQ_G => 200.0,
         ADC0_INVERT_CH    => ADC0_INVERT_CH,
         ADC1_INVERT_CH    => ADC1_INVERT_CH,
         ADC2_INVERT_CH    => ADC2_INVERT_CH
      )
      port map ( 
         -- Master system clock
         sysClk        => coreClk,
         sysClkRst     => serdesReset,
         -- Clock for IDELAYCTRL
         iDelayCtrlClk => iDelayCtrlClk,
         iDelayCtrlRst => iDelayCtrlRst,
         -- Configuration input for delays
         -- IDELAYCTRL status output
         epixConfig    => epixConfig,
         iDelayCtrlRdy => epixStatus.iDelayCtrlRdy,
         -- ADC Data Interface
         adcValid      => adcValid,
         adcData       => adcData,
         -- ADC Interface Signals
         adcFClkP      => adcFclkP,
         adcFClkN      => adcFclkN,
         adcDClkP      => adcDClkP,
         adcDClkN      => adcDclkN,
         adcChP        => adcChP,
         adcChN        => adcChN
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
         risingEdge  => adcCardPowerUpEdge);
   U_AdcCardPowerUpReset : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 50
      )
      port map (
         clk      => coreClk,
         asyncRst => adcCardPowerUpEdge,
         syncRst  => serdesReset);
   
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
         adcData       => epixStatus.slowAdc2Data,

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
         adcData       => epixStatus.slowAdc2Data,

         -- Converted data outputs
         outEnvData    => epixStatus.envData
      );
      

   --------------------------------------------
   --     ePix Startup Sequencer             --
   --------------------------------------------
   U_EpixStartup : entity work.EpixStartupGen2
      generic map (
         TPD_G => TPD_G
      )
      port map (
         sysClk           => coreClk,
         sysClkRst        => axiRst,
         startupReq       => epixConfig.requestStartupCal,
         startupAck       => epixStatus.startupAck,
         startupFail      => epixStatus.startupFail,
         adcValid         => adcValid,
         adcData          => adcData,
         pbAxiReadMaster  => sAxiReadMaster(1),
         pbAxiReadSlave   => sAxiReadSlave(1),
         pbAxiWriteMaster => sAxiWriteMaster(1),
         pbAxiWriteSlave  => sAxiWriteSlave(1)
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
   
end top_level;

