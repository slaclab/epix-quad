-------------------------------------------------------------------------------
-- Title         : EPIX Project Types
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : EpixTypes.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/14/2013
-------------------------------------------------------------------------------
-- Description:
-- Epix Project Types
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/13/2013: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package EpixTypes is

   subtype WORD16 is STD_LOGIC_VECTOR (15 downto 0);
   type word16_array is array ( NATURAL range <> ) of WORD16;

   subtype WORD8 is STD_LOGIC_VECTOR (7 downto 0);
   type word8_array is array ( NATURAL range <> ) of WORD8;

   subtype WORD7 is STD_LOGIC_VECTOR (6 downto 0);
   type word7_array is array ( NATURAL range <> ) of WORD7;

   subtype WORD6 is STD_LOGIC_VECTOR (5 downto 0);
   type word6_array is array ( NATURAL range <> ) of WORD6;

end EpixTypes;

