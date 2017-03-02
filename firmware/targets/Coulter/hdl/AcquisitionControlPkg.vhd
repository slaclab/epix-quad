-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AcquisitionControlPkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-22
-- Last update: 2017-03-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AcquisitionControlPkg is

   type AcquisitionStatusType is record
      trigger        : sl;
      adcWindow      : sl;
      adcWindowStart : sl;
      adcWindowEnd   : sl;
      adcLast        : sl;
      mckPulse       : sl;
      scFall         : sl;
      cfgMckCount    : slv(7 downto 0);
   end record AcquisitionStatusType;

   constant ACQUISITION_STATUS_INIT_C : AcquisitionStatusType := (
      trigger        => '0',
      adcWindow      => '0',
      adcWindowStart => '0',
      adcWindowEnd   => '0',
      adcLast        => '0',
      mckPulse       => '0',
      scFall         => '0',
      cfgMckCount    => (others => '0'));

end package AcquisitionControlPkg;
