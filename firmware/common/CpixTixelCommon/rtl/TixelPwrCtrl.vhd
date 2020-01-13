-------------------------------------------------------------------------------
-- Title      : TixelPwrCtrl
-- Project    : Tixel Detector
-------------------------------------------------------------------------------
-- File       : TixelPwrCtrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity TixelPwrCtrl is 
   generic (
      TPD_G          : time      := 1 ns;
      ON_DIG_ANA_G   : natural   := 1000000;
      ON_ANA_IO_G    : natural   := 1000000;
      OFF_IO_ANA_G   : natural   := 1000000;
      OFF_ANA_DIG_G  : natural   := 1000000
   );
   port ( 
      clk         : in  sl;
      rst         : in  sl;
      enableReq   : in  sl;
      enableAck   : out sl;
      digPwr      : out sl;
      anaPwr      : out sl;
      ioPwr       : out sl
   );
end TixelPwrCtrl;


-- Define architecture
architecture RTL of TixelPwrCtrl is
   
   type StateType is (PWROFF_S, PWRON_S, ON_DEL1_S, ON_DEL2_S, OFF_DEL1_S, OFF_DEL2_S);
   
   type FsmType is record
      state          : StateType;
      stCnt          : natural;
      enableReq      : slv(3 downto 0);
      enableAck      : sl;
      digPwr         : sl;
      anaPwr         : sl;
      ioPwr          : sl;
   end record;

   constant FSM_INIT_C : FsmType := (
      state          => PWROFF_S,
      stCnt          => 0,
      enableReq      => "0000",
      enableAck      => '0',
      digPwr         => '0',
      anaPwr         => '0',
      ioPwr          => '0'
   );
   
   signal f   : FsmType := FSM_INIT_C;
   signal fin : FsmType;
   
begin
   
   comb : process (rst, f, enableReq) is
      variable fv       : FsmType;
   begin
      fv := f;
      
      -- sync enableReq
      fv.enableReq := f.enableReq(2 downto 0) & enableReq;
      
      case f.state is
         when PWROFF_S =>
            fv.digPwr := '0';
            fv.anaPwr := '0';
            fv.ioPwr := '0';
            fv.enableAck := '0';
            if f.enableReq(3) = '1' then
               fv.digPwr := '1';
               fv.stCnt := 0;
               fv.state := ON_DEL1_S;
            end if;
         
         when ON_DEL1_S =>
            if f.stCnt < ON_DIG_ANA_G then
               fv.stCnt := f.stCnt + 1;
            else
               fv.anaPwr := '1';
               fv.stCnt := 0;
               fv.state := ON_DEL2_S;
            end if;
         
         when ON_DEL2_S =>
            if f.stCnt < ON_ANA_IO_G then
               fv.stCnt := f.stCnt + 1;
            else
               fv.ioPwr := '1';
               fv.stCnt := 0;
               fv.state := PWRON_S;
            end if;
            
         when PWRON_S =>
            fv.digPwr := '1';
            fv.anaPwr := '1';
            fv.ioPwr := '1';
            fv.enableAck := '1';
            if f.enableReq(3) = '0' then
               fv.enableAck := '0';
               fv.ioPwr := '0';
               fv.stCnt := 0;
               fv.state := OFF_DEL1_S;
            end if;
         
         when OFF_DEL1_S =>
            if f.stCnt < OFF_IO_ANA_G then
               fv.stCnt := f.stCnt + 1;
            else
               fv.anaPwr := '0';
               fv.stCnt := 0;
               fv.state := OFF_DEL2_S;
            end if;
         
         when OFF_DEL2_S =>
            if f.stCnt < OFF_ANA_DIG_G then
               fv.stCnt := f.stCnt + 1;
            else
               fv.digPwr := '0';
               fv.stCnt := 0;
               fv.state := PWROFF_S;
            end if;
         
         when others =>
      end case;
      
      -- reset logic
      
      if (rst = '1') then
         fv := FSM_INIT_C;
      end if;

      -- outputs
      fin         <= fv;      
      digPwr      <= f.digPwr;
      anaPwr      <= f.anaPwr;
      ioPwr       <= f.ioPwr;
      enableAck   <= f.enableAck;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         f <= fin after TPD_G;
      end if;
   end process seq;

end RTL;

