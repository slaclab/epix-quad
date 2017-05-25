------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity TB_Tixel_8b10b is 

end TB_Tixel_8b10b;


-- Define architecture
architecture beh of TB_Tixel_8b10b is

   signal slowClk :      std_logic;
   signal fastClk :      std_logic;
   signal slowRst :      std_logic;
   
   constant dataInVec   : std_logic_vector(39 downto 0) := "1100000101" & "0101010101" & "0011111010" & "0101010101";
   signal dataInP       : std_logic;
   signal dataInM       : std_logic;
   signal dataInCnt     : integer range 0 to 39;
   constant dataInStart : integer := 19;
   
   
   signal dataOut  : std_logic_vector(7 downto 0);
   signal dataKOut : std_logic_vector(0 downto 0);
   signal codeErr  : std_logic_vector(0 downto 0);
   signal dispErr  : std_logic_vector(0 downto 0);

begin

   -- parallel/slow clock process
   process
   begin
      slowClk <= '0';
      wait for 10 ns;
      slowClk <= '1';
      wait for 10 ns;
   end process;
   
   -- serial/fast clock process
   process
   begin
      fastClk <= '0';
      wait for 2 ns;
      fastClk <= '1';
      wait for 2 ns;
   end process;
   
   -- slowClk reset process
   process
   begin
      slowRst <= '1';
      wait for 20 ns;
      slowRst <= '0';
      wait;
   end process;
   
   process
   begin
   
      dataInCnt <= dataInStart;
      
      wait for 1 ns;
      
      loop
      
         if dataInCnt > 0 then
            dataInCnt <= dataInCnt - 1;
         else
            dataInCnt <= 39;
         end if;
         
         wait for 2 ns;
         
      end loop;
      
   end process;
   
   dataInP <= dataInVec(dataInCnt);
   dataInM <= not dataInVec(dataInCnt);
   
   
   --DUT
   Dut_i: entity work.Deserializer
   generic map (
      IDELAYCTRL_FREQ_G => 200.0
   )
   port map ( 
      byteClkRst     => slowRst,
      byteClk     => slowClk,
      bitClk     => fastClk,
      asicDoutP   => dataInP,
      asicDoutM   => dataInM,
      patternCnt  => open,
      testDone    => open,
      inSync     => open,
      dataOut       => open,
      dataKOut      => open,
      codeErr       => open,
      dispErr       => open,
      resync      => '0',
      delay       => "00000"
   );


end beh;

