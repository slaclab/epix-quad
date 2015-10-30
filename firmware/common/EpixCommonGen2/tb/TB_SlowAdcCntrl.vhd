-------------------------------------------------------------------------------
-- Title         : ADS1217 ADC Controller
-- Project       : EPIX Detector
-------------------------------------------------------------------------------
-- File          : SlowAdcCntrl.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 10/29/2015
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for reading the voltages, currents and strongback  
-- temperatures from the ADS1217 on the generation 2 EPIX analog board.
-- The ADS1217 is an 8 channel ADC.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Maciej Kwiatkowski. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/29/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity TB_SlowAdcCntrl is 

end TB_SlowAdcCntrl;


-- Define architecture
architecture beh of TB_SlowAdcCntrl is

   signal clk :      std_logic;
   signal rst :      std_logic;
   signal adcSclk :      std_logic;
   signal adcCsL :      std_logic;
   signal adcDin :      std_logic;
   signal trigger :      std_logic;

begin

   process
   begin
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
   end process;
   
   process
   begin
      rst <= '1';
      wait for 20 ns;
      rst <= '0';
      wait;
   end process;
   
   
   process
   begin
      trigger <= '0';
      wait for 500 ns;
      trigger <= '1';
      wait for 500 ns;
   end process;
   
   
   --DUT
   Dut_i: entity work.SlowAdcCntrl
      generic map (
         SPI_SCLK_PERIOD_G => 5.0E-9  	-- 20 MHz for simulation
      )
      port map ( 
         -- Master system clock
         sysClk          => clk,
         sysClkRst       => rst,

         -- Operation Control
         adcStart        => trigger,
         adcData         => open,

         -- ADC Control Signals
         adcDrdy       => trigger,
         adcSclk       => adcSclk,
         adcDout       => trigger,
         adcCsL        => adcCsL,
         adcDin        => adcDin
      );
   
   

end beh;

