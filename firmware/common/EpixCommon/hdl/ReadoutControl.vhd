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
library UNISIM;
use UNISIM.vcomponents.all;

entity ReadoutControl is
   port (

      -- Clocks and reset
      sysClk              : in    std_logic;
      sysClkRst           : in    std_logic;

      -- Configuration
      epixConfig          : in    EpixConfigType;

      -- Run control
      readStart           : in    std_logic;
      dataSend            : in    std_logic;

      -- ADC Data
      adcValid            : in    std_logic_vector(19 downto 0);
      adcData             : in    word16_array(19 downto 0);

      -- Slow ADC data
      slowAdcData         : in    word16_array(15 downto 0);

      -- Data Out
      frameTxIn           : out   UsBuff32InType;
      frameTxOut          : in    UsBuffOutType;

      -- MPS
      mpsOut              : out   std_logic
   );
end ReadoutControl;

-- Define architecture
architecture ReadoutControl of ReadoutControl is

   -- Local Signals
   signal adcCnt : std_logic_vector(4 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   process ( sysCLk, sysClkRst ) begin
      if sysClkRst = '1' then
         adcCnt <= (others=>'0') after tpd;
      elsif rising_edge(sysClk) then
         if adcCnt = 19 then
            adcCnt <= (others=>'0') after tpd;
         else
            adcCnt <= adcCnt + 1 after tpd;
         end if;
      end if;
   end process;

   -- Outputs
   frameTxIn.frameTxEnable <= '0';
   frameTxIn.frameTxSOF    <= adcValid(conv_integer(adcCnt));
   frameTxIn.frameTxEOF    <= '0';
   frameTxIn.frameTxEOFE   <= '0';
   frameTxIn.frameTxData   <= x"0000" & adcData(conv_integer(adcCnt));

   mpsOut <= '0';

end ReadoutControl;

