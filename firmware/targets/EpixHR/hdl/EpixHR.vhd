-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixHR.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-12-11
-- Last update: 2014-12-11
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
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
-- Modification history:
-- 09/01/2015: created.
-- 5/11/2017: Modified form the tPix project to fit the epixHR prototype analog
--            board. 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
use work.EpixHRPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.SaciMasterPkg.all;
use work.Pgp2bPkg.all;


library unisim;
use unisim.vcomponents.all;

entity EpixHR is
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
      SYNC_ANA_DCDC       : out sl;
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
      vBiasDacSclk        : out sl;
      vBiasDacDin         : out sl;
      vBiasDacCsb         : out slv(4 downto 0);
      vBiasDacClrb        : out sl;
      -- wave form (High speed) DAC (DAC8812)
      vWFDacCsL           : out sl;
      vWFDacLdacL         : out sl;

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
      -- ASIC SACI Interface
      asicSaciCmd         : out sl;
      asicSaciClk         : out sl;
      asicSaciSel         : out slv(1 downto 0);
      asicSaciRsp         : in  sl;
      -- ADC readout signals
      adcClkP             : out slv( 1 downto 0);
      adcClkM             : out slv( 1 downto 0);
      adcDoClkP           : in  slv( 2 downto 0);
      adcDoClkM           : in  slv( 2 downto 0);
      adcFrameClkP        : in  slv( 2 downto 0);
      adcFrameClkM        : in  slv( 2 downto 0);
      adcDoP              : in  slv(19 downto 0);
      adcDoM              : in  slv(19 downto 0);
      -- ASIC Control
      asic01DM1           : in sl;
      asic01DM2           : in sl;
      asicTpulse          : out sl;
      asicStart           : out sl;
      asicPPbe            : out sl;
      asicR0              : out sl;
      asicPpmat           : out sl;
      asicGlblRst         : out sl;
      asicSync            : out sl;
      asicAcq             : out sl;
      asicDoutP           : in  slv(1 downto 0);
      asicDoutM           : in  slv(1 downto 0);
      asicRoClkP          : out slv(1 downto 0);
      asicRoClkM          : out slv(1 downto 0);
      asicRefClkP         : out slv(1 downto 0);
      asicRefClkM         : out slv(1 downto 0);
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
      -- TODO: Add DDR pins
      -- TODO: Add I2C pins for SFP
      -- TODO: Add sync pins for DC/DCs
   );
end EpixHR;

architecture RTL of EpixHR is

   signal iFpgaOutputEn : sl;
   
   -- Internal versions of signals so that we don't
   -- drive anything unpowered until the components
   -- are online.
   signal iVBiasDacClrb : slv(4 downto 0);
   signal iVBiasDacSclk : slv(4 downto 0);
   signal iVBiasDacDin  : slv(4 downto 0);
   signal iVBiasDacCsb  : slv(4 downto 0);

   -- wave form (High speed) DAC (DAC8812)
   signal iWFDacCsL            : sl;
   signal iWFDacLdacL          : sl;
   signal iWFDacDin            : sl;
   signal iWFDacSclk           : sl;
   signal iWFDacClrL           : sl;

   
   signal iRunTg : sl;
   signal iDaqTg : sl;
   signal iMps   : sl;
   signal iTgOut : sl;
   
   signal iSerialIdIo : slv(1 downto 0);
   
   signal iSaciClk  : sl;
   signal iSaciSelL : slv(1 downto 0);
   signal iSaciCmd  : sl;
   signal iSaciRsp  : sl;
   
   signal iAdcPdwn       : slv(2 downto 0);
   signal iAdcSpiCsb     : slv(2 downto 0);
   signal iAdcSpiClk     : sl;   
   signal iAdcClkP       : slv( 2 downto 0);
   signal iAdcClkM       : slv( 2 downto 0);
   
   signal iBootCsL      : sl;
   signal iBootMosi     : sl;
   
   signal iAsicRoClk    : slv(1 downto 0);
   signal iAsicRefClk   : slv(1 downto 0);
   signal iAsicR0       : sl;
   signal iAsicAcq      : sl;
   signal iAsicPpmat    : sl;
   signal iAsicPPbe     : sl;
   signal iAsicGlblRst  : sl;
   signal iAsicSync     : sl;
   signal iAsicTpulse   : sl;
   signal iAsicStart    : sl;

   
begin

   ---------------------------------------------------------------------------------
   -- EpixHR Core
   ---------------------------------------------------------------------------------
   U_EpixHR : entity work.EpixHRCore
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
         led                 => led,
         -- Power enables
         digitalPowerEn      => analogCardDigPwrEn,
         analogPowerEn       => analogCardAnaPwrEn,
         fpgaOutputEn        => iFpgaOutputEn,
         syncAnaDcdc         => SYNC_ANA_DCDC,
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
         -- Guard ring DAC
         vBiasDacSclk        => iVBiasDacSclk,
         vBiasDacDin         => iVBiasDacDin,
         vBiasDacCsb         => iVBiasDacCsb,
         vBiasDacClrb        => iVBiasDacClrb,
         -- wave form (High speed) DAC (DAC8812)
         WFDacDin            => iWFDacDin,
         WFDacSclk           => iWFDacSclk,
         WFDacCsL            => iWFDacCsL,
         WFDacLdacL          => iWFDacLdacL,
         WFDacClrL           => iWFDacClrL,
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
         -- SACI
         saciClk             => iSaciClk,
         saciSelL            => iSaciSelL,
         saciCmd             => iSaciCmd,
         saciRsp             => iSaciRsp,
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
         asic01DM1           => asic01DM1,
         asic01DM2           => asic01DM2,
         asicPPbe            => iAsicPPbe,
         asicPpmat           => iAsicPpmat,
         asicTpulse          => iAsicTpulse,
         asicStart           => iAsicStart,
         asicR0              => iAsicR0,
         asicGlblRst         => iAsicGlblRst,
         asicSync            => iAsicSync,
         asicAcq             => iAsicAcq,
         asicDoutP           => asicDoutP,
         asicDoutM           => asicDoutM,
         asicRefClk          => iAsicRefClk,
         asicRoClk           => iAsicRoClk,
         -- Boot Memory Ports
         bootCsL             => iBootCsL,
         bootMosi            => iBootMosi,
         bootMiso            => bootMiso
      );
      
      adcClkP(1) <= iAdcClkP(2);
      adcClkM(1) <= iAdcClkM(2);

   ----------------------------
   -- Map ports/signals/etc. --
   ----------------------------
   
   -- Boot Memory Ports
   bootCsL  <= iBootCsL    when iFpgaOutputEn = '1' else 'Z';
   bootMosi <= iBootMosi   when iFpgaOutputEn = '1' else 'Z';
   
   -- Bias DAC (0 is the guard ring, all others are new)
   vBiasDacSclk <= iVBiasDacSclk(0) or iVBiasDacSclk(1) or iVBiasDacSclk(2) or iVBiasDacSclk(3) or iVBiasDacSclk(4) or iWFDacSclk when iFpgaOutputEn = '1' else 'Z';
   vBiasDacDin  <= iVBiasDacDin(0) or iVBiasDacDin(1) or iVBiasDacDin(2) or iVBiasDacDin(3) or iVBiasDacDin(4)  or iWFDacDin when iFpgaOutputEn = '1' else 'Z';
   vBiasDacCsb  <= iVBiasDacCsb  when iFpgaOutputEn = '1' else (others => 'Z');
   vBiasDacClrb <= ivBiasDacClrb(0) or ivBiasDacClrb(1) or ivBiasDacClrb(2) or ivBiasDacClrb(3) or ivBiasDacClrb(4) or iWFDacClrL when iFpgaOutputEn = '1' else 'Z';

   -- wave form (High speed) DAC (DAC8812)
   vWFDacCsL   <= iWFDacCsL when iFpgaOutputEn = '1' else 'Z';
   vWFDacLdacL <= iWFDacLdacL when iFpgaOutputEn = '1' else 'Z';

   
   -- TTL interfaces (accounting for inverters on ADC card)
   mps    <= not(iMps)   when iFpgaOutputEn = '1' else 'Z';
   tgOut  <= not(iTgOut) when iFpgaOutputEn = '1' else 'Z';
   iRunTg <= not(runTg);
   iDaqTg <= not(daqTg);

   -- ASIC SACI interfaces
   asicSaciCmd    <= iSaciCmd when iFpgaOutputEn = '1' else 'Z';
   asicSaciClk    <= iSaciClk when iFpgaOutputEn = '1' else 'Z';
   G_SACISEL : for i in 0 to 1 generate
      asicSaciSel(i) <= iSaciSelL(i) when iFpgaOutputEn = '1' else 'Z';
   end generate;
   iSaciRsp <= asicSaciRsp;

   -- Fast ADC Configuration
   adcSpiClk     <= iAdcSpiClk when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(0)  <= iAdcSpiCsb(0) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(1)  <= iAdcSpiCsb(1) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(2)  <= iAdcSpiCsb(2) when iFpgaOutputEn = '1' else 'Z';
   adcPdwn01     <= iAdcPdwn(0)   when iFpgaOutputEn = '1' else '0';
   adcPdwnMon    <= iAdcPdwn(2)   when iFpgaOutputEn = '1' else '0';
   
   -- ASIC control signals (differential)
   G_ROCLK : for i in 0 to 1 generate
      U_ASIC_ROCLK_OBUFTDS : OBUFTDS port map ( I => iAsicRoClk(i), T => not(iFpgaOutputEn), O => asicRoClkP(i), OB => asicRoClkM(i) );
      U_ASIC_RFCLK_OBUFTDS : OBUFTDS port map ( I => iAsicRefClk(i), T => not(iFpgaOutputEn), O => asicRefClkP(i), OB => asicRefClkM(i) );
   end generate;
   -- ASIC control signals (single ended)
   asicR0         <= iAsicR0      when iFpgaOutputEn = '1' else 'Z';
   asicAcq        <= iAsicAcq     when iFpgaOutputEn = '1' else 'Z';
   asicPpmat      <= iAsicPpmat   when iFpgaOutputEn = '1' else 'Z';
   asicPPbe       <= iAsicPPbe    when iFpgaOutputEn = '1' else 'Z';
   asicGlblRst    <= iAsicGlblRst when iFpgaOutputEn = '1' else 'Z';
   asicSync       <= iAsicSync    when iFpgaOutputEn = '1' else 'Z';  
   asicTpulse     <= iAsicTpulse  when iFpgaOutputEn = '1' else 'Z';  
   asicStart      <= iAsicStart  when iFpgaOutputEn = '1' else 'Z';  

   
end RTL;
