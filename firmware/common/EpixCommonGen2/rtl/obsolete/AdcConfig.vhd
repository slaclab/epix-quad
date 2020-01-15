-------------------------------------------------------------------------------
-- Title      : ADC Shift Controller
-- Project    : Heavy Photon Test Board
-------------------------------------------------------------------------------
-- File       : AdcConfig.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- This block controls shift of data in and out of the external ADC
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

entity AdcConfig is
   generic (
      TPD_G             : time := 1 ns;
      CLK_PERIOD_G      : real := 8.0e-9;
      CLK_EN_PERIOD_G   : real := 16.0e-9
   );
   port ( 

      -- Master system clock, 125Mhz
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- ADC Control
      adcWrData       : in  std_logic_vector(7  downto 0);
      adcRdData       : out std_logic_vector(7  downto 0);
      adcAddr         : in  std_logic_vector(12 downto 0);
      adcWrReq        : in  std_logic;
      adcRdReq        : in  std_logic;
      adcAck          : out std_logic;
      adcSel          : in  std_logic_vector(1 downto 0);

      -- Interface To ADC
      adcSClk         : out std_logic;
      adcSDin         : in  std_logic;
      adcSDout        : out std_logic;
      adcSDEn         : out std_logic;
      adcCsb          : out std_logic_vector(2 downto 0)
   );
end AdcConfig;


-- Define architecture
architecture AdcConfig of AdcConfig is

   constant SPI_CLK_PERIOD_DIV2_CYCLES_C : integer := integer(CLK_EN_PERIOD_G / CLK_PERIOD_G) / 2;
   constant SCLK_COUNTER_SIZE_C          : integer := bitSize(SPI_CLK_PERIOD_DIV2_CYCLES_C);

   -- Local Signals
   signal intShift   : std_logic_vector(23 downto 0);
   signal nextClk    : std_logic;
   signal nextAck    : std_logic;
   signal shiftCnt   : std_logic_vector(12 downto 0);
   signal shiftCntEn : std_logic;
   signal shiftEn    : std_logic;
   signal locSDout   : std_logic;
   signal adcSDir    : std_logic;
   signal intCsb     : std_logic;

   signal sysClkEn    : std_logic;
   signal sclkCounter : std_logic_vector(SCLK_COUNTER_SIZE_C-1 downto 0);

   -- State Machine
   constant ST_IDLE      : std_logic_vector(1 downto 0) := "01";
   constant ST_SHIFT     : std_logic_vector(1 downto 0) := "10";
   constant ST_DONE      : std_logic_vector(1 downto 0) := "11";
   signal   curState     : std_logic_vector(1 downto 0);
   signal   nxtState     : std_logic_vector(1 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Generate clock enable for state machine
   process( sysClk ) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            sclkCounter <= (others => '0');
            sysClkEn    <= '0';
         else
            if (sclkCounter = SPI_CLK_PERIOD_DIV2_CYCLES_C) then
               sclkCounter <= (others => '0');
               sysClkEn    <= '1';
            else
               sclkCounter <= sclkCounter + 1;
               sysClkEn    <= '0';
            end if;
         end if;
      end if;
   end process;

   -- Output Data
   adcRdData <= intShift(7 downto 0);

   -- ADC data
   adcSDout <= locSDout when adcSDir = '0' else '1';
   -- Enable for the top level tri-state
   adcSDEn  <= not(adcSDir);

   -- Chip select
   adcCsb(0) <= intCsb when adcSel = 0 else '1';
   adcCsb(1) <= intCsb when adcSel = 1 else '1';
   adcCsb(2) <= intCsb when adcSel = 2 else '1';

   -- Control shift memory register
   process ( sysClk, sysClkRst, sysClkEn ) begin
      if sysClkRst = '1' then
         adcAck       <= '0'           after tpd;
         adcSDir      <= '0'           after tpd;
         locSDout     <= '0'           after tpd;
         adcSClk      <= '0'           after tpd;
         intCsb       <= '1'           after tpd;
         nextClk      <= '1'           after tpd;
         shiftCnt     <= (others=>'0') after tpd;
         shiftCntEn   <= '0'           after tpd;
         intShift     <= (others=>'0') after tpd;
         curState     <= ST_IDLE       after tpd;
      elsif sysClkEn = '1' and rising_edge(sysClk) then
      --elsif rising_edge(sysClk) then

         -- Next state
         curState <= nxtState after tpd;
         adcAck   <= nextAck  after tpd;

         -- Shift count is not enabled
         if shiftCntEn = '0' then
            adcSClk   <= '0' after tpd;
            locSDout  <= '0' after tpd;
            adcSDir   <= '0' after tpd;
            intCsb    <= '1' after tpd;
            nextClk   <= '1' after tpd;

            -- Wait for shift request
            if shiftEn = '1' then
               shiftCntEn             <= '1'           after tpd;
               shiftCnt               <= (others=>'0') after tpd;
               intShift(23)           <= adcRdReq      after tpd;
               intShift(22 downto 21) <= "00"          after tpd;
               intShift(20 downto  8) <= adcAddr       after tpd;
               intShift(7  downto  0) <= adcWrData     after tpd;
            end if;
         else
            shiftCnt <= shiftCnt + 1  after tpd;

            -- Clock 0, setup output
            if shiftCnt(7 downto 0) = 0 then
             
               -- Clock goes back to zero
               adcSClk <= '0' after tpd;

               -- Shift Count 0-23, output and shift data
               if shiftCnt(12 downto 8) < 24 then
                  locSDout  <= intShift(23)                     after tpd;
                  intShift  <= intShift(22 downto 0) & adcSDin  after tpd;
                  intCsb    <= '0'                              after tpd;
                  nextClk   <= '1'                              after tpd;

               -- Done, Sample last value
               else
                  intShift  <= intShift(22 downto 0) & adcSDin  after tpd;
                  locSDout  <= '0' after tpd;
                  intCsb    <= '1' after tpd;
                  nextClk   <= '0' after tpd;
               end if;

            -- Clock 3, clock output
            elsif shiftCnt(7 downto 0) = 8 then
               adcSClk <= nextClk after tpd;

               -- Tristate after 16 bits if read
               if shiftCnt(12 downto 8) = 15 and adcRdReq = '1' then
                  adcSDir <= '1' after tpd;
               end if;

               -- Stop counter
               if shiftCnt(12 downto 8) = 24 then
                  shiftCntEn <= '0' after tpd;
               end if;
            end if;
         end if;
      end if;
   end process;


   -- State machine control
   process ( curState, adcWrReq, adcRdReq, shiftCntEn ) begin
      case curState is

         -- IDLE, wait for request
         when ST_IDLE =>
            nextAck <= '0';

            -- Shift Request
            if adcWrReq = '1' or adcRdReq = '1' then
               shiftEn  <= '1';
               nxtState <= ST_SHIFT;
            else
               shiftEn  <= '0'; 
               nxtState <= curState;
            end if;

         -- Shifting Data
         when ST_SHIFT =>
            nextAck <= '0';
            shiftEn <= '0'; 

            -- Wait for shift to be done
            if shiftCntEn = '0' then
               nxtState <= ST_DONE;
            else
               nxtState <= curState;
            end if;

         -- Done
         when ST_DONE =>
            nextAck <= '1';
            shiftEn <= '0'; 

            -- Wait for request to go away
            if adcRdReq = '0' and adcWrReq = '0' then
               nxtState <= ST_IDLE;
            else
               nxtState <= curState;
            end if;

         when others =>
            nextAck  <= '0';
            shiftEn  <= '0'; 
            nxtState <= ST_IDLE;
      end case;
   end process;

end AdcConfig;

