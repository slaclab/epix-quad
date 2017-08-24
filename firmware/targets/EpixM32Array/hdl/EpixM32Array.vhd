-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixM32Array.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 09/30/2015
-- Last update: 09/30/2015
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;


library unisim;
use unisim.vcomponents.all;

entity EpixM32Array is
   generic (
      TPD_G : time := 1 ns;
      FPGA_BASE_CLOCK_G : slv(31 downto 0) := x"00" & x"100000"; 
      BUILD_INFO_G  : BuildInfoType
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
      -- Guard ring DAC
      vGuardDacSclk       : out sl;
      vGuardDacDin        : out sl;
      vGuardDacCsb        : out sl;
      vGuardDacClrb       : out sl;
      -- External Signals
      runTg               : in  sl;
      daqTg               : in  sl;
      mps                 : out sl;
      tgOut               : out sl;
      -- Board IDs
      snIoAdcCard         : inout sl;
      snIoCarrier         : inout sl;
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
      adcClkP             : out slv( 0 downto 0);
      adcClkM             : out slv( 0 downto 0);
      adcDoClkP           : in  slv( 1 downto 0);
      adcDoClkM           : in  slv( 1 downto 0);
      adcFrameClkP        : in  slv( 1 downto 0);
      adcFrameClkM        : in  slv( 1 downto 0);
      adcDoP              : in  slv(15 downto 0);
      adcDoM              : in  slv(15 downto 0);
      -- ASIC Control
      asicGr              : out sl;
      asicClk             : out sl;
      asicR1              : out sl;
      asicR2              : out sl;
      asicR3              : out sl;
      vbufOe              : out sl;
--      asicDoutP           : in  slv(3 downto 0);
--      asicDoutM           : in  slv(3 downto 0);
--      asicRoClkP          : out slv(3 downto 0);
--      asicRoClkM          : out slv(3 downto 0);
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl;
      -- DDR pins
      ddr3_dq             : inout slv(31 downto 0);
      ddr3_dqs_n          : inout slv(3 downto 0);
      ddr3_dqs_p          : inout slv(3 downto 0);
      ddr3_addr           : out   slv(14 downto 0);
      ddr3_ba             : out   slv(2 downto 0);
      ddr3_ras_n          : out   sl;
      ddr3_cas_n          : out   sl;
      ddr3_we_n           : out   sl;
      ddr3_reset_n        : out   sl;
      ddr3_ck_p           : out   slv(0 to 0);
      ddr3_ck_n           : out   slv(0 to 0);
      ddr3_cke            : out   slv(0 to 0);
      ddr3_cs_n           : out   slv(0 to 0);
      ddr3_dm             : out   slv(3 downto 0);
      ddr3_odt            : out   slv(0 to 0)
      
      -- TODO: Add I2C pins for SFP
      -- TODO: Add sync pins for DC/DCs
   );
end EpixM32Array;

architecture top_level of EpixM32Array is
   signal iLed          : slv(3 downto 0);
   signal iFpgaOutputEn : sl;
   signal iLedEn        : sl;
   
   -- Internal versions of signals so that we don't
   -- drive anything unpowered until the components
   -- are online.
   signal iRunTg : sl;
   signal iDaqTg : sl;
   signal iMps   : sl;
   signal iTgOut : sl;
   
   signal iSerialIdIo : slv(1 downto 0);
   
   signal iAdcPdwn       : slv(2 downto 0);
   signal iAdcSpiCsb     : slv(2 downto 0);
   signal iAdcSpiClk     : sl;   
   signal iAdcClkP       : slv( 0 downto 0);
   signal iAdcClkM       : slv( 0 downto 0);
   
   signal iBootCsL      : sl;
   signal iBootMosi     : sl;
   
   signal iAsicGlblRst    : sl;
   signal iAsicR1         : sl;
   signal iAsicR2         : sl;
   signal iAsicR3         : sl;
   signal iAsicClk        : sl;
   signal iAsicDout     : slv(3 downto 0);
   
   
begin
   
   ---------------------------
   -- Core block            --
   ---------------------------
   U_EpixCore : entity work.EpixM32ArrayCore
      generic map (
         TPD_G => TPD_G,
         FPGA_BASE_CLOCK_G => FPGA_BASE_CLOCK_G,
         BUILD_INFO_G => BUILD_INFO_G,
         -- Polarity of selected LVDS data lanes is swapped on gen2 ADC board
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
         -- External Signals
         runTrigger          => iRunTg,
         daqTrigger          => iDaqTg,
         mpsOut              => iMps,
         triggerOut          => iTgOut,
         -- Board IDs
         serialIdIo(1)       => snIoCarrier,
         serialIdIo(0)       => snIoAdcCard,
         -- Slow ADC
         slowAdcRefClk       => slowAdcRefClk,
         slowAdcSclk         => slowAdcSclk,
         slowAdcDin          => slowAdcDin,
         slowAdcCsb          => slowAdcCsb,
         slowAdcDout         => slowAdcDout,
         slowAdcDrdy         => slowAdcDrdy,
         -- Fast ADC Control
         adcSpiClk           => iAdcSpiClk,
         adcSpiData          => adcSpiData,
         adcSpiCsb           => iAdcSpiCsb,
         adcPdwn             => iAdcPdwn,
         -- Fast ADC readout
         adcClkP             => iAdcClkP,
         adcClkN             => iAdcClkM,
         adcFClkP            => adcFrameClkP,
         adcFClkN            => adcFrameClkM,
         adcDClkP            => adcDoClkP,
         adcDClkN            => adcDoClkM,
         adcChP              => adcDoP,
         adcChN              => adcDoM,
         -- ASIC Control
         asicGlblRst         => iAsicGlblRst,
         asicR1              => iAsicR1,
         asicR2              => iAsicR2,
         asicR3              => iAsicR3,
         asicClk             => iAsicClk,
         -- ASIC digital data
         asicDout            => iAsicDout,
         -- Boot Memory Ports
         bootCsL             => iBootCsL,
         bootMosi            => iBootMosi,
         bootMiso            => bootMiso
      );
      
      adcClkP(0) <= iAdcClkP(0);      
      adcClkM(0) <= iAdcClkM(0);
      

   ----------------------------
   -- Map ports/signals/etc. --
   ----------------------------
   led <= iLed when iLedEn = '1' else (others => '0');
   
   -- Boot Memory Ports
   bootCsL  <= iBootCsL    when iFpgaOutputEn = '1' else 'Z';
   bootMosi <= iBootMosi   when iFpgaOutputEn = '1' else 'Z';
   
   -- TTL interfaces (accounting for inverters on ADC card)
   mps    <= not(iMps)   when iFpgaOutputEn = '1' else 'Z';
   tgOut  <= not(iTgOut) when iFpgaOutputEn = '1' else 'Z';
   iRunTg <= not(runTg);
   iDaqTg <= not(daqTg);

   -- Fast ADC Configuration
   adcSpiClk     <= iAdcSpiClk when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(0)  <= iAdcSpiCsb(0) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(1)  <= iAdcSpiCsb(1) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(2)  <= iAdcSpiCsb(2) when iFpgaOutputEn = '1' else 'Z';
   adcPdwn01     <= iAdcPdwn(0) when iFpgaOutputEn = '1' else '0';
   adcPdwnMon    <= iAdcPdwn(2) when iFpgaOutputEn = '1' else '0';
   
   -- ASIC control signals (single ended)   
   asicGr      <= iAsicGlblRst when iFpgaOutputEn = '1' else 'Z';
   asicClk     <= iAsicClk     when iFpgaOutputEn = '1' else 'Z';
   asicR1      <= iAsicR1      when iFpgaOutputEn = '1' else 'Z';
   asicR2      <= iAsicR2      when iFpgaOutputEn = '1' else 'Z';
   asicR3      <= iAsicR3      when iFpgaOutputEn = '1' else 'Z';
   vbufOe      <= iFpgaOutputEn;
   
end top_level;
