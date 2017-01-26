-------------------------------------------------------------------------------
-- Title         : Version File
-- Project       : Coulter
-------------------------------------------------------------------------------
-- File          : Version.vhd
-- Author        : Benjamin Reese <bareese@slac.stanford.edu>
-- Created       : 09/30/2015
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
-- Modification history:
-- 09/30/2015: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package Version is

   constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"0000000C";  -- MAKE_VERSION

   constant BUILD_STAMP_C : string := "Coulter: Vivado v2016.3 (x86_64) Built Wed Jan 25 14:56:53 PST 2017 by bareese";

end Version;

-------------------------------------------------------------------------------
-- Revision History:

-- 0000000C - It works again after not for a while!
-- 00000009 - 2.5 Gbps fixed latency works!.
-- 00000008 - Add MMCM on tx and use refclk. Still var lat. Doesn't work
-- 00000007 - Var latency 2.5 Gbps
-- 00000004 - Fixed Latency Pgp - Rx doesn't work
-- 00000003 - Try to make Pgp2bAxi.txFrameCount work. (It was a software bug)
-- 00000002 - Most peripherals work. Haven't tried ASIC config yet.
-- 00000000 - First version that software could talk to. Much broken.

-------------------------------------------------------------------------------

