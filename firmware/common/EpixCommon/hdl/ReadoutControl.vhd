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
      dataRead            : in    std_logic;

      -- ADC Data
      adcValid            : in    std_logic_vector(23 downto 0);
      adcData             : in    word16_array(23 downto 0);

      -- Slow ADC data
      slowAdcData         : in    word16_array(15 downto 0);

      -- Data Out
      frameTxIn           : out   UsBuff32InType;
      frameTxOut          : in    UsBuffOutType;

      -- MPS
      mpsOut              : out   std_logic;
   );
end ReadoutControl;

-- Define architecture
architecture ReadoutControl of ReadoutControl is

   -- Local Signals

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin



   -- Outputs
   frameTxIn.frameTxEnable <= '0';
   frameTxIn.frameTxSOF    <= '0';
   frameTxIn.frameTxEOF    <= '0';
   frameTxIn.frameTxEOFE   <= '0';
   frameTxIn.frameTxData   <= (others=>'0');

end ReadoutControl;

