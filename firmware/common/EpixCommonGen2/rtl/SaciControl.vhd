-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : SaciControl.vhd
-- Author     : Kurtis Nishimura  <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-25
-- Last update: 2015-03-25
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Arbiter and state machines to handle multiple SACI
--              request sources.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

LIBRARY ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.SaciMasterPkg.all;

entity SaciControl is
   generic (
      TPD_G        : time := 1 ns;
      NUM_ASICS_G  : natural range 1 to 8 := 4;
   );
   port (
      
   );
end SaciControl;

architecture rtl of SaciControl is

begin

end rtl;

