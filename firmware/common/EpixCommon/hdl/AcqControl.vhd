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
-- Copyright (c) 2011 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.EpixTypes.all;
use work.StdRtlPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity AcqControl is
   port (

      -- Clocks and reset
      sysClk              : in    std_logic;
      sysClkRst           : in    std_logic;

      -- Run control
      acqStart            : in    std_logic;
      acqBusy             : out   std_logic;
      readDone            : in    std_logic;
      readStart           : out   std_logic;
      readValid           : out   std_logic;

      -- Configuration
      epixConfig          : in    EpixConfigType;
      epixDigPower        : in    std_logic;

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
      asicRoClkP          : out   std_logic_vector(3 downto 0);
      asicRoClkM          : out   std_logic_vector(3 downto 0)

   );
end AcqControl;


-- Define architecture
architecture AcqControl of AcqControl is

   -- Local Signals
   signal adcClk             : std_logic             := '0';
   signal adcClkEdge         : std_logic             := '0';
   signal asicClk            : std_logic             := '0';
   signal adcCnt             : unsigned(31 downto 0) := (others => '0');
   signal adcSampCnt         : unsigned(31 downto 0) := (others => '0');
   signal adcSampCntEn       : sl := '0';
   signal adcSampCntRst      : sl := '0';
   signal rstCnt             : unsigned(25 downto 0) := (others => '0');  --width 26 for reality, small for simulation
   signal stateCnt           : unsigned(31 downto 0) := (others => '0');
   signal stateCntEn         : sl := '0';
   signal stateCntRst        : sl := '0';
   signal pixelCnt           : unsigned(31 downto 0) := (others => '0');
   signal pixelCntEn         : sl := '0';
   signal pixelCntRst        : sl := '0';
   signal iReadValid         : sl := '0';
   signal iReadValidTestMode : sl := '0';
   signal readValidDelayed   : slv(127 downto 0) := (others => '0');
   signal firstPixel         : sl := '0';
   signal firstPixelSet      : sl := '0';
   signal firstPixelRst      : sl := '0';
   signal prePulseR0         : sl := '0';

   -- Multiplexed ASIC outputs.  These versions are the
   -- automatic ones controlled by state machine.
   -- You can override them with the manualPinControl config bits.
   signal iAsicR0       : std_logic             := '0';
   signal iAsicPpmat    : std_logic             := '0';
   signal iAsicPpbe     : std_logic             := '0';
   signal iAsicGlblRst  : std_logic             := '0';
   signal iAsicAcq      : std_logic             := '0';
   signal iAsicClk      : std_logic             := '0';

   -- State machine values
   type state is (IDLE_S,
                  PRE_R0_S,
                  POST_PRE_R0_S,
                  WAIT_R0_S,
                  PULSE_R0_S,
                  WAIT_ACQ_S,
                  ACQ_S,
                  DROP_ACQ_S,
                  WAIT_PPMAT_S,
                  SYNC_TO_ADC_S,
                  WAIT_ADC_S,
                  NEXT_CELL_S,
                  SACI_RESET_S,
                  DONE_S,
                  TEST_S);
   signal curState           : state := IDLE_S;
   signal nxtState           : state := IDLE_S;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- ADC Clock outputs
   U_AdcClk0 : OBUFDS port map ( I => adcClk, O => adcClkP(0), OB => adcClkM(0) );
   U_AdcClk1 : OBUFDS port map ( I => adcClk, O => adcClkP(1), OB => adcClkM(1) );
   U_AdcClk2 : OBUFDS port map ( I => adcClk, O => adcClkP(2), OB => adcClkM(2) );

   -- ASIC Clock Outputs
   U_AsicClk0 : OBUFDS port map ( I => asicClk, O => asicRoClkP(0), OB => asicRoClkM(0) );
   U_AsicClk1 : OBUFDS port map ( I => asicClk, O => asicRoClkP(1), OB => asicRoClkM(1) );
   U_AsicClk2 : OBUFDS port map ( I => asicClk, O => asicRoClkP(2), OB => asicRoClkM(2) );
   U_AsicClk3 : OBUFDS port map ( I => asicClk, O => asicRoClkP(3), OB => asicRoClkM(3) );


  readStart <= acqStart; 

   --MUXes for manual control of ASIC signals
   asicGlblRst <= iAsicGlblRst           when ePixConfig.manualPinControl(0) = '0' else
                  ePixConfig.asicPins(0) when ePixConfig.manualPinControl(0) = '1' else
                  'X';
   asicAcq     <= iAsicAcq               when ePixConfig.manualPinControl(1) = '0' else
                  ePixConfig.asicPins(1) when ePixConfig.manualPinControl(1) = '1' else
                  'X';
   asicR0      <= iAsicR0                when ePixConfig.manualPinControl(2) = '0' else
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

   --Use 6th bit of manual pin control to activate or deactivate pre-pulsing of R0
   prePulseR0 <= ePixConfig.manualPinControl(6); 

   --Outputs not incorporated into state machine at the moment
  iAsicPpbe    <= '1'; 



-- Normal path for taking data frames
   --Asynchronous state machine outputs
   process(curState,stateCnt,adcSampCnt,ePixConfig) begin
      --All signals default values
      iAsicClk           <= '0' after tpd;
      iAsicR0            <= '1' after tpd;
      iAsicPpmat         <= '0' after tpd;
      iAsicAcq           <= '0' after tpd;
      saciReadoutReq     <= '0' after tpd;
      stateCntEn         <= '0' after tpd;
      stateCntRst        <= '0' after tpd;
      adcSampCntRst      <= '0' after tpd;
      adcSampCntEn       <= '0' after tpd;
      pixelCntEn         <= '0' after tpd;
      pixelCntRst        <= '1' after tpd;
      acqBusy            <= '1' after tpd;
      firstPixelRst      <= '0' after tpd;
      firstPixelSet      <= '0' after tpd;
      iReadValidTestMode <= '0' after tpd;
      case curState is
         --Idle state, all signals zeroed out, counters reset
         when IDLE_S =>
            acqBusy         <= '0' after tpd;
            stateCntRst     <= '1' after tpd;
            adcSampCntRst   <= '1' after tpd;
            firstPixelRst   <= '1' after tpd;
         --Bring up PPmat through just before the asicClk
         when WAIT_R0_S =>
            iAsicPpmat      <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.acqToAsicR0Delay) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         -- Prepulse R0
         when PRE_R0_S =>
            iAsicPpmat      <= '1' after tpd;
            iAsicR0         <= '0' after tpd;
            if stateCnt < unsigned(ePixConfig.prePulseR0Width) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         -- Hold off before rest of state machine
         when POST_PRE_R0_S =>
            iAsicPpmat      <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.prePulseR0Delay) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Drop R0 low before asicAcq
         when PULSE_R0_S =>
            iAsicPpmat      <= '1' after tpd;
            iAsicR0         <= '0' after tpd;
            if stateCnt < unsigned(ePixConfig.asicR0Width) then
               stateCntEn      <= '1' after tpd;
            else 
               stateCntRst     <= '1' after tpd;
            end if;
         --Bring up R0 and hold through the rest of the readout
         when WAIT_ACQ_S =>
            iAsicPpmat      <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicR0ToAsicAcq) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Bring up Acq and hold for a specified time
         when ACQ_S =>
            iAsicPpmat      <= '1' after tpd;
            iAsicAcq        <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicAcqWidth) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Drop ACQ and send the SACI reset to reset pixel position
         when DROP_ACQ_S =>
            iAsicPpmat      <= '1' after tpd;
            stateCntEn      <= '1' after tpd;
         --Ensure that the minimum hold off time has been enforced before dropping PPmat
         when WAIT_PPMAT_S =>
            iAsicPpmat <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicAcqLToPPmatL) then
               stateCntEn   <= '1' after tpd;
            else
               stateCntRst  <= '1' after tpd;
            end if;
         --Synchronize phases of ASIC RoClk and ADC clk
         when SYNC_TO_ADC_S =>
         --Wait for the ADC to readout the desired number of samples
         --(or a minimum of the ASIC clock half period)
         when WAIT_ADC_S =>
            pixelCntRst  <= '0' after tpd;
            adcSampCntEn  <= '1' after tpd;
            firstPixelSet <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicRoClkHalfT) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
               pixelCntEn      <= '1' after tpd;
            end if;
         --Clock once to the next cell
         when NEXT_CELL_S =>
            pixelCntRst  <= '0' after tpd;
            adcSampCntEn <= '1';
            iAsicClk     <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicRoClkHalfT) then
               stateCntEn      <= '1' after tpd;
            else 
               adcSampCntRst   <= '1' after tpd;
               stateCntRst     <= '1' after tpd;
            end if;
         --Clock once to the next cell
         when TEST_S =>
            if stateCnt < unsigned(ePixConfig.totalPixelsToRead) then
               stateCntEn         <= '1' after tpd;
					iReadValidTestMode <= '1' after tpd;
            else 
               stateCntRst        <= '1' after tpd;
            end if;
         --Send SACI prepare for readout for the next event
         when SACI_RESET_S =>
            saciReadoutReq <= '1' after tpd;
         --Send the done signal
         when DONE_S =>
            acqBusy       <= '0' after tpd;
            adcSampCntRst <= '1' after tpd;
            stateCntRst   <= '1' after tpd;
         --Undefined states: treat with default
         when others =>
      end case;
   end process;

   --Next state logic
   process(curState,acqStart,stateCnt,saciReadoutAck,adcSampCnt,pixelCnt,ePixConfig,prePulseR0,adcClkEdge,readDone) begin
      case curState is
         --Remain idle until we get the acqStart signal
         when IDLE_S =>
            if acqStart = '1' then
               if ePixConfig.manualPinControl(7) = '0' then
                  nxtState <= WAIT_R0_S after tpd;
               else
                  nxtState <= TEST_S after tpd;
               end if;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait a specified number of clock cycles before bringing asicR0 up
         when WAIT_R0_S =>
            if stateCnt = unsigned(ePixConfig.acqToAsicR0Delay) then
               if (prePulseR0 = '0') then
                  nxtState <= PULSE_R0_S after tpd;
               else
                  nxtState <= PRE_R0_S after tpd;
               end if;
            else
               nxtState <= curState after tpd;
            end if; 
         -- Prepulse R0
         when PRE_R0_S =>
            if stateCnt = unsigned(ePixConfig.prePulseR0Width) then
               nxtState <= POST_PRE_R0_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         -- Hold off before rest of state machine
         when POST_PRE_R0_S =>
            if stateCnt = unsigned(ePixConfig.prePulseR0Delay) then
               nxtState <= PULSE_R0_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Pulse R0 low for a specified number of clock cycles
         when PULSE_R0_S =>
            if stateCnt = unsigned(ePixConfig.asicR0Width) then
               nxtState <= WAIT_ACQ_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait a specified number of clock cycles before bringing asicAcq up
         when WAIT_ACQ_S => 
            if stateCnt = unsigned(ePixConfig.asicR0ToAsicAcq) then
               nxtState <= ACQ_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Hold acq high for a specified time
         when ACQ_S =>
            if stateCnt = unsigned(ePixConfig.asicAcqWidth) then
               nxtState <= DROP_ACQ_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait for the matrix counter to reset (via saci interface)
         when DROP_ACQ_S =>
            nxtState <= WAIT_PPMAT_S after tpd;
         --Ensure that the minimum hold off time has been enforced before dropping PPmat
         when WAIT_PPMAT_S =>
            if stateCnt = unsigned(ePixConfig.asicAcqLToPPmatL) then
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
         --Wait for 8+N valid ADC readouts.  If we're done with all pixels, finish.
         when WAIT_ADC_S => 
            if stateCnt >= unsigned(ePixConfig.asicRoClkHalfT) then
               if pixelCnt < unsigned(ePixConfig.totalPixelsToRead)-1 then
                  nxtState <= NEXT_CELL_S after tpd;
               else
                  nxtState <= SACI_RESET_S after tpd;
               end if;
            else
               nxtState <= curState after tpd;
            end if;
         --Toggle the asicClk, then back to ADC readouts if there are more pixels to read.
         when NEXT_CELL_S => 
            if stateCnt = unsigned(ePixConfig.asicRoClkHalfT) then
               nxtState <= WAIT_ADC_S after tpd;
            else 
               nxtState <= curState after tpd;
            end if;
         when TEST_S =>
            if stateCnt = unsigned(ePixConfig.totalPixelsToRead) then
               nxtState <= DONE_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Perform a SACI prepare for readout
         when SACI_RESET_S =>
            if (saciReadoutAck = '1') then
               nxtState <= DONE_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Send the done signal
         when DONE_S =>
            if readDone = '1' then
               nxtState <= IDLE_S after tpd;
            else
               nxtState <= curState after tpd;
            end if;
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
   process(adcSampCnt,epixConfig,firstPixel) begin
      if adcSampCnt < unsigned(ePixConfig.adcReadsPerPixel)+1 and adcSampCnt > 0 and firstPixel = '0' then
         iReadValid <= '1' after tpd;
      else
         iReadValid <= '0' after tpd;
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

   --Or have an initial startup timer reset
   iAsicGlblRst <= rstCnt(rstCnt'left);
   process(sysClk) begin
      if rising_edge(sysClk) then
         if epixDigPower = '0' then
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
         if (adcClkEdge = '1') then
            if sysClkRst = '1' then
               readValidDelayed <= (others => '0') after tpd;
            else
               for i in 1 to 127 loop
                  readValidDelayed(i) <= readValidDelayed(i-1) after tpd; 
               end loop;
               readValidDelayed(0) <= iReadValid or iReadValidTestMode after tpd;
            end if;
         end if;
      end if;
   end process; 
   --Wire up the delayed output
   readValid <= readValidDelayed( conv_integer(epixConfig.pipelineDelay(6 downto 0)) );

   -- Edge detection for signals that interface with other blocks
   U_DataSendEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => adcClk,
         risingEdge => adcClkEdge
      );

end AcqControl;

