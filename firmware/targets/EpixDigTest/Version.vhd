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

constant FpgaVersion : std_logic_vector(31 downto 0) := x"E0000005"; -- MAKE_VERSION

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--            (0xE0000004): Version used for original ASIC characterization.
-- 11/05/2013 (0xE0000005): First version that supports "final" readout format.
-------------------------------------------------------------------------------

