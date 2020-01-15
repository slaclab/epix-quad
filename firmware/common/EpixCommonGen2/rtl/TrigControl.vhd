-------------------------------------------------------------------------------
-- Title         : Trigger Control
-- Project       : EPIX Gen2 Readout
-------------------------------------------------------------------------------
-- File       : TrigControl.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Trigger control block
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

use work.EpixPkgGen2.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity TrigControl is
   port ( 

      -- Master system clock
      sysClk        : in  std_logic;
      sysClkRst     : in  std_logic;
      -- Inputs
      runTrigger    : in  std_logic;
      daqTrigger    : in  std_logic;
      swRun         : in   sl;
      pgpOpCode     : in   slv(7 downto 0);
      pgpOpCodeEn   : in   sl;
      -- Fiducial code output
      opCodeOut     : out slv(7 downto 0);
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
   signal coreSidebandRun : sl;
   signal coreSidebandDaq : sl;
   signal combinedRunTrig : sl;
   signal combinedDaqTrig : sl;
   
   signal runTriggerEdge  : std_logic;
   signal daqTriggerEdge  : std_logic;
   signal runTriggerCnt   : std_logic_vector(31 downto 0);
   signal daqTriggerCnt   : std_logic_vector(31 downto 0);
   signal runTriggerOut   : std_logic;
   signal daqTriggerOut   : std_logic;
   signal countEnable     : std_logic;
   signal intCount        : std_logic_vector(31 downto 0);
   signal swRead          : std_logic;
   signal iRunTrigOut     : std_logic;
   signal iDaqTrigOut     : std_logic;
   signal hwRunTrig     : std_logic;
   signal hwDaqTrig     : std_logic;
   signal autoRunEn     : std_logic;
   signal autoDaqEn     : std_logic;
   signal pgpTrigEn     : std_logic;
   
   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin
   
   -----------------------------------
   -- SW Triggers:
   -- Run trigger is opCode x00
   -----------------------------------
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            swRead <= '0' after tpd;
         else
            swRead <= swRun after tpd;
         end if;
      end if;
   end process;

   -----------------------------------------
   -- PGP Sideband Triggers:
   -- Any op code is a trigger, 
   -- actual opcode is the fiducial.
   -----------------------------------------
   -- Map op code to output port
   -- Have sideband DAQ lag 1 cycle behind sideband run
   coreSidebandRun <= pgpOpCodeEn;
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            opCodeOut <= (others => '0') after tpd;
         elsif coreSidebandRun = '1' then
            opCodeOut <= pgpOpCode after tpd;
         end if;
         coreSidebandDaq <= coreSidebandRun;
      end if;
   end process;
      
   --------------------------------------------------
   -- Combine with TTL triggers and look for edges --
   --------------------------------------------------
   combinedRunTrig <= (coreSidebandRun and pgpTrigEn) or (runTrigger and not pgpTrigEn);
   combinedDaqTrig <= (coreSidebandDaq and pgpTrigEn) or (daqTrigger and not pgpTrigEn);
   
   pgpTrigEn <= epixConfig.pgpTrigEn;
   
   --------------------------------
   -- Run Input
   --------------------------------   
   -- Edge Detect
   U_RunEdge : entity surf.SynchronizerEdge 
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => combinedRunTrig,
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
   -- DAQ trigger input
   --------------------------------

   -- Edge Detect
   U_AcqEdge : entity surf.SynchronizerEdge 
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => combinedDaqTrig,
         risingEdge => daqTriggerEdge
      );
   
   -- Delay
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         daqTriggerCnt  <= (others=>'0') after tpd;
         daqTriggerOut  <= '0'           after tpd;
      elsif rising_edge(sysClk) then

         -- DAQ trigger is disabled
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
   -- External triggers
   --------------------------------
   hwRunTrig <= runTriggerOut;
   hwDaqTrig <= daqTriggerOut;

   --------------------------------
   -- Autotrigger block
   --------------------------------
   U_AutoTrig : entity work.AutoTrigger
   port map (
      -- Sync clock and reset
      sysClk        => sysClk,
      sysClkRst     => sysClkRst,
      -- Inputs 
      runTrigIn     => hwRunTrig,
      daqTrigIn     => hwDaqTrig,
      -- Number of clock cycles between triggers
      trigPeriod    => epixConfig.autoTrigPeriod,
      --Enable run and daq triggers
      runEn         => autoRunEn,
      daqEn         => autoDaqEn,
      -- Outputs
      runTrigOut    => iRunTrigOut,
      daqTrigOut    => iDaqTrigOut
   );
   
   autoRunEn <= epixConfig.autoRunEn and epixConfig.runTriggerEnable;
   autoDaqEn <= epixConfig.autoDaqEn and epixConfig.daqTriggerEnable;

   --------------------------------
   -- Acquisition Counter And Outputs
   --------------------------------
   acqStart   <= iRunTrigOut or swRun;
   dataSend   <= iDaqTrigOut or swRead;
   acqCount   <= intCount;

   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         intCount    <= (others=>'0') after tpd;
         countEnable <= '0'           after tpd;
      elsif rising_edge(sysClk) then
         countEnable <= iRunTrigOut or swRun after tpd;

         if epixConfig.acqCountReset = '1' then
            intCount <= (others=>'0') after tpd;
         elsif countEnable = '1' then
            intCount <= intCount + 1 after tpd;
         end if;
      end if;
   end process;

end TrigControl;

