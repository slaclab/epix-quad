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
-- 03/12/2015: Adapted by Kurtis for ePix Gen2, 7 series interface.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity AdcReadout3x is
   generic (
      TPD_G             : time := 1 ns;
      IDELAYCTRL_FREQ_G : real := 200.0;
      ADC0_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC1_INVERT_CH    : slv(7 downto 0) := "00000000";
      ADC2_INVERT_CH    : slv(7 downto 0) := "00000000"
   );
   port ( 
      -- Master system clock
      sysClk        : in  sl;
      sysClkRst     : in  sl;
      -- Clock for IDELAYCTRL
      iDelayCtrlClk : in  sl;
      iDelayCtrlRst : in  sl;
      -- Configuration input for delays
      epixConfig    : in  EpixConfigType;
      -- IDELAYCTRL status output
      iDelayCtrlRdy : out sl;
      -- ADC Data Interface
      adcValid      : out slv(19 downto 0);
      adcData       : out Slv16Array(19 downto 0);
      -- ADC Interface Signals
      adcFClkP      : in  slv( 2 downto 0);
      adcFClkN      : in  slv( 2 downto 0);
      adcDClkP      : in  slv( 2 downto 0);
      adcDClkN      : in  slv( 2 downto 0);
      adcChP        : in  slv(19 downto 0);
      adcChN        : in  slv(19 downto 0)
   );

end AdcReadout3x;


-- Define architecture
architecture AdcReadout3x of AdcReadout3x is

   constant ADC01_INVERT_CH : Slv8Array(1 downto 0) := (0 => ADC0_INVERT_CH, 1 => ADC1_INVERT_CH);

begin

   ------------------------
   -- ADC instantiations --
   ------------------------
   -- Channel ADCs
   GenAdc : for i in 0 to 1 generate 
      U_AdcReadout: entity work.AdcReadout 
         generic map (
            NUM_CHANNELS_G => 8,
            ADC_INVERT_CH => ADC01_INVERT_CH(i),
            IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G
         ) port map ( 
            sysClk        => sysClk,
            sysClkRst     => sysClkRst,
            frameDelay    => epixConfig.frameDelay(i),
            dataDelay     => epixConfig.dataDelay(i),
            adcValid      => adcValid((i*8)+7 downto i*8),
            adcData       => adcData((i*8)+7 downto i*8),
            adcFClkP      => adcFClkP(i),
            adcFClkN      => adcFClkN(i),
            adcDClkP      => adcDClkP(i),
            adcDClkN      => adcDClkN(i),
            adcChP        => adcChP((i*8)+7 downto i*8),
            adcChN        => adcChN((i*8)+7 downto i*8)
         );
   end generate;
   -- Monitor ADC
   U_AdcMon: entity work.AdcReadout 
      generic map (
         NUM_CHANNELS_G => 4,
         ADC_INVERT_CH => ADC2_INVERT_CH,
         IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G
      ) port map ( 
         sysClk        => sysClk,
         sysClkRst     => sysClkRst,
         frameDelay    => epixConfig.frameDelay(2),
         dataDelay     => epixConfig.dataDelay(2),
         adcValid      => adcValid(19 downto 16),
         adcData       => adcData(19 downto 16),
         adcFClkP      => adcFClkP(2),
         adcFClkN      => adcFClkN(2),
         adcDClkP      => adcDClkP(2),
         adcDClkN      => adcDClkN(2),
         adcChP        => adcChP(19 downto 16),
         adcChN        => adcChN(19 downto 16)
      );

   -----------------------------
   -- Tap delay calibration  ---
   -----------------------------
   U_IDelayCtrl : IDELAYCTRL
      port map (
         REFCLK => iDelayCtrlClk,
         RST    => iDelayCtrlRst,
         RDY    => iDelayCtrlRdy
      );
   
end AdcReadout3x;

