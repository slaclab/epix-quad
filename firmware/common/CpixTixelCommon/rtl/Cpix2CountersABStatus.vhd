-------------------------------------------------------------------------------
-- Title         : Cpix2StreamAxi
-- Project       : Cpix2 Detector
-------------------------------------------------------------------------------
-- File          : AsicStreamAxi.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 4/27/2017
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'Tixel Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 4/27/2017: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

entity Cpix2CountersABStatus is 
   generic (
      TPD_G           	: time := 1 ns
   );
   port ( 
      -- clocks
      Clk               : in  sl;
      Rst               : in  sl;
      -- waveform signal in
      asicSRO           : in  sl; -- waveform
      asicSync          : in  sl; -- waveform
      -- deserializer data in
      decSof            : in  sl;
      -- counters status out
      countersABStatus  : out  slv(1 downto 0) 
   );
end Cpix2CountersABStatus;


-- Define architecture
architecture RTL of Cpix2CountersABStatus is

   
   type StateType is (WAIT_SRO_A_ST, WAIT_SRO_B_ST, WAIT_DATA_A_ST, DONE_ST, ERROR_ST);
   
   type StrType is record
      state          : StateType;
      stCnt          : natural;
      status         : slv(1 downto 0);
   end record;

   constant STR_INIT_C : StrType := (
      state          => WAIT_SRO_A_ST,
      stCnt          => 0,
      status         => (others=>'0')
   );
   
  
   signal s   : StrType := STR_INIT_C;
   signal sin : StrType;
   signal asicSRO_i   : sl;
   signal asicSync_i  : sl;
   signal decSof_i    : sl;
   
   attribute keep : string;                              -- for chipscope
   attribute keep of s : signal is "true";               -- for chipscope

begin

   -- wire output signals
   countersABStatus <= s.status;

   --------------------------------------
   -- synchronizers
   --------------------------------------
   Sync_SRO_U : entity work.Synchronizer
   port map (
      clk     => Clk,
      rst     => Rst,
      dataIn  => asicSRO,
      dataOut => asicSRO_i
   );

   Sync_SYNC_U : entity work.Synchronizer
   port map (
      clk     => Clk,
      rst     => Rst,
      dataIn  => asicSync,
      dataOut => asicSync_i
   );

   Sync_SOF_U : entity work.Synchronizer
   port map (
      clk     => Clk,
      rst     => Rst,
      dataIn  => decSof,
      dataOut => decSof_i
   );

    
   -----------------------------------------
   -- state machine combinatorial process
   -----------------------------------------   
   comb : process (Rst,s,asicSRO_i,asicSync_i,decSof_i ) is
      variable sv       : StrType;
   begin
      sv := s;    -- s is in AXI stream clock domain
      
      -- cross clock sync   

      -- state machine itself    
      case s.state is
         -- WAIT_SRO_A_ST, WAIT_SRO_B_ST, WAIT_DATA_A_ST, DONE_ST, ERROR_ST
         when WAIT_SRO_A_ST =>
            sv.status := "00";
            if (asicSRO_i = '1') then
                -- 
                sv.state := WAIT_DATA_A_ST;
            end if;    

         when WAIT_DATA_A_ST =>
            sv.status := "00";
            if (asicSRO_i = '1') then
                -- 
                sv.state := ERROR_ST;
            elsif (decSof_i = '1') then
                --
                sv.state := WAIT_SRO_B_ST;
            end if;    

         when WAIT_SRO_B_ST =>
            sv.status := "00";
            if (asicSRO_i = '1') then
                -- 
                sv.state := DONE_ST;
            end if;    

         when DONE_ST =>
            sv.status := "01";

         when ERROR_ST =>
            sv.status := "10";

         when others =>
            sv.status := "11";
      end case;
      
    
      -- reset logic
      if (Rst = '1' or asicSync_i = '1') then
         sv := STR_INIT_C;
      end if;

      -- outputs
      sin <= sv;

   end process comb;

 
   sseq : process (Clk) is
   begin
      if (rising_edge(Clk)) then
         s <= sin after TPD_G;
      end if;
   end process sseq;
   

end RTL;

