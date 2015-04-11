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

constant FPGA_VERSION_C    : std_logic_vector(31 downto 0) := x"EA010003"; -- MAKE_VERSION

constant BUILD_STAMP_C     : string := "EpixDigGen2: Built Mon Mar 16 17:26:54 PDT 2015 by kurtisn";

constant FPGA_BASE_CLOCK_C : std_logic_vector(31 downto 0) := x"00" & x"100000";  

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 02/05/2015 (0x00010000): Initial build on digital card generation 2.  Simple
--                          data tester for PGP with programmable rate and 
--                          packet size.
-- 02/06/2015 (0x00010001): Changed to spi x1 due to some observed programming
--                          issues (turned out to be SPI speed... 
--                                           --> must be < 50 MHz).  
-- 03/30/2015 (0xEA010001): Upper byte of version encodes the ASIC.
-- 04/10/2015 (0xEA010002): First version of new digital card to be used at LCLS.
--                          
-------------------------------------------------------------------------------

