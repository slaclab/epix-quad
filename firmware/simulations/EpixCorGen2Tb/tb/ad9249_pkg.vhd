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

package ad9249_pkg is
   
   
   type OutType is (
      AIN_OUT,
      NOISE_OUT,
      PATTERN_OUT,
      COUNT_OUT
   );
   
   type OutTypeArray  is array (natural range <>) of OutType;
   
end ad9249_pkg;

