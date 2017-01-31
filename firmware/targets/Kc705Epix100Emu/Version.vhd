------------------------------------------------------------------------------
-- This file is part of 'Example Project Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Example Project Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package Version is

   constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"EA02000B";

   constant BUILD_STAMP_C : string := "Kc705Epix100Emu: Vivado v2016.2 (x86_64) Built Mon Jan 30 14:35:54 PST 2017 by ruckman";

   constant FPGA_BASE_CLOCK_C : std_logic_vector(31 downto 0) := x"00" & x"100000";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 01/30/2017 (0xEA02000B): Added 150us delay after receiving OP-code trigger before sending packet
-- 01/29/2017 (0xEA02000A): EN_MICROBLAZE_G  = false
-- 01/27/2017 (0xEA020009): AXI_ERROR_RESP_G = AXI_RESP_OK_C
-- 01/26/2017 (0xEA020008): AND Gating the fiber trigger with epixConfig.runTriggerEnable
-- 01/26/2017 (0xEA020007): Added the non-FMC SFP cage to emulate up to 5 EPIX links
-- 01/26/2017 (0xEA020006): Added this functionality:
--                         "An acquisition counter and should clear it when I write to address 6.  
--                          The counter is at address 5." 
-- 01/25/2017 (0xEA020005): Reverted back to version 0x1 then added the following modules
--                          Added RegControl.vhd, which maps to Address = 0x000FFFFF:0x00000000
--                   
-- 01/25/2017 (0x00000002): Sets the register @ address = 0x0 to 0xEA020004
-- 01/25/2017 (0x00000001): Initial Build
--
-------------------------------------------------------------------------------

