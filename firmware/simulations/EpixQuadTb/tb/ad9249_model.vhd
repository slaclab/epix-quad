-------------------------------------------------------------------------------
-- File       : ad9249_model.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-05
-- Last update: 2017-07-06
-------------------------------------------------------------------------------
-- Description: AD9249 simulation model
-- The analog input is simplified. There is no VCM, Vref or analog input constraints. 
-- Only the analog span is limited to 2.0 as in the real device
-------------------------------------------------------------------------------
-- This file is part of 'EPIX'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

use work.StdRtlPkg.all;

entity ad9249_model is 
   generic (
      NO_INPUT_G           : boolean         := false;
      NO_INPUT_BASELINE_G  : real            := 0.5;
      NO_INPUT_NOISE_G     : real            := 10.0e-3;
      INDEX_G              : natural         := 0
   );
   port (
      -- Analog Signals
      aInP     : in real;
      aInN     : in real;
      -- Sampling clock
      sClk     : in  sl;
      -- Data Output Clock
      -- Should be 7x Sampling Clock
      dClk     : in  sl;
      -- Digital Signals
      fcoP     : out sl;
      fcoN     : out sl;
      dcoP     : out sl;
      dcoN     : out sl;
      dP       : out sl;
      dN       : out sl
   );
end ad9249_model;

architecture behav of ad9249_model is
   
   constant TFCO_C            : time      := 2.3 ns;
   constant DCLK_C            : time      := 0.7 ns;
   constant SAMPLE_PIPELINE_C : integer   := 16;
   signal digPipe             : Slv14Array(SAMPLE_PIPELINE_C downto 0) := (others=>(others=>'0'));
   signal fco                 : sl;
   signal dIndex              : integer   := 13;
   signal pipeEn              : sl        := '0';

begin
   
   -----------------------------------------------------------------------
   -- sampling process
   -----------------------------------------------------------------------
   process
      variable aIn            : real := 0.0;
      variable digVal         : slv(13 downto 0) := (others=>'0');
      constant digMax         : real := real(2**14-1);
      variable seed1          : positive := 2342*(INDEX_G+1);
      variable seed2          : positive := 5232*(INDEX_G+1);
      variable aInNoise       : real := 0.0;
      
   begin
      
      wait until pipeEn = '1';
      
      loop
      
         -- wait until rising edge
         wait until rising_edge(fco);
         
         if NO_INPUT_G = false then 
            -- store difference (-1.0 to 1.0)
            aIn := aInP - aInN;
            if aIn > 1.0 then
               aIn := 1.0;
            elsif aIn < -1.0 then
               aIn := -1.0;
            end if;
            
            -- shift input to positive (0.0 to 2.0)
            aIn := aIn + 1.0;
            
         else
            -- random input noise 0.0 to 1.0  
            uniform(seed1, seed2, aInNoise);
            -- scale the noise
            aInNoise := aInNoise * NO_INPUT_NOISE_G - NO_INPUT_NOISE_G/2.0;
            -- set input to baseline + noise
            aIn := aInNoise + NO_INPUT_BASELINE_G;
            -- limit to the Vpp span
            if aIn > 2.0 then
               aIn := 2.0;
            elsif aIn < 0.0 then
               aIn := 0.0;
            end if;
            
         end if;
         
         -- digitize (offset binary mode)
         digVal := toSlv(integer(aIn*digMax/2.0), 14);
         
         -- shift into pipeline
         digPipe <= digPipe(SAMPLE_PIPELINE_C-1 downto 0) & digVal;
         
         -- wait until falling edge 
         wait until falling_edge(fco);
      
      end loop;
      
   end process;
   
   -------------------------------------------------------------------------
   ---- data shift out processes
   -------------------------------------------------------------------------
   
   dcoP <= dClk;
   dcoN <= not dClk;
   fcoP <= fco;
   fcoN <= not fco;
   
   -- frame clock process
   process
      
   begin
      
      fco <= '0';
      
      loop
         
         -- wait until rising edge of the sClk
         wait until rising_edge(sClk);
         
         wait for TFCO_C;
         fco <= '1';
         
         -- wait until falling edge of the sClk
         wait until falling_edge(sClk);
         
         wait for TFCO_C;
         fco <= '0';
         
      end loop;
      
   end process;
   
   -- serial data out index process
   
   process
      
   begin
   
      pipeEn <= '0';
      
      wait until rising_edge(fco);
      wait until dClk'event;
      wait until rising_edge(fco);
      wait until dClk'event;
      wait until rising_edge(fco);
      wait until dClk'event;
      wait until rising_edge(fco);
      wait until dClk'event;
      
      pipeEn <= '1';
      
      FCLK_loop: loop
         wait until rising_edge(fco);
         dIndex <= 13;
         
         
         DCLK_Loop: loop
         
            wait until dClk'event;
            wait for DCLK_C;
            dIndex <= dIndex - 1;
            
            exit DCLK_Loop when dIndex = 1;
         
         end loop;
         
      end loop;
      
   end process;
   
   -- serial data out
   dP <= digPipe(SAMPLE_PIPELINE_C)(dIndex);
   dN <= not digPipe(SAMPLE_PIPELINE_C)(dIndex);
   
   
end behav;
