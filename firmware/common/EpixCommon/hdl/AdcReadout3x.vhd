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
-- Copyright (c) 2011 by SLAC. All rights reserved.
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

      -- Master system clock, 125Mhz
      sysClk        : in  std_logic;
      sysClkRst     : in  std_logic;

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

begin

   -- ADC
   GenAdc : for i in 0 to 1 generate 

      U_AdcReadout: entity work.AdcReadout 
         generic map (
            NUM_CHANNELS_G => 8,
            EN_DELAY       => 0
         ) port map ( 
            sysClk        => sysClk,
            sysClkRst     => sysClkRst,
            inputDelay    => (others=>'0'),
            inputDelaySet => '0',
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
         EN_DELAY       => 0
      ) port map ( 
         sysClk        => sysClk,
         sysClkRst     => sysClkRst,
         inputDelay    => (others=>'0'),
         inputDelaySet => '0',
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

end AdcReadout3x;

