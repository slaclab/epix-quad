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

constant FpgaVersion : std_logic_vector(31 downto 0) := x"EA00000C"; -- MAKE_VERSION
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"100000";  
-- FPGA base clock (used for calculating various delay units)
-- Top two nybbles reserved
-- Bottom 6 nybbles are base clock rate in kHz (binary coded decimal)

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--            (0xEA000000): Version used for original ASIC characterization.
--                          Forked from 100p version (0xE000013)
--            (0xEA000002): Version compatible with carrier rev C01
--            (0xEA000003): Intermediate test version while
--                          adding multi pixel write commands.
--            (0xEA00000B): Version used at LCLS/SSRL user workshop 2014.
--                          Working quad-pixel writes.  Autocalibration upon
--                          startup.
-------------------------------------------------------------------------------

