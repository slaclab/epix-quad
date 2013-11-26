-------------------------------------------------------------------------------
-- Title         : Trigger Control
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : TrigControl.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/21/2013
-------------------------------------------------------------------------------
-- Description:
-- Trigger control block
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
use work.Pgp2AppTypesPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity TrigControl is
   port ( 

      -- Master system clock, 125Mhz
      sysClk        : in  std_logic;
      sysClkRst     : in  std_logic;

      -- Inputs
      runTrigger    : in  std_logic;
      daqTrigger    : in  std_logic;
      pgpCmd        : in  CmdSlaveOutType;

      -- Configuration
      epixConfig    : in  EpixConfigType;

      -- Outputs
      acqCount      : out std_logic_vector(31 downto 0);
      acqStart      : out std_logic;
      dataSend      : out std_logic
   );

end TrigControl;

-- Define architecture
architecture TrigControl of TrigControl is

   -- Local Signals
   signal runTriggerEdge  : std_logic;
   signal daqTriggerEdge  : std_logic;
   signal runTriggerCnt   : std_logic_vector(31 downto 0);
   signal daqTriggerCnt   : std_logic_vector(31 downto 0);
   signal runTriggerOut   : std_logic;
   signal daqTriggerOut   : std_logic;
   signal countEnable     : std_logic;
   signal intCount        : std_logic_vector(31 downto 0);
   signal swRun           : std_logic;
   signal swRead          : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   --------------------------------
   -- SW Input
   --------------------------------
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         swRun  <= '0' after tpd;
         swRead <= '0' after tpd;
      elsif rising_edge(sysClk) then
         if pgpCmd.cmdEn = '1' and pgpCmd.cmdOpCode = 0 then
            swRun <= '1' after tpd;
         else
            swRun <= '0' after tpd;
         end if;
         swRead <= swRun after tpd;
      end if;
   end process;


   --------------------------------
   -- Run Input
   --------------------------------

   -- Edge Detect
   U_RunEdge : entity work.SynchronizerEdge 
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => runTrigger,
         risingEdge => runTriggerEdge
      );
  
   -- Delay
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         runTriggerCnt  <= (others=>'0') after tpd;
         runTriggerOut  <= '0'           after tpd;
      elsif rising_edge(sysClk) then

         -- Run trigger is disabled
         if epixConfig.runTriggerEnable = '0' then
            runTriggerCnt  <= (others=>'0') after tpd;
            runTriggerOut  <= '0'           after tpd;

         -- Edge detected
         elsif runTriggerEdge = '1' then
            runTriggerCnt <= epixConfig.runTriggerDelay after tpd;

            -- Trigger immediatly if delay is set to zero
            if epixConfig.runTriggerDelay = 0 then
               runTriggerOut <= '1' after tpd;
            else
               runTriggerOut <= '0' after tpd;
            end if;

         -- Stop at zero
         elsif runTriggerCnt = 0 then
            runTriggerOut <= '0' after tpd;

         -- About to reach zero
         elsif runTriggerCnt = 1 then
            runTriggerOut <= '1'           after tpd;
            runTriggerCnt <= (others=>'0') after tpd;

         -- Counting down
         else
            runTriggerOut <= '0'               after tpd;
            runTriggerCnt <= runTriggerCnt - 1 after tpd;
         end if;
      end if;
   end process;

   --------------------------------
   -- Acq Input
   --------------------------------

   -- Edge Detect
   U_AcqEdge : entity work.SynchronizerEdge 
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => daqTrigger,
         risingEdge => daqTriggerEdge
      );
   
   -- Delay
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         daqTriggerCnt  <= (others=>'0') after tpd;
         daqTriggerOut  <= '0'           after tpd;
      elsif rising_edge(sysClk) then

         -- Run trigger is disabled
         if epixConfig.daqTriggerEnable = '0' then
            daqTriggerCnt  <= (others=>'0') after tpd;
            daqTriggerOut  <= '0'           after tpd;

         -- Edge detected
         elsif daqTriggerEdge = '1' then
            daqTriggerCnt <= epixConfig.daqTriggerDelay after tpd;

            -- Trigger immediatly if delay is set to zero
            if epixConfig.daqTriggerDelay = 0 then
               daqTriggerOut <= '1' after tpd;
            else
               daqTriggerOut <= '0' after tpd;
            end if;

         -- Stop at zero
         elsif daqTriggerCnt = 0 then
            daqTriggerOut <= '0' after tpd;

         -- About to reach zero
         elsif daqTriggerCnt = 1 then
            daqTriggerOut <= '1'           after tpd;
            daqTriggerCnt <= (others=>'0') after tpd;

         -- Counting down
         else
            daqTriggerOut <= '0'               after tpd;
            daqTriggerCnt <= daqTriggerCnt - 1 after tpd;
         end if;
      end if;
   end process;

   --------------------------------
   -- Acquisition Counter And Outputs
   --------------------------------
   acqStart   <= runTriggerOut or swRun;
   dataSend   <= daqTriggerOut or swRead;
   acqCount   <= intCount;

   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         intCount    <= (others=>'0') after tpd;
         countEnable <= '0'           after tpd;
      elsif rising_edge(sysClk) then
         countEnable <= runTriggerOut or swRun after tpd;

         if epixConfig.acqCountReset = '1' then
            intCount <= (others=>'0') after tpd;
         elsif countEnable = '1' then
            intCount <= intCount + 1 after tpd;
         end if;
      end if;
   end process;

end TrigControl;

