-------------------------------------------------------------------------------
-- Title         : Version Constant File
-- Project       : Epix 100A
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 07/03/2014
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FpgaVersion : std_logic_vector(31 downto 0) := x"EA000000"; -- MAKE_VERSION
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"125000";  
-- FPGA base clock (used for calculating various delay units)
-- Top two nybbles reserved
-- Bottom 6 nybbles are base clock rate in kHz (binary coded decimal)

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--            (0xEA000000): Version used for original ASIC characterization.
--                          Forked from 100p version (0xE000013)
-------------------------------------------------------------------------------

