-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixCoreGen2.vhd
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-17
-- Last update: 2015-03-17
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
--
--Missing items:
--[X] Add user reset at write to register 0
--[~] Add Pseudoscope
--[~] Adapt pseudoscope to axistream
--[ ] Fix ring buffer issue (off by 1?) in pseudoscope
--[X] SACI command master in reg controller
--[~] Multipixel writes (implemented for 100a only)
--[A] Startup sequencer (PB for Artix-7)
--[X] Adapt readoutcontrol to axistream
--[X] IDs re-read on power/FPGA enable
--[X] ADC clock moves back into AcqControl
--[~] Instantiate slow ADC
--[~] Choose readout point of slow ADC (was this causing some common mode noise previously...?)
--[X] Fix implementation of PGP triggering to match Larry's
--[ ] Speed up ADC configuration (right now effective SPI CLK rate is ~200 kHz)
--[ ] Add assert to avoid successful compilation with an invalid ASIC code.
--[ ] Permanent 50 MHz ADC clock
--[ ] Add DDR
--[ ] Add I2C for SFP
--[ ] Add sync signals for DC-DC's
--[ ] Pins for digital outputs are all effed up, fix on new ADC card 
--[ ] Need a graceful way to handle overloading of Dm1/Dm2 with snIoCarrierCard
--
--[ ] Verify guard ring DAC
--[ ] Verify fast ADC handshaking (mainly for autocal and Ryan's DAQ)
--[ ] Verify strongback thermistor
--[ ] Make ASIC mask an AND of auto and user?

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

entity EpixCoreGen2 is
   generic (
      TPD_G       : time := 1 ns;
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
      asicDout            : in  slv(3 downto 0) := "0000"
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

   signal adcClk      : sl := '0';
   
   signal iDelayCtrlClk : sl;
   signal iDelayCtrlRst : sl;
   
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
   signal readValid          : slv(MAX_OVERSAMPLE_C-1 downto 0);
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
   
   signal iSaciSelL  : slv(3 downto 0);
   
   attribute keep : boolean;
   attribute keep of coreClk : signal is true;
   
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
         powerBad    => not(powerGood),
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
   -- TODO : Check it it is better to change back to 300 MHz. Modify picoblaze default delay range.
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
         adcPdwn        => adcPdwn
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

   ---------------------
   -- Acq control     --
   ---------------------      
   U_AcqControl : entity work.AcqControl
      port map (
         sysClk          => coreClk,
         sysClkRst       => axiRst,
         acqStart        => acqStart,
         acqBusy         => acqBusy,
         readDone        => readDone,
         readValid       => readValid,
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
         readValid      => readValid,
         readDone       => readDone,
         acqBusy        => acqBusy,
         dataSend       => dataSend,
         readTps        => readTps,
         adcPulse       => adcPulse,
         adcValid       => adcValid,
         adcData        => adcData,
         slowAdcData    => epixStatus.slowAdcData,
         envData        => epixStatus.envData,
         mAxisMaster    => userAxisMaster,
         mAxisSlave     => userAxisSlave,
         mpsOut         => open,
         asicDout       => asicDout
      );
         
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
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
   --     Slow ADC Readout ADC gen 1         --
   --------------------------------------------
   G_EPIX100A_SLOW_ADC_GEN1 : if (FPGA_VERSION_C(31 downto 16) = x"EA01") generate
   
      U_AdcCntrl : entity work.AdcCntrl 
         generic map (
            TPD_G        => TPD_G,
            N_CHANNELS_G => 8
         )
         port map ( 
            sysClk        => coreClk,
            sysClkRst     => axiRst,
            adcChanCount  => "0111",
            adcStart      => readDone,
            adcData       => epixStatus.slowAdcData,
            adcStrobe     => open,
            adcSclk       => slowAdcSclk,
            adcDout       => slowAdcDout,
            adcCsL        => slowAdcCsb,
            adcDin        => slowAdcDin
         );
      
   end generate;
   
   --------------------------------------------
   --     Slow ADC Readout ADC gen 2         --
   -------------------------------------------- 
   G_EPIX100A_SLOW_ADC_GEN2 : if (FPGA_VERSION_C(31 downto 16) = x"EA02") generate
     
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
      
   end generate;

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
         asicRoClk      => iAsicRoClk,
         asicSaciSel    => iSaciSelL,
         scopeConfig    => scopeConfig,
         acqCount       => epixStatus.acqCount,
         seqCount       => epixStatus.seqCount,
         mAxisMaster    => scopeAxisMaster,
         mAxisSlave     => scopeAxisSlave
      );
      
end top_level;
