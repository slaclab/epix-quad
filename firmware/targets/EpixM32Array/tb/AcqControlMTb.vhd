-------------------------------------------------------------------------------
-- File       : AcqControlMTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-08-27
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Testbench for design "AxiAds42lb69Core"
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

----------------------------------------------------------------------------------------------------

entity AcqControlMTb is

end entity AcqControlMTb;

----------------------------------------------------------------------------------------------------

architecture sim of AcqControlMTb is
   
   constant TPD_C    : time := 1 ns;
   
   signal clk        : sl := '0';
   signal rst        : sl := '1';
   
   -- ASIC signals
   signal iAsicGlblRst    : sl;
   signal iAsicR1         : sl;
   signal iAsicR2         : sl;
   signal iAsicR3         : sl;
   signal iAsicClk        : sl;
   signal iAsicStart      : sl;
   signal iAsicSample     : sl;
   signal iAsicReady      : sl;
   signal iAsicReady0     : sl;
   signal iAsicReady1     : sl;
   
   signal acqStart        : sl;
   signal adcClk          : sl;
   signal serialIdIo      : slv(1 downto 0);
   
   signal adcValid        : slv(1 downto 0);
   signal adcData         : Slv16Array(1 downto 0);
   
   signal doutAxisMaster : AxiStreamMasterArray(1 downto 0);
   signal doutAxisSlave  : AxiStreamSlaveArray(1 downto 0);
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   
   signal dataAxisMaster      : AxiStreamMasterType;
   signal dataAxisSlave       : AxiStreamSlaveType;

begin

   -- component instantiation
   U_RegControlM : entity work.RegControlM
   generic map (
      TPD_G          => TPD_C,
      CLK_PERIOD_G   => 10.0e-9,
      EN_DEVICE_DNA_G=> false,
      BUILD_INFO_G   => BUILD_INFO_DEFAULT_SLV_C
   )
   port map (
      axiClk         => clk,
      axiRst         => open,
      sysRst         => rst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => axiReadMaster ,
      axiReadSlave   => axiReadSlave  ,
      axiWriteMaster => axiWriteMaster,
      axiWriteSlave  => axiWriteSlave ,
      -- Register Inputs/Outputs (axiClk domain)
      powerEn        => open,
      dbgSel1        => open,
      dbgSel2        => open,
      -- 1-wire board ID interfaces
      serialIdIo     => serialIdIo,
      -- fast ADC clock
      adcClk         => adcClk,
      -- ASICs acquisition signals
      acqStart       => acqStart,
      asicGlblRst    => iAsicGlblRst,
      asicR1         => iAsicR1,
      asicR2         => iAsicR2,
      asicR3         => iAsicR3,
      asicClk        => iAsicClk,
      asicStart      => iAsicStart,
      asicSample     => iAsicSample,
      asicReady      => iAsicReady
   );
   
   ---------------------
   -- Acquisition control    --
   ---------------------
   
   U_Acq0ControlM : entity work.AcqControlM
   generic map (
      CHANNEL_G         => "0000"
   )
   port map (
      clk               => clk,
      rst               => rst,
      adcData           => adcData(0),
      adcValid          => adcValid(0),
      asicStart         => iAsicStart,
      asicSample        => iAsicSample,
      asicReady         => iAsicReady0,
      asicGlblRst       => iAsicGlblRst,
      -- AxiStream output
      axisClk           => clk,
      axisRst           => rst,
      axisMaster        => doutAxisMaster(0),
      axisSlave         => doutAxisSlave(0)
   );
   
   U_Acq1ControlM : entity work.AcqControlM
   generic map (
      CHANNEL_G         => "0001"
   )
   port map (
      clk               => clk,
      rst               => rst,
      adcData           => adcData(1),
      adcValid          => adcValid(1),
      asicStart         => iAsicStart,
      asicSample        => iAsicSample,
      asicReady         => iAsicReady1,
      asicGlblRst       => iAsicGlblRst,
      -- AxiStream output
      axisClk           => clk,
      axisRst           => rst,
      axisMaster        => doutAxisMaster(1),
      axisSlave         => doutAxisSlave(1)
   );
   
   iAsicReady <= iAsicReady0 and iAsicReady1;
   
   U_AxiStreamMux : entity work.AxiStreamMux
   generic map(
      NUM_SLAVES_G   => 2
   )
   port map(
      -- Clock and reset
      axisClk        => clk,
      axisRst        => rst,
      -- Slaves
      sAxisMasters   => doutAxisMaster,
      sAxisSlaves    => doutAxisSlave,
      -- Master
      mAxisMaster    => dataAxisMaster,
      mAxisSlave     => dataAxisSlave
      
   );

   ---------------------

   -- clock generation
   clk <= not clk after 10 ns;
   -- reset generation
   rst <= '0' after 80 ns;
   
   AdcGen_Proc : process
      variable adcVal1 : slv(15 downto 0) := x"0000";
      variable adcVal2 : slv(15 downto 0) := x"ffff";
   begin
      adcValid <= (others=>'0');
      adcData  <= (others=>(others=>'0'));
      
      wait until falling_edge(rst);
      
      loop
         
         wait until falling_edge(clk);
         adcValid <= "00";
         adcVal1 := adcVal1 + 1;
         adcVal2 := adcVal2 - 1;
         
         
         wait until falling_edge(clk);
         adcValid <= "11";
         adcData(0) <= adcVal1;
         adcData(1) <= adcVal2;
         
      end loop;
      
   end process AdcGen_Proc;

   -- waveform generation
   WaveGen_Proc : process
      variable axilRdata         : slv(31 downto 0);
   begin
      acqStart <= '0';
      dataAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;
      
      -- enable power
      axiLiteBusSimWrite(clk, axiWriteMaster, axiWriteSlave, x"00000200", x"03", true);
      wait until rising_edge(iAsicGlblRst);
      
      --axiLiteBusSimWrite(clk, axiWriteMaster, axiWriteSlave, x"00000200", x"FF", true);
      --axiLiteBusSimWrite(clk, axiWriteMaster, axiWriteSlave, x"00000204", x"04", true);
      --axiLiteBusSimWrite(clk, axiWriteMaster, axiWriteSlave, x"00000208", x"05", true);
      --axiLiteBusSimRead(clk, axiReadMaster, axiReadSlave, x"00000200", axilRdata, true);
      --axiLiteBusSimRead(clk, axiReadMaster, axiReadSlave, x"00000204", axilRdata, true);
      --axiLiteBusSimRead(clk, axiReadMaster, axiReadSlave, x"00000208", axilRdata, true);
      
      wait for 1 us;
      
      --loop
         
         -- trigger and wait for the acquisition complete
         wait until falling_edge(clk);
         acqStart <= '1';
         wait until falling_edge(clk);
         acqStart <= '0';
         wait until rising_edge(iAsicReady);
         
         wait for 10 us;
         
         -- enable R1 test mode
         axiLiteBusSimWrite(clk, axiWriteMaster, axiWriteSlave, x"00000118", x"01", true);
         -- move sampling point
         axiLiteBusSimWrite(clk, axiWriteMaster, axiWriteSlave, x"00000124", x"80", true);
         wait for 10 us;
         
         -- trigger and wait for the acquisition complete
         wait until falling_edge(clk);
         acqStart <= '1';
         wait until falling_edge(clk);
         acqStart <= '0';
         wait until rising_edge(iAsicReady);
         
         wait for 10 us;
      
      --end loop;
      
      report "Simulation done" severity failure;
      wait;
      
   end process WaveGen_Proc;

   

end architecture sim;

