-------------------------------------------------------------------------------
-- Title         : Version Constant File
-- Project       : COB Zynq DTM
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/07/2013
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module
-------------------------------------------------------------------------------
-- Copyright (c) 2012 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FpgaVersion : std_logic_vector(31 downto 0) := x"E1000001"; -- MAKE_VERSION
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"200000";  
-- FPGA base clock (used for calculating various delay units)
-- Top two nybbles reserved
-- Bottom 6 nybbles are base clock rate in kHz (binary coded decimal)

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 05/07/2013 (0xDC000001): Initial Version
-------------------------------------------------------------------------------

