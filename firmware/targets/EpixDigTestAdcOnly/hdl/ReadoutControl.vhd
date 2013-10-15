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

library ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.EpixTypes.all;
use work.Pgp2AppTypesPkg.all;

entity ReadoutControl is
   port (
      -- Clocks and reset
      sysClk      : in  sl;
      sysClkRst   : in  sl;
      -- Configuration
      epixConfig  : in  EpixConfigType;
      -- Run control
      readStart   : in  sl;
      readValid   : in  sl;
      readDone    : in  sl;
      dataSend    : in  sl;
      -- ADC Data
      adcValid    : in  slv(19 downto 0);
      adcData     : in  word16_array(19 downto 0);
      -- Slow ADC data
      slowAdcData : in  word16_array(15 downto 0);
      -- Data Out
      frameTxIn   : out UsBuff32InType;
      frameTxOut  : in  UsBuff32OutType;
      -- MPS
      mpsOut      : out sl);
end ReadoutControl;

-- Define architecture
architecture ReadoutControl of ReadoutControl is
   type StateType is (
      IDLE_S,
      FAST_DATA_S,
      SLOW_DATA_S,
      STOP_S);
   signal state        : StateType             := IDLE_S;
   signal dataSendEdge : sl;
   signal chPntr       : integer range 0 to 19 := 0;

begin
   -- Default mps to '0' for now.
   mpsOut <= '0';

   -- Edge detection for signals that interface with other blocks
   U_DataSendEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => dataSend,
         risingEdge => dataSendEdge);

   process (sysClk)
   begin
      if rising_edge(sysClk) then
         frameTxIn.frameTxEnable <= '0';
         frameTxIn.frameTxSOF    <= '0';
         frameTxIn.frameTxEOF    <= '0';
         frameTxIn.frameTxEOFE   <= '0';
         if sysClkRst = '1' then
            chPntr    <= 0;
            frameTxIn <= UsBuff32InInit;
            state     <= IDLE_S;
         elsif (frameTxOut.frameTxAfull = '0') then
            case (state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  --wait for a trigger
                  if dataSendEdge = '1' then
                     frameTxIn.frameTxEnable <= '1';
                     frameTxIn.frameTxSOF    <= '1';
                     frameTxIn.frameTxData   <= x"BABECAFE";  --start header
                     state                   <= FAST_DATA_S;
                  end if;
                  ----------------------------------------------------------------------
               when FAST_DATA_S =>
                  if adcValid(chPntr) = '1' then
                     frameTxIn.frameTxEnable <= '1';
                     frameTxIn.frameTxData   <= x"0000" & adcData(chPntr);
                     chPntr                  <= chPntr + 1;
                     if chPntr = 19 then
                        chPntr <= 0;
                        state  <= SLOW_DATA_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when SLOW_DATA_S =>
                  frameTxIn.frameTxEnable <= '1';
                  frameTxIn.frameTxData   <= x"0000" & slowAdcData(chPntr);
                  chPntr                  <= chPntr + 1;
                  if chPntr = 15 then
                     chPntr <= 0;
                     state  <= STOP_S;
                  end if;
                  ----------------------------------------------------------------------
               when STOP_S =>
                  frameTxIn.frameTxEnable <= '1';
                  frameTxIn.frameTxEOF    <= '1';
                  frameTxIn.frameTxData   <= x"BEEFCAFE";  --stop header             
                  state                   <= IDLE_S;
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

end ReadoutControl;

