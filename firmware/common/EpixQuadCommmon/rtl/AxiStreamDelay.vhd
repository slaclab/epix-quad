-------------------------------------------------------------------------------
-- File       : AxiStreamDelay.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-16
-- Last update: 2016-06-16
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamDelay is
   generic (
      TPD_G         : time                 := 1 ns;
      AXIS_CONFIG_G : AxiStreamConfigType  := AXI_STREAM_CONFIG_INIT_C
   );
   port (

      -- Clock and reset
      axisClk     : in  sl;
      axisRst     : in  sl;

      -- Delay
      delay       : in  slv(31 downto 0);

      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
   );
end AxiStreamDelay;

architecture rtl of AxiStreamDelay is

   type StateType is ( IDLE_S, MOVE_S, DELAY_S );

   type RegType is record
      state    : StateType;
      delay    : slv(31 downto 0);
      obMaster : AxiStreamMasterType;
      ibSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => IDLE_S,
      delay    => (others=>'0'),
      obMaster => axiStreamMasterInit(AXIS_CONFIG_G),
      ibSlave  => AXI_STREAM_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (mAxisSlave, sAxisMaster, axisRst, delay, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.ibSlave.tReady := '0';
      v.obMaster := AXI_STREAM_MASTER_INIT_C;

      case r.state is

         -- Wait for frame
         when IDLE_S =>
            if sAxisMaster.tValid = '1' and mAxisSlave.tReady = '1' then
               v.delay := (others=>'0');
               v.state := DELAY_S;
            end if;
         
         -- Delay frame
         when DELAY_S =>
            if r.delay >= delay then
               v.delay := (others=>'0');
               v.state := MOVE_S;
            else
               v.delay := r.delay + 1;
            end if;
         
         -- Moving data 
         when MOVE_S =>
            v.ibSlave.tReady := mAxisSlave.tReady;

            v.obMaster := sAxisMaster;
            v.obMaster.tValid := sAxisMaster.tValid and mAxisSlave.tReady;

            -- End of frame
            if sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' then
               v.state := IDLE_S;
            end if;

         when others =>
            v.state := IDLE_S;

      end case;
      
      -- Combinatorial outputs before the reset
      sAxisSlave <= v.ibSlave;

      -- Reset
      if axisRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Registered Outputs
      mAxisMaster <= r.obMaster;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
