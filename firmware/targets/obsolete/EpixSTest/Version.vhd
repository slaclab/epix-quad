-------------------------------------------------------------------------------
-- Title         : Version Constant File
-- Project       : EpixS
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 10/09/2014
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FpgaVersion : std_logic_vector(31 downto 0) := x"E300000A"; -- MAKE_VERSION
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"100000";  
-- FPGA base clock (used for calculating various delay units)
-- Top two nybbles reserved
-- Bottom 6 nybbles are base clock rate in kHz (binary coded decimal)

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--            (0xE3000000): Version used for original ASIC characterization.
--                          Forked from 100a version (0xEA0000B)
--            (0xE3000003): New version that reads out only active ADC channels.
--                          So it should give a 100x100 image.
--                          (+calib and env rows)
--            (0xE3000009): As above with some fixes to writing the matrix.
--                          And had some mismapped channels as well. 
-------------------------------------------------------------------------------

