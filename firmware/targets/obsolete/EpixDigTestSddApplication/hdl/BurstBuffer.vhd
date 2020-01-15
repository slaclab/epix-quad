-------------------------------------------------------------------------------
-- Title      : Acquisition Control Block
-- Project    : EPIX Readout
-------------------------------------------------------------------------------
-- File       : BurstBuffer.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Acquisition control block
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity BurstBuffer is
   generic (
      ADDR_WIDTH_G : integer := 4);
   port (
      -- Clocks and reset
      sysClk    : in  sl;
      sysClkRst : in  sl;
      -- sampling trigger and handshaking
      trig      : in  sl;
      ack       : in  sl;
      raddr     : in  slv((ADDR_WIDTH_G-1) downto 0);
      rdata     : out slv(15 downto 0);
      req       : out sl;
      -- ADC Data
      adcValid  : in  sl;
      adcData   : in  slv(15 downto 0));
end BurstBuffer;

-- Define architecture
architecture rtl of BurstBuffer is
   constant MAX_ADDR_C : slv((ADDR_WIDTH_G-1) downto 0) := (others => '1');

   type StateType is (
      IDLE_S,
      COLLECT_S,
      REQ_S,
      ACK_S);
   signal state : StateType := IDLE_S;

   signal wen : sl := '0';
   signal cnt,
      waddr : slv((ADDR_WIDTH_G-1) downto 0) := (others => '0');
   signal wdata : slv(15 downto 0) := (others => '0');
   
begin

   SimpleDualPortRam_Inst : entity surf.SimpleDualPortRam
      generic map(
         MEMORY_TYPE_G=> "block",
         DATA_WIDTH_G => 16,
         ADDR_WIDTH_G => ADDR_WIDTH_G)
      port map (
         -- Port A
         clka  => sysClk,
         wea   => wen,
         addra => waddr,
         dina  => wdata,
         -- Port B
         clkb  => sysClk,
         addrb => raddr,
         doutb => rdata); 

   process (sysClk)
   begin
      if rising_edge(sysClk) then
         wen <= '0';
         if sysClkRst = '1' then
            req   <= '0';
            cnt   <= (others => '0');
            waddr <= (others => '0');
            wdata <= (others => '0');
            state <= IDLE_S;
         else
            case (state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  if trig = '1' then
                     state <= COLLECT_S;
                  end if;
                  ----------------------------------------------------------------------
               when COLLECT_S =>
                  if adcValid = '1' then
                     wen   <= '1';
                     wdata <= adcData;
                     waddr <= cnt;
                     cnt   <= cnt + 1;
                     if cnt = MAX_ADDR_C then
                        cnt   <= (others => '0');
                        req   <= '1';
                        state <= REQ_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when REQ_S =>
                  if ack = '1' then
                     req   <= '0';
                     state <= ACK_S;
                  end if;
                  ----------------------------------------------------------------------
               when ACK_S =>
                  if ack = '0' then
                     state <= IDLE_S;
                  end if;                  
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

end rtl;
