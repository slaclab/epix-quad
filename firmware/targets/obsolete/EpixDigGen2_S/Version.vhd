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

constant FPGA_VERSION_C    : std_logic_vector(31 downto 0) := x"E3010001"; -- MAKE_VERSION

constant BUILD_STAMP_C     : string := "EpixDigGen2: Built Mon Mar 16 17:26:54 PDT 2015 by kurtisn";

constant FPGA_BASE_CLOCK_C : std_logic_vector(31 downto 0) := x"00" & x"100000";  

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 05/04/2015 (0xE3010000): Migrated from 100A version 3.
-- 06/17/2015 (0xE3010001): Recompiling to pick up fixes to ASIC register i/f.
-------------------------------------------------------------------------------

