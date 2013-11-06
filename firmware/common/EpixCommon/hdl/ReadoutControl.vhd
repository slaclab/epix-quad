-------------------------------------------------------------------------------
-- Title         : Acquisition Control Block
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : ReadoutControl.vhd
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
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.EpixTypes.all;
use work.Pgp2AppTypesPkg.all;
use work.StdRtlPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity ReadoutControl is
   port (

      -- Clocks and reset
      sysClk              : in    sl;
      sysClkRst           : in    sl;

      -- Configuration
      epixConfig          : in    EpixConfigType;

      -- Data for headers
      acqCount            : in    slv(31 downto 0);
      seqCount            : in    slv(31 downto 0);

      -- Run control
      acqStart            : in    sl;
      readValid           : in    slv(MAX_OVERSAMPLE-1 downto 0);
      readDone            : out   sl;
      acqBusy             : in    sl;
      dataSend            : in    sl;
      readTps             : in    sl;

      -- ADC Data
      adcValid            : in    slv(19 downto 0);
      adcData             : in    word16_array(19 downto 0);

      -- Slow ADC data
      slowAdcData         : in    word16_array(15 downto 0);

      -- Data Out
      frameTxIn           : out   UsBuff32InType;
      frameTxOut          : in    UsBuff32OutType;

      -- MPS
      mpsOut              : out   sl
   );
end ReadoutControl;

-- Define architecture
architecture ReadoutControl of ReadoutControl is

   -- Timeout in clock cycles between acqStart and sendData
   constant DAQ_TIMEOUT : integer := 12500; --100 us at 125 MHz

   -- Depth of FIFO 
   constant CH_FIFO_ADDR_WIDTH : integer := 10;
   constant CH_FIFO_FULL_THRES : integer := 96;

   -- State definitions
   type state is (IDLE_S,
                  ARMED_S, 
                  HEADER_S,
                  READ_FIFO_S,
                  READ_FIFO_TEST_S,
                  TPS_DATA_S,
                  FOOTER_S);

   -- Local Signals
   signal curState       : state := IDLE_S;
   signal nxtState       : state := IDLE_S;
   signal wordCnt        : unsigned(31 downto 0);
   signal clearFifos     : sl := '0';
   signal memRst         : sl := '0';
   signal timeoutCnt     : unsigned(13 downto 0);
   signal timeoutCntEn   : sl := '0';
   signal timeoutCntRst  : sl := '0';
   signal wordCntRst     : sl;
   signal wordCntEn      : sl;
   signal chCnt          : unsigned(3 downto 0);
   signal chCntRst       : sl;
   signal chCntEn        : sl;
   signal overSmplCnt    : unsigned(log2(MAX_OVERSAMPLE)-1 downto 0);
   signal overSmplCntRst : sl;
   signal overSmplCntEn  : sl;
   signal fillCnt        : unsigned(CH_FIFO_ADDR_WIDTH-1 downto 0);
   signal fillCntRst     : sl;
   signal fillCntEn      : sl;
   signal adcCnt         : unsigned(11 downto 0);
   signal adcCntRst      : sl;
   signal adcCntEn       : sl;
   signal dataSendEdge   : sl;
   signal acqStartEdge   : sl;
   signal adcMemWrEn     : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemRdOrder  : std_logic_vector(15 downto 0);
   signal adcMemRdRdy    : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemRdValid  : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemOflow    : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemOflowAny : std_logic;
   signal adcMemRdData   : Slv16VectorArray(MAX_OVERSAMPLE-1 downto 0,15 downto 0);
   signal adcStreamMode  : std_logic;
   signal testPattern    : std_logic;

   signal adcFifoWrEn    : slv(15 downto 0);
   signal adcFifoEmpty   : slv(15 downto 0);
   signal adcFifoOflow   : slv(15 downto 0);
   signal adcFifoRdEn    : slv(15 downto 0);
   signal adcFifoRdValid : slv(15 downto 0);
   signal adcFifoRdData  : Slv32Array(15 downto 0);
   signal adcFifoWrData  : Slv16Array(15 downto 0);
   signal fifoOflowAny   : sl := '0';
   signal fifoEmptyAll   : sl := '0';

   type chanMap is array(15 downto 0) of integer range 0 to 15;
   signal channelOrder   : chanMap;

   signal tpsAdcData     : Slv16Array(3 downto 0);

   -- Hard coded words in the data stream
   -- Some may be updated later.
   constant cLane     : slv( 1 downto 0) := "00";
   constant cVC       : slv( 1 downto 0) := "00";
   constant cQuad     : slv( 1 downto 0) := "00";
   constant cOpCode   : slv( 7 downto 0) := x"00";
   constant cZeroWord : slv(31 downto 0) := x"00000000";

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Mode to decide whether we readout ASICs or pure ADC streams
   adcStreamMode <= epixConfig.adcStreamMode;
   -- Test pattern mode to help check data alignment, etc.
   testPattern <= epixConfig.testPattern;
   -- Channel Order for ASIC readout (last downto first)
   channelOrder <= (4,5,6,7,8,9,10,11,3,2,1,0,15,14,13,12) when adcStreamMode = '0' else
                   (15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0);
   -- Readout order based on ePix100 ASIC numbering scheme (0 - forward, 1 - backward)
   adcMemRdOrder <= x"0FF0" when adcStreamMode = '0' else
                    x"0000";

   -- Edge detection for signals that interface with other blocks
   U_DataSendEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => dataSend,
         risingEdge => dataSendEdge
      );
   U_ReadStartEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => acqStart,
         risingEdge => acqStartEdge
      );


   -- Outputs
   -- Default mps to '0' for now.
   mpsOut <= '0';

   --------------------------------------------------
   -- Simple state machine to just send ADC values --
   --------------------------------------------------
   process (curState,adcFifoRdData,chCnt,adcFifoRdValid,fillCnt,wordCnt,
            acqCount,seqCount,overSmplCnt,fifoOflowAny,ePixConfig,
            frameTxOut,tpsAdcData,channelOrder,acqBusy,adcFifoEmpty,adcMemOflowAny) begin
         --Defaults
         frameTxIn.frameTxEnable <= '0' after tpd;
         frameTxIn.frameTxSOF    <= '0' after tpd;
         frameTxIn.frameTxEOF    <= '0' after tpd;
         frameTxIn.frameTxEOFE   <= '0' after tpd;
         frameTxIn.frameTxData   <= (others => '0') after tpd;
         wordCntRst              <= '0' after tpd;
         wordCntEn               <= '0' after tpd;
         chCntRst                <= '0' after tpd;
         chCntEn                 <= '0' after tpd;
         overSmplCntRst          <= '0' after tpd;
         overSmplCntEn           <= '0' after tpd;
         fillCntRst              <= '0' after tpd;
         fillCntEn               <= '0' after tpd;
         timeoutCntRst           <= '0' after tpd;
         timeoutCntEn            <= '0' after tpd;
         adcFifoRdEn             <= (others => '0') after tpd;
         readDone                <= '0' after tpd;
         clearFifos              <= '0' after tpd;
         --State specific outputs
         case curState is
            --Idle state
            when IDLE_S =>
               readDone      <= '1' after tpd;
               wordCntRst    <= '1' after tpd;
               clearFifos    <= '1' after tpd;
               timeoutCntRst <= '1' after tpd;
               fillCntRst    <= '1' after tpd;
               chCntRst      <= '1' after tpd;
            --Acq received, wait for daq
            when ARMED_S  =>
               timeoutCntEn  <= '1' after tpd;
            --Send header words
            when HEADER_S =>
               wordCntEn               <= '1' after tpd;
               frameTxIn.frameTxEnable <= '1' after tpd;
               overSmplCntRst          <= '1' after tpd;
               case to_integer(wordCnt) is
                  when 0 => frameTxIn.frameTxData <= x"000000" & "00" & cLane & "00" & cVC after tpd;
                            frameTxIn.frameTxSOF  <= '1' after tpd;
                  when 1 => frameTxIn.frameTxData <= x"0" & "00" & cQuad & cOpCode & acqCount(15 downto 0) after tpd;
                  when 2 => frameTxIn.frameTxData <= seqCount after tpd;
                  when 3 => frameTxIn.frameTxData <= cZeroWord after tpd;
                  when 4 => frameTxIn.frameTxData <= cZeroWord after tpd;
                  when 5 => frameTxIn.frameTxData <= cZeroWord after tpd;
                  when 6 => frameTxIn.frameTxData <= cZeroWord after tpd;
                  when 7 => frameTxIn.frameTxData <= cZeroWord after tpd;
                  when others  => frameTxIn.frameTxData <= cZeroWord after tpd;
               end case;
            --Readout data 1 row at a time, suitable for ASIC readout
            when READ_FIFO_S =>
               wordCntRst <= '1' after tpd;
               --Normal data
               frameTxIn.frameTxData <= adcFifoRdData(channelOrder(to_integer(chCnt))) after tpd;
               --FIFO has FWFT enabled, logic is written accordingly.
               if (adcFifoRdValid(channelOrder(to_integer(chCnt))) = '1' and frameTxOut.frameTxAFull = '0') then
                  frameTxIn.frameTxEnable                        <= '1' after tpd;
                  adcFifoRdEn(channelOrder(to_integer(chCnt))) <= '1' after tpd;
                  fillCntEn                                      <= '1' after tpd;
                  if (to_integer(fillCnt) = CH_FIFO_FULL_THRES/2-1) then
                     chCntEn    <= '1' after tpd;
                     fillCntRst <= '1' after tpd;
                  end if;
               end if;
            --Readout data 1 full channel at a time, suitable for ADC waveforms
            when READ_FIFO_TEST_S =>
               wordCntRst <= '1' after tpd;
               frameTxIn.frameTxData <= adcFifoRdData(to_integer(chCnt)) after tpd;
               --Test mode, ADCs read out sequentially
               if (adcFifoRdValid(to_integer(chCnt)) = '1' and frameTxOut.frameTxAFull = '0' and acqBusy = '0') then
                  frameTxIn.frameTxEnable          <= '1' after tpd;
                  adcFifoRdEn(to_integer(chCnt)) <= '1' after tpd;
                  fillCntEn                        <= '1' after tpd;
               end if;
               --Increment to next ADC if this one is empty
               if (adcFifoEmpty(to_integer(chCnt)) = '1' and acqBusy = '0') then
                  chCntEn    <= '1' after tpd;
                  fillCntRst <= '1' after tpd;
               end if;
            --Two words of data from the TPS system (ADC(3))
            when TPS_DATA_S  =>
               wordCntEn               <= '1' after tpd;
               frameTxIn.frameTxEnable <= '1' after tpd;
               case to_integer(wordCnt) is
                  when 0 => frameTxIn.frameTxData <= tpsAdcData(1) & tpsAdcData(0) after tpd;
                  when 1 => frameTxIn.frameTxData <= tpsAdcData(3) & tpsAdcData(2) after tpd;
                  when others  => frameTxIn.frameTxData <= cZeroWord after tpd;
               end case;
            --Send footer word
            when FOOTER_S    =>
               readDone                <= '1' after tpd;
               frameTxIn.frameTxData   <= cZeroWord after tpd;
               frameTxIn.frameTxEnable <= '1' after tpd; 
               frameTxIn.frameTxEOF    <= '1' after tpd;
               frameTxIn.frameTxEOFE   <= fifoOflowAny or adcMemOflowAny after tpd;
            --Use defaults for uncaught cases
            when others =>
         end case;
   end process;
   --Next state logic
   process (curState,acqStartEdge,wordCnt,fillCnt,
            overSmplCnt,acqBusy,fifoEmptyAll,dataSendEdge,timeoutCnt,
            fifoOflowAny,adcMemOflowAny,adcStreamMode) begin
      --Default is to remain in current state
      nxtState <= curState after tpd;
      --State specific next-states
      case curState is 
         when IDLE_S =>
            if acqStartEdge = '1' then
               nxtState <= ARMED_S after tpd;
            end if;
         when ARMED_S =>
            if dataSendEdge = '1' then
               nxtState <= HEADER_S after tpd;
            elsif (timeoutCnt >= DAQ_TIMEOUT) then
               nxtState <= IDLE_S after tpd;
            end if; 
         when HEADER_S =>
            if (wordCnt = 7) then
               if (adcStreamMode = '0') then
                  nxtState <= READ_FIFO_S after tpd;
               elsif (adcStreamMode = '1') then
                  nxtState <= READ_FIFO_TEST_S after tpd;
               end if;
            end if;
         when READ_FIFO_S =>
            if acqBusy = '0' and fifoEmptyAll = '1' then
               nxtState <= TPS_DATA_S;
            elsif fifoOflowAny = '1' or adcMemOflowAny = '1' then
               nxtState <= FOOTER_S;
            end if;
         when READ_FIFO_TEST_S =>
            if fifoEmptyAll = '1' and acqBusy = '0' then
               nxtState <= FOOTER_S;
            elsif fifoOflowAny = '1' or adcMemOflowAny = '1' then
               nxtState <= FOOTER_S;
            end if;
         when TPS_DATA_S =>
            if (wordCnt = 1) then
               nxtState <= FOOTER_S after tpd;
            end if;
         when FOOTER_S =>
            nxtState <= IDLE_S after tpd;
         when others =>
            nxtState <= IDLE_S after tpd;
      end case;
   end process;
   --Transition to next state
   process (sysClk, sysClkRst) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            curState <= IDLE_S after tpd;
         else
            curState <= nxtState after tpd;
         end if;
      end if;
   end process;

   --Counts the number of words to choose what data to send next
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wordCntRst = '1' then
            wordCnt <= (others => '0') after tpd;
         elsif wordCntEn = '1' then
            wordCnt <= wordCnt + 1 after tpd;
         end if; 
      end if; 
   end process;
   --Count which channel we're on (0-15)
   process(sysClk) begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1' or chCntRst = '1') then
            chCnt <= (others => '0') after tpd;
         elsif chCntEn = '1' then
            chCnt <= chCnt + 1 after tpd;
         end if;
      end if;
   end process;
   --Count which sample we're on (0-(MAX_OVERSAMPLE-1))
   process(sysClk) begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1' or overSmplCntRst = '1') then
            overSmplCnt <= (others => '0') after tpd;
         elsif overSmplCntEn = '1' then
            overSmplCnt <= overSmplCnt + 1 after tpd;
         end if;
      end if;
   end process;
   --Fill count for filling up FIFOs
   process(sysClk) begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1' or fillCntRst = '1') then
            fillCnt <= (others => '0') after tpd;
         elsif fillCntEn = '1' then
            fillCnt <= fillCnt + 1 after tpd;
         end if;
      end if;
   end process;
   --Timeout counter between acqStart and dataSend
   process(sysClk) begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1' or timeoutCntRst = '1') then
            timeoutCnt <= (others => '0') after tpd;
         elsif timeoutCntEn = '1' then
            timeoutCnt <= timeoutCnt + 1 after tpd;
         end if;
      end if;
   end process;
   --Count number of ADC writes
   adcCntEn  <= readValid(0) and adcValid(0);
   adcCntRst <= memRst;
   process(sysClk) begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1' or adcCntRst = '1') then
            adcCnt <= (others => '0') after tpd;
         elsif adcCntEn = '1' then
            adcCnt <= adcCnt + 1 after tpd;
         end if;
      end if;
   end process;
   --Register the TPS ADC data when readTps is high
   process(sysClk) 
   begin
      if rising_edge(sysClk) then
         for i in 0 to 3 loop
            if readTps = '1' and adcValid(16+i) = '1' then
               tpsAdcData(i) <= adcData(16+i);
            end if;
         end loop;
      end if;
   end process;

   --Simple logic to choose which memory to read from
   process(sysClk) begin
      if rising_edge(sysClk) then
         if adcStreamMode = '0' then
            for i in 0 to 15 loop
               adcFifoWrEn(i)   <= adcMemRdValid(0)(i);
               if testPattern = '0' then
                  adcFifoWrData(i) <= adcMemRdData(0,i);
               else
                  adcFifoWrData(i) <= "0000" & std_logic_vector(to_unsigned(i,4)) & adcMemRdData(0,i)(7 downto 0);
               end if;
            end loop;
         else
            for i in 0 to 15 loop
               adcFifoWrEn(i)   <= readValid(0) and adcValid(i);
               if testPattern = '0' then
                  adcFifoWrData(i) <= adcData(i);
               else
                  adcFifoWrData(i) <= std_logic_vector(to_unsigned(i,4)) & std_logic_vector(adcCnt);
               end if;
            end loop;
         end if;
      end if;
   end process;

   --Blockrams to reorder data
   --Memory and fifos are reset on system reset or on IDLE state
   memRst <= clearFifos or sysClkRst;
   --Generate logic
   G_RowBuffers : for i in 0 to 15 generate
      G_OversampBuffers : for j in 0 to MAX_OVERSAMPLE-1 generate
         --Write when the ADC block says data is good AND when AcqControl agrees
         adcMemWrEn(j)(i) <= readValid(j) and adcValid(i) when adcStreamMode = '0' else
                             '0';
         --Instantiate memory
         U_RowBuffer : entity work.EpixRowBlockRam
         port map (
            sysClk      => sysClk,
            sysClkRst   => sysClkRst,
            wrReset     => clearFifos,
            wrData      => adcData(i),
            wrEn        => adcMemWrEn(j)(i),
            rdOrder     => adcMemRdOrder(i),
            rdReady     => adcMemRdRdy(j)(i),
            rdStart     => adcMemRdRdy(j)(i),
            overflow    => adcMemOflow(j)(i),
            rdData      => adcMemRdData(j,i),
            dataValid   => adcMemRdValid(j)(i),
            testPattern => testPattern
         );
      end generate;
   end generate;
   --Or of all memory overflow bits
   process(sysClk) 
      variable runningOr : std_logic := '0';
   begin
      if rising_edge(sysClk) then
         runningOr := '0';
         for i in 0 to 15 loop
            for j in 0 to MAX_OVERSAMPLE-1 loop
               runningOr := runningOr or adcMemOflow(j)(i);
            end loop;
         end loop;
         adcMemOflowAny <= runningOr;
      end if;
   end process;
   
   -- Instantiate FIFOs
   G_AdcFifos : for i in 0 to 15 generate
      --Instantiate the FIFOs
      U_AdcFifo : entity work.FifoMux
         generic map(
            WR_DATA_WIDTH_G => 16,
            RD_DATA_WIDTH_G => 32,
            GEN_SYNC_FIFO_G => true,
            ADDR_WIDTH_G    => CH_FIFO_ADDR_WIDTH,
            FWFT_EN_G       => true,
            USE_BUILT_IN_G  => false,
            XIL_DEVICE_G    => "VIRTEX5",
            EMPTY_THRES_G   => 1
         )
         port map(
            rst           => memRst,
            --Write ports
            wr_clk        => sysClk,
            wr_en         => adcFifoWrEn(i),
            din           => adcFifoWrData(i),
            overflow      => adcFifoOflow(i),
            --Read ports
            rd_clk        => sysClk,
            rd_en         => adcFifoRdEn(i),
            dout          => adcFifoRdData(i),
            valid         => adcFifoRdValid(i),
            empty         => adcFifoEmpty(i)
         );
   end generate;
   --Or of all fifo overflow bits
   --And of all fifo empty bits
   process(sysClk) 
      variable runningOr : std_logic := '0';
      variable runningAnd : std_logic := '0';
   begin
      if rising_edge(sysClk) then
         runningOr := '0';
         runningAnd := '1';
         for i in 0 to 15 loop
            runningOr := runningOr or adcFifoOflow(i);
            runningAnd := runningAnd and adcFifoEmpty(i);
         end loop;
         fifoOflowAny <= runningOr;
         fifoEmptyAll <= runningAnd;
      end if;
   end process;

end ReadoutControl;

