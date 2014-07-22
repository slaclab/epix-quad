-------------------------------------------------------------------------------
-- Title         : Register Control
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : RegControl.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/21/2013
-------------------------------------------------------------------------------
-- Description:
-- Register control block
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
use work.ScopeTypes.all;
use work.VcPkg.all;
use work.SaciMasterPkg.all;
use work.Version.all;
use work.StdRtlPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity RegControl is
   port ( 

      -- Master system clock, 125Mhz
      sysClk          : in    std_logic;
      sysClkRst       : in    std_logic;

      -- Register Bus
      pgpRegOut       : in    VcRegSlaveOutType;
      pgpRegIn        : out   VcRegSlaveInType;

      -- Configuration
      epixConfig      : out   EpixConfigType;
      scopeConfig     : out   ScopeConfigType;
      resetReq        : out   std_logic;

      -- Status
      acqCount        : in    std_logic_vector(31 downto 0);
      seqCount        : in    std_logic_vector(31 downto 0);

      -- Readout start command request
      saciReadoutReq  : in    std_logic;
      saciReadoutAck  : out   std_logic;

      -- Serial interface
      saciClk         : out   std_logic;
      saciSelL        : out   std_logic_vector(3 downto 0);
      saciCmd         : out   std_logic;
      saciRsp         : in    std_logic_vector(3 downto 0);

      -- DAC
      dacSclk         : out   std_logic;
      dacDin          : out   std_logic;
      dacCsb          : out   std_logic;
      dacClrb         : out   std_logic;

      -- Board IDs
      serialIdOut     : out   std_logic_vector(1 downto 0);
      serialIdEn      : out   std_logic_vector(1 downto 0);
      serialIdIn      : in    std_logic_vector(1 downto 0);

      -- Fast ADC Control
      adcSpiClk       : out   std_logic;
      adcSpiDataOut   : out   std_logic;
      adcSpiDataIn    : in    std_logic;
      adcSpiDataEn    : out   std_logic;
      adcSpiCsb       : out   std_logic_vector(2 downto 0);
      adcPdwn         : out   std_logic_vector(2 downto 0);

      -- Slow ADC Data
      slowAdcData     : in    word16_array(15 downto 0);

      -- Power enable
      powerEnable     : out   std_logic_vector(1 downto 0);

      -- Status of IDELAYCTRL blocks
      iDelayCtrlRdy   : in    std_logic

   );

end RegControl;

-- Define architecture
architecture RegControl of RegControl is

   -- Local Signals
   signal intConfig      : EpixConfigType;
   signal intScopeConfig : ScopeConfigType;
   signal intRegIn       : VcRegSlaveInType;
   signal saciRegIn      : SaciMasterInType;
   signal saciRegOut     : SaciMasterOutType;
   signal saciSelIn      : SaciMasterInType;
   signal saciSelOut     : SaciMasterOutType;
   signal saciTimeout       : std_logic := '0';
   signal saciTimeoutCnt    : unsigned (12 downto 0) := (others => '0');
   signal saciTimeoutCntEn  : std_logic := '0';
   signal saciTimeoutCntRst : std_logic := '0';
   signal intSelL     : std_logic_vector(3 downto 0);
   signal intRsp      : std_logic;
   signal saciCnt     : std_logic_vector(7 downto 0);
   signal intClk      : std_logic;
   signal dacData     : std_logic_vector(15 downto 0);
   signal dacStrobe   : std_logic;
   signal ipowerEn    : std_logic_vector(1 downto 0);
   signal adcRdData   : std_logic_vector(7 downto 0);
   signal adcWrReq    : std_logic;
   signal adcRdReq    : std_logic;
   signal adcAck      : std_logic;
   signal adcSel      : std_logic_vector(1 downto 0);
   type serNum is array(1 downto 0) of slv(63 downto 0);
   signal serNumRaw   : serNum;
   signal serNumReg   : serNum;
   signal serNumValid : slv(1 downto 0);
   signal serNumValidEdge : slv(1 downto 0);
   signal serClkEn    : sl;
   signal spiClkEn    : sl;
   signal memAddr     : std_logic_vector(15 downto 0);
   signal memDataIn   : std_logic_vector(63 downto 0);
   signal memDataOutRaw : std_logic_vector(63 downto 0);
   signal memDataOutReg : std_logic_vector(63 downto 0);
   signal memDataValid  : std_logic;
   signal memReadReq  : std_logic;
   signal memWriteReq : std_logic;
   signal memDataValidEdge : sl;
   signal sacibit : std_logic;
   signal saciClkEdge : std_logic;
   signal saciRst     : std_logic;
   -- States
   type saci_state is (IDLE_S, REG_S, SYNC_S, 
                       CMD_0_S, PAUSE_0_S,
                       CMD_1_S, PAUSE_1_S,
                       CMD_2_S, PAUSE_2_S,
                       CMD_3_S, 
                       DONE_S);
   signal   curState   : saci_state := IDLE_S;
   signal   nxtState   : saci_state := IDLE_S;
   -- Pseudo-constants (constant within a compile, 
   --                   but vary by application/base clock rate)
   signal NCYCLES      : integer range 0 to 2047;
   signal NCYCLES_SPI  : integer range 0 to 31; 
 
   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   ------------------
   -- Outputs
   ------------------
   epixConfig  <= intConfig;
   scopeConfig <= intScopeConfig;
   saciSelL    <= intSelL;
   powerEnable <= ipowerEn;

   --------------------------------
   -- Register control block
   --------------------------------
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then

         intConfig       <= EpixConfigInit  after tpd;
         intScopeConfig  <= ScopeConfigInit after tpd;
         pgpRegIn.ack    <= '0'             after tpd;
         pgpRegIn.fail   <= '0'             after tpd;
         pgpRegIn.rdData <= (others=>'0')   after tpd;
         saciRegIn.req   <= '0'             after tpd;
         resetReq        <= '0'             after tpd;
         dacData         <= (others=>'0')   after tpd;
         dacStrobe       <= '0'             after tpd;
         ipowerEn        <= "00"            after tpd;
         adcWrReq        <= '0'             after tpd;
         adcRdReq        <= '0'             after tpd;
         adcSel          <= "00"            after tpd;
      elsif rising_edge(sysClk) then

         -- Defaults
         pgpRegIn.ack            <= pgpRegOut.req after tpd;
         pgpRegIn.fail           <= '0'              after tpd;
         pgpRegIn.rdData         <= (others=>'0')    after tpd;
         intConfig.acqCountReset <= '0'              after tpd;
         intConfig.seqCountReset <= '0'              after tpd;
         saciRegIn.req           <= '0'              after tpd;
         dacStrobe               <= '0'              after tpd;
         adcWrReq                <= '0'              after tpd;
         adcRdReq                <= '0'              after tpd;
         adcSel                  <= "00"             after tpd;

         -- Version register, 0x000000
         if pgpRegOut.addr = x"000000" then
            pgpRegIn.rdData <= FpgaVersion after tpd;
            resetReq <= pgpRegOut.req and pgpRegOut.op after tpd; -- Reset request

         -- Run Trigger Enable, 0x000001
         elsif pgpRegOut.addr = x"000001" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.runTriggerEnable <= pgpRegOut.wrData(0) after tpd;
            end if;
            pgpRegIn.rdData(0) <= intConfig.runTriggerEnable after tpd;

         -- Run Trigger Delay, 0x000002
         elsif pgpRegOut.addr = x"000002" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.runTriggerDelay <= pgpRegOut.wrData after tpd;
            end if;
            pgpRegIn.rdData <= intConfig.runTriggerDelay after tpd;

         -- DAQ Trigger Enable, 0x000003
         elsif pgpRegOut.addr = x"000003" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.daqTriggerEnable <= pgpRegOut.wrData(0) after tpd;
            end if;
            pgpRegIn.rdData(0) <= intConfig.daqTriggerEnable after tpd;

         -- DAQ Trigger Delay, 0x000004
         elsif pgpRegOut.addr = x"000004" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.daqTriggerDelay <= pgpRegOut.wrData after tpd;
            end if;
            pgpRegIn.rdData <= intConfig.daqTriggerDelay after tpd;

         -- ACQ Counter, 0x000005
         elsif pgpRegOut.addr = x"000005" then
            pgpRegIn.rdData <= acqCount after tpd;

         -- ACQ Count Reset, 0x000006
         elsif pgpRegOut.addr = x"000006" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.acqCountReset <= '1' after tpd;
            end if;

         -- DAC Setting, 0x000007
         elsif pgpRegOut.addr = x"000007" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               dacData   <= pgpRegOut.wrData(15 downto 0) after tpd;
               dacStrobe <= '1'                               after tpd;
            end if;
            pgpRegIn.rdData <= x"0000" & dacData after tpd;

         -- Power Enable, 0x000008
         elsif pgpRegOut.addr = x"000008" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               ipowerEn <= pgpRegOut.wrData(1 downto 0) after tpd;
            end if;
            pgpRegIn.rdData(1 downto 0) <= ipowerEn after tpd;

         -- Fast ADC frame delay, 0x000009
         elsif pgpRegOut.addr = x"000009" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.adcDelay(0) <= pgpRegOut.wrData(5  downto 0);
               intConfig.adcDelay(1) <= pgpRegOut.wrData(11 downto 6);
               intConfig.adcDelay(2) <= pgpRegOut.wrData(17 downto 12);
            end if;
            intConfig.adcDelayUpdate <= pgpRegOut.req and pgpRegOut.op;
            pgpRegIn.rdData <= x"000" & "00" & intConfig.adcDelay(2) & intConfig.adcDelay(1) & intConfig.adcDelay(0);

         -- IDELAYCTRL status, 0x00000A
         elsif pgpRegOut.addr = x"00000A" then
            pgpRegIn.rdData(0) <= iDelayCtrlRdy;

         -- Frame count, 0x00000B
         elsif pgpRegOut.addr = x"00000B" then
            pgpRegIn.rdData <= seqCount after tpd;

         -- Frame count reset, 0x00000C
         elsif pgpRegOut.addr = x"00000C" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               intConfig.seqCountReset <= '1' after tpd;
            end if;

         -- ASIC Mask, 0x00000D
         elsif pgpRegOut.addr = x"00000D" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               intConfig.asicMask <= pgpRegOut.wrData(3 downto 0) after tpd;
            end if;
            pgpRegIn.rdData <= x"0000000" & intConfig.asicMask after tpd;

         -- FPGA base clock frequency, 0x000010
         elsif pgpRegOut.addr = x"000010" then
            pgpRegIn.rdData <= FpgaBaseClock after tpd;

         -- Auto trigger enables, run, 0x000011
         elsif pgpRegOut.addr <= x"000011" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               intConfig.autoRunEn <= pgpRegOut.wrData(0) after tpd;
            end if;
            pgpRegIn.rdData(0) <= intConfig.autoRunEn after tpd;

         -- Auto trigger enables, run, 0x000012
         elsif pgpRegOut.addr <= x"000012" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               intConfig.autoTrigPeriod <= pgpRegOut.wrData after tpd;
            end if;
            pgpRegIn.rdData <= intConfig.autoTrigPeriod after tpd;

         -- Auto trigger enables, run, 0x000013
         elsif pgpRegOut.addr <= x"000013" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               intConfig.autoDaqEn <= pgpRegOut.wrData(0) after tpd;
            end if;
            pgpRegIn.rdData(0) <= intConfig.autoDaqEn after tpd;
            

         -- Slow ADC, 0x0000100 -  0x000010F
         elsif pgpRegOut.addr(23 downto 4) = x"00010" then
            pgpRegIn.rdData(15 downto 0) <= slowAdcData(conv_integer(pgpRegOut.addr(3 downto 0))) after tpd;

         -- ASIC digital output pipeline delay
         elsif pgpRegOut.addr = x"00001F" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               intConfig.doutPipelineDelay <= pgpRegOut.wrData after tpd;
            end if;
            pgpRegIn.rdData <= intConfig.doutPipelineDelay after tpd;

         -- ASIC acquisition control interfacing, 0x000020 -0x00002F
         -- 0x000020: Cycles from delayed system ACQ (when PPmat turns on) to ASIC R0
         -- 0x000021: Cycles from ASIC R0 coming high to ASIC ACQ coming high
         -- 0x000022: Cycles to keep ASIC ACQ high
         -- 0x000023: Cycles from ASIC ACQ dropping low to ASIC PPmat dropping low
         -- 0x000024: Half-period of the minimum allowed ASIC readout clock in system clock cycles
         -- 0x000025: Number of ADC values to read from the ASIC per pixel
         -- 0x000026: Half-period of the clock to the ADC in system clock cycles
         -- 0x000027: Total number of pixels to read from the ASIC
         -- 0x000028: Saci clock speed, counter bit position (0-7)
         -- 0x000029: Pin status of ASIC pins (see next reg)
         -- 0x00002A: Manual pin control for ASIC pins
         -- 0x00002B: Width of ASIC R0 signal
         -- 0x00002C: ADC Pipeline Delay
         -- 0x00002D: ADC channel to read
         -- 0x00002E: Adjust width of pre-pulse R0
         -- 0x00002F: Adjust delay from pre-pulse R0 to start of "normal" state machine
         elsif pgpRegOut.addr(23 downto 4) = x"0002" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               case pgpRegOut.addr(3 downto 0) is
                  when x"0"   => intConfig.acqToAsicR0Delay  <= pgpRegOut.wrData after tpd;
                  when x"1"   => intConfig.asicR0ToAsicAcq   <= pgpRegOut.wrData after tpd;
                  when x"2"   => intConfig.asicAcqWidth      <= pgpRegOut.wrData after tpd; 
                  when x"3"   => intConfig.asicAcqLToPPmatL  <= pgpRegOut.wrData after tpd;
                  when x"4"   => intConfig.asicRoClkHalfT    <= pgpRegOut.wrData after tpd;
                  when x"5"   => intConfig.adcReadsPerPixel  <= pgpRegOut.wrData after tpd;
                  when x"6"   => intConfig.adcClkHalfT       <= pgpRegOut.wrData after tpd;
                  when x"7"   => intConfig.totalPixelsToRead <= pgpRegOut.wrData after tpd;
                  when x"8"   => intConfig.saciClkBit        <= pgpRegOut.wrData after tpd;
                  when x"9"   => intConfig.asicPins          <= pgpRegOut.wrData(5 downto 0) after tpd;
                  when x"A"   => intConfig.manualPinControl  <= pgpRegOut.wrData(5 downto 0) after tpd;
                                 intConfig.prePulseR0        <= pgpRegOut.wrData(6) after tpd;
                                 intConfig.adcStreamMode     <= pgpRegOut.wrData(7) after tpd;
                                 intConfig.testPattern       <= pgpRegOut.wrData(8) after tpd;
                                 intConfig.syncMode          <= pgpRegOut.wrData(10 downto 9) after tpd;
                                 intConfig.asicR0Mode        <= pgpRegOut.wrData(11) after tpd;
                  when x"B"   => intConfig.asicR0Width       <= pgpRegOut.wrData after tpd;
                  when x"C"   => intConfig.pipelineDelay     <= pgpRegOut.wrData after tpd;
                  when x"D"   => intConfig.syncWidth         <= pgpRegOut.wrData(15 downto  0) after tpd;
                                 intConfig.syncDelay         <= pgpRegOut.wrData(31 downto 16) after tpd;
                  when x"E"   => intConfig.prePulseR0Width   <= pgpRegOut.wrData after tpd;
                  when x"F"   => intConfig.prePulseR0Delay   <= pgpRegOut.wrData after tpd;
                  when others =>
               end case;
            end if;
            case pgpRegOut.addr(3 downto 0) is
               when x"0"   => pgpRegIn.rdData <= intConfig.acqToAsicR0Delay  after tpd;
               when x"1"   => pgpRegIn.rdData <= intConfig.asicR0ToAsicAcq   after tpd;
               when x"2"   => pgpRegIn.rdData <= intConfig.asicAcqWidth      after tpd;
               when x"3"   => pgpRegIn.rdData <= intConfig.asicAcqLToPPmatL  after tpd;
               when x"4"   => pgpRegIn.rdData <= intConfig.asicRoClkHalfT    after tpd;
               when x"5"   => pgpRegIn.rdData <= intConfig.adcReadsPerPixel  after tpd;
               when x"6"   => pgpRegIn.rdData <= intConfig.adcClkHalfT       after tpd;
               when x"7"   => pgpRegIn.rdData <= intConfig.totalPixelsToRead after tpd;
               when x"8"   => pgpRegIn.rdData <= intConfig.saciClkBit        after tpd;
               when x"9"   => pgpRegIn.rdData <= x"000000" & "00" & intConfig.asicPins          after tpd;
               when x"A"   => pgpRegIn.rdData <= x"00000" & 
                                                    intConfig.asicR0Mode & 
                                                    intConfig.syncMode &
                                                    intConfig.testPattern &
                                                    intConfig.adcStreamMode & 
                                                    intConfig.prePulseR0 & 
                                                    intConfig.manualPinControl  after tpd;
               when x"B"   => pgpRegIn.rdData <= intConfig.asicR0Width       after tpd;
               when x"C"   => pgpRegIn.rdData <= intConfig.pipelineDelay     after tpd;
               when x"D"   => pgpRegIn.rdData <= intConfig.syncDelay & intConfig.syncWidth after tpd;
               when x"E"   => pgpRegIn.rdData <= intConfig.prePulseR0Width   after tpd;
               when x"F"   => pgpRegIn.rdData <= intConfig.prePulseR0Delay   after tpd;
               when others =>
            end case;

         -- Serial ID chip (digital card)
         elsif pgpRegOut.addr = x"00030" then 
            pgpRegIn.rdData <= serNumReg(0)(31 downto 0);
         elsif pgpRegOut.addr = x"00031" then
            pgpRegIn.rdData <= serNumReg(0)(63 downto 32);
         -- Serial ID chip (analog card)
         elsif pgpRegOut.addr = x"00032" then 
            pgpRegIn.rdData <= serNumReg(1)(31 downto 0);
         elsif pgpRegOut.addr = x"00033" then
            pgpRegIn.rdData <= serNumReg(1)(63 downto 32);

         -- EEPROM (digital card)
         elsif pgpRegOut.addr = x"00034" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               memAddr <= pgpRegOut.wrData (15 downto 0);
            end if;
            pgpRegIn.rdData (15 downto 0) <= memAddr after tpd;
         elsif pgpRegOut.addr = x"00037" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               memAddr <= pgpRegOut.wrData (15 downto 0);
            end if;
            pgpRegIn.rdData (15 downto 0) <= memAddr after tpd;
         elsif pgpRegOut.addr = x"00035" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               memDataIn (31 downto 0) <= pgpRegOut.wrData after tpd;
            end if;
            pgpRegIn.rdData <= memDataIn (31 downto 0) after tpd;
         elsif pgpRegOut.addr = x"00036" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               memDataIn (63 downto 32)  <= pgpRegOut.wrData after tpd;
            end if;
            pgpRegIn.rdData <= memDataIn (63 downto 32) after tpd;
         elsif pgpRegOut.addr = x"00038" then
            pgpRegIn.rdData <= memDataOutReg(31 downto 0) after tpd;
         elsif pgpRegOut.addr = x"00039" then
            pgpRegIn.rdData <= memDataOutReg(63 downto 32) after tpd;

         -- TPS control register to decide when TPS system reads (0x00040)
         elsif pgpRegOut.addr = x"00040" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then 
               intConfig.tpsEdge  <= pgpRegOut.wrData(16) after tpd;
               intConfig.tpsDelay <= pgpRegOut.wrData(15 downto 0) after tpd;
            end if;
            pgpRegIn.rdData <= x"000" & "000" & intConfig.tpsEdge & intConfig.tpsDelay after tpd;
            
         -- Virtual oscilloscope x"0005X"
         elsif pgpRegOut.addr = x"00050" then
            intScopeConfig.arm <= pgpRegOut.req and pgpRegOut.op;
         elsif pgpRegOut.addr = x"00051" then
            intScopeConfig.trig <= pgpRegOut.req and pgpRegOut.op;

         elsif pgpRegOut.addr(23 downto 4) = x"0005" then
            if pgpRegOut.req = '1' and pgpRegOut.op = '1' then
               case pgpRegOut.addr(3 downto 0) is
                  when x"2"   => intScopeConfig.scopeEnable       <= pgpRegOut.wrData(0)              after tpd;
                                 intScopeConfig.triggerEdge       <= pgpRegOut.wrData(1)              after tpd;
                                 intScopeConfig.triggerChannel    <= pgpRegOut.wrData( 5 downto  2)   after tpd;
                                 intScopeConfig.triggerMode       <= pgpRegOut.wrData( 7 downto  6)   after tpd;
                                 intScopeConfig.triggerAdcThresh  <= pgpRegOut.wrData(31 downto 16)   after tpd;
                  when x"3"   => intScopeConfig.triggerHoldoff    <= pgpRegOut.wrData(12 downto  0)   after tpd;
                                 intScopeConfig.triggerOffset     <= pgpRegOut.wrData(25 downto 13)   after tpd;
                  when x"4"   => intScopeConfig.traceLength       <= pgpRegOut.wrData(12 downto  0)   after tpd;
                                 intScopeConfig.skipSamples       <= pgpRegOut.wrData(25 downto 13)   after tpd;
                  when x"5"   => intScopeConfig.inputChannelA     <= pgpRegOut.wrData( 4 downto  0)   after tpd;
                                 intScopeConfig.inputChannelB     <= pgpRegOut.wrData( 9 downto  5)   after tpd;
                  when others =>
               end case;
            end if;
            case pgpRegOut.addr(3 downto 0) is
               when x"2"   => pgpRegIn.rdData <= intScopeConfig.triggerAdcThresh &
                                                    x"00" & 
                                                    intScopeConfig.triggerMode & 
                                                    intScopeConfig.triggerChannel &
                                                    intScopeConfig.triggerEdge &
                                                    intScopeConfig.scopeEnable after tpd; 
               when x"3"   => pgpRegIn.rdData <= "000000" &
                                                    intScopeConfig.triggerOffset &
                                                    intScopeConfig.triggerHoldoff after tpd;
               when x"4"   => pgpRegIn.rdData <= "000000" &
                                                    intScopeConfig.skipSamples &
                                                    intScopeConfig.traceLength after tpd;
               when x"5"   => pgpRegIn.rdData <= x"00000" & "00" & 
                                                    intScopeConfig.inputChannelB &
                                                    intScopeConfig.inputChannelA after tpd;
               when others =>
            end case;

         -- Fast ADCs, 0x008000 -  0x00FFFF
         elsif pgpRegOut.addr(23 downto 16) = x"00" and pgpRegOut.addr(15) = '1' then
            pgpRegIn.rdData(7 downto 0) <= adcRdData                                  after tpd;
            adcSel                         <= pgpRegOut.addr(14 downto 13)            after tpd;
            adcWrReq                       <= pgpRegOut.req and pgpRegOut.op       after tpd;
            adcRdReq                       <= pgpRegOut.req and (not pgpRegOut.op) after tpd;
            pgpRegIn.ack                <= adcAck                                     after tpd;

         -- SACI Space, 0x800000
         elsif pgpRegOut.addr(23) = '1' then
            saciRegIn.req      <= pgpRegOut.req  after tpd;
            pgpRegIn.rdData <= saciRegOut.rdData after tpd;
            pgpRegIn.ack    <= saciRegOut.ack    after tpd;
            pgpRegIn.fail   <= saciRegOut.fail   after tpd;
         end if;

      end if;
   end process;

   -- SACI Constants
   saciRegIn.reset  <= sysClkRst;
   saciRegIn.chip   <= pgpRegOut.addr(21 downto 20);
   saciRegIn.op     <= pgpRegOut.op;
   saciRegIn.cmd    <= pgpRegOut.addr(18 downto 12);
   saciRegIn.addr   <= pgpRegOut.addr(11 downto 0);
   saciRegIn.wrData <= pgpRegOut.wrData;

   -----------------------------------------------
   -- Readout Init Request
   -----------------------------------------------

   -- Sync states
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         curState <= IDLE_S after tpd;
      elsif rising_edge(sysClk) then
--         if (saciClkEdge = '1') then
         curState <= nxtState after tpd;
--         end if;
      end if;  
   end process;

   -- Async states
   process ( curState, saciRegIn,  saciSelOut, saciReadoutReq, saciTimeout, intConfig ) begin
      saciRegOut.ack    <= '0';
      saciRegOut.fail   <= '0';
      saciRegOut.rdData <= (others=>'0');
      saciSelIn.reset   <= '0';
      saciSelIn.req     <= '0';
      saciSelIn.chip    <= "00";
      saciSelIn.op      <= '0';
      saciSelIn.cmd     <= "0000000";
      saciSelIn.addr    <= x"000";
      saciSelIn.wrData  <= x"00000000";
      saciReadoutAck    <= '0';
      saciTimeoutCntEn  <= '1';
      saciTimeoutCntRst <= '0';
      nxtState          <= curState;

      case curState is 

         when IDLE_S =>
            saciTimeoutCntEn  <= '0';
            saciTimeoutCntRst <= '1';
            -- By default, listen to the register controller.
            saciSelIn  <= saciRegIn;
            saciRegOut <= saciSelOut;
            -- If we get a reg request, move to reg state to
            -- monitor for timeouts.
            if saciRegIn.req = '1' then
               nxtState <= REG_S;
            -- Otherwise, process the automatic prepare for
            -- readout command.
            elsif saciReadoutReq = '1' then
               if intConfig.asicMask(0) = '1' then
                  nxtState <= CMD_0_S;
               else
                  nxtState <= PAUSE_0_S;
               end if;
            end if;

         when REG_S =>
            saciSelIn  <= saciRegIn;
            saciRegOut <= saciSelOut;

            -- Request de-asserted
            if saciRegIn.req = '0' then
               nxtState <= IDLE_S;
            end if;

         when CMD_0_S =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "00";

            -- Transaction acked or we timed out
            if saciSelOut.ack = '1' or saciTimeout = '1' then
               saciSelIn.req <= '0';
               nxtState <= PAUSE_0_S;
            end if;

         when PAUSE_0_S =>
            saciSelIn.req     <= '0';
            saciTimeoutCntRst <= '1';
            if saciSelOut.ack = '0' then
               if intConfig.asicMask(1) = '1' then
                  nxtState          <= CMD_1_S;
               else
                  nxtState          <= PAUSE_1_S;
               end if;
            end if;

         when CMD_1_S =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "01";

            -- Transaction acked or we timed out
            if saciSelOut.ack = '1' or saciTimeout = '1' then
               saciSelIn.req <= '0';
               nxtState <= PAUSE_1_S;
            end if;

         when PAUSE_1_S =>
            saciSelIn.req     <= '0';
            saciTimeoutCntRst <= '1';
            if saciSelOut.ack = '0' then
               if intConfig.asicMask(2) = '1' then
                  nxtState          <= CMD_2_S;
               else
                  nxtState          <= PAUSE_2_S;
               end if;
            end if;

         when CMD_2_S =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "10";

            -- Transaction acked or we timed out 
            if saciSelOut.ack = '1' or saciTimeout = '1' then
               saciSelIn.req <= '0';
               nxtState <= PAUSE_2_S;
            end if;

         when PAUSE_2_S =>
            saciSelIn.req     <= '0';
            saciTimeoutCntRst <= '1';
            if saciSelOut.ack = '0' then
               if intConfig.asicMask(3) = '1' then
                  nxtState          <= CMD_3_S;
               else
                  nxtState          <= DONE_S;
               end if;
            end if;

         when CMD_3_S =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "11";

            -- Transaction acked or we timed out
            if saciSelOut.ack = '1' or saciTimeout = '1' then
               saciSelIn.req <= '0';
               nxtState <= DONE_S;
            end if;

         when DONE_S =>
            saciReadoutAck    <= '1';
            saciTimeoutCntRst <= '1';
            if saciReadoutReq = '0' then
               nxtState <= IDLE_S;
            end if;

         when others =>
      end case;
   end process;

   --Timeout logic for SACI
--   saciTimeout <= saciTimeoutCnt(saciTimeoutCnt'left);
   saciTimeout <= saciTimeoutCnt(5 ) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 7 else
                  saciTimeoutCnt(6 ) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 6 else
                  saciTimeoutCnt(7 ) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 5 else
                  saciTimeoutCnt(8 ) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 4 else
                  saciTimeoutCnt(9 ) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 3 else
                  saciTimeoutCnt(10) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 2 else
                  saciTimeoutCnt(11) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 1 else
                  saciTimeoutCnt(12) when conv_integer(intConfig.saciClkBit(2 downto 0)) = 0 else
                  saciTimeoutCnt(saciTimeoutCnt'left);
   process( sysClk ) begin
      if rising_edge(sysClk) then
         if saciTimeoutCntRst = '1' or sysClkRst = '1' then
            saciTimeoutCnt <= (others => '0');
         elsif saciTimeoutCntEn = '1' and saciClkEdge = '1' then
            saciTimeoutCnt <= saciTimeoutCnt + 1;
         end if;
      end if;
   end process;
   --Edge detect for SACI clk
   U_DataSaciClkEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => sacibit,
         risingEdge => saciClkEdge
      );

   -----------------------------------------------
   -- SACI Controller
   -----------------------------------------------

   -- SACI specific reset
   saciRst <= sysClkRst or saciTimeout;
   -- Generate SACI Clock
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         saciCnt <= (others=>'0') after tpd;
      elsif rising_edge(sysClk) then
         saciCnt <= saciCnt + 1 after tpd;
      end if;  
   end process;

   --- ~1Mhz fixed
   --U_SaciClk: bufg port map ( I => saciCnt(6), O => intClk );
   --- Adjustable by register
   sacibit <= saciCnt(conv_integer(intConfig.saciClkBit(2 downto 0)));
   U_SaciClk: bufg port map ( I => sacibit , O => intClk );

   -- Controller
   U_Saci : entity work.SaciMaster 
     port map (
       clk           => intClk,
       rst           => saciRst,
       saciClk       => saciClk,
       saciSelL      => intSelL,
       saciCmd       => saciCmd,
       saciRsp       => intRsp,
       saciMasterIn  => saciSelIn,
       saciMasterOut => saciSelOut
   );

   -- Mask response
   intRsp <= '0' when (saciRsp and (not intSelL)) = 0 else '1';

   -----------------------------------------------
   -- DAC Controller
   -----------------------------------------------
   U_DacCntrl : entity work.DacCntrl 
      port map ( 
         sysClk          => sysClk,
         sysClkRst       => sysClkRst,
         dacData         => dacData,
         dacStrobe       => dacStrobe,
         dacDin          => dacDin,
         dacSclk         => dacSclk,
         dacCsL          => dacCsb,
         dacClrL         => dacClrb
      );

   -----------------------------------------------
   -- Serial Number/EEPROM IC Interfaces (1-wire)
   -----------------------------------------------
   U_SliceDimmIdAnalogCard : entity work.SliceDimmId
      port map (
         pgpClk    => sysClk,
         pgpRst    => sysClkRst,
         serClkEn  => serClkEn,
         fdSerDin  => serialIdIn(1),
         fdSerDout => serialIdOut(1),
         fdSerDenL => serialIdEn(1),
         fdSerial  => serNumRaw(1),
         fdValid   => serNumValid(1)
      );
   U_IdAndEepromDigitalCard : entity work.EepromId
      port map (
         pgpClk    => sysClk,
         pgpRst    => sysClkRst,
         serClkEn  => serClkEn,
         fdSerDin  => serialIdIn(0),
         fdSerDout => serialIdOut(0),
         fdSerDenL => serialIdEn(0),
         fdSerial  => serNumRaw(0),
         fdValid   => serNumValid(0),
         address   => memAddr,
         dataIn    => memDataIn,
         dataOut   => memDataOutRaw,
         dataValid => memDataValid,
         readReq   => memReadReq,
         writeReq  => memWriteReq
      );
   --Edge detect for the valid signals
   G_DataSendEdgeSer : for i in 0 to 1 generate
      U_DataSendEdgeSer : entity work.SynchronizerEdge
         port map (
            clk        => sysClk,
            rst        => sysClkRst,
            dataIn     => serNumValid(i),
            risingEdge => serNumValidEdge(i)
         );
   end generate;
   --Clock the serial number into a register when it's valid
   process(sysClk, sysClkRst) begin
      for i in 0 to 1 loop
         if rising_edge(sysClk) then
            if sysClkRst = '1' then
               serNumReg(i) <= (others => '0');
            elsif serNumValidEdge(i) = '1' then
               serNumReg(i) <= serNumRaw(i);
            end if;
         end if;
      end loop;
   end process;
   --Edge detect for the valid signals
   U_DataSendEdgeMem : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => memDataValid,
         risingEdge => memDataValidEdge
      );
   --Clock the data into a register when it's valid
   process(sysClk, sysClkRst) begin
         if rising_edge(sysClk) then
            if sysClkRst = '1' then
               memDataOutReg <= (others => '0');
            elsif memDataValidEdge = '1' then
               memDataOutReg <= memDataOutRaw;
            end if;
         end if;
   end process;
   --Generate a slow enable for the 1-wire interfaces
   --  Modified NCYCLES to be a variable so that we can support
   --  the slow clock enables with different clock rates (e.g.,
   --  for both the SDD application, which uses 200 MHz base
   --  rate, and the ePix application, which uses 125 MHz base
   --  rate).
   NCYCLES <= 820  when FpgaVersion(31 downto 24) = x"E0" else --ePix100
              410  when FpgaVersion(31 downto 24) = x"E1" else --SDD
              820  when FpgaVersion(31 downto 24) = x"E2" else --ePix10k
              1000;
   NCYCLES_SPI <= 10 when FpgaVersion(31 downto 24) = x"E0" else --ePix100
                  5  when FpgaVersion(31 downto 24) = x"E1" else --SDD
                  10 when FpgaVersion(31 downto 24) = x"E2" else --ePix10k
                  20;
   process(sysClk,sysClkRst) 
      variable counter     : integer range 0 to 2047 := 0;
      variable counter_spi : integer range 0 to 127 := 0;
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            counter     := 0;
            counter_spi := 0;
         else
            if (counter = NCYCLES) then
               counter := 0;
               serClkEn <= '1';
            else 
               counter := counter + 1;
               serClkEn <= '0';
            end if;
            if (counter_spi = NCYCLES_SPI) then
               counter_spi := 0;
               spiClkEn    <= '1';
            else
               counter_spi := counter_spi + 1;
              spiClkEn    <= '0';
            end if;
         end if;
      end if;
   end process;
   --Hold write or read request for slow enable
   process(sysClk) 
      variable counter     : integer range 0 to 2047 := 0;
      variable counter_spi : integer range 0 to 127 := 0;
      variable RW          : integer range 0 to 2 := 0;
   begin
   if rising_edge(sysClk) then   
      if (pgpRegOut.addr = x"00034" and pgpRegOut.req = '1' and pgpRegOut.op = '1')  then
          RW := 1;
      elsif (pgpRegOut.addr = x"00037" and pgpRegOut.req = '1' and pgpRegOut.op = '1') then
          RW := 2; 
      end if;
      if RW = 1 then
         if counter = NCYCLES then
            counter := 0;
            memWriteReq <= '0';
            RW := 0;
         else
            counter := counter + 1;
            memWriteReq <= '1';
         end if;
      elsif RW = 2 then
         if counter = NCYCLES then
            counter := 0;
            memReadReq <= '0';
            RW := 0;
         else
            counter := counter + 1;
            memReadReq <= '1';
         end if;
      end if;
   end if;
   end process;


   -----------------------------------------------
   -- Fast ADC Control
   -----------------------------------------------

   -- ADC Control
   U_AdcConfig : entity work.AdcConfig
      port map (
         sysClk     => sysClk,
         sysClkRst  => sysClkRst,
         sysClkEn   => spiClkEn,
         adcWrData  => pgpRegOut.wrData(7 downto 0),
         adcRdData  => adcRdData,
         adcAddr    => pgpRegOut.addr(12 downto 0),
         adcWrReq   => adcWrReq,
         adcRdReq   => adcRdReq,
         adcAck     => adcAck,
         adcSel     => adcSel,
         adcSClk    => adcSpiClk,
         adcSDin    => adcSpiDataIn,
         adcSDout   => adcSpiDataOut,
         adcSDEn    => adcSpiDataEn,
         adcCsb     => adcSpiCsb
      );

   -- Never power down
   adcPdwn         <= "000";

end RegControl;

