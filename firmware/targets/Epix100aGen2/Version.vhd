-------------------------------------------------------------------------------
-- Title         : Version File
-- Project       : ePix Generation 2 Digital and Analog Card Firmware
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 09/30/2015
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
-- 09/30/2015: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C    : std_logic_vector(31 downto 0) := x"EA020004"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "Epix100aGen2: Vivado v2016.1 (x86_64) Built Mon Jul 25 10:21:39 PDT 2016 by mkwiatko";

constant FPGA_BASE_CLOCK_C : std_logic_vector(31 downto 0) := x"00" & x"100000";  

end Version;

-------------------------------------------------------------------------------
-- Revision History:
-- 09/30/2015 (0xEA020000): Upper byte of version encodes the ASIC, 
--                          second byte encodes the analog board version: 01 - gen1, 02 - gen2
--                          Initial build on digital and analog cards generation 2
-- 09/30/2015 (0xEA020001): First release of the EPIX100a firmware for the analog card gen2
-- 02/23/2016 (0xEA020002): Fixed SACI reliability issues, ADC wrong default encoding, carier ID readout. 
--                          Removed unused ASIC sync modes fixed random packet without data.
-- 06/03/2016 (0xEA020003): Reduced SACI clock to 4.5MHz to avoid matrix setup issues
-- 07/08/2016 (0xEA020004): Added optical/TTL trigger switch into the register space
--                          Added monitoring data output stream via PGP VC3 and enable/disable input command on the same VC3
--                          Added FPGA flash programming over the PGP
--                          Old non AXIL components replaced by the new AXIL components
--                          Picoblaze replaced by Microblaze with AXIL log memory
-- 07/08/2016 (0xEA020005): New working copy version number (change date when released)
--               
-------------------------------------------------------------------------------

