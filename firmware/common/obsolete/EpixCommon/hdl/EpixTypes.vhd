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
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
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
   type adcWord6_array is array ( NATURAL range <> ) of word6_array(7 downto 0);
   
   --Maximum oversampling rate supported
   constant MAX_OVERSAMPLE : integer := 2;
   --Number of columns in an ePix row
   constant EPIX100_COLS_PER_ROW : integer := 96;
   constant EPIX10K_COLS_PER_ROW : integer := 48;
   constant EPIXS_COLS_PER_ROW   : integer := 10;

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
      frameDelay        : word6_array(2 downto 0);
      dataDelay         : adcWord6_array(1 downto 0);
      monDataDelay      : word6_array(3 downto 0);
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
      doutPipelineDelay : std_logic_vector(31 downto 0);
      syncWidth         : std_logic_vector(15 downto 0);
      syncDelay         : std_logic_vector(15 downto 0);
      prePulseR0Width   : std_logic_vector(31 downto 0);
      prePulseR0Delay   : std_logic_vector(31 downto 0);
      prePulseR0        : std_logic;
      asicR0Mode        : std_logic;
      testPattern       : std_logic;
      adcStreamMode     : std_logic;
      asicMask          : std_logic_vector(3 downto 0);
      syncMode          : std_logic_vector(1 downto 0);
      tpsEdge           : std_logic;
      tpsDelay          : std_logic_vector(15 downto 0);
      autoTrigPeriod    : std_logic_vector(31 downto 0);
      autoRunEn         : std_logic;
      autoDaqEn         : std_logic;
      asicPPmatToReadout: std_logic_vector(31 downto 0);
   end record;

   -- Initialize
   constant EpixConfigInit : EpixConfigType := ( 
      runTriggerEnable  => '0',
      runTriggerDelay   => (others=>'0'),
      daqTriggerEnable  => '0',
      daqTriggerDelay   => (others=>'0'),
      acqCountReset     => '0',
      seqCountReset     => '0',
      frameDelay        => (others=> (others=>'0')),
      dataDelay         => (others=> (others=> (others => '0'))),
      monDataDelay      => (others=> (others=>'0')),
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
      doutPipelineDelay => (others=>'0'),
      syncMode          => (others=>'0'),
      syncWidth         => (others=>'0'),
      syncDelay         => (others=>'0'),
      prePulseR0        => '0',
      asicR0Mode        => '0',
      prePulseR0Width   => (others => '0'),
      prePulseR0Delay   => (others => '0'),
      testPattern       => '0',
      adcStreamMode     => '0',
      asicMask          => (others => '0'),
      tpsEdge           => '0',
      tpsDelay          => (others => '0'),
      autoTrigPeriod    => (others => '0'),
      autoRunEn         => '0',
      autoDaqEn         => '0',
      asicPPmatToReadout=> (others => '0')
   ); 

   --Functions to allow use of EPIX100 or 10k
   function getNumColumns ( version : std_logic_vector ) return integer;
   function getWordsPerSuperRow ( version : std_logic_vector ) return integer;

   constant NCOL_C : integer := getNumColumns(FpgaVersion);
   --Number of columns in ePix "super row"
   -- (columns / ch) * (channels / asic) * (asics / row) / (adc values / word)
   -- constant WORDS_PER_SUPER_ROW_C : integer := NCOL_C * 4 * 2 / 2; 
   constant WORDS_PER_SUPER_ROW_C : integer := getWordsPerSuperRow(FpgaVersion); 

   
end EpixTypes;

package body EpixTypes is

   function getNumColumns (version : std_logic_vector ) return integer is
   begin
      --Epix 100p and Epix100a
      if (version(31 downto 24) = x"E0" or version(31 downto 24) = x"EA") then
         return EPIX100_COLS_PER_ROW;
      --Epix 10k
      elsif (version(31 downto 24) = x"E2") then
         return EPIX10K_COLS_PER_ROW;
      --Epix S
      elsif (version(31 downto 24) = x"E3") then
         return EPIXS_COLS_PER_ROW;
      --Other (default to Epix 100)
      else
         return EPIX100_COLS_PER_ROW;
      end if;
   end function;

   function getWordsPerSuperRow (version : std_logic_vector ) return integer is
   begin
      --EpixS reads only the active ASICs
      if (version(31 downto 24) = x"E3") then
         return EPIXS_COLS_PER_ROW * 2 / 2;
      --Other
      else
         return NCOL_C * 4 * 2 / 2;
      end if;
   end function;

end package body EpixTypes;
