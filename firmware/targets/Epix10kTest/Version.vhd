-------------------------------------------------------------------------------
-- Title         : Version Constant File
-- Project       : Epix 10k Test
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Kurtis Nishimura
-- Created       : 02/07/2013
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module
-------------------------------------------------------------------------------
-- Copyright (c) 2012 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FpgaVersion : std_logic_vector(31 downto 0) := x"E2000001"; -- MAKE_VERSION
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"125000";  
-- FPGA base clock (used for calculating various delay units)
-- Top two nybbles reserved
-- Bottom 6 nybbles are base clock rate in kHz (binary coded decimal)

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 02/07/2014 (0xE2000000): First version for testing epix10k_p
--                          Note E2 prefix is for this project
--                               E1 is used by SDD
--                               E0 is for epix100_p
-- 03/06/2014 (0xE2000001): Added adjustable TPS sampling point
-------------------------------------------------------------------------------

