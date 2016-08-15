-------------------------------------------------------------------------------
-- Title         : Virtual Oscilloscope Types
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : ScopeTypes.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 03/10/2014
-------------------------------------------------------------------------------
-- Description:
-- Types for EPIX virtual oscilloscope
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/10/2014: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package ScopeTypes is

   --------------------------------------------
   -- Configuration Type
   --------------------------------------------

   -- Record
   type ScopeConfigType is record
      scopeEnable       : std_logic;
      triggerEdge       : std_logic;
      triggerChannel    : std_logic_vector(3 downto 0);
      triggerMode       : std_logic_vector(1 downto 0);
      triggerAdcThresh  : std_logic_vector(15 downto 0);
      triggerHoldoff    : std_logic_vector(12 downto 0);
      triggerOffset     : std_logic_vector(12 downto 0);
      traceLength       : std_logic_vector(12 downto 0);
      skipSamples       : std_logic_vector(12 downto 0);
      inputChannelA     : std_logic_vector(4 downto 0);
      inputChannelB     : std_logic_vector(4 downto 0);
      arm               : std_logic;
      trig              : std_logic;
   end record;

   -- Initialize
   constant ScopeConfigInit : ScopeConfigType := ( 
      scopeEnable      => '0',
      triggerEdge      => '0',
      triggerChannel   => (others => '0'), 
      triggerMode      => (others => '0'), 
      triggerAdcThresh => (others => '0'),
      triggerHoldoff   => (others => '0'),
      triggerOffset    => (others => '0'),
      traceLength      => (others => '0'),
      skipSamples      => (others => '0'),
      inputChannelA    => (others => '0'),
      inputChannelB    => (others => '0'),
      arm              => '0',
      trig             => '0'
   ); 
   
end ScopeTypes;
