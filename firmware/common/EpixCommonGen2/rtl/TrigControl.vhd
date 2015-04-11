-------------------------------------------------------------------------------
-- Title         : Trigger Control
-- Project       : EPIX Gen2 Readout
-------------------------------------------------------------------------------
-- File          : TrigControl.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 05/21/2013
-------------------------------------------------------------------------------
-- Description:
-- Trigger control block
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/17/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity TrigControl is
   port ( 

      -- Master system clock
      sysClk        : in  std_logic;
      sysClkRst     : in  std_logic;
      -- PGP clocks and reset
      pgpClk        : in  sl;
      pgpClkRst     : in  sl;
      -- Inputs
      runTrigger    : in  std_logic;
      daqTrigger    : in  std_logic;
      ssiCmd        : in  SsiCmdMasterType;
      pgpRxOut      : in  Pgp2bRxOutType;
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
   signal pgpSidebandRun  : sl;
   signal pgpSidebandDaq  : sl;
   signal coreSidebandRun : sl;
   signal coreSidebandDaq : sl;
   signal ttlSidebandRun  : sl;
   signal ttlSidebandDaq  : sl;   
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
   signal swRun           : std_logic;
   signal swRead          : std_logic;
   signal iRunTrigOut     : std_logic;
   signal iDaqTrigOut     : std_logic;
   signal hwRunTrig     : std_logic;
   signal hwDaqTrig     : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -----------------------------------
   -- SW Triggers:
   --   Run trigger is opCode x00
   --   DAQ trigger trails by 1 clock
   -----------------------------------
   U_TrigPulser : entity work.SsiCmdMasterPulser
      generic map (
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1
      )
      port map (
          -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"00",
         -- output pulse to sync module
         syncPulse   => swRun,
         -- Local clock and reset
         locClk      => sysClk,
         locRst      => sysClkRst              
      );
   process(sysClk,sysClkRst) begin
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
   --   Run trigger - programmable opCode 
   --   DAQ trigger - programmable opCode 
   -----------------------------------------
   process ( pgpClk ) begin
      if rising_edge(pgpClk) then
         if ( pgpClkRst = '1' ) then
            pgpSidebandRun <= '0' after tpd;
            pgpSidebandDaq <= '0' after tpd;
         elsif pgpRxOut.opCodeEn = '1' then
            pgpSidebandRun <= '1' after tpd;
         else
            pgpSidebandRun <= '0' after tpd;
         end if;
         pgpSidebandDaq <= pgpSidebandRun;
      end if;
   end process;
   -- Synchronize PGP sideband triggers to core clock
   U_PgpRunSync : entity work.Synchronizer
      port map (
         clk     => sysClk,
         rst     => sysClkRst,
         dataIn  => pgpSidebandRun,
         dataOut => coreSidebandRun
      );
   U_PgpDaqSync : entity work.Synchronizer
      port map (
         clk     => sysClk,
         rst     => sysClkRst,
         dataIn  => pgpSidebandDaq,
         dataOut => coreSidebandDaq
      );

   --------------------------------------------------
   -- Combine with TTL triggers and look for edges --
   --------------------------------------------------
   combinedRunTrig <= coreSidebandRun or runTrigger;
   combinedDaqTrig <= coreSidebandDaq or daqTrigger;
   
   --------------------------------
   -- Run Input
   --------------------------------   
   -- Edge Detect
   U_RunEdge : entity work.SynchronizerEdge 
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
   U_AcqEdge : entity work.SynchronizerEdge 
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
      runEn         => epixConfig.autoRunEn and epixConfig.runTriggerEnable,
      daqEn         => epixConfig.autoDaqEn and epixConfig.daqTriggerEnable,
      -- Outputs
      runTrigOut    => iRunTrigOut,
      daqTrigOut    => iDaqTrigOut
   );

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

