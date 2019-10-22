-------------------------------------------------------------------------------
-- Title         : Acquisition Control Block
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : AcqControl.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- Acquisition control block
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-- [MK] 01/14/2016 - Removed unused sync modes and reset prepulse. 
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.EpixPkgGen2.all;
use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity AcqControl is
   generic (
      ASIC_TYPE_G       : AsicType := EPIX100A_C
   );
   port (

      -- Clocks and reset
      sysClk              : in    std_logic;
      sysClkRst           : in    std_logic;

      -- Run control
      acqStart            : in    std_logic;
      acqBusy             : out   std_logic;
      readDone            : in    std_logic;
      readValidA0         : out   std_logic;
      readValidA1         : out   std_logic;
      readValidA2         : out   std_logic;
      readValidA3         : out   std_logic;
      adcPulse            : out   std_logic;
      readTps             : out   std_logic;
      roClkTail           : in    std_logic_vector(7 downto 0);

      -- Configuration
      epixConfig          : in    EpixConfigType;
      epixConfigExt       : in    EpixConfigExtType;

      -- SACI Command
      saciReadoutReq      : out   std_logic;
      saciReadoutAck      : in    std_logic;

      -- Fast ADC Readout
      adcClkP             : out   std_logic_vector(2 downto 0);
      adcClkM             : out   std_logic_vector(2 downto 0);

      -- ASIC Control
      asicR0              : out   std_logic;
      asicPpmat           : out   std_logic;
      asicPpbe            : out   std_logic;
      asicGlblRst         : out   std_logic;
      asicAcq             : out   std_logic;
      asicSync            : out   std_logic;
      asicRoClk           : out   std_logic

   );
end AcqControl;


-- Define architecture
architecture AcqControl of AcqControl is
   
   
   -- epix10ka dummy acquisition settings
   -- dummy acquisition to remove the ghost
   constant DUMMY_ASIC_ROCLK_HALFT_C   : natural := 2;
   constant DUMMY_ASIC_R0_TO_ACQ_C     : natural := 2500;
   constant DUMMY_ASIC_ACQ_WIDTH_C     : natural := 2500;
   
   -- arbitrary sync pulse width (1us)
   constant SYNC_WIDTH_C               : natural := 100;
   
   constant DUMMY_ACQ_EN_C : boolean := ite(ASIC_TYPE_G = EPIX10KA_C, true, false);
   
   signal dummyAcq : sl;
   signal dummyAcqSet : sl;
   signal dummyAcqClr : sl;

   -- Local Signals
   signal adcClk             : std_logic             := '0';
   signal adcClkEdge         : std_logic             := '0';
   signal asicClk            : std_logic             := '0';
   signal acqStartEdge       : std_logic             := '0';
   signal adcCnt             : unsigned(31 downto 0) := (others => '0');
   signal adcSampCnt         : slv(31 downto 0) := (others => '0');
   signal adcSampCntEn       : sl := '0';
   signal adcSampCntRst      : sl := '0';
   signal rstCnt             : unsigned(25 downto 0) := (others => '0');
   signal stateCnt           : unsigned(31 downto 0) := (others => '0');
   signal stateCntEn         : sl := '0';
   signal stateCntRst        : sl := '0';
   signal pixelCnt           : unsigned(31 downto 0) := (others => '0');
   signal pixelCntEn         : sl := '0';
   signal pixelCntRst        : sl := '0';
   signal iReadValid         : sl := '0';
   signal iReadValidWaitingA0: sl := '0';
   signal iReadValidWaitingA1: sl := '0';
   signal iReadValidWaitingA2: sl := '0';
   signal iReadValidWaitingA3: sl := '0';
   signal iReadValidTestMode : sl := '0';
   signal readValidDelayedA0 : slv(127 downto 0);
   signal readValidDelayedA1 : slv(127 downto 0);
   signal readValidDelayedA2 : slv(127 downto 0);
   signal readValidDelayedA3 : slv(127 downto 0);
   signal firstPixel         : sl := '0';
   signal firstPixelSet      : sl := '0';
   signal firstPixelRst      : sl := '0';
   signal iAcqBusy           : sl := '0';
   signal risingAcq          : sl := '0';
   signal fallingAcq         : sl := '0';
   signal iTpsDelayed        : sl := '0';
   signal iTps               : sl := '0';

   -- Multiplexed ASIC outputs.  These versions are the
   -- automatic ones controlled by state machine.
   -- You can override them with the manualPinControl config bits.
   signal iAsicR0          : std_logic := '0';
   signal iAsicPpmat       : std_logic := '0';
   signal iAsicPpmatRising : std_logic := '0';
   signal iAsicPpbe        : std_logic := '0';
   signal iAsicGlblRst     : std_logic := '0';
   signal iAsicAcq         : std_logic := '0';
   signal iAsicClk         : std_logic := '0';
   
   signal iAsicSync         : sl;
   
   -- Alternate R0 that can be used for "original" polarity
   -- (i.e., usually low except before ACQ and through readout)
   signal iAsicR0Alt    : std_logic             := '0';

   -- State machine values
   type state is (IDLE_S,
                  WAIT_R0_S,
                  PULSE_R0_S,
                  WAIT_ACQ_S,
                  ACQ_S,
                  DROP_ACQ_S,
                  WAIT_PPMAT_S,
                  WAIT_POST_PPMAT_S,
                  SYNC_TO_ADC_S,
                  WAIT_ADC_S,
                  NEXT_CELL_S,
                  
                  WAIT_DOUT_S,
                  NEXT_DOUT_S,
                  
                  WAIT_FOR_READOUT_S,
                  SACI_RESET_S,
                  DONE_S);
   signal curState           : state := IDLE_S;
   signal nxtState           : state := IDLE_S;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;
   
   attribute keep : string;
   attribute keep of pixelCnt : signal is "true";
   attribute keep of curState : signal is "true";
   attribute keep of iReadValid : signal is "true";
   

begin

   -- ADC Clock outputs
   U_AdcClk0 : OBUFDS port map ( I => adcClk, O => adcClkP(0), OB => adcClkM(0) );
   U_AdcClk1 : OBUFDS port map ( I => adcClk, O => adcClkP(1), OB => adcClkM(1) );
   U_AdcClk2 : OBUFDS port map ( I => adcClk, O => adcClkP(2), OB => adcClkM(2) );

   -- Single ended version out
   asicRoClk <= asicClk;

   --MUXes for manual control of ASIC signals
   asicGlblRst <= iAsicGlblRst           when ePixConfig.manualPinControl(0) = '0' else
                  ePixConfig.asicPins(0) when ePixConfig.manualPinControl(0) = '1' else
                  'X';
   asicAcq     <= iAsicAcq               when ePixConfig.manualPinControl(1) = '0' else
                  ePixConfig.asicPins(1) when ePixConfig.manualPinControl(1) = '1' else
                  'X';
   -- removed asicR0Mode = '0' option. R0 must be low in IDLE otherwise the matrix configuration does not work.
   asicR0      <= iAsicR0Alt             when ePixConfig.manualPinControl(2) = '0' and ePixConfig.asicR0Mode = '0' else
                  iAsicR0Alt             when ePixConfig.manualPinControl(2) = '0' and ePixConfig.asicR0Mode = '1' else
                  ePixConfig.asicPins(2) when ePixConfig.manualPinControl(2) = '1' else
                  'X';
   asicPpmat   <= iAsicPpmat             when ePixConfig.manualPinControl(3) = '0' else
                  ePixConfig.asicPins(3) when ePixConfig.manualPinControl(3) = '1' else
                  'X';
   asicPpbe    <= iAsicPpbe              when ePixConfig.manualPinControl(4) = '0' else
                  ePixConfig.asicPins(4) when ePixConfig.manualPinControl(4) = '1' else
                  'X';
   asicClk     <= iAsicClk               when ePixConfig.manualPinControl(5) = '0' else
                  ePixConfig.asicPins(5) when ePixConfig.manualPinControl(5) = '1' else
                  'X';
   asicSync    <= iAsicSync;
   
   --Outputs not incorporated into state machine at the moment
   iAsicPpbe    <= '1'; 

   --Read TPS signal
   readTps <= iTpsDelayed;

   --Busy is internal busy or data left in the pipeline
   acqBusy <= iAcqBusy or iReadValidWaitingA0 or iReadValidWaitingA1 or iReadValidWaitingA2 or iReadValidWaitingA3;
   
   -- ADC pulse signal allows counting of adc cycles in other blocks
   adcPulse <= adcClkEdge;
   
   U_ReadStartEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => acqStart,
         risingEdge => acqStartEdge
      );


-- Normal path for taking data frames
   --Asynchronous state machine outputs
   process(curState,stateCnt,adcSampCnt,ePixConfig, saciReadoutAck, dummyAcq) begin
      --All signals default values
      iAsicClk           <= '0' after tpd;
      iAsicR0            <= '1' after tpd;
      iAsicR0Alt         <= '1' after tpd;
      iAsicPpmat         <= '0' after tpd;
      iAsicAcq           <= '0' after tpd;
      iAsicSync          <= '0' after tpd;
      saciReadoutReq     <= '0' after tpd;
      stateCntEn         <= '0' after tpd;
      stateCntRst        <= '0' after tpd;
      adcSampCntRst      <= '0' after tpd;
      adcSampCntEn       <= '0' after tpd;
      pixelCntEn         <= '0' after tpd;
      pixelCntRst        <= '1' after tpd;
      iAcqBusy           <= '1' after tpd;
      firstPixelRst      <= '0' after tpd;
      firstPixelSet      <= '0' after tpd;
      iReadValidTestMode <= '0' after tpd;
      case curState is
         --Idle state, all signals zeroed out, counters reset
         when IDLE_S =>
            iAcqBusy        <= '0' after tpd;
            stateCntRst     <= '1' after tpd;
            adcSampCntRst   <= '1' after tpd;
            firstPixelRst   <= '1' after tpd;
            iAsicR0Alt      <= '0' after tpd;
         --Bring up PPmat through just before the asicClk
         when WAIT_R0_S =>
            iAsicPpmat      <= '1' after tpd;
            iAsicR0Alt      <= '0' after tpd;
            if stateCnt < unsigned(ePixConfig.acqToAsicR0Delay)  and dummyAcq = '0' then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Drop R0 low before asicAcq
         when PULSE_R0_S =>
            iAsicPpmat      <= '1' after tpd;
            iAsicR0         <= '0' after tpd;
            iAsicR0Alt      <= '0' after tpd;
            if stateCnt < unsigned(ePixConfig.asicR0Width) and dummyAcq = '0' then
               stateCntEn      <= '1' after tpd;
            else 
               stateCntRst     <= '1' after tpd;
            end if;
         --Bring up R0 and hold through the rest of the readout
         when WAIT_ACQ_S =>
            iAsicPpmat      <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicR0ToAsicAcq) and dummyAcq = '0' then
               stateCntEn      <= '1' after tpd;
            elsif stateCnt < DUMMY_ASIC_R0_TO_ACQ_C-1 and dummyAcq = '1' then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Bring up Acq and hold for a specified time
         when ACQ_S =>
            iAsicPpmat      <= '1' after tpd;
            iAsicAcq        <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicAcqWidth) and dummyAcq = '0' then
               stateCntEn      <= '1' after tpd;
            elsif stateCnt < DUMMY_ASIC_ACQ_WIDTH_C-1 and dummyAcq = '1' then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Drop ACQ and send the SACI reset to reset pixel position
         when DROP_ACQ_S =>
            iAsicPpmat      <= '1' after tpd;
            stateCntEn      <= '1' after tpd;
         --Ensure that the minimum hold off time has been enforced before dropping PPmat
         --Send the signal to read the test point system here (last item before power down)
         when WAIT_PPMAT_S =>
            iAsicPpmat <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicAcqLToPPmatL) and dummyAcq = '0' then
               stateCntEn   <= '1' after tpd;
            else
               stateCntRst  <= '1' after tpd;
            end if;
         -- Programmable delay before starting the readout after dropping PPmat
         when WAIT_POST_PPMAT_S =>
            if stateCnt < unsigned(ePixConfig.asicPPmatToReadout) and dummyAcq = '0' then
               stateCntEn <= '1' after tpd;
            else
               stateCntRst <= '1' after tpd;
            end if;
         --Synchronize phases of ASIC RoClk and ADC clk
         when SYNC_TO_ADC_S =>
         --Wait for the ADC to readout the desired number of samples
         --(or a minimum of the ASIC clock half period)
         when WAIT_ADC_S =>
            pixelCntRst   <= '0' after tpd;
            adcSampCntEn  <= '1' after tpd;
            firstPixelSet <= '1' after tpd;
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or ePixConfig.asicRoClkHalfT = 0) and dummyAcq = '0' then
               stateCntRst     <= '1' after tpd;
               pixelCntEn      <= '1' after tpd;
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               stateCntRst     <= '1' after tpd;
               pixelCntEn      <= '1' after tpd;
            else
               stateCntEn      <= '1' after tpd;
            end if;
         --Clock once to the next cell
         when NEXT_CELL_S =>
            pixelCntRst  <= '0' after tpd;
            adcSampCntEn <= '1';
            iAsicClk     <= '1' after tpd;
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or ePixConfig.asicRoClkHalfT = 0) and dummyAcq = '0' then
               adcSampCntRst   <= '1' after tpd;
               stateCntRst     <= '1' after tpd;
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               adcSampCntRst   <= '1' after tpd;
               stateCntRst     <= '1' after tpd;
            else
               stateCntEn      <= '1' after tpd;
            end if;
         
         
         -- continue asicClk until all douts are captured (epix10ka only)
         when NEXT_DOUT_S =>
            pixelCntRst  <= '0' after tpd;
            iAsicClk     <= '1' after tpd;
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or ePixConfig.asicRoClkHalfT = 0) and dummyAcq = '0' then
               stateCntRst     <= '1' after tpd;
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               stateCntRst     <= '1' after tpd;
            else
               stateCntEn      <= '1' after tpd;
            end if;
            
         when WAIT_DOUT_S =>
            pixelCntRst   <= '0' after tpd;
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or ePixConfig.asicRoClkHalfT = 0) and dummyAcq = '0' then
               stateCntRst     <= '1' after tpd;
               pixelCntEn      <= '1' after tpd;
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               stateCntRst     <= '1' after tpd;
               pixelCntEn      <= '1' after tpd;
            else
               stateCntEn      <= '1' after tpd;
            end if;
            
         
         --Wait for readout to finish before sending SACI
         --"prepare for readout."  This way we avoid cross-talk
         --with the ADC lines.
         when WAIT_FOR_READOUT_S =>
            iAcqBusy       <= '0' after tpd;
            iAsicR0Alt     <= '0' after tpd;
         --Send SACI prepare for readout for the next event
         when SACI_RESET_S =>
            saciReadoutReq <= '0' after tpd; -- use SYNC pin to allow higher frame rates
            iAsicSync      <= '1' after tpd;
            iAcqBusy       <= '0' after tpd;
            iAsicR0Alt     <= '0' after tpd;
            if stateCnt < SYNC_WIDTH_C then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Done
         when DONE_S =>
            iAcqBusy       <= '0' after tpd;
            iAsicR0Alt     <= '0' after tpd;
         --Undefined states: treat with default
         when others =>
      end case;
   end process;

   --Next state logic
   process(curState,acqStartEdge,stateCnt,saciReadoutAck,adcSampCnt,pixelCnt,ePixConfig,adcClkEdge,readDone,roClkTail,dummyAcq,epixConfigExt) begin
      
      dummyAcqSet <= '0' after tpd;
      dummyAcqClr <= '0' after tpd;
      
      case curState is
         --Remain idle until we get the acqStart signal
         when IDLE_S =>
            dummyAcqClr <= '1' after tpd;
            if acqStartEdge = '1' then
               nxtState <= WAIT_R0_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait a specified number of clock cycles before bringing asicR0 up
         when WAIT_R0_S =>
            if stateCnt = unsigned(ePixConfig.acqToAsicR0Delay) or dummyAcq = '1' then
               nxtState <= PULSE_R0_S after tpd;
            else
               nxtState <= curState after tpd;
            end if; 
         --Pulse R0 low for a specified number of clock cycles
         when PULSE_R0_S =>
            if stateCnt = unsigned(ePixConfig.asicR0Width) or dummyAcq = '1' then
               nxtState <= WAIT_ACQ_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait a specified number of clock cycles before bringing asicAcq up
         when WAIT_ACQ_S => 
            if stateCnt = unsigned(ePixConfig.asicR0ToAsicAcq) and dummyAcq = '0' then
               nxtState <= ACQ_S after tpd;
            elsif stateCnt = DUMMY_ASIC_R0_TO_ACQ_C-1 and dummyAcq = '1' then
               nxtState <= ACQ_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Hold acq high for a specified time
         when ACQ_S =>
            if stateCnt = unsigned(ePixConfig.asicAcqWidth) and dummyAcq = '0' then
               nxtState <= DROP_ACQ_S after tpd;
            elsif stateCnt = DUMMY_ASIC_ACQ_WIDTH_C-1 and dummyAcq = '1' then
               nxtState <= DROP_ACQ_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait for the matrix counter to reset (via saci interface)
         when DROP_ACQ_S =>
            nxtState <= WAIT_PPMAT_S after tpd;
         --Ensure that the minimum hold off time has been enforced before dropping PPmat
         when WAIT_PPMAT_S =>
            if stateCnt = unsigned(ePixConfig.asicAcqLToPPmatL) or dummyAcq = '1' then
               nxtState <= WAIT_POST_PPMAT_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         -- Programmable delay before starting the readout after dropping PPmat
         when WAIT_POST_PPMAT_S =>
            if stateCnt = unsigned(ePixConfig.asicPPmatToReadout) or dummyAcq = '1' then
               nxtState <= SYNC_TO_ADC_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Synchronize phases of ASIC RoClk and ADC clk
         when SYNC_TO_ADC_S =>
            if adcClkEdge = '1' then
               nxtState <= NEXT_CELL_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --ADC reads out while we wait a half period of RoClk.  If we're done with all pixels, finish.
         when WAIT_ADC_S => 
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or unsigned(ePixConfig.asicRoClkHalfT) = 0) and dummyAcq = '0' then
               if pixelCnt < unsigned(ePixConfig.totalPixelsToRead)-1 then
                  nxtState <= NEXT_CELL_S after tpd;
               else
                  if unsigned(roClkTail) = 0 then
                     nxtState <= WAIT_FOR_READOUT_S after tpd;
                  else
                     nxtState <= NEXT_DOUT_S after tpd;
                  end if;
               end if;
            -- do faster (dummy) readout 
            -- DUMMY_ASIC_ROCLK_HALFT_C = 2 -> 40ns -> 25MHz (this clock is divided by 4 inside epix10kA)
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               if pixelCnt < unsigned(ePixConfig.totalPixelsToRead)-1 then
                  nxtState <= NEXT_CELL_S after tpd;
               else
                  if unsigned(roClkTail) = 0 then
                     nxtState <= WAIT_FOR_READOUT_S after tpd;
                  else
                     nxtState <= NEXT_DOUT_S after tpd;
                  end if;
               end if;
            else
               nxtState <= curState after tpd;
            end if;
         --Toggle the asicClk, then back to ADC readouts if there are more pixels to read.
         when NEXT_CELL_S => 
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or unsigned(ePixConfig.asicRoClkHalfT) = 0) and dummyAcq = '0' then
               nxtState <= WAIT_ADC_S after tpd;
            -- do faster (dummy) readout 
            -- DUMMY_ASIC_ROCLK_HALFT_C = 2 -> 40ns -> 25MHz (this clock is divided by 4 inside epix10kA)
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               nxtState <= WAIT_ADC_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         
         -- continue asicClk untill all douts are captured (epix10ka only)
         when NEXT_DOUT_S => 
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or unsigned(ePixConfig.asicRoClkHalfT) = 0) and dummyAcq = '0' then
               nxtState <= WAIT_DOUT_S after tpd;
            -- do faster (dummy) readout 
            -- DUMMY_ASIC_ROCLK_HALFT_C = 2 -> 40ns -> 25MHz (this clock is divided by 4 inside epix10kA)
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               nxtState <= WAIT_DOUT_S after tpd;
            else 
               nxtState <= curState after tpd;
            end if;
         
         when WAIT_DOUT_S => 
            if (stateCnt = unsigned(ePixConfig.asicRoClkHalfT)-1 or unsigned(ePixConfig.asicRoClkHalfT) = 0) and dummyAcq = '0' then
               if pixelCnt < unsigned(ePixConfig.totalPixelsToRead)+unsigned(roClkTail)-1 then
                  nxtState <= NEXT_DOUT_S after tpd;
               else
                  nxtState <= WAIT_FOR_READOUT_S after tpd;
               end if;
            -- do faster (dummy) readout 
            -- DUMMY_ASIC_ROCLK_HALFT_C = 2 -> 40ns -> 25MHz (this clock is divided by 4 inside epix10kA)
            elsif stateCnt = DUMMY_ASIC_ROCLK_HALFT_C-1 and dummyAcq = '1' then
               if pixelCnt < unsigned(ePixConfig.totalPixelsToRead)+unsigned(roClkTail)-1 then
                  nxtState <= NEXT_DOUT_S after tpd;
               else
                  nxtState <= SACI_RESET_S after tpd;
               end if;
            else
               nxtState <= curState after tpd;
            end if;
         
         --Wait for readout to finish before sending SACI commands
         when WAIT_FOR_READOUT_S =>
            if readDone = '1' then
               nxtState <= SACI_RESET_S;
            else
               nxtState <= curState after tpd;
            end if;
         --Use SACI prepare for readout
         when SACI_RESET_S =>
            -- arbitrary sync pulse width (1us)
            if stateCnt >= SYNC_WIDTH_C then
               -- this is implementing the gost effect correction in epix10ka
               -- until we have new ASICs with a proper fix
               -- run one more dummy ASIC acquisition cycle
               -- outputs won't be sampled and sent out
               -- the dummy cycle will be faster than normal acq cycle
               if dummyAcq = '0' and epixConfigExt.ghostCorr = '1' then
                  nxtState <= WAIT_R0_S after tpd;
                  dummyAcqSet <= '1' after tpd;
               else
                  nxtState <= DONE_S after tpd;
               end if;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait for readout to be done
         when DONE_S =>
            nxtState <= IDLE_S after tpd;
         --Send back to IDLE if we end up in an undefined state
         when others =>
            nxtState <= IDLE_S after tpd;
      end case;
   end process;

   --Next state register update and synchronous reset to IDLE
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            curState <= IDLE_S after tpd;
         else 
            curState <= nxtState after tpd;
         end if;
      end if;
   end process;

   --Process to clock the ADC at selected frequency (50-50 duty cycle)
   process(sysClk) begin
      if rising_edge(sysClk) then
         if adcCnt >= unsigned(ePixConfig.adcClkHalfT)-1 then
            adcClk <= not(AdcClk)     after tpd;
            adcCnt <= (others => '0') after tpd;
         else
            adcCnt <= adcCnt + 1 after tpd;
         end if;
      end if;
   end process;

   --Count the number of ADC clocks sent out since last reset
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or adcSampCntRst = '1' then
            adcSampCnt <= (others => '0') after tpd;
         elsif adcSampCntEn = '1' and adcCnt = unsigned(ePixConfig.adcClkHalfT)-1 and adcClk = '0' then
            adcSampCnt <= adcSampCnt + 1 after tpd;
         end if;
      end if;
   end process;
   --Give a flag saying whether the samples are valid to read
   process(adcSampCnt,epixConfig,firstPixel,sysClkRst, pixelCnt, dummyAcq) begin
      if sysClkRst = '1' or dummyAcq = '1' then
         iReadValid <= '0';
      else
         iReadValid <= '0';
         if ASIC_TYPE_G = EPIX10KA_C then
            -- in epix10ka analog output is valid after 4 readout clocks
            if adcSampCnt < ePixConfig.adcReadsPerPixel+1 and adcSampCnt > 0 and firstPixel = '0' and pixelCnt(1 downto 0) = 3 then
               iReadValid <= '1' after tpd;
            end if;
         else
            if adcSampCnt < ePixConfig.adcReadsPerPixel+1 and adcSampCnt > 0 and firstPixel = '0' then
               iReadValid <= '1' after tpd;
            end if;
         end if;
      end if;
   end process;

   --Count the current pixel position
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or pixelCntRst = '1' then
            pixelCnt <= (others => '0') after tpd;
         elsif pixelCntEn = '1' then
            pixelCnt <= pixelCnt + 1;
         end if;
      end if;
   end process;

   --Flag the first pixel
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or firstPixelRst = '1' then
            firstPixel <= '1' after tpd;
         elsif firstPixelSet = '1' then
            firstPixel <= '0';
         end if;
      end if;
   end process;
   
   --Set dummy ACQ flag
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or dummyAcqClr = '1' then
            dummyAcq <= '0' after tpd;
         elsif dummyAcqSet = '1' then
            dummyAcq <= '1';
         end if;
      end if;
   end process;

   --Or have an initial startup timer reset
   iAsicGlblRst <= rstCnt(rstCnt'left);
   process(sysClk) begin
      if rising_edge(sysClk) then
         if epixConfig.powerEnable(0) = '0' then
            rstCnt <= (others => '0') after tpd;
         elsif rstCnt(rstCnt'left) = '0' then
            rstCnt <= rstCnt + 1 after tpd;
         end if;
      end if;
   end process;

   --Generic counter for holding state machine states
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or stateCntRst = '1' then
            stateCnt <= (others => '0') after tpd;
         elsif stateCntEn = '1' then
            stateCnt <= stateCnt + 1 after tpd;
         end if;
      end if;
   end process;

   --Pipeline for the valid signal
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            readValidDelayedA0 <= (others => '0') after tpd;
            readValidDelayedA1 <= (others => '0') after tpd;
            readValidDelayedA2 <= (others => '0') after tpd;
            readValidDelayedA3 <= (others => '0') after tpd;       
         elsif (adcClkEdge = '1') then
            --Shift register to allow picking off delayed samples
            for i in 1 to 127 loop
               readValidDelayedA0(i) <= readValidDelayedA0(i-1) after tpd; 
               readValidDelayedA1(i) <= readValidDelayedA1(i-1) after tpd; 
               readValidDelayedA2(i) <= readValidDelayedA2(i-1) after tpd; 
               readValidDelayedA3(i) <= readValidDelayedA3(i-1) after tpd; 
            end loop;
            --Assignment of shifted-in bits
            --Test mode can only use the first oversampling shift register
            readValidDelayedA0(0) <= iReadValid or iReadValidTestMode after tpd;
            readValidDelayedA1(0) <= iReadValid or iReadValidTestMode after tpd;
            readValidDelayedA2(0) <= iReadValid or iReadValidTestMode after tpd;
            readValidDelayedA3(0) <= iReadValid or iReadValidTestMode after tpd;
         end if;
      end if;
   end process; 
   --Wire up the delayed output
   readValidA0 <= readValidDelayedA0( conv_integer(epixConfig.pipelineDelayA0(6 downto 0)) );
   readValidA1 <= readValidDelayedA1( conv_integer(epixConfig.pipelineDelayA1(6 downto 0)) );
   readValidA2 <= readValidDelayedA2( conv_integer(epixConfig.pipelineDelayA2(6 downto 0)) );
   readValidA3 <= readValidDelayedA3( conv_integer(epixConfig.pipelineDelayA3(6 downto 0)) );
   --Single bit signal that indicates whether there is anything left in the pipeline
   process(sysClk)
      variable runningOrA0 : std_logic := '0';
      variable runningOrA1 : std_logic := '0';
      variable runningOrA2 : std_logic := '0';
      variable runningOrA3 : std_logic := '0';
   begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1') then
            iReadValidWaitingA0 <= '0';
            iReadValidWaitingA1 <= '0';
            iReadValidWaitingA2 <= '0';
            iReadValidWaitingA3 <= '0';
         else
            runningOrA0 := '0';
            runningOrA1 := '0';
            runningOrA2 := '0';
            runningOrA3 := '0';
            for i in 0 to 127 loop
               runningOrA0 := runningOrA0 or readValidDelayedA0(i);
               runningOrA1 := runningOrA1 or readValidDelayedA1(i);
               runningOrA2 := runningOrA2 or readValidDelayedA2(i);
               runningOrA3 := runningOrA3 or readValidDelayedA3(i);
            end loop;
            iReadValidWaitingA0 <= runningOrA0;
            iReadValidWaitingA1 <= runningOrA1;
            iReadValidWaitingA2 <= runningOrA2;
            iReadValidWaitingA3 <= runningOrA3;
         end if;
      end if;
   end process;

   -- Edge detection for signals that interface with other blocks
   U_DataSendEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => adcClk,
         risingEdge => adcClkEdge
      );
   -- We want the possibility to drive out the asic Sync signal
   -- at a delay relative to the rising edge of R0
   U_R0Edge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => iAsicPpmat,
         risingEdge => iAsicPpmatRising
      );

   -- TPS can trigger on either rising or falling edge of Acq
   U_AcqEdge : entity work.SynchronizerEdge
      port map (
         clk         => sysClk,
         rst         => sysClkRst,
         dataIn      => iAsicAcq,
         risingEdge  => risingAcq,
         fallingEdge => fallingAcq
      );
   -- Choose which edge here
   iTps <= risingAcq  when ePixConfig.tpsEdge = '1' else
           fallingAcq when ePixConfig.tpsEdge = '0' else
           'X';
   -- Get the delayed version of iTps here
   PROC_TPS_DELAY : process(sysClk) 
      variable delay : unsigned(15 downto 0) := (others => '0');
   begin
      if rising_edge(sysClk) then
         iTpsDelayed <= '0';
         if iTps = '1' then 
            delay := (others => '0');
         else
            iTpsDelayed <= '0';
            if (delay = unsigned(epixConfig.tpsDelay)) then
               iTpsDelayed <= '1';
               delay := delay + 1; --Add one so this only occurs for one cycle
            elsif (delay < unsigned(ePixConfig.tpsDelay)) then
               delay := delay + 1;
            end if;
         end if;
      end if;
   end process; 


end AcqControl;

