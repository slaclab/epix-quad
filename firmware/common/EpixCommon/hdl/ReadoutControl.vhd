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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
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
      readStart           : in    sl;
      readValid           : in    sl;
      readDone            : out   sl;
      acqBusy             : in    sl;
      dataSend            : in    sl;

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

   -- Depth of FIFO 
   constant CH_FIFO_ADDR_WIDTH : integer := 11;
   constant CH_FIFO_FULL_THRES : integer := 96;

   -- State definitions
   type state is (IDLE_S, 
                  HEADER_S,
                  FILL_FIFO_S,
                  READ_FIFO_S,
                  FOOTER_S);

   -- Local Signals
   signal curState       : state := IDLE_S;
   signal nxtState       : state := IDLE_S;
   signal wordCnt        : unsigned(31 downto 0);
   signal wordCntRst     : sl;
   signal wordCntEn      : sl;
   signal chCnt          : unsigned(3 downto 0);
   signal chCntRst       : sl;
   signal chCntEn        : sl;
   signal fillCnt        : unsigned(CH_FIFO_ADDR_WIDTH-1 downto 0);
   signal fillCntRst     : sl;
   signal fillCntEn      : sl;
   signal dataSendEdge   : sl;
   signal readStartEdge  : sl;
   signal adcBuffReg     : slv(31 downto 0);
   signal adcFifoWrEn    : slv(15 downto 0);
   signal adcFifoEmpty   : slv(15 downto 0);
   signal adcFifoOflow   : slv(15 downto 0);
   signal adcFifoRdEn    : slv(15 downto 0);
   signal adcFifoRdValid : slv(15 downto 0);
   signal adcFifoRdData  : Slv32Array(15 downto 0);
   signal adcFifoRdRdy   : slv(15 downto 0);

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
         dataIn     => readStart,
         risingEdge => readStartEdge
      );


   -- Outputs
   -- Default mps to '0' for now.
   mpsOut <= '0';

   --------------------------------------------------
   -- Simple state machine to just send ADC values --
   --------------------------------------------------
   process (curState,adcFifoRdData,chCnt,adcFifoRdValid,fillCnt,wordCnt) begin
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
         fillCntRst              <= '0' after tpd;
         fillCntEn               <= '0' after tpd;
         adcFifoRdEn             <= (others => '0') after tpd;
         readDone                <= '0' after tpd;
         --State specific outputs
         case curState is
            when IDLE_S =>
               wordCntRst <= '1' after tpd;
            when HEADER_S =>
               wordCntEn               <= '1' after tpd;
               frameTxIn.frameTxEnable <= '1' after tpd;
               chCntRst                <= '1' after tpd;
               fillCntRst              <= '1' after tpd;
               case conv_integer(wordCnt) is
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
            when FILL_FIFO_S => 
               fillCntRst <= '1' after tpd;
            when READ_FIFO_S =>
               frameTxIn.frameTxData <= adcFifoRdData(conv_integer(chCnt)) after tpd;
               --frameTxIn.frameTxData <= x"000" & std_logic_vector(chCnt) & "00000" & std_logic_vector(fillCnt) after tpd;
               if (adcFifoRdValid(conv_integer(chCnt)) = '1') then
                  fillCntEn <= '1' after tpd;
                  frameTxIn.frameTxEnable <= adcFifoRdValid(conv_integer(chCnt)) after tpd;
               end if;
               if (conv_integer(fillCnt) < CH_FIFO_FULL_THRES/2-1) then
                  adcFifoRdEn(conv_integer(chCnt)) <= '1' after tpd;
               else
                  chCntEn    <= '1' after tpd;
                  fillCntRst <= '1' after tpd;
               end if;
            when FOOTER_S    =>
               readDone <= '1' after tpd;
               frameTxIn.frameTxData   <= cZeroWord after tpd;
               frameTxIn.frameTxEnable <= '1' after tpd; 
               frameTxIn.frameTxEOF    <= '1' after tpd;
               frameTxIn.frameTxEOFE   <= '0' after tpd; --TEMPORARY... IMPLEMENT ME!
            --Use defaults for uncaught cases
            when others =>
         end case;
   end process;
   --Next state logic
   process (curState,readStartEdge,wordCnt,adcFifoRdRdy,fillCnt,chCnt,acqBusy) begin
      --Default is to remain in current state
      nxtState <= curState after tpd;
      --State specific next-states
      case curState is 
         when IDLE_S =>
            if readStartEdge = '1' then
               nxtState <= HEADER_S after tpd;
            end if;
         when HEADER_S =>
            if (wordCnt = 7) then
               nxtState <= FILL_FIFO_S after tpd;
            end if;
         when FILL_FIFO_S =>
            if adcFifoRdRdy(conv_integer(chCnt)) = '1' then
               nxtState <= READ_FIFO_S after tpd;
            elsif acqBusy = '0' and adcFifoEmpty = x"0000" then
               nxtState <= FOOTER_S after tpd;
            end if;
         when READ_FIFO_S =>
            if (conv_integer(fillCnt) = CH_FIFO_FULL_THRES/2-1) then
               nxtState <= FILL_FIFO_S after tpd;
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

   G_AdcFifos : for i in 0 to 15 generate
      --Write when the ADC block says data is good AND when AcqControl agrees
      adcFifoWrEn(i) <= readValid and adcValid(i) after tpd;
      --Instantiate the FIFOs
      U_AdcFifo : entity work.FifoMux
         generic map(
            WR_DATA_WIDTH_G => 16,
            RD_DATA_WIDTH_G => 32,
            GEN_SYNC_FIFO_G => true,
            ADDR_WIDTH_G    => CH_FIFO_ADDR_WIDTH,
            FULL_THRES_G    => CH_FIFO_FULL_THRES/2,
            FWFT_EN_G       => false,
            USE_BUILT_IN_G  => false,
            XIL_DEVICE_G    => "VIRTEX5",
            EMPTY_THRES_G   => 1
         )
         port map(
            rst           => sysClkRst,
            --Write ports
            wr_clk        => sysClk,
            wr_en         => adcFifoWrEn(i),
            din           => adcData(i),
            wr_ack        => open,
            overflow      => adcFifoOflow(i),
            prog_full     => adcFifoRdRdy(i),
            almost_full   => open,
            full          => open,
            --Read ports
            rd_clk        => sysClk,
            rd_en         => adcFifoRdEn(i),
            dout          => adcFifoRdData(i),
            valid         => adcFifoRdValid(i),
            underflow     => open,
            prog_empty    => open,
            almost_empty  => open,
            empty         => adcFifoEmpty(i)
         );
   end generate;


end ReadoutControl;

