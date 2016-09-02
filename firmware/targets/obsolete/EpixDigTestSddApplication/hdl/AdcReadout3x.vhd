-------------------------------------------------------------------------------
-- Title         : ADC Readout Control
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : AdcReadout3x.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
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
-- 12/08/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.EpixTypes.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity AdcReadout3x is
   port ( 

      -- Master system clock, 200Mhz
      sysClk        : in  std_logic;
      sysClkRst     : in  std_logic;

      -- Configuration input for delays
      -- IDELAYCTRL status output
      epixConfig    : in  EpixConfigType;
      iDelayCtrlRdy : out std_logic;

      -- ADC Data Interface
      adcValid      : out std_logic_vector(19 downto 0);
      adcData       : out word16_array(19 downto 0);
      
      -- ADC Interface Signals
      adcFClkP      : in  std_logic_vector(2 downto 0);
      adcFClkM      : in  std_logic_vector(2 downto 0);
      adcDClkP      : in  std_logic_vector(2 downto 0);
      adcDClkM      : in  std_logic_vector(2 downto 0);
      adcChP        : in  std_logic_vector(19 downto 0);
      adcChM        : in  std_logic_vector(19 downto 0)
   );

end AdcReadout3x;


-- Define architecture
architecture AdcReadout3x of AdcReadout3x is

   signal iDelayRst  : std_logic;

begin

   -- ADC
   GenAdc : for i in 0 to 1 generate 

      U_AdcReadout: entity work.AdcReadout 
         generic map (
            NUM_CHANNELS_G => 8,
            EN_DELAY       => 1
         ) port map ( 
            sysClk        => sysClk,
            sysClkRst     => sysClkRst,
            inputDelay    => epixConfig.adcDelay(i),
            inputDelaySet => epixConfig.adcDelayUpdate,
            frameSwapOut  => open,
            adcValid      => adcValid((i*8)+7 downto i*8),
            adcData       => adcData((i*8)+7 downto i*8),
            adcFClkP      => adcFClkP(i),
            adcFClkM      => adcFClkM(i),
            adcDClkP      => adcDClkP(i),
            adcDClkM      => adcDClkM(i),
            adcChP        => adcChP((i*8)+7 downto i*8),
            adcChM        => adcChM((i*8)+7 downto i*8)
         );
   end generate;

   U_AdcMon: entity work.AdcReadout 
      generic map (
         NUM_CHANNELS_G => 4,
         EN_DELAY       => 1
      ) port map ( 
         sysClk        => sysClk,
         sysClkRst     => sysClkRst,
         inputDelay    => epixConfig.adcDelay(2),
         inputDelaySet => epixConfig.adcDelayUpdate,
         frameSwapOut  => open,
         adcValid      => adcValid(19 downto 16),
         adcData       => adcData(19 downto 16),
         adcFClkP      => adcFClkP(2),
         adcFClkM      => adcFClkM(2),
         adcDClkP      => adcDClkP(2),
         adcDClkM      => adcDClkM(2),
         adcChP        => adcChP(19 downto 16),
         adcChM        => adcChM(19 downto 16)
      );

   U_IDelayCtrl : IDELAYCTRL
      port map (
         REFCLK => sysClk,
         RST    => iDelayRst,
         RDY    => iDelayCtrlRdy
      );
   --Generate a longer reset for IDELAYCTRL (minimum is 50 ns)
   process(sysClk) 
      variable counter : integer range 0 to 15 := 0;
      constant delay   : integer := 10;
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            counter := delay;
            iDelayRst <= '1';
         elsif (counter > 0) then
            iDelayRst <= '1';
            counter := counter - 1;
         else
            iDelayRst <= '0';
         end if;
      end if;
   end process;

end AdcReadout3x;
