-------------------------------------------------------------------------------
-- Title         : Test-bench of CpixLUT unit
-- Project       : Cpix Detector
-------------------------------------------------------------------------------
-- File          : TB_CpixLUT.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 01/19/2016
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/10/2016: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.CpixLUTPkg.all;


entity TB_CpixLUT is 

end TB_CpixLUT;


-- Define architecture
architecture beh of TB_CpixLUT is
   
   constant TPD_G             : time := 1 ns;
   
   signal coreClk  : std_logic;
   signal address  : std_logic_vector(14 downto 0);
   signal dataOut  : std_logic_vector(14 downto 0);
   signal enable   : std_logic;
   

begin
   
   -- clocks and resets
   
   process
   begin
      coreClk <= '0';
      wait for 5 ns;
      coreClk <= '1';
      wait for 5 ns;
   end process;
   
   -- addres counter
   process
   begin
   
      address <= (others=>'0');
      
      wait for 80 ns;
      
      loop
         
         wait until rising_edge(coreClk);
         
         wait for TPD_G;
         assert CPIX_NORMAL_SIM_ARRAY_C(to_integer(unsigned(address))) = unsigned(dataOut) 
            report "Bad memory entry at address " & integer'image(to_integer(unsigned(address))) & ". Expected " & integer'image(CPIX_NORMAL_SIM_ARRAY_C(to_integer(unsigned(address)))) & " got " & integer'image(to_integer(unsigned(dataOut)))
            severity error;
         
         wait until falling_edge(coreClk);
         address <= std_logic_vector(unsigned(address) + 1);
         
         if unsigned(address) = 2**15-1 then
            report "Simulation done. No errors." severity error;
         end if;
         
      end loop;
      
   end process;
   
   -------------------------------------------------------
   -- Look-up Table - unit under test
   -------------------------------------------------------
      
   U_CpixLUT : entity work.CpixLUT
   port map ( 
      sysClk   => coreClk,
      address  => address,
      dataOut  => dataOut,
      enable   => enable
   );
   
   enable <= '1';


end beh;

