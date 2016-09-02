-------------------------------------------------------------------------------
-- Title         : Version Constant File
-- Project       : COB Zynq DTM
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/07/2013
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module
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

constant FpgaVersion : std_logic_vector(31 downto 0) := x"E0000015"; -- MAKE_VERSION
--constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"125000";  
constant FpgaBaseClock : std_logic_vector(31 downto 0) := x"00" & x"100000";
-- FPGA base clock (used for calculating various delay units)
-- Top two nybbles reserved
-- Bottom 6 nybbles are base clock rate in kHz (binary coded decimal)

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--            (0xE0000004): Version used for original ASIC characterization.
-- 11/05/2013 (0xE0000005): First version that supports "final" readout format.
-- 11/15/2013 (0xE0000006): Added "BaseClock" register at 0x000010.  Turned off 
--                          DAC SPI clock when not in use to reduce ADC noise.
-- 12/03/2013 (0xE0000007): Modified trig_out behavior so something is still 
--                          sent out when in ADC stream mode.
-- 12/16/2013 (0xE0000008): Modified readout control for SSRL ePix test.
--                          Words 1 and 2 of the "TPS" data now come from
--                          the slow ADC thermistor channels rather than ASICs.
-- 12/17/2013 (0xE0000009): Added asicMask register at 0xD.  This register is 
--                          used to control which ASICs get a SACI "prepare 
--                          for readout.  This should reduce dead time waiting
--                          for ASICs that aren't present.
-- 01/14/2014 (0xE000000A): Fixed a "counting by 1" issue for asicRoClk. 
--                          Improved SACI timeout logic so that various
--                          frequencies can be used without screwing up the 
--                          timeout logic. 
-- 03/12/2014 (0xE000000D): Last stable version before adding oscilloscope
--                          functionality on VC 2.
-- 04/08/2014 (0xE000000F): Adds two fake rows to readout for env. data.
--       2014 (0xE0000012): Version used for beam tests through July.
-- 07/22/2014 (0xE0000013): Migrated to Vclib and cleaned up ReadoutControl.
--                          This fixed the spurious startup issue.
-- 07/29/2014 (0xE0000014): Ramped up to 50 MSPS.  Added tristates for 
--                          FPGA outputs for ease of power sequencing.
--                          Added IDELAYs for all ADC signals and offset 
--                          constraints to improve data quality/reproducibility.
-------------------------------------------------------------------------------

