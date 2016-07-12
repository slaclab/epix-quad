-------------------------------------------------------------------------------
-- Title         : Version File
-- Project       : Tixel Prototype Firmware
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 02/05/2015
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by SLAC National Accelerator Laboratory. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/01/2015: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C    : std_logic_vector(31 downto 0) := x"EB010002"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "TixelP: Vivado v2016.1 (x86_64) Built Mon Jul 11 17:42:26 PDT 2016 by mkwiatko";

constant FPGA_BASE_CLOCK_C : std_logic_vector(31 downto 0) := x"00" & x"100000";  

end Version;



