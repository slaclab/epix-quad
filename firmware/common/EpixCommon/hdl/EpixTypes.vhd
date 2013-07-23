-------------------------------------------------------------------------------
-- Title         : EPIX Project Types
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : EpixTypes.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/14/2013
-------------------------------------------------------------------------------
-- Description:
-- Epix Project Types
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/13/2013: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package EpixTypes is

   subtype WORD16 is STD_LOGIC_VECTOR (15 downto 0);
   type word16_array is array ( NATURAL range <> ) of WORD16;

   subtype WORD8 is STD_LOGIC_VECTOR (7 downto 0);
   type word8_array is array ( NATURAL range <> ) of WORD8;

   subtype WORD7 is STD_LOGIC_VECTOR (6 downto 0);
   type word7_array is array ( NATURAL range <> ) of WORD7;

   subtype WORD6 is STD_LOGIC_VECTOR (5 downto 0);
   type word6_array is array ( NATURAL range <> ) of WORD6;

   --------------------------------------------
   -- Configuration Type
   --------------------------------------------

   -- Record
   type EpixConfigType is record
      runTriggerEnable  : std_logic;
      runTriggerDelay   : std_logic_vector(31 downto 0);
      daqTriggerDelay   : std_logic_vector(31 downto 0);
      daqTriggerEnable  : std_logic;
      acqCountReset     : std_logic;
      acqToAsicR0Delay  : std_logic_vector(31 downto 0);
      asicR0ToAsicAcq   : std_logic_vector(31 downto 0);
      asicAcqWidth      : std_logic_vector(31 downto 0);
      asicAcqLToPPmatL  : std_logic_vector(31 downto 0);
      asicRoClkHalfT    : std_logic_vector(31 downto 0);
      adcReadsPerPixel  : std_logic_vector(31 downto 0);
      adcClkHalfT       : std_logic_vector(31 downto 0);
      saciClkBit        : std_logic_vector(31 downto 0);
      --Should this be a register or determined on the fly?
      totalPixelsToRead : std_logic_vector(31 downto 0);
   end record;

   -- Initialize
   constant EpixConfigInit : EpixConfigType := ( 
      runTriggerEnable  => '0',
      runTriggerDelay   => (others=>'0'),
      daqTriggerEnable  => '0',
      daqTriggerDelay   => (others=>'0'),
      acqCountReset     => '0',
      acqToAsicR0Delay  => (others=>'0'),
      asicR0ToAsicAcq   => (others=>'0'),
      asicAcqWidth      => (others=>'0'),
      asicAcqLToPPmatL  => (others=>'0'),
      asicRoClkHalfT    => (others=>'0'),
      adcReadsPerPixel  => (others=>'0'),
      adcClkHalfT       => (others=>'0'),
      totalPixelsToRead => (others=>'0'),
      saciClkBit        => (others=>'0')
   ); 
   
end EpixTypes;

