
-------------------------------------------------------------------------------
-- Title         : Acquisition Control Block
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : BurstBuffer.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- Acquisition control block
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

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
      ACK_S);
   signal state : StateType := IDLE_S;

   signal wen : sl := '0';
   signal cnt,
      waddr : slv((ADDR_WIDTH_G-1) downto 0) := (others => '0');
   signal wdata : slv(15 downto 0) := (others => '0');
   
begin

   SimpleDualPortRam_Inst : entity work.SimpleDualPortRam
      generic map(
         BRAM_EN_G    => true,
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
                        state <= ACK_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when ACK_S =>
                  if ack = '1' then
                     req   <= '0';
                     state <= IDLE_S;
                  end if;
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

end rtl;
