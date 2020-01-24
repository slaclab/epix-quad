-------------------------------------------------------------------------------
-- Title      : Tixel Detector Readout System Core
-------------------------------------------------------------------------------
-- File       : TixelCore.vhd
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SsiCmdMasterPkg.all;
use surf.Pgp2bPkg.all;
use surf.Ad9249Pkg.all;
use surf.Code8b10bPkg.all;

use work.TixelPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TixelCore is
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
      ioPowerEn           : out sl;
      fpgaOutputEn        : out sl;
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
      saciSelL            : out slv(1 downto 0);
      saciCmd             : out sl;
      saciRsp             : in  sl;
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiData          : inout sl;
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
   
   signal asicRfClkDiv2 : sl;
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
   signal errInhibit    : sl;
   
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
   signal framerAxisMaster    : AxiStreamMasterArray(NUMBER_OF_ASICS_C-1 downto 0);
   signal framerAxisSlave     : AxiStreamSlaveArray(NUMBER_OF_ASICS_C-1 downto 0);
   signal userAxisMaster      : AxiStreamMasterType;
   signal userAxisSlave       : AxiStreamSlaveType;
   signal scopeAxisMaster     : AxiStreamMasterType;
   signal scopeAxisSlave      : AxiStreamSlaveType;
   signal monitorAxisMaster   : AxiStreamMasterType;
   signal monitorAxisSlave    : AxiStreamSlaveType;
   
   -- Command interface
   signal ssiCmd           : SsiCmdMasterType;
   
   -- Configuration and status
   signal tixelConfig      : TixelConfigType;
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
   
   signal acqStart           : sl;
   signal dataSend           : sl;
   signal saciPrepReadoutReq : sl;
   signal saciPrepReadoutAck : sl;
   
   -- Power up reset to SERDES block
   signal adcCardPowerUp     : sl;
   signal adcCardPowerUpEdge : sl;
   signal serdesReset        : sl;
   
   signal iSaciSelL        : slv(NUMBER_OF_ASICS_C-1 downto 0);
   signal iSaciClk         : sl;
   signal iSaciCmd         : sl;
   
   signal iAdcSpiCsb : slv(3 downto 0);
   signal iAdcPdwn   : slv(3 downto 0);
   
   signal tgOutMux         : sl;
   signal mpsOutMux        : sl;
   
   signal inSync           : slv(NUMBER_OF_ASICS_C-1 downto 0);
   
   signal monAdc        : Ad9249SerialGroupType;
   
   signal fpgaReload : sl;
   signal bootSck    : sl;
   
   signal adcClk     : sl;
   
   signal asicValid     : slv(NUMBER_OF_ASICS_C-1 downto 0);
   signal asicData      : Slv20Array(NUMBER_OF_ASICS_C-1 downto 0);
   
   signal pwrEnableAck     : sl;
   signal iDigitalPowerEn  : sl;
   signal iAnalogPowerEn   : sl;
   signal iIoPowerEn       : sl;
   
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
   attribute keep of errInhibit : signal is "true";
   
   
begin

   -- Fixed state logic signals
   sfpDisable     <= '0';
   -- Triggers in
   iRunTrigger    <= runTrigger;
   iDaqTrigger    <= daqTrigger;
   -- Triggers out
   --triggerOut     <= iAsicAcq;
   --mpsOut         <= pgpOpCodeOneShot;
   triggerOut     <= tgOutMux;
   mpsOut         <= mpsOutMux;
   -- SACI signals
   saciSelL       <= iSaciSelL;
   saciClk        <= iSaciClk;
   saciCmd        <= iSaciCmd;
   
   
   tgOutMux <= 
      iAsic01DM1        when tixelConfig.tixelDbgSel1 = "00000" else
      iAsicSync         when tixelConfig.tixelDbgSel1 = "00001" else
      iAsicStart        when tixelConfig.tixelDbgSel1 = "00010" else
      iAsicAcq          when tixelConfig.tixelDbgSel1 = "00011" else
      iAsicTpulse       when tixelConfig.tixelDbgSel1 = "00100" else
      iAsicR0           when tixelConfig.tixelDbgSel1 = "00101" else
      iSaciClk          when tixelConfig.tixelDbgSel1 = "00110" else
      iSaciCmd          when tixelConfig.tixelDbgSel1 = "00111" else
      saciRsp           when tixelConfig.tixelDbgSel1 = "01000" else
      iSaciSelL(0)      when tixelConfig.tixelDbgSel1 = "01001" else
      iSaciSelL(1)      when tixelConfig.tixelDbgSel1 = "01010" else
      asicRdClk         when tixelConfig.tixelDbgSel1 = "01011" else
      bitClk            when tixelConfig.tixelDbgSel1 = "01100" else
      byteClk           when tixelConfig.tixelDbgSel1 = "01101" else
      asicRfClkDiv2     when tixelConfig.tixelDbgSel1 = "01110" else
      '0';   
   
   mpsOutMux <=
      iAsic01DM2        when tixelConfig.tixelDbgSel2 = "00000" else
      iAsicSync         when tixelConfig.tixelDbgSel2 = "00001" else
      iAsicStart        when tixelConfig.tixelDbgSel2 = "00010" else
      iAsicAcq          when tixelConfig.tixelDbgSel2 = "00011" else
      iAsicTpulse       when tixelConfig.tixelDbgSel2 = "00100" else
      iAsicR0           when tixelConfig.tixelDbgSel2 = "00101" else
      iSaciClk          when tixelConfig.tixelDbgSel2 = "00110" else
      iSaciCmd          when tixelConfig.tixelDbgSel2 = "00111" else
      saciRsp           when tixelConfig.tixelDbgSel2 = "01000" else
      iSaciSelL(0)      when tixelConfig.tixelDbgSel2 = "01001" else
      iSaciSelL(1)      when tixelConfig.tixelDbgSel2 = "01010" else
      asicRdClk         when tixelConfig.tixelDbgSel2 = "01011" else
      bitClk            when tixelConfig.tixelDbgSel2 = "01100" else
      byteClk           when tixelConfig.tixelDbgSel2 = "01101" else
      asicRfClkDiv2     when tixelConfig.tixelDbgSel2 = "01110" else
      '0';
   
   -- Temporary one-shot for grabbing PGP op code
   U_OpCodeEnOneShot : entity surf.SynchronizerOneShot
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
   led(3) <= pwrEnableAck;
   led(2) <= rxReady;
   led(1) <= txReady;
   led(0) <= heartBeat;
   ---------------------
   -- Heart beat LED  --
   ---------------------
   U_Heartbeat : entity surf.Heartbeat
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
         -- Axi Slave Interface - PGP Status Registers (axiClk domain)
         sAxiLiteReadMaster  => mAxiReadMasters(PGPSTAT_AXI_INDEX_C),
         sAxiLiteReadSlave   => mAxiReadSlaves(PGPSTAT_AXI_INDEX_C),
         sAxiLiteWriteMaster => mAxiWriteMasters(PGPSTAT_AXI_INDEX_C),
         sAxiLiteWriteSlave  => mAxiWriteSlaves(PGPSTAT_AXI_INDEX_C),  
         -- Streaming data Links (axiClk domain)      
         dataAxisMaster    => userAxisMaster,
         dataAxisSlave     => userAxisSlave,
         scopeAxisMaster   => scopeAxisMaster,
         scopeAxisSlave    => scopeAxisSlave,
         monitorAxisMaster => monitorAxisMaster,
         monitorAxisSlave  => monitorAxisSlave,
         -- Monitoring enable command incoming stream
         monEnAxisMaster   => open,
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
   -- clkOut(0) : 80 MHz serial data bit clock
   -- clkOut(1) : 100.00 MHz system clock
   -- clkOut(2) : 8 MHz ASIC readout clock
   -- clkOut(3) : 20 MHz ASIC reference clock
   -- clkOut(4) : 200 MHz Idelaye2 calibration clock
   U_CoreClockGen : entity surf.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 5,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 10,
      CLKFBOUT_MULT_F_G    => 38.4,
      
      CLKOUT0_DIVIDE_F_G   => 7.5,
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
      CLKOUT3_DUTY_CYCLE_G => 0.5,
      
      CLKOUT4_DIVIDE_G     => 3,
      CLKOUT4_PHASE_G      => 0.0,
      CLKOUT4_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => bitClk,
      clkOut(1) => coreClk,
      clkOut(2) => asicRdClk,
      clkOut(3) => asicRfClk,
      clkOut(4) => iDelayCtrlClk,
      rstOut(0) => bitClkRst,
      rstOut(1) => coreClkRst,
      rstOut(2) => asicRdClkRst,
      rstOut(3) => asicRfClkRst,
      rstOut(4) => iDelayCtrlRst,
      locked    => open,
      -- AXI-Lite Interface       
      axilClk           => coreClk,
      axilRst           => axiRst,
      axilReadMaster    => mAxiReadMasters(PLLREGS_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(PLLREGS_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(PLLREGS_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(PLLREGS_AXI_INDEX_C)
   );
   
   U_BUFR1 : BUFR
   generic map (
      SIM_DEVICE  => "7SERIES",
      BUFR_DIVIDE => "2"
   )
   port map (
      I   => asicRfClk,
      O   => asicRfClkDiv2,
      CE  => '1',
      CLR => '0'
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
   
   U_RdPwrUpRst : entity surf.PwrUpRst
   generic map (
      DURATION_G => 20000000
   )
   port map (
      clk      => byteClk,
      rstOut   => byteClkRst
   );
   
   
   G_ASIC : for i in 0 to NUMBER_OF_ASICS_C-1 generate 
   
      -------------------------------------------------------
      -- ASIC clock outputs
      -------------------------------------------------------      
      roClkDdr_i : ODDR 
      port map ( 
         Q  => asicRoClk(i),
         C  => asicRdClk,
         CE => '1',
         D1 => '1',
         D2 => '0',
         R  => '0',
         S  => '0'
      );
      
      refClkDdr_i : ODDR 
      port map ( 
         Q  => asicRefClk(i),
         C  => asicRfClk,
         CE => '1',
         D1 => '1',
         D2 => '0',
         R  => '0',
         S  => '0'
      );
   
      -------------------------------------------------------
      -- ASIC deserializers
      -------------------------------------------------------      
      U_AsicDeser : entity work.Deserializer
      generic map (
         IODELAY_GROUP_G => IODELAY_GROUP_G
      )
      port map ( 
         bitClk            => bitClk,
         byteClk           => byteClk,
         byteRst           => byteClkRst,
         serDinP           => asicDoutP(i),
         serDinM           => asicDoutM(i),
         axilClk           => coreClk,
         axilRst           => axiRst,
         axilReadMaster    => mAxiReadMasters(DESER0_AXI_INDEX_C+i),
         axilReadSlave     => mAxiReadSlaves(DESER0_AXI_INDEX_C+i),
         axilWriteMaster   => mAxiWriteMasters(DESER0_AXI_INDEX_C+i),
         axilWriteSlave    => mAxiWriteSlaves(DESER0_AXI_INDEX_C+i),
         rxData            => asicData(i),
         rxValid           => asicValid(i)
      );
      
      -------------------------------------------------------
      -- ASIC AXI stream framers
      -------------------------------------------------------
      
      U_AXI_Framer : entity work.AsicStreamAxi
      generic map (
         ASIC_NO_G   => std_logic_vector(to_unsigned(i, 3))
      )
      port map (
         rxClk             => byteClk,
         rxRst             => byteClkRst,
         rxData            => asicData(i),
         rxValid           => asicValid(i),
         axilClk           => coreClk,
         axilRst           => axiRst,
         sAxilWriteMaster  => mAxiWriteMasters(ASICS0_AXI_INDEX_C+i),
         sAxilWriteSlave   => mAxiWriteSlaves(ASICS0_AXI_INDEX_C+i),
         sAxilReadMaster   => mAxiReadMasters(ASICS0_AXI_INDEX_C+i),
         sAxilReadSlave    => mAxiReadSlaves(ASICS0_AXI_INDEX_C+i),
         axisClk           => coreClk,
         axisRst           => axiRst,
         mAxisMaster       => framerAxisMaster(i),
         mAxisSlave        => framerAxisSlave(i),
         acqNo             => tixelConfig.acqCnt,
         testTrig          => iAsicAcq,
         errInhibit        => errInhibit
      );
   
   end generate;
   
   
   -------------------------------------------------------
   -- AXI stream mux
   -------------------------------------------------------
   U_AxiStreamMux : entity surf.AxiStreamMux
   generic map(
      NUM_SLAVES_G   => NUMBER_OF_ASICS_C
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
   
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   -- Master 0 : PGP register controller     --
   -- Master 1 : Microblaze reg controller    --
   -- Master 2 : SaciPrepRdout controller    --
   --------------------------------------------
   U_AxiLiteCrossbar : entity surf.AxiLiteCrossbar
   generic map (
      NUM_SLAVE_SLOTS_G  => TIXEL_NUM_AXI_SLAVE_SLOTS_C,
      NUM_MASTER_SLOTS_G => TIXEL_NUM_AXI_MASTER_SLOTS_C,
      MASTERS_CONFIG_G   => TIXEL_AXI_CROSSBAR_MASTERS_CONFIG_C
   )
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
   
   ---------------------------------------------
   -- SACI prepare for readout command Master --
   ---------------------------------------------
   U_SaciPrepRdout : entity work.SaciPrepRdout
   generic map (
      MASK_REG_ADDR_G    => x"01000210",
      SACI_BASE_ADDR_G   => x"04000000"
   )
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
      mAxilWriteMaster  => sAxiWriteMaster(2),
      mAxilWriteSlave   => sAxiWriteSlave(2),
      mAxilReadMaster   => sAxiReadMaster(2),
      mAxilReadSlave    => sAxiReadSlave(2)
   );
   
   --------------------------------------------
   --     Master Register Controllers        --
   --------------------------------------------   
   
   -- Tixel register controller
   
   U_RegControlTixel : entity work.RegControlTixel
   generic map (
      TPD_G          => TPD_G,
      BUILD_INFO_G   => BUILD_INFO_G
   )
   port map (
      axiClk         => coreClk,
      axiRst         => axiRst,
      sysRst         => sysRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(TIXEL_REG_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(TIXEL_REG_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(TIXEL_REG_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(TIXEL_REG_AXI_INDEX_C),
      -- Register Inputs/Outputs (axiClk domain)
      tixelConfig    => tixelConfig,
      -- Guard ring DAC interfaces
      dacSclk        => vGuardDacSclk,
      dacDin         => vGuardDacDin,
      dacCsb         => vGuardDacCsb,
      dacClrb        => vGuardDacClrb,
      -- 1-wire board ID interfaces
      serialIdIo     => serialIdIo,
      -- fast ADC clock
      adcClk         => adcClk,
      -- ASICs acquisition signals
      acqStart       => acqStart,
      asicRefClkDiv2 => asicRfClkDiv2,
      saciReadoutReq => saciPrepReadoutReq,
      saciReadoutAck => saciPrepReadoutAck,
      asicPPbe       => iAsicPpbe,
      asicPpmat      => iAsicPpmat,
      asicTpulse     => iAsicTpulse,
      asicStart      => iAsicStart,
      asicR0         => iAsicR0,
      asicGlblRst    => iAsicGrst,
      asicSync       => iAsicSync,
      asicAcq        => iAsicAcq,
      errInhibit     => errInhibit
   );
   
   asicAcq        <= iAsicAcq;
   asicR0         <= iAsicR0;
   asicPpmat      <= iAsicPpmat;
   asicPPbe       <= iAsicPpbe;
   asicSync       <= iAsicSync;
   asicGlblRst    <= iAsicGrst;
   asicTpulse     <= iAsicTpulse;
   asicStart      <= iAsicStart;
   
   iAsic01DM1     <= asic01DM1;
   iAsic01DM2     <= asic01DM2;
   
   --------------------------------------------
   --     Tixel power seqence controller     --
   --------------------------------------------   
   U_TixelPwrCtrl: entity work.TixelPwrCtrl
   generic map (
      ON_DIG_ANA_G   => 1000000, -- 10 ms @ 100MHz
      ON_ANA_IO_G    => 1000000,
      OFF_IO_ANA_G   => 1000000,
      OFF_ANA_DIG_G  => 1000000
   )
   port map ( 
      clk         => coreClk,
      rst         => axiRst,
      enableReq   => tixelConfig.pwrEnableReq,
      enableAck   => pwrEnableAck,
      digPwr      => iDigitalPowerEn,
      anaPwr      => iAnalogPowerEn,
      ioPwr       => iIoPowerEn
   );
   
   -- Map out power enables
   digitalPowerEn <= iDigitalPowerEn   when tixelConfig.pwrManual = '0' else tixelConfig.pwrManualDig;
   analogPowerEn  <= iAnalogPowerEn    when tixelConfig.pwrManual = '0' else tixelConfig.pwrManualAna;
   ioPowerEn      <= iIoPowerEn        when tixelConfig.pwrManual = '0' else tixelConfig.pwrManualIo;
   fpgaOutputEn   <= iIoPowerEn        when tixelConfig.pwrManual = '0' else tixelConfig.pwrManualFpga;
   
   --------------------------------------------
   -- SACI interface controller              --
   -------------------------------------------- 
   U_AxiLiteSaciMaster : entity surf.AxiLiteSaciMaster
   generic map (
      AXIL_CLK_PERIOD_G  => 10.0E-9, -- In units of seconds
      AXIL_TIMEOUT_G     => 1.0E-3,  -- In units of seconds
      SACI_CLK_PERIOD_G  => 0.25E-6, -- In units of seconds
      SACI_CLK_FREERUN_G => false,
      SACI_RSP_BUSSED_G  => true,
      SACI_NUM_CHIPS_G   => NUMBER_OF_ASICS_C)
   port map (
      -- SACI interface
      saciClk           => iSaciClk,
      saciCmd           => iSaciCmd,
      saciSelL          => iSaciSelL,
      saciRsp(0)        => saciRsp,
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
   
   --------------------------------------------
   --     Fast ADC Readout                   --
   --------------------------------------------
   
   -- ADC Clock outputs
   U_AdcClk2 : OBUFDS port map ( I => adcClk, O => adcClkP(2), OB => adcClkN(2) );
   
   -- Tap delay calibration  
   U_IDelayCtrl : IDELAYCTRL
   port map (
      REFCLK => iDelayCtrlClk,
      RST    => iDelayCtrlRst,
      RDY    => open
   );   
   
   monAdc.fClkP <= adcFClkP(2);
   monAdc.fClkN <= adcFClkN(2);
   monAdc.dClkP <= adcDClkP(2);
   monAdc.dClkN <= adcDClkN(2);
   monAdc.chP   <= adcChP(19 downto 16);
   monAdc.chN   <= adcChN(19 downto 16);
      
   U_MonAdcReadout : entity surf.Ad9249ReadoutGroup
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
      axilReadMaster    => mAxiReadMasters(ADC_RD_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(ADC_RD_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(ADC_RD_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(ADC_RD_AXI_INDEX_C),

      -- Reset for adc deserializer
      adcClkRst         => serdesReset,

      -- Serial Data from ADC
      adcSerial         => monAdc,

      -- Deserialized ADC Data
      adcStreamClk      => coreClk,
      adcStreams        => adcStreams(19 downto 16)
   );
   
   
   -- Give a special reset to the SERDES blocks when power
   -- is turned on to ADC card.
   adcCardPowerUp <= iDigitalPowerEn and iAnalogPowerEn and iIoPowerEn;
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
   --     Fast ADC Config                    --
   --------------------------------------------
   
   U_AdcConf : entity surf.Ad9249Config
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
   --     Slow ADC Readout  --
   -------------------------------------------- 
   
   U_AdcCntrl: entity work.CpixTixelSlowAdcCntrlAxi
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
   -- Microblaze based ePix Startup Sequencer --
   ---------------------------------------------
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
      interrupt(7 downto 1)   => "000000",
      interrupt(0)            => tixelConfig.requestStartupCal,
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
   U_LogMem : entity surf.AxiDualPortRam
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
   
   U_PseudoScope : entity work.PseudoScopeAxi
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
      asicSaciSel(1 downto 0) => iSaciSelL,
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
   
   GenAdcStr : for i in 0 to 19 generate 
      adcData(i)  <= adcStreams(i).tData(15 downto 0);
      adcValid(i) <= adcStreams(i).tValid;
   end generate;
   
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
   U_Iprog7Series : entity surf.Iprog7Series
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
   U_AxiMicronN25QCore : entity surf.AxiMicronN25QCore
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

