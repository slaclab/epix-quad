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

      -- Run control
      readStart           : in    sl;
      readValid           : in    sl;
      readDone            : in    sl;
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

   -- Local Signals
--   signal adcCnt : slv(4 downto 0);
   signal curState       : slv(2 downto 0);
   signal nxtState       : slv(2 downto 0);
   signal wordCnt        : unsigned(31 downto 0);
   signal wordCntRst     : sl;
   signal wordCntEn      : sl;
   signal dataSendEdge   : sl;
   signal readStartEdge  : sl;
   signal adcBuffReg     : slv(31 downto 0);

   -- State machine state definitions
   constant ST_IDLE      : slv(2 downto 0) := "000";
   constant ST_HEADER    : slv(2 downto 0) := "001";
   constant ST_WAIT_ADC  : slv(2 downto 0) := "010";
   constant ST_ADC       : slv(2 downto 0) := "011";
   constant ST_MON_DATA  : slv(2 downto 0) := "100";
   constant ST_TAIL      : slv(2 downto 0) := "101";

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
   process (curState,dataSendEdge) begin
         --Defaults
         frameTxIn.frameTxEnable <= '0' after tpd;
         frameTxIn.frameTxSOF    <= '0' after tpd;
         frameTxIn.frameTxEOF    <= '0' after tpd;
         frameTxIn.frameTxEOFE   <= '0' after tpd;
         frameTxIn.frameTxData   <= (others => '0') after tpd;
         wordCntRst              <= '0';
         wordCntEn               <= '0';
         --State specific outputs
         case curState is
            when ST_IDLE =>
               wordCntRst                 <= '1';
               if (dataSendEdge = '1') then
                  wordCntEn               <= '1';
                  frameTxIn.frameTxData   <= x"01234567";
                  frameTxIn.frameTxSOF    <= '1';
                  frameTxIn.frameTxEnable <= '1';
               end if;
            when ST_ADC =>
               if readDone = '1' then
                  frameTxIn.frameTxData   <= x"BEEFCAFE";
                  frameTxIn.frameTxEnable <= '1';
                  frameTxIn.frameTxEOF    <= '1';
               else
                  frameTxIn.frameTxData   <= x"0000" & adcData(conv_integer(epixConfig.adcChannelToRead(4 downto 0)));
                  frameTxIn.frameTxEnable <= adcValid(conv_integer(epixConfig.adcChannelToRead(4 downto 0))) and readValid;
               end if;
            --Use defaults for uncaught cases
            when others =>
         end case;
   end process;
   --Next state logic
   process (curState) begin
      --Default is to remain in current state
      nxtState <= curState;
      --State specific next-states
      case curState is 
         when ST_IDLE =>
            if dataSendEdge = '1' then
               nxtState <= ST_ADC;
            end if;
         when ST_ADC =>
            if readDone = '1' then
               nxtState <= ST_IDLE;
            end if;
         when others =>
            nxtState <= ST_IDLE;
      end case;
   end process;
   --Transition to next state
   process (sysClk, sysClkRst) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            curState <= ST_IDLE;
         else
            curState <= nxtState;
         end if;
      end if;
   end process;

   --Counts the number of words to choose what data to send next
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wordCntRst = '1' then
            wordCnt <= (others => '0') after tpd;
         elsif wordCntEn = '1' then
            wordCnt <= wordCnt + 1;
         end if; 
      end if; 
   end process;

end ReadoutControl;

