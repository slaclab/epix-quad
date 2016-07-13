-------------------------------------------------------------------------------
-- Title         : Version File
-- Project       : ePix10kp Generation 2 Digital and Analog Card Firmware
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 07/12/2016
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 07/12/2016: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C    : std_logic_vector(31 downto 0) := x"E2020000"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "Epix10kp: Vivado v2016.1 (x86_64) Built Tue Jul 12 17:33:33 PDT 2016 by mkwiatko";

constant FPGA_BASE_CLOCK_C : std_logic_vector(31 downto 0) := x"00" & x"100000";  

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 07/12/2016 (0xE2020000): Upper byte of version encodes the ASIC: xE2 - Epix10kp, 
--                          second byte encodes the analog board version: 01 - gen1, 02 - gen2
--                          Initial build on digital and analog cards generation 2
-------------------------------------------------------------------------------

