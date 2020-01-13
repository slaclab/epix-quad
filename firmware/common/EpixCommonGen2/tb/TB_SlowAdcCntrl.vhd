-------------------------------------------------------------------------------
-- Title         : ADS1217 ADC Controller
-- Project       : EPIX Detector
-------------------------------------------------------------------------------
-- File          : SlowAdcCntrl.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for reading the voltages, currents and strongback  
-- temperatures from the ADS1217 on the generation 2 EPIX analog board.
-- The ADS1217 is an 8 channel ADC.
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
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity TB_SlowAdcCntrl is 

end TB_SlowAdcCntrl;


-- Define architecture
architecture beh of TB_SlowAdcCntrl is

   signal clk :      std_logic;
   signal rst :      std_logic;
   signal adcSclk :      std_logic;
   signal adcCsL :      std_logic;
   signal adcDin :      std_logic;
   signal adcRefClk :      std_logic;
   signal trigger :      std_logic;
   
   signal adcData         : Slv24Array(8 downto 0);
   signal adcDataLUT      : Slv32Array(8 downto 0);
   signal allChRd         : std_logic;
   
   signal mAxisMaster     : AxiStreamMasterType;
   signal mAxisSlave      : AxiStreamSlaveType;

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
   DutADC_i: entity work.SlowAdcCntrl
   generic map (
      SPI_SCLK_PERIOD_G => 100.0E-9  	-- 10 MHz for simulation
   )
   port map ( 
      -- Master system clock
      sysClk          => clk,
      sysClkRst       => rst,

      -- Operation Control
      adcStart        => trigger,
      adcData         => adcData,
      allChRd         => allChRd,

      -- ADC Control Signals
      adcRefClk     => adcRefClk,
      adcDrdy       => trigger,
      adcSclk       => adcSclk,
      adcDout       => trigger,
      adcCsL        => adcCsL,
      adcDin        => adcDin
   );
   
   U_AdcEnv : entity work.SlowAdcLUT
   port map ( 
      -- Master system clock
      sysClk        => clk,
      sysClkRst     => rst,
      
      -- ADC raw data inputs
      adcData       => adcData,

      -- Converted data outputs
      outEnvData    => adcDataLUT
   );
   
   DutStrm_i: entity work.SlowAdcStream
   port map ( 
      sysClk          => clk,
      sysRst          => rst,
      acqCount        => x"00000001",
      seqCount        => x"00000002",
      trig            => allChRd,
      dataIn          => adcDataLUT,
      mAxisMaster     => mAxisMaster,
      mAxisSlave      => mAxisSlave
      
   );
   
   -- only for the simulation
   mAxisSlave.tReady <= '1';

end beh;

