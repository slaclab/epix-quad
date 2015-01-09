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

constant FpgaVersion : std_logic_vector(31 downto 0) := x"E2000009"; -- MAKE_VERSION
--constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"125000";  
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"100000";  
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
--       2014 (0xE2000003): Version used for beam tests through July.
-- 07/22/2014 (0xE2000004): Migrated to Vclib and cleaned up ReadoutControl.
-- 07/23/2014 (0xE2000005): New version with 100 MHz core clock to try 50 MSPS
--                          ADC sampling.  Turned on LVDS DIFF_TERM.
-- 07/24/2014 (0xE2000006): As above with LVDS DIFF_TERM off.
--                      7 : Readded DIFF_TERM, commented out ADC0A,B inputs
--                          for probe checks.
--                      8 : Added timing constraints for adc clocks.
-------------------------------------------------------------------------------

