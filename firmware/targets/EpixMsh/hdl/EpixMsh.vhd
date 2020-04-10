-------------------------------------------------------------------------------
-- File       : EpixMsh.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SsiCmdMasterPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixMsh is
   generic (
      TPD_G          : time := 1 ns;
      BUILD_INFO_G   : BuildInfoType
   );
   port (
      -- Debugging IOs
      led                 : out slv(3 downto 0);
      -- Power good
      powerGood           : in  sl;
      -- Power Control
      analogCardDigPwrEn  : out sl;
      analogCardAnaPwrEn  : out sl;
      -- GT CLK Pins
      gtRefClk0P          : in  sl;
      gtRefClk0N          : in  sl;
      -- SFP TX/RX
      gtDataTxP           : out sl;
      gtDataTxN           : out sl;
      gtDataRxP           : in  sl;
      gtDataRxN           : in  sl;
      -- SFP control signals
      sfpDisable          : out sl;
      -- DACs
      dacSclk             : out sl;
      dacDin              : out sl;
      dacCs               : out slv(1 downto 0);
      -- External Signals
      runTg               : in  sl;
      daqTg               : in  sl;
      mps                 : out sl;
      tgOut               : out sl;
      -- Board IDs
      snIoAdcCard         : inout sl;
      -- Slow ADC
      slowAdcSclk         : out sl;
      slowAdcDin          : out sl;
      slowAdcCsb          : out sl;
      slowAdcRefClk       : out sl;
      slowAdcDout         : in  sl;
      slowAdcDrdy         : in  sl;
      slowAdcSync         : out sl; --unconnected by default
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiData          : inout sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn01           : out sl;
      adcPdwnMon          : out sl;
      -- ADC readout signals
      adcClkP             : out slv(1 downto 0);
      adcClkM             : out slv(1 downto 0);
      adcDoClkP           : in  slv(2 downto 0);
      adcDoClkM           : in  slv(2 downto 0);
      adcFrameClkP        : in  slv(2 downto 0);
      adcFrameClkM        : in  slv(2 downto 0);
      adcDoP              : in  slv(19 downto 0);
      adcDoM              : in  slv(19 downto 0);
      -- ASIC Control
      asicGR              : out sl;
      asicCk              : out sl;
      asicRst             : out sl;
      asicCdsBline        : out sl;
      asicRstComp         : out sl;
      asicSampleN         : out sl;
      asicDinjEn          : out sl;
      asicCKinjEn         : out sl;
      bufEn               : out sl; -- enable level translator
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
   );
end EpixMsh;

architecture top_level of EpixMsh is
   signal iLed          : slv(3 downto 0);
   signal iFpgaOutputEn : sl;
   signal iLedEn        : sl;
   
   -- Internal versions of signals so that we don't
   -- drive anything unpowered until the components
   -- are online.
   signal iDacSclk   : sl;
   signal iDacDin    : sl;
   signal iDacCs     : slv(1 downto 0);
   
   signal iRunTg : sl;
   signal iDaqTg : sl;
   signal iMps   : sl;
   signal iTgOut : sl;
   
   signal iAdcSpiDataOut : sl;
   signal iAdcSpiDataIn   : sl;
   signal iAdcSpiDataEn  : sl;
   signal iAdcPdwn       : slv(2 downto 0);
   signal iAdcSpiCsb     : slv(2 downto 0);
   signal iAdcSpiClk     : sl;   
   signal iAdcClk        : sl;
   
   signal iBootCsL      : sl;
   signal iBootMosi     : sl;
   
   signal iAsicGR          : sl;
   signal iAsicCk          : sl;
   signal iAsicRst         : sl;
   signal iAsicCdsBline    : sl;
   signal iAsicRstComp     : sl;
   signal iAsicSampleN     : sl;
   signal iAsicDinjEn      : sl;
   signal iAsicCKinjEn     : sl;
   
begin
   
   bufEn <= '1';
   
   ---------------------------
   -- Core block            --
   ---------------------------
   U_EpixCore : entity work.EpixMCore
      generic map (
         TPD_G             => TPD_G,
         BUILD_INFO_G      => BUILD_INFO_G,
         ADC1_INVERT_CH    => "10000000",
         ADC2_INVERT_CH    => "00000010"
      )
      port map (
         -- Debugging IOs
         led                 => iLed,
         -- Power enables
         digitalPowerEn      => analogCardDigPwrEn,
         analogPowerEn       => analogCardAnaPwrEn,
         fpgaOutputEn        => iFpgaOutputEn,
         ledEn               => iLedEn,
         -- Clocks and reset
         powerGood           => powerGood,
         gtRefClk0P          => gtRefClk0P,
         gtRefClk0N          => gtRefClk0N,
         -- SFP interfaces
         sfpDisable          => sfpDisable,
         -- SFP TX/RX
         gtDataRxP           => gtDataRxP,
         gtDataRxN           => gtDataRxN,
         gtDataTxP           => gtDataTxP,
         gtDataTxN           => gtDataTxN,
         -- DAC
         dacSclk             => iDacSclk,
         dacDin              => iDacDin,
         dacCs               => iDacCs,
         -- External Signals
         runTrigger          => iRunTg,
         daqTrigger          => iDaqTg,
         mpsOut              => iMps,
         triggerOut          => iTgOut,
         -- Slow ADC
         slowAdcRefClk       => slowAdcRefClk,
         slowAdcSclk         => slowAdcSclk,
         slowAdcDin          => slowAdcDin,
         slowAdcCsb          => slowAdcCsb,
         slowAdcDout         => slowAdcDout,
         slowAdcDrdy         => slowAdcDrdy,
         -- Fast ADC Control
         adcSpiClk           => iAdcSpiClk,
         adcSpiDataOut       => iAdcSpiDataOut,
         adcSpiDataIn        => iAdcSpiDataIn,
         adcSpiDataEn        => iAdcSpiDataEn,
         adcSpiCsb           => iAdcSpiCsb,
         adcPdwn             => iAdcPdwn,
         -- Fast ADC readout
         adcClk              => iAdcClk,
         adcFClkP            => adcFrameClkP,
         adcFClkN            => adcFrameClkM,
         adcDClkP            => adcDoClkP,
         adcDClkN            => adcDoClkM,
         adcChP              => adcDoP,
         adcChN              => adcDoM,
         -- ASIC Control
         asicGR              => iAsicGR      ,
         asicCk              => iAsicCk      ,
         asicRst             => iAsicRst     ,
         asicCdsBline        => iAsicCdsBline,
         asicRstComp         => iAsicRstComp ,
         asicSampleN         => iAsicSampleN ,
         asicDinjEn          => iAsicDinjEn  ,
         asicCKinjEn         => iAsicCKinjEn ,
         -- Boot Memory Ports
         bootCsL             => iBootCsL,
         bootMosi            => iBootMosi,
         bootMiso            => bootMiso
      );
      
   -- ADC Clock outputs
   U_AdcClk0 : OBUFDS port map ( I => iAdcClk, O => adcClkP(0), OB => adcClkM(0) );
   U_AdcClk1 : OBUFDS port map ( I => iAdcClk, O => adcClkP(1), OB => adcClkM(1) );

   ----------------------------
   -- Map ports/signals/etc. --
   ----------------------------
   led <= iLed when iLedEn = '1' else (others => '0');
   
   -- Boot Memory Ports
   bootCsL  <= iBootCsL    when iFpgaOutputEn = '1' else 'Z';
   bootMosi <= iBootMosi   when iFpgaOutputEn = '1' else 'Z';
   
   -- DAC
   dacSclk  <= iDacSclk  when iFpgaOutputEn = '1' else 'Z';
   dacDin   <= iDacDin   when iFpgaOutputEn = '1' else 'Z';
   dacCs(0) <= iDacCs(0) when iFpgaOutputEn = '1' else 'Z';
   dacCs(1) <= iDacCs(1) when iFpgaOutputEn = '1' else 'Z';
   
   -- TTL interfaces (accounting for inverters on ADC card)
   mps    <= not(iMps)   when iFpgaOutputEn = '1' else 'Z';
   tgOut  <= not(iTgOut) when iFpgaOutputEn = '1' else 'Z';
   iRunTg <= not(runTg);
   iDaqTg <= not(daqTg);

   -- Fast ADC Configuration
   adcSpiClk     <= iAdcSpiClk when iFpgaOutputEn = '1' else 'Z';
   --adcSpiData    <= '0' when iAdcSpiDataOut = '0' and iAdcSpiDataEn = '1' and iFpgaOutputEn = '1' else 'Z';
   adcSpiData    <= iAdcSpiDataOut when  iAdcSpiDataEn = '1' and iFpgaOutputEn = '1' else 'Z';
   iAdcSpiDataIn <= adcSpiData;
   adcSpiCsb(0)  <= iAdcSpiCsb(0) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(1)  <= iAdcSpiCsb(1) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(2)  <= iAdcSpiCsb(2) when iFpgaOutputEn = '1' else 'Z';
   adcPdwn01     <= iAdcPdwn(0) when iFpgaOutputEn = '1' else '0';
   adcPdwnMon    <= '0';
   
   -- ASIC control signals (single ended)
   asicGR       <= iAsicGR       when iFpgaOutputEn = '1' else 'Z';
   asicCk       <= iAsicCk       when iFpgaOutputEn = '1' else 'Z';
   asicRst      <= iAsicRst      when iFpgaOutputEn = '1' else 'Z';
   asicCdsBline <= iAsicCdsBline when iFpgaOutputEn = '1' else 'Z';
   asicRstComp  <= iAsicRstComp  when iFpgaOutputEn = '1' else 'Z';
   asicSampleN  <= iAsicSampleN  when iFpgaOutputEn = '1' else 'Z';
   asicDinjEn   <= iAsicDinjEn   when iFpgaOutputEn = '1' else 'Z';
   asicCKinjEn  <= iAsicCKinjEn  when iFpgaOutputEn = '1' else 'Z';
   
end top_level;
