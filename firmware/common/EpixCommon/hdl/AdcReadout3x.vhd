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
   generic (
      USE_ADC_CLK_G  : boolean := true
   );
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

   signal iClkFb        : std_logic;
   signal iClkFbBufG    : std_logic;
   signal iClk200MHz    : std_logic;
   signal iDelayRst     : std_logic;
   signal iPllFb        : std_logic;
   signal iPllLocked    : std_logic;
   signal iClk350MHz    : std_logic;
   signal iClk350MHzRaw : std_logic;

begin

   -- ADC
   GenAdc : for i in 0 to 1 generate 
      U_AdcReadout: entity work.AdcReadout 
         generic map (
            NUM_CHANNELS_G => 8,
            EN_DELAY_G     => 1,
            USE_ADC_CLK_G  => USE_ADC_CLK_G
         ) port map ( 
            sysClk        => sysClk,
            sysClkRst     => sysClkRst,
            sysDataClock  => iClk350MHz,
            frameDelay    => epixConfig.frameDelay(i),
            dataDelay     => epixConfig.dataDelay(i),
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
         EN_DELAY_G     => 1,
         USE_ADC_CLK_G  => USE_ADC_CLK_G
      ) port map ( 
         sysClk        => sysClk,
         sysClkRst     => sysClkRst,
         sysDataClock  => iClk350MHz,
         frameDelay    => epixConfig.frameDelay(2),
         dataDelay     => epixConfig.monDataDelay,
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
   U_IDelayRst : entity work.RstSync
      generic map (
         TPD_G           => ns,
         IN_POLARITY_G   => '1',
         OUT_POLARITY_G  => '1',
         BYPASS_SYNC_G   => false,
         RELEASE_DELAY_G => 32
      )
      port map (
         clk      => iClk200Mhz,
         asyncRst => sysClkRst,
         syncRst  => iDelayRst
      );
   -- DCM for generating 200 MHz for IDelayCtrl
   U_200MHzDcm : DCM_ADV
   generic map( 
      CLK_FEEDBACK          => "1X",
      CLKDV_DIVIDE          => 2.0,
      CLKFX_DIVIDE          => 8,  -- Was 5 for 125 MHz input
      CLKFX_MULTIPLY        => 8,  -- Was 8 for 125 MHz input
      CLKIN_DIVIDE_BY_2     => FALSE,
      CLKIN_PERIOD          => 10.000,
      CLKOUT_PHASE_SHIFT    => "NONE",
      DCM_AUTOCALIBRATION   => TRUE,
      DCM_PERFORMANCE_MODE  => "MAX_SPEED",
      DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
      DFS_FREQUENCY_MODE    => "HIGH",
      DLL_FREQUENCY_MODE    => "LOW",
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
      CLKFX    => open,
      CLKFX180 => open,
      CLK0     => iClkFb,
      CLK2X    => iClk200MHz,
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

   -- PLL to generate 350 MHz clock
   U_AdcDoClkGen : PLL_BASE
      generic map( 
         BANDWIDTH          => "OPTIMIZED", -- "HIGH", "LOW" or "OPTIMIZED"
         CLKFBOUT_MULT      =>   7, -- Multiplication factor for all output clocks
         CLKFBOUT_PHASE     => 0.0, -- Phase shift (degrees) of all output clocks
         CLKIN_PERIOD       =>10.0, -- Clock period (ns) of input clock on CLKIN
         CLKOUT0_DIVIDE     =>   2, -- Division factor for CLKOUT0 (1 to 128)
         CLKOUT0_DUTY_CYCLE => 0.5, -- Duty cycle for CLKOUT0 (0.01 to 0.99)
         CLKOUT0_PHASE      => 0.0, -- Phase shift (degrees) for CLKOUT0 (0.0 to 360.0)
         COMPENSATION       => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRNOUS",
                                                     -- "SOURCE_SYNCHRNOUS", "INTERNAL",
                                                     -- "EXTERNAL", "DCM2PLL", "PLL2DCM"
         DIVCLK_DIVIDE      => 1,    -- Division factor for all clocks (1 to 52)
         REF_JITTER         => 0.100 -- Input reference jitter (0.000 to 0.999 UI%)
      ) 
      port map (
         CLKFBOUT => iPllFb,        -- General output feedback signal
         CLKOUT0  => iClk350MHzRaw, -- One of six general clock output signals
         CLKOUT1  => open,          -- One of six general clock output signals
         CLKOUT2  => open,          -- One of six general clock output signals
         CLKOUT3  => open,          -- One of six general clock output signals
         CLKOUT4  => open,          -- One of six general clock output signals
         CLKOUT5  => open,          -- One of six general clock output signals
         LOCKED   => iPllLocked,    -- Active high PLL lock signal
         CLKFBIN  => iPllFb,        -- Clock feedback input
         CLKIN    => sysClk,        -- Clock input
         RST      => sysClkRst      -- Asynchronous PLL reset
      );
   U_SysClkBufG : BUFG port map ( I => iClk350MHzRaw, O => iClk350MHz );

   
end AdcReadout3x;

