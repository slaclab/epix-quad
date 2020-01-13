-------------------------------------------------------------------------------
-- Title      : Version File
-- Project    : ePix Generation 2 Digital Card Firmware
-------------------------------------------------------------------------------
-- File       : Version.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module.
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C    : std_logic_vector(31 downto 0) := x"EA010004"; -- MAKE_VERSION

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
--                          Second byte encodes the analog board version: 01 - gen1, 02 - gen2.
-- 04/10/2015 (0xEA010002): First version of new digital card to be used at LCLS.
-- 05/13/2015 (0xEA010003): Includes PGP op-code triggering for use w/ new PGP card.
-- XX/XX/2015 (0xEA010004): Current working version...
--                          
-------------------------------------------------------------------------------

