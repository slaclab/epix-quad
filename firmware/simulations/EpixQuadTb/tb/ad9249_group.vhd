-------------------------------------------------------------------------------
-- File       : ad9249_group.vhd
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

entity ad9249_group is 
   generic (
      NO_INPUT_G           : BooleanArray(7 downto 0) := (others=>false);
      NO_INPUT_BASELINE_G  : RealArray(7 downto 0)    := (others=>0.5);
      NO_INPUT_NOISE_G     : RealArray(7 downto 0)    := (others=>10.0e-3);
      USE_PATTERN_G        : BooleanArray(7 downto 0) := (others=>false);
      PATTERN_G            : Slv16Array(7 downto 0)   := (others=>x"2A5A");
      INDEX_G              : natural                  := 0
   );
   port (
      -- Analog Signals
      aInP     : in RealArray(7 downto 0);
      aInN     : in RealArray(7 downto 0);
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
      dP       : out slv(7 downto 0);
      dN       : out slv(7 downto 0)
   );
end ad9249_group;

architecture behav of ad9249_group is

begin
   
   G_AdcModel : for i in 0 to 7 generate 
      U_ADC : entity work.ad9249_model
         generic map (
            NO_INPUT_G           => NO_INPUT_G(i),
            NO_INPUT_BASELINE_G  => NO_INPUT_BASELINE_G(i),
            NO_INPUT_NOISE_G     => NO_INPUT_NOISE_G(i),
            USE_PATTERN_G        => USE_PATTERN_G(i),
            PATTERN_G            => PATTERN_G(i),
            INDEX_G              => INDEX_G*8+i
         )
         port map (
            aInP     => aInP(i),
            aInN     => aInN(i),
            sClk     => sClk,
            dClk     => dClk,
            fcoP     => fcoP,
            fcoN     => fcoN,
            dcoP     => dcoP,
            dcoN     => dcoN,
            dP       => dP(i),
            dN       => dN(i)
         );
   end generate;
   
end behav;
