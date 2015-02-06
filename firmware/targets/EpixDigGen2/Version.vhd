-------------------------------------------------------------------------------
-- Title         : Version File
-- Project       : ePix Generation 2 Digital Card Firmware
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 02/05/2015
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by SLAC National Accelerator Laboratory. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/05/2015: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"00010001"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "EpixDigGen2: Built Thu Feb  5 10:36:44 PST 2015 by kurtisn";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 02/05/2015 (0x00010000): Initial build on digital card generation 2.  Simple
--                          data tester for PGP with programmable rate and 
--                          packet size.
-------------------------------------------------------------------------------

