-------------------------------------------------------------------------------
-- Title         : DAC Controller
-- Project       : CSPAD Detector
-------------------------------------------------------------------------------
-- File          : DacCntrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- DAC Controller.
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

use work.EpixTypes.all;

entity DacCntrl is 
   port ( 

      -- Master system clock
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- DAC Data
      dacData         : in  std_logic_vector(15 downto 0);
      dacStrobe       : in  std_logic;

      -- DAC Control Signals
      dacDin          : out std_logic;
      dacSclk         : out std_logic;
      dacCsL          : out std_logic;
      dacClrL         : out std_logic
   );
end DacCntrl;


-- Define architecture
architecture DacCntrl of DacCntrl is

   -- Local Signals
   signal intData   : std_logic_vector(15 downto 0);
   signal intCnt    : std_logic_vector(2  downto 0);
   signal intClk    : std_logic;
   signal intClkEn  : std_logic;
   signal intBitRst : std_logic;
   signal intBitEn  : std_logic;
   signal intBit    : std_logic_vector(3 downto 0);
   signal nxtDin    : std_logic;
   signal nxtCsL    : std_logic;

   -- State Machine
   constant ST_IDLE      : std_logic_vector(1 downto 0) := "01";
   constant ST_WAIT      : std_logic_vector(1 downto 0) := "10";
   constant ST_SHIFT     : std_logic_vector(1 downto 0) := "11";
   signal   curState     : std_logic_vector(1 downto 0);
   signal   nxtState     : std_logic_vector(1 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Clear
-- dacClrL <= '0' when sysClkRst = '1' else 'Z'; --Original
   dacClrL <= '0' when sysClkRst = '1' else '1'; --Kurtis change: clrL is pulled low on the ePix analog card

   -- Latch data when strobe is asserted
   process ( sysClk, sysClkRst ) begin
      if sysClkRst = '1' then
         intData <= (others=>'0') after tpd;
      elsif rising_edge(sysClk) then
         if dacStrobe = '1' then
            intData <= dacData after tpd;
         end if;
      end if;
   end process;

   -- Generate clock and enable signal
   process ( sysClk, sysClkRst ) begin
      if sysClkRst = '1' then
         intClk   <= '0'           after tpd;
         intCnt   <= (others=>'0') after tpd;
         intClkEn <= '0'           after tpd;
      elsif rising_edge(sysClk) then
         if intCnt = 7 then
            intCnt   <= (others=>'0') after tpd;
            intClk   <= not intClk    after tpd;
            intClkEn <= intClk        after tpd;
         else
            intCnt   <= intCnt + 1    after tpd;
            intClkEn <= '0'           after tpd;
         end if;
      end if;
   end process;

   -- Output clock
   -- dacSclk <= intClk;  --Original: clock runs all the time
   dacSclk <= '0' when curState = ST_IDLE else intClk;  --Kurtis change: clock gated off when not in use

   -- State machine
   process ( sysClk, sysClkRst ) begin
      if sysClkRst = '1' then
         intBit   <= (others=>'1') after tpd;
         curState <= ST_IDLE       after tpd;
      elsif rising_edge(sysClk) then

         -- Bit counter
         if intBitRst = '1' then
            intBit <= (others=>'1') after tpd;
         elsif intBitEn = '1' then
            intBit <= intBit - 1 after tpd;
         end if;

         -- DAC controls
         dacDin <= nxtDin after tpd;
         dacCsL <= nxtCsL after tpd;

         -- State
         curState <= nxtState after tpd;
      end if;
   end process;

   -- State machine
   process ( curState, intBit, dacStrobe, intClkEn, intData ) begin
      case ( curState ) is

         -- IDLE
         when ST_IDLE =>
            intBitRst <= '1';
            intBitEn  <= '0';
            nxtDin    <= '0';
            nxtCsL    <= '1';

            if dacStrobe = '1' then
               nxtState <= ST_WAIT;
            else 
               nxtState <= curState;
            end if;

         -- Wait for neg edge
         when ST_WAIT =>
            intBitRst <= '1';
            intBitEn  <= '0';
            nxtDin    <= '0';
            nxtCsL    <= '1';

            if intClkEn = '1' then
               nxtState <= ST_SHIFT;
            else 
               nxtState <= curState;
            end if;

         -- Shift data
         when ST_SHIFT =>
            intBitRst <= '0';
            intBitEn  <= intClkEn;
            nxtDin    <= intData(conv_integer(intBit));
            nxtCsL    <= '0';

            if intClkEn = '1' and intBit = 0 then
               nxtState <= ST_IDLE;
            else 
               nxtState <= curState;
            end if;

         when others =>
            intBitRst <= '0';
            intBitEn  <= '0';
            nxtDin    <= '0';
            nxtCsL    <= '0';
            nxtState  <= ST_IDLE;
      end case;
   end process;

end DacCntrl;

