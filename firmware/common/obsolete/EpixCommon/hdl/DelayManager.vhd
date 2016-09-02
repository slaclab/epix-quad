-------------------------------------------------------------------------------
-- Title         : DelayManager
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : DelayManager.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- IDELAY/ODELAY interface for Virtex 5.
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 07/23/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EpixTypes.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity DelayManager is
   generic (
      TPD_G       : time := 1 ns
   );
   port ( 
      -- Master system clock and reset
      sysClk      : in  sl;
      sysClkRst   : in  sl;
      -- Desired input delay
      delayIn     : in  slv(5 downto 0);
      -- Interfaces to IDELAY
      delayCe     : out sl;
      delayIncDir : out sl
   );

end DelayManager;


-- Define architecture
architecture DelayManager of DelayManager is

   type StateType is (IDLE_S, CHECK_S, COUNT_S);
   type RegType is record
      ioCe     : sl;
      curCount : slv(5 downto 0);
      state    : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      ioCe     => '0',
      curCount => (others => '0'),
      state    => IDLE_S
   );
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

      comb : process(sysClkRst,delayIn,r) 
         variable v : RegType;
      begin
         v := r;
         
         case (r.state) is
            when IDLE_S =>
               v.ioCe := '0';
               if (delayIn /= r.curCount) then
                  v.state := COUNT_S;
               end if;
            when CHECK_S =>
               v.ioCe := '0';
               if (r.curCount = delayIn) then
                  v.state := IDLE_S;
               else
                  v.state := COUNT_S;
               end if;
            when COUNT_S =>
               v.ioCe     := '1';
               v.curCount := r.curCount + 1;
               v.state    := CHECK_S;
            when others =>
               v.state := IDLE_S;
         end case;
         
         if (sysClkRst = '1') then
            v := REG_INIT_C;
         end if;
         
         rin <= v;
         
         --Outputs
         delayCe     <= r.ioCe;
         delayIncDir <= '1';
         
      end process;
      
      seq : process (sysClk) begin
         if rising_edge(sysClk) then
            r <= rin after TPD_G;
         end if;
      end process;
      
end DelayManager;

