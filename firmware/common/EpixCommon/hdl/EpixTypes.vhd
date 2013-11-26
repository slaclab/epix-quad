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

   --Maximum oversampling rate supported
   constant MAX_OVERSAMPLE : integer := 2;
   --Number of columns in an ePix row
   constant EPIX_COLS_PER_ROW : integer := 96;

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
      seqCountReset     : std_logic;
      adcDelay          : word6_array(2 downto 0);
      adcDelayUpdate    : std_logic;
      acqToAsicR0Delay  : std_logic_vector(31 downto 0);
      asicR0Width       : std_logic_vector(31 downto 0);
      asicR0ToAsicAcq   : std_logic_vector(31 downto 0);
      asicAcqWidth      : std_logic_vector(31 downto 0);
      asicAcqLToPPmatL  : std_logic_vector(31 downto 0);
      asicRoClkHalfT    : std_logic_vector(31 downto 0);
      adcReadsPerPixel  : std_logic_vector(31 downto 0);
      adcClkHalfT       : std_logic_vector(31 downto 0); 
      totalPixelsToRead : std_logic_vector(31 downto 0);
      saciClkBit        : std_logic_vector(31 downto 0);
      asicPins          : std_logic_vector(5 downto 0);
      manualPinControl  : std_logic_vector(5 downto 0);
      pipelineDelay     : std_logic_vector(31 downto 0);
      adcChannelToRead  : std_logic_vector(31 downto 0);
      prePulseR0Width   : std_logic_vector(31 downto 0);
      prePulseR0Delay   : std_logic_vector(31 downto 0);
      prePulseR0        : std_logic;
      testPattern       : std_logic;
      adcStreamMode     : std_logic;
   end record;

   -- Initialize
   constant EpixConfigInit : EpixConfigType := ( 
      runTriggerEnable  => '0',
      runTriggerDelay   => (others=>'0'),
      daqTriggerEnable  => '0',
      daqTriggerDelay   => (others=>'0'),
      acqCountReset     => '0',
      seqCountReset     => '0',
      adcDelay          => (others=> (others=>'0')),
      adcDelayUpdate    => '0',
      acqToAsicR0Delay  => (others=>'0'),
      asicR0Width       => (others=>'0'),
      asicR0ToAsicAcq   => (others=>'0'),
      asicAcqWidth      => (others=>'0'),
      asicAcqLToPPmatL  => (others=>'0'),
      asicRoClkHalfT    => (others=>'0'),
      adcReadsPerPixel  => (others=>'0'),
      adcClkHalfT       => (others=>'0'),
      totalPixelsToRead => (others=>'0'),
      saciClkBit        => (others=>'0'),
      asicPins          => (others=>'0'),
      manualPinControl  => (others=>'0'),
      pipelineDelay     => (others=>'0'),
      adcChannelToRead  => (others=>'0'),
      prePulseR0        => '0',
      prePulseR0Width   => (others => '0'),
      prePulseR0Delay   => (others => '0'),
      testPattern       => '0',
      adcStreamMode     => '0'
   ); 
   
end EpixTypes;

