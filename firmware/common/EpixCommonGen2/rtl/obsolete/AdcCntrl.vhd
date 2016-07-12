-------------------------------------------------------------------------------
-- Title         : AD7490/Adc7928 ADC Controller
-- Project       : CSPAD Detector
-------------------------------------------------------------------------------
-- File          : AdcCntrl.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/27/2012
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for reading the strongback temperatures 
-- from the AD7490 or AD7928 ADC on the analog board.
-- The AD7928 is an 8 channel ADC while the AD7490 is an 8 channel ADC.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/27/2012: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;

entity AdcCntrl is 
   generic (
      TPD_G           : time := 1 ns;
      N_CHANNELS_G    : integer := 16
   );
   port ( 
      -- Master system clock
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- Operation Control
      adcChanCount    : in  std_logic_vector(3 downto 0);
      adcStart        : in  std_logic;
      adcData         : out Slv16Array(7 downto 0);
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
   signal intData      : Slv16Array(15 downto 0);
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

begin

   -- ADC data
   G_DataMap : for i in 0 to N_CHANNELS_G-1 generate
      adcData(i) <= intData(i);
   end generate;
   adcCsL  <= intCsL;

   -- Control shift memory register
   process ( sysClk, sysClkRst ) begin
      if sysClkRst = '1' then
         curState    <= ST_IDLE                 after TPD_G;
         clkCnt      <= (others=>'0')           after TPD_G;
         shiftCnt    <= (others=>'0')           after TPD_G;
         chanCnt     <= (others=>'0')           after TPD_G;
         adcSclk     <= '1'                     after TPD_G;
         adcStrobe   <= '0'                     after TPD_G;
         intCsL      <= '1'                     after TPD_G;
         adcDin      <= '1'                     after TPD_G;
         intDout     <= '0'                     after TPD_G;
         intShift    <= (others=>'0')           after TPD_G;
         intData     <= (others=>(others=>'0')) after TPD_G;
      elsif rising_edge(sysClk) then

         -- Next state
         curState <= nxtState after TPD_G;

         -- Clk counter
         if clkCntEn = '1' then
            clkCnt <= clkCnt + 1 after TPD_G;
         else
            clkCnt <= (others=>'0') after TPD_G;
         end if;

         -- Shift counter
         if shiftCntRst = '1' then
            shiftCnt <= (others=>'0') after TPD_G;
         elsif shiftCntEn = '1' then
            shiftCnt <= shiftCnt + 1 after TPD_G;
         end if;

         -- Channel counter
         if chanCntRst = '1' then
            chanCnt <= (others=>'0') after TPD_G;
         elsif chanCntEn = '1' then
            chanCnt <= chanCnt + 1 after TPD_G;
         end if;

         -- Output values
         adcSclk   <= nxtSclk   after TPD_G;
         intCsL    <= nxtCsL    after TPD_G;
         adcDin    <= nxtDin    after TPD_G;
         adcStrobe <= nxtStrobe after TPD_G;

         -- Input data
         intDout <= adcDout after TPD_G;

         -- Shift register
         if shiftEn = '1' then
            intShift <= intShift(14 downto 0) & intDout after TPD_G;
         end if;

         -- Store data
         if storeEn = '1' then
            intData(conv_integer(intShift(15 downto 12))) <= "0000" & intShift(11 downto 0) after TPD_G;
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

