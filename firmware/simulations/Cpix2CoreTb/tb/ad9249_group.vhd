-------------------------------------------------------------------------------
-- File       : ad9249_group.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AD9249 simulation model
-- The analog input is simplified. There is no VCM, Vref or analog input constraints. 
-- Only the analog span is limited to 2.0 as in the real device
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

use work.ad9249_pkg.all;

entity ad9249_group is 
   generic (
      OUTPUT_TYPE_G        : OutTypeArray(7 downto 0) := (others=>AIN_OUT);
      NOISE_BASELINE_G     : RealArray(7 downto 0)    := (others=>0.5);
      NOISE_VPP_G          : RealArray(7 downto 0)    := (others=>10.0e-3);
      PATTERN_G            : Slv16Array(7 downto 0)   := (others=>x"2A5A");
      COUNT_UP             : BooleanArray(7 downto 0) := (others=>true);
      COUNT_MIN_G          : Slv16Array(7 downto 0)   := (others=>x"0000");
      COUNT_MAX_G          : Slv16Array(7 downto 0)   := (others=>x"3FFF");
      COUNT_MASK_G         : Slv16Array(7 downto 0)   := (others=>x"0000");
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
            OUTPUT_TYPE_G     => OUTPUT_TYPE_G(i),
            NOISE_BASELINE_G  => NOISE_BASELINE_G(i),
            NOISE_VPP_G       => NOISE_VPP_G(i),
            PATTERN_G         => PATTERN_G(i),
            COUNT_UP          => COUNT_UP(i),
            COUNT_MIN_G       => COUNT_MIN_G(i),
            COUNT_MAX_G       => COUNT_MAX_G(i),
            COUNT_MASK_G      => COUNT_MASK_G(i),
            INDEX_G           => INDEX_G*8+i
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
