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
      readStart           : out   std_logic;
      readValid           : out   std_logic;
      readDone            : out   std_logic;

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
   signal adcClk        : std_logic             := '0';
   signal adcClkEdge    : std_logic             := '0';
   signal asicClk       : std_logic             := '0';
   signal curState      : slv(3 downto 0)       := "0000";
   signal nxtState      : slv(3 downto 0)       := "0000";
   signal adcCnt        : unsigned(31 downto 0) := (others => '0');
   signal adcSampCnt    : unsigned(31 downto 0) := (others => '0');
   signal adcSampCntEn  : sl := '0';
   signal adcSampCntRst : sl := '0';
   signal rstCnt        : unsigned(25 downto 0) := (others => '0');  --width 26 for reality, small for simulation
   signal stateCnt      : unsigned(31 downto 0) := (others => '0');
   signal stateCntEn    : sl := '0';
   signal stateCntRst   : sl := '0';
   signal pixelCnt      : unsigned(31 downto 0) := (others => '0');
   signal pixelCntEn    : sl := '0';
   signal pixelCntRst   : sl := '0';
   signal iReadValid       : sl               := '0';
   signal readValidDelayed : slv(127 downto 0) := (others => '0');
   signal firstPixel    : sl := '0';
   signal firstPixelSet : sl := '0';
   signal firstPixelRst : sl := '0';

   -- Multiplexed
   signal iAsicR0       : std_logic             := '0';
   signal iAsicPpmat    : std_logic             := '0';
   signal iAsicPpbe     : std_logic             := '0';
   signal iAsicGlblRst  : std_logic             := '0';
   signal iAsicAcq      : std_logic             := '0';
   signal iAsicClk      : std_logic             := '0';

   -- This constant is locked to the ADC.  Not sure if this should
   -- sit here or elsewhere?
   --constant cAdcPipelineDly   : unsigned(31 downto 0) := x"00000008"; --Pipeline delay for AD9252 --Absolute minimum
   --constant cAdcPipelineDly   : unsigned(31 downto 0) := x"00000013"; --Pipeline delay for AD9252

   -- State machine values
   constant ST_IDLE       : slv(3 downto 0) := "0000";
   constant ST_WAIT_R0    : slv(3 downto 0) := "0001";
   constant ST_PULSE_R0   : slv(3 downto 0) := "0010";
   constant ST_WAIT_ACQ   : slv(3 downto 0) := "0011";
   constant ST_ACQ        : slv(3 downto 0) := "0100";
   constant ST_SACI_RST   : slv(3 downto 0) := "0101";
   constant ST_WAIT_PPMAT : slv(3 downto 0) := "0110";
   constant ST_SYNC_TO_ADC: slv(3 downto 0) := "0111";
   constant ST_WAIT_ADC   : slv(3 downto 0) := "1000";
   constant ST_NEXT_CELL  : slv(3 downto 0) := "1001";
   constant ST_DONE       : slv(3 downto 0) := "1010";

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


  --saciReadoutReq <= acqStart; 
  saciReadoutReq <= '0';  --Sending this manually for now. 
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

   --Outputs not incorporated into state machine at the moment
  iAsicPpbe    <= '1'; 



--Simple version that just pulses Acq
--
--   process(curState,stateCnt,ePixConfig) begin
--      --Default
--      asicR0      <= '1' after tpd;
--      asicAcq     <= '0' after tpd;
--      stateCntRst <= '0' after tpd;
--      stateCntEn  <= '0' after tpd;
--      case curState is 
--         when ST_IDLE =>
--            stateCntRst <= '1' after tpd;
--         when ST_WAIT_R0 =>
--            if stateCnt < unsigned(ePixConfig.acqToAsicR0Delay) then
--               stateCntEn <= '1' after tpd;
--            else
--               stateCntRst <= '1' after tpd;
--            end if;
--         when ST_WAIT_ACQ =>
--            asicR0  <= '0';
--            asicAcq <= '1';
--            if stateCnt < unsigned(ePixConfig.asicAcqWidth) then
--               stateCntEn <= '1' after tpd;
--            else 
--               stateCntRst <= '0' after tpd;
--            end if;
--         when others =>
--      end case;
--   end process;
--   process(curState,stateCnt,ePixConfig) begin
--      case curState is
--         --Remain idle until we get the acqStart signal
--         when ST_IDLE =>
--            if acqStart = '1' then
--               nxtState <= ST_WAIT_R0 after tpd;
--            else
--               nxtState <= curState after tpd;
--            end if;
--         --ADC recording will begin immediately
--         --Wait a specified number of clock cycles before bringin asicR0 up
--         when ST_WAIT_R0 =>
--            if stateCnt = unsigned(ePixConfig.acqToAsicR0Delay) then
--               nxtState <= ST_WAIT_ACQ after tpd;
--            else
--               nxtState <= curState after tpd;
--            end if; 
--         when ST_WAIT_ACQ =>
--            if stateCnt = unsigned(ePixConfig.asicAcqWidth) then
--               nxtState <= ST_IDLE after tpd;
--            else
--               nxtState <= curState after tpd;
--            end if;
--         when others =>
--            nxtState <= ST_IDLE;
--      end case;
--   end process;
----

-- Normal path for taking data frames
   --Asynchronous state machine outputs
   process(curState,stateCnt,adcSampCnt,ePixConfig) begin
      --All signals default to '0'.  Assign '1' in specific applicable states.
      iAsicClk       <= '0' after tpd;
      iAsicR0        <= '1' after tpd;
      iAsicPpmat     <= '0' after tpd;
      iAsicAcq       <= '0' after tpd;
--      saciReadoutReq <= '0' after tpd;
      stateCntEn     <= '0' after tpd;
      stateCntRst    <= '0' after tpd;
      adcSampCntRst  <= '0' after tpd;
      adcSampCntEn   <= '0' after tpd;
      pixelCntEn     <= '0' after tpd;
      pixelCntRst    <= '1' after tpd;
      readDone       <= '0' after tpd;
      firstPixelRst  <= '0' after tpd;
      firstPixelSet  <= '0' after tpd;
      case curState is
         --Idle state, all signals zeroed out, counters reset
         when ST_IDLE =>
            stateCntRst     <= '1' after tpd;
            adcSampCntRst   <= '1' after tpd;
            firstPixelRst   <= '1' after tpd;
         --Bring up PPmat through just before the asicClk
         when ST_WAIT_R0 =>
            iAsicPpmat      <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.acqToAsicR0Delay) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Drop R0 low before asicAcq
         when ST_PULSE_R0 =>
            iAsicPpmat      <= '1' after tpd;
            iAsicR0         <= '0' after tpd;
            if stateCnt < unsigned(ePixConfig.asicR0Width) then
               stateCntEn      <= '1' after tpd;
            else 
               stateCntRst     <= '1' after tpd;
            end if;
         --Bring up R0 and hold through the rest of the readout
         when ST_WAIT_ACQ =>
            iAsicPpmat      <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicR0ToAsicAcq) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Bring up Acq and hold for a specified time
         when ST_ACQ =>
            iAsicPpmat      <= '1' after tpd;
            iAsicAcq        <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicAcqWidth) then
               stateCntEn      <= '1' after tpd;
            else
               stateCntRst     <= '1' after tpd;
            end if;
         --Drop ACQ and send the SACI reset to reset pixel position
         when ST_SACI_RST =>
            iAsicPpmat      <= '1' after tpd;
--            saciReadoutReq  <= '1' after tpd;
            stateCntEn      <= '1' after tpd;
         --Ensure that the minimum hold off time has been enforced before dropping PPmat
         when ST_WAIT_PPMAT =>
            iAsicPpmat <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicAcqLToPPmatL) then
               stateCntEn   <= '1' after tpd;
            else
               stateCntRst  <= '1' after tpd;
            end if;
         --Synchronize phases of ASIC RoClk and ADC clk
         when ST_SYNC_TO_ADC =>
         --Wait for the ADC to readout the desired number of samples
         --(or a minimum of the ASIC clock half period)
         when ST_WAIT_ADC =>
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
         when ST_NEXT_CELL =>
            pixelCntRst  <= '0' after tpd;
            adcSampCntEn <= '1';
            iAsicClk     <= '1' after tpd;
            if stateCnt < unsigned(ePixConfig.asicRoClkHalfT) then
               stateCntEn      <= '1' after tpd;
            else 
               adcSampCntRst   <= '1' after tpd;
               stateCntRst     <= '1' after tpd;
            end if;
         --Send the done signal
         when ST_DONE =>
            adcSampCntRst         <= '1' after tpd;
            if stateCnt < 128 then
               stateCntEn         <= '1' after tpd;
            else
               stateCntRst        <= '1' after tpd;
               readDone           <= '1' after tpd;
            end if;
         --Undefined states: treat outputs same as IDLE state
         when others =>
      end case;
   end process;

   --Next state logic
   process(curState,acqStart,stateCnt,saciReadoutAck,adcSampCnt,pixelCnt,ePixConfig) begin
      case curState is
         --Remain idle until we get the acqStart signal
         when ST_IDLE =>
            if acqStart = '1' then
               nxtState <= ST_WAIT_R0 after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait a specified number of clock cycles before bringing asicR0 up
         when ST_WAIT_R0 =>
            if stateCnt = unsigned(ePixConfig.acqToAsicR0Delay) then
               nxtState <= ST_PULSE_R0 after tpd;
            else
               nxtState <= curState after tpd;
            end if; 
         --Pulse R0 low for a specified number of clock cycles
         when ST_PULSE_R0 =>
            if stateCnt = unsigned(ePixConfig.asicR0Width) then
               nxtState <= ST_WAIT_ACQ after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait a specified number of clock cycles before bringing asicAcq up
         when ST_WAIT_ACQ => 
            if stateCnt = unsigned(ePixConfig.asicR0ToAsicAcq) then
               nxtState <= ST_ACQ after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Hold acq high for a specified time
         when ST_ACQ =>
            if stateCnt = unsigned(ePixConfig.asicAcqWidth) then
               nxtState <= ST_SACI_RST after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait for the matrix counter to reset (via saci interface)
         when ST_SACI_RST =>
            nxtState <= ST_WAIT_PPMAT after tpd;
--            if (saciReadoutAck = '1') then
--               nxtState <= ST_WAIT_PPMAT after tpd;
--            else
--               nxtState <= curState after tpd;
--            end if;
         --Ensure that the minimum hold off time has been enforced before dropping PPmat
         when ST_WAIT_PPMAT =>
            if stateCnt = unsigned(ePixConfig.asicAcqLToPPmatL) then
               nxtState <= ST_SYNC_TO_ADC after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Synchronize phases of ASIC RoClk and ADC clk
         when ST_SYNC_TO_ADC =>
            if adcClkEdge = '1' then
               nxtState <= ST_NEXT_CELL after tpd;
            else
               nxtState <= curState after tpd;
            end if;
         --Wait for 8+N valid ADC readouts.  If we're done with all pixels, finish.
         when ST_WAIT_ADC => 
            if stateCnt >= unsigned(ePixConfig.asicRoClkHalfT) then
--            if stateCnt >= unsigned(ePixConfig.asicRoClkHalfT) and adcSampCnt > cAdcPipelineDly + unsigned(ePixConfig.adcReadsPerPixel) then
               if pixelCnt < unsigned(ePixConfig.totalPixelsToRead)-1 then
                  nxtState <= ST_NEXT_CELL after tpd;
               else
                  nxtState <= ST_DONE after tpd;
               end if;
            else
               nxtState <= curState after tpd;
            end if;
         --Toggle the asicClk, then back to ADC readouts if there are more pixels to read.
         when ST_NEXT_CELL => 
            if stateCnt = unsigned(ePixConfig.asicRoClkHalfT) then
               nxtState <= ST_WAIT_ADC after tpd;
            else 
               nxtState <= curState after tpd;
            end if;
         --Send the done signal
         when ST_DONE =>
            if stateCnt = 128 then
               nxtState <= ST_IDLE;
            else
               nxtState <= curState;
            end if;
         --Send back to IDLE if we end up in an undefined state
         when others =>
            nxtState <= ST_IDLE after tpd;
      end case;
   end process;

   --Next state register update and synchronous reset to IDLE
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            curState <= ST_IDLE after tpd;
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
      if (adcClkEdge = '1') then
         if rising_edge(sysClk) then
            if sysClkRst = '1' then
               readValidDelayed <= (others => '0') after tpd;
            else
               for i in 1 to 127 loop
                  readValidDelayed(i) <= readValidDelayed(i-1) after tpd; 
               end loop;
               readValidDelayed(0) <= iReadValid after tpd;
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

