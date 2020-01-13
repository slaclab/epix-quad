-------------------------------------------------------------------------------
-- Title      : AD7490/Adc7928 ADC Controller
-- Project    : CSPAD Detector
-------------------------------------------------------------------------------
-- File       : AdcCntrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for reading the strongback temperatures 
-- from the AD7490 or AD7928 ADC on the analog board.
-- The AD7928 is an 8 channel ADC while the AD7490 is an 8 channel ADC.
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

entity AdcCntrl is 
   port ( 

      -- Master system clock
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- Operation Control
      adcChanCount    : in  std_logic_vector(3 downto 0);
      adcStart        : in  std_logic;
      adcData         : out word16_array(15 downto 0);
      adcStrobe       : out std_logic;

      -- ADC Control Signals
      adcSclk       : out   std_logic;
      adcDout       : in    std_logic;
      adcCsL        : out   std_logic;
      adcDin        : out   std_logic
   );
end AdcCntrl;


-- Define architecture
architecture AdcCntrl of AdcCntrl is

   -- Local Signals
   signal shiftCnt     : std_logic_vector(3 downto 0);
   signal shiftCntEn   : std_logic;
   signal shiftCntRst  : std_logic;
   signal chanCnt      : std_logic_vector(3 downto 0);
   signal chanCntEn    : std_logic;
   signal chanCntRst   : std_logic;
   signal clkCnt       : std_logic_vector(15 downto 0);
   signal clkCntEn     : std_logic;
   signal intDout      : std_logic;
   signal intShift     : std_logic_vector(15 downto 0);
   signal shiftEn      : std_logic;
   signal storeEn      : std_logic;
   signal intData      : word16_array(15 downto 0);
   signal intCsL       : std_logic;
   signal nxtSclk      : std_logic;
   signal nxtCsL       : std_logic;
   signal nxtDin       : std_logic;
   signal nxtStrobe    : std_logic;
   signal cntrlShift   : std_logic_vector(15 downto 0);

   -- State Machine
   constant ST_IDLE      : std_logic_vector(2 downto 0) := "001";
   constant ST_CLK_SET   : std_logic_vector(2 downto 0) := "010";
   constant ST_CLK_HOLD  : std_logic_vector(2 downto 0) := "011";
   constant ST_SHIFT     : std_logic_vector(2 downto 0) := "100";
   constant ST_WAIT      : std_logic_vector(2 downto 0) := "101";
   constant ST_DONE      : std_logic_vector(2 downto 0) := "110";
   signal   curState     : std_logic_vector(2 downto 0);
   signal   nxtState     : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- ADC data
   adcData <= intData;
   adcCsL  <= intCsL;

   -- Control shift memory register
   process ( sysClk, sysClkRst ) begin
      if sysClkRst = '1' then
         curState    <= ST_IDLE                 after tpd;
         clkCnt      <= (others=>'0')           after tpd;
         shiftCnt    <= (others=>'0')           after tpd;
         chanCnt     <= (others=>'0')           after tpd;
         adcSclk     <= '1'                     after tpd;
         adcStrobe   <= '0'                     after tpd;
         intCsL      <= '1'                     after tpd;
         adcDin      <= '1'                     after tpd;
         intDout     <= '0'                     after tpd;
         intShift    <= (others=>'0')           after tpd;
         intData     <= (others=>(others=>'0')) after tpd;
      elsif rising_edge(sysClk) then

         -- Next state
         curState <= nxtState after tpd;

         -- Clk counter
         if clkCntEn = '1' then
            clkCnt <= clkCnt + 1 after tpd;
         else
            clkCnt <= (others=>'0') after tpd;
         end if;

         -- Shift counter
         if shiftCntRst = '1' then
            shiftCnt <= (others=>'0') after tpd;
         elsif shiftCntEn = '1' then
            shiftCnt <= shiftCnt + 1 after tpd;
         end if;

         -- Channel counter
         if chanCntRst = '1' then
            chanCnt <= (others=>'0') after tpd;
         elsif chanCntEn = '1' then
            chanCnt <= chanCnt + 1 after tpd;
         end if;

         -- Output values
         adcSclk   <= nxtSclk   after tpd;
         intCsL    <= nxtCsL    after tpd;
         adcDin    <= nxtDin    after tpd;
         adcStrobe <= nxtStrobe after tpd;

         -- Input data
         intDout <= adcDout after tpd;

         -- Shift register
         if shiftEn = '1' then
            intShift <= intShift(14 downto 0) & intDout after tpd;
         end if;

         -- Store data
         if storeEn = '1' then
            intData(conv_integer(intShift(15 downto 12))) <= "0000" & intShift(11 downto 0) after tpd;
         end if;
      end if;
   end process;

   -- Control shift data, MSB first
   cntrlShift <= "0000110011" & chanCnt(0) & chanCnt(1) & chanCnt(2) & chanCnt(3) & "01";

   -- State machine control
   process ( curState, adcStart, clkCnt, shiftCnt, chanCnt, cntrlShift, adcChanCount ) begin
      case curState is

         -- IDLE, wait for request
         when ST_IDLE =>
            shiftCntEn   <= '0';
            shiftCntRst  <= '1';
            chanCntEn    <= '0';
            chanCntRst   <= '1';
            clkCntEn     <= '0';
            shiftEn      <= '0';
            storeEn      <= '0';
            nxtSclk      <= '1';
            nxtCsL       <= '1';
            nxtDin       <= '0';
            nxtStrobe    <= '0';

            -- Wait for shift request
            if adcStart = '1' then
               nxtState <= ST_CLK_SET;
            else
               nxtState <= curState;
            end if;

         -- CLK Setup period
         when ST_CLK_SET =>
            shiftCntEn   <= '0';
            shiftCntRst  <= '0';
            chanCntEn    <= '0';
            chanCntRst   <= '0';
            storeEn      <= '0';
            nxtSclk      <= '1';
            nxtCsL       <= '0';
            nxtDin       <= cntrlShift(conv_integer(shiftCnt));
            nxtStrobe    <= '0';

            -- Wait 8 clocks, sample
            if clkCnt(2 downto 0) = 7 then
               shiftEn  <= '1';
               clkCntEn <= '0';
               nxtState <= ST_CLK_HOLD;
            else
               shiftEn  <= '0';
               clkCntEn <= '1';
               nxtState <= curState;
            end if;

         -- CLK Hold period
         when ST_CLK_HOLD =>
            shiftCntEn   <= '0';
            shiftCntRst  <= '0';
            chanCntEn    <= '0';
            chanCntRst   <= '0';
            shiftEn      <= '0';
            storeEn      <= '0';
            nxtSclk      <= '0';
            nxtCsL       <= '0';
            nxtDin       <= cntrlShift(conv_integer(shiftCnt));
            nxtStrobe    <= '0';

            -- Wait 8 clocks
            if clkCnt(2 downto 0) = 7 then
               clkCntEn <= '0';
               nxtState <= ST_SHIFT;
            else
               clkCntEn <= '1';
               nxtState <= curState;
            end if;

         -- Shift to next bit
         when ST_SHIFT =>
            chanCntRst   <= '0';
            shiftEn      <= '0';
            nxtSclk      <= '1';
            nxtCsL       <= '0';
            nxtDin       <= cntrlShift(conv_integer(shiftCnt));
            clkCntEn     <= '0';
            shiftEn      <= '0';
            nxtStrobe    <= '0';

            -- Done with channel
            if shiftCnt = 15 then
               shiftCntRst <= '1';
               shiftCntEn  <= '0';
               chanCntEn   <= '1';
               storeEn     <= '1';

               -- All channels done
               if chanCnt = adcChanCount then
                  nxtState <= ST_DONE;
               else
                  nxtState <= ST_WAIT;
               end if;
            else
               shiftCntRst <= '0';
               shiftCntEn  <= '1';
               chanCntEn   <= '0';
               storeEn     <= '0';
               nxtState    <= ST_CLK_SET;
            end if;

         -- WAIT between cycles
         when ST_WAIT =>
            chanCntEn    <= '0';
            chanCntRst   <= '0';
            shiftCntEn   <= '0';
            shiftCntRst  <= '1';
            shiftEn      <= '0';
            storeEn      <= '0';
            nxtSclk      <= '1';
            nxtCsL       <= '1';
            nxtDin       <= '0';
            shiftEn      <= '0';
            nxtStrobe    <= '0';

            if clkCnt = x"7FFF" then
               clkCntEn    <= '0';
               nxtState    <= ST_CLK_SET;
            else
               clkCntEn    <= '1';
               nxtState    <= curState;
            end if;

         -- Done
         when ST_DONE =>
            shiftCntEn   <= '0';
            shiftCntRst  <= '1';
            chanCntEn    <= '0';
            chanCntRst   <= '1';
            clkCntEn     <= '0';
            shiftEn      <= '0';
            storeEn      <= '0';
            nxtSclk      <= '1';
            nxtCsL       <= '0';
            nxtDin       <= '0';
            nxtStrobe    <= '1';
            nxtState     <= ST_IDLE;

         when others =>
            shiftCntEn   <= '0';
            shiftCntRst  <= '0';
            chanCntEn    <= '0';
            chanCntRst   <= '0';
            clkCntEn     <= '0';
            shiftEn      <= '0';
            storeEn      <= '0';
            nxtSclk      <= '0';
            nxtCsL       <= '0';
            nxtDin       <= '0';
            nxtStrobe    <= '0';
            nxtState     <= ST_IDLE;
      end case;
   end process;

end AdcCntrl;

