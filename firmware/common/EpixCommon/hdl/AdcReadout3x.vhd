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

   signal iClkFb     : std_logic;
   signal iClkFbBufG : std_logic;
   signal iClk200MHz : std_logic;
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
         REFCLK => iClk200MHz,
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

   -- DCM for generating 200 MHz for IDelayCtrl
   U_200MHzDcm : DCM_ADV
   generic map( 
      CLK_FEEDBACK          => "1X",
      CLKDV_DIVIDE          => 2.0,
      CLKFX_DIVIDE          => 5,
      CLKFX_MULTIPLY        => 8,
      CLKIN_DIVIDE_BY_2     => FALSE,
      CLKIN_PERIOD          => 8.000,
      CLKOUT_PHASE_SHIFT    => "NONE",
      DCM_AUTOCALIBRATION   => TRUE,
      DCM_PERFORMANCE_MODE  => "MAX_SPEED",
      DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
      DFS_FREQUENCY_MODE    => "HIGH",
      DLL_FREQUENCY_MODE    => "HIGH",
      DUTY_CYCLE_CORRECTION => TRUE,
      FACTORY_JF            => x"F0F0",
      PHASE_SHIFT           => 0,
      STARTUP_WAIT          => FALSE,
      SIM_DEVICE            => "VIRTEX5"
   )
   port map (
      CLKFB    => iClkFbBufG,
      CLKIN    => sysClk,
      DADDR    => (others => '0'),
      DCLK     => '0',
      DEN      => '0',
      DI       => (others => '0'),
      DWE      => '0',
      PSCLK    => '0',
      PSEN     => '0',
      PSINCDEC => '0',
      RST      => sysClkRst,
      CLKDV    => open,
      CLKFX    => iClk200MHz,
      CLKFX180 => open,
      CLK0     => iClkFb,
      CLK2X    => open,
      CLK2X180 => open,
      CLK90    => open,
      CLK180   => open,
      CLK270   => open,
      DO       => open,
      DRDY     => open,
      LOCKED   => open,
      PSDONE   => open
   );

   U_ClkFbBufG : BUFG port map ( I => iClkFb, O => iClkFbBufG );

end AdcReadout3x;

