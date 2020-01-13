-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Epix10kp.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 07/12/2016
-- Last update: 07/12/2016
-- Platform   : Vivado 2016.1
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

entity Epix10kp is
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
      asicSaciSel         : out slv(3 downto 0);
      asicSaciRsp         : in  slv(3 downto 0);
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
      asicDm1             : inout sl;
      asicR0              : out sl;
      asicPpmat           : out sl;
      asicPpbe            : out sl;
      asicGlblRst         : out sl;
      asicSync            : out sl;
      asicAcq             : out sl;
      asic01DoutP         : in  sl;
      asic01DoutM         : in  sl;
      asic01RoClkP        : out sl;
      asic01RoClkM        : out sl;
      asic23DoutP         : in  sl;
      asic23DoutM         : in  sl;
      asic23RoClkP        : out sl;
      asic23RoClkM        : out sl;
      -- Boot Memory Ports
      bootCsL             : out sl;
      bootMosi            : out sl;
      bootMiso            : in  sl
      -- TODO: Add DDR pins
      -- TODO: Add I2C pins for SFP
      -- TODO: Add sync pins for DC/DCs
   );
end Epix10kp;

architecture top_level of Epix10kp is
   signal iLed          : slv(3 downto 0);
   signal iFpgaOutputEn : sl;
   signal iLedEn        : sl;
   
   -- Internal versions of signals so that we don't
   -- drive anything unpowered until the components
   -- are online.
   signal iVGuardDacClrb : sl;
   signal iVGuardDacSclk : sl;
   signal iVGuardDacDin  : sl;
   signal iVGuardDacCsb  : sl;
   
   signal iRunTg : sl;
   signal iDaqTg : sl;
   signal iMps   : sl;
   signal iTgOut : sl;
   
   signal iSerialIdIo : slv(1 downto 0);
   
   signal iSaciClk  : sl;
   signal iSaciSelL : slv(3 downto 0);
   signal iSaciCmd  : sl;
   signal iSaciRsp  : sl;
   
   signal iAdcSpiDataOut : sl;
   signal iAdcSpiDataIn   : sl;
   signal iAdcSpiDataEn  : sl;
   signal iAdcPdwn       : slv(2 downto 0);
   signal iAdcSpiCsb     : slv(2 downto 0);
   signal iAdcSpiClk     : sl;   
   signal iAdcClkP       : slv( 2 downto 0);
   signal iAdcClkM       : slv( 2 downto 0);
   
   signal iBootCsL      : sl;
   signal iBootMosi     : sl;
   
   signal iAsicRoClk    : sl;
   signal iAsicR0       : sl;
   signal iAsicAcq      : sl;
   signal iAsicPpmat    : sl;
   signal iAsicPpbe     : sl;
   signal iAsicGlblRst  : sl;
   signal iAsicSync     : sl;
   signal iAsicDm1      : sl;
   signal iAsicDm2      : sl;
   signal iAsicDout     : slv(3 downto 0);
   signal iAsic01Dout   : sl;
   signal iAsic23Dout   : sl;
   
   -- Keep douts from getting trimmed even if they're not used in this design
   attribute dont_touch : string;
   attribute dont_touch of iAsicDout : signal is "true";
   attribute dont_touch of iAsicDm1  : signal is "true";
   attribute dont_touch of iAsicDm2  : signal is "true";
   
begin

   ---------------------------
   -- Core block            --
   ---------------------------
   U_EpixCore : entity work.EpixCoreGen2
      generic map (
         TPD_G => TPD_G,
         ASIC_TYPE_G => EPIX10KP_C,
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
         -- Guard ring DAC
         vGuardDacSclk       => iVGuardDacSclk,
         vGuardDacDin        => iVGuardDacDin,
         vGuardDacCsb        => iVGuardDacCsb,
         vGuardDacClrb       => iVGuardDacClrb,
         -- External Signals
         runTrigger          => iRunTg,
         daqTrigger          => iDaqTg,
         mpsOut              => iMps,
         triggerOut          => iTgOut,
         -- Board IDs
         serialIdIo(1)       => asicDm1,
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
         adcSpiDataOut       => iAdcSpiDataOut,
         adcSpiDataIn        => iAdcSpiDataIn,
         adcSpiDataEn        => iAdcSpiDataEn,
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
         asicR0              => iAsicR0,
         asicPpmat           => iAsicPpmat,
         asicPpbe            => iAsicPpbe,
         asicGrst            => iAsicGlblRst,
         asicAcq             => iAsicAcq,
         asic0Dm2            => iAsicDm1,
         asic0Dm1            => iAsicDm2,
         asicRoClk           => iAsicRoClk,
         asicSync            => iAsicSync,
         -- ASIC digital data
         asicDout            => iAsicDout,
         -- Boot Memory Ports
         bootCsL             => iBootCsL,
         bootMosi            => iBootMosi,
         bootMiso            => bootMiso
      );
      
      adcClkP(0) <= iAdcClkP(0);      
      adcClkM(0) <= iAdcClkM(0);
      
      adcClkP(1) <= iAdcClkP(2);
      adcClkM(1) <= iAdcClkM(2);

   ----------------------------
   -- Map ports/signals/etc. --
   ----------------------------
   led <= iLed when iLedEn = '1' else (others => '0');
   
   -- Boot Memory Ports
   bootCsL  <= iBootCsL    when iFpgaOutputEn = '1' else 'Z';
   bootMosi <= iBootMosi   when iFpgaOutputEn = '1' else 'Z';
   
   -- Guard ring DAC
   vGuardDacSclk <= iVGuardDacSclk when iFpgaOutputEn = '1' else 'Z';
   vGuardDacDin  <= iVGuardDacDin  when iFpgaOutputEn = '1' else 'Z';
   vGuardDacCsb  <= iVGuardDacCsb  when iFpgaOutputEn = '1' else 'Z';
   vGuardDacClrb <= ivGuardDacClrb when iFpgaOutputEn = '1' else 'Z';
   
   -- TTL interfaces (accounting for inverters on ADC card)
   mps    <= not(iMps)   when iFpgaOutputEn = '1' else 'Z';
   tgOut  <= not(iTgOut) when iFpgaOutputEn = '1' else 'Z';
   iRunTg <= not(runTg);
   iDaqTg <= not(daqTg);

   -- ASIC SACI interfaces
   asicSaciCmd    <= iSaciCmd when iFpgaOutputEn = '1' else 'Z';
   asicSaciClk    <= iSaciClk when iFpgaOutputEn = '1' else 'Z';
   G_SACISEL : for i in 0 to 3 generate
      asicSaciSel(i) <= iSaciSelL(i) when iFpgaOutputEn = '1' else 'Z';
   end generate;
   iSaciRsp <= 
      asicSaciRsp(0) when iSaciSelL = "1110" else
      asicSaciRsp(1) when iSaciSelL = "1101" else
      asicSaciRsp(2) when iSaciSelL = "1011" else
      asicSaciRsp(3);   

   -- Fast ADC Configuration
   adcSpiClk     <= iAdcSpiClk when iFpgaOutputEn = '1' else 'Z';
   --adcSpiData    <= '0' when iAdcSpiDataOut = '0' and iAdcSpiDataEn = '1' and iFpgaOutputEn = '1' else 'Z';
   adcSpiData    <= iAdcSpiDataOut when  iAdcSpiDataEn = '1' and iFpgaOutputEn = '1' else 'Z';
   iAdcSpiDataIn <= adcSpiData;
   adcSpiCsb(0)  <= iAdcSpiCsb(0) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(1)  <= iAdcSpiCsb(1) when iFpgaOutputEn = '1' else 'Z';
   adcSpiCsb(2)  <= iAdcSpiCsb(2) when iFpgaOutputEn = '1' else 'Z';
   adcPdwn01     <= iAdcPdwn(0) when iFpgaOutputEn = '1' else '0';
   --adcPdwn(1)    <= iAdcPdwn(1) when iFpgaOutputEn = '1' else '0';
   adcPdwnMon    <= iAdcPdwn(2) when iFpgaOutputEn = '1' else '0';
   
   -- ASIC control signals (differential)
   U_ASIC01_DOUT_IBUFDS : IBUFDS port map (I => asic01DoutP, IB => asic01DoutM, O => iAsic01Dout);
   U_ASIC23_DOUT_IBUFDS : IBUFDS port map (I => asic23DoutP, IB => asic23DoutM, O => iAsic23Dout);
   iAsicDout(0) <= iAsic01Dout;
   iAsicDout(1) <= iAsic01Dout;
   iAsicDout(2) <= iAsic23Dout;
   iAsicDout(3) <= iAsic23Dout;
   U_ASIC01_ROCLK_OBUFTDS : OBUFTDS port map ( I => iAsicRoClk, T => not(iFpgaOutputEn), O => asic01RoClkP, OB => asic01RoClkM );
   U_ASIC23_ROCLK_OBUFTDS : OBUFTDS port map ( I => iAsicRoClk, T => not(iFpgaOutputEn), O => asic23RoClkP, OB => asic23RoClkM );
   
   -- ASIC control signals (single ended)
   asicR0      <= iAsicR0      when iFpgaOutputEn = '1' else 'Z';
   asicAcq     <= iAsicAcq     when iFpgaOutputEn = '1' else 'Z';
   asicPpmat   <= iAsicPpmat   when iFpgaOutputEn = '1' else 'Z';
   asicPpbe    <= iAsicPpbe    when iFpgaOutputEn = '1' else 'Z';
   asicGlblRst <= iAsicGlblRst when iFpgaOutputEn = '1' else 'Z';
   asicSync    <= iAsicSync    when iFpgaOutputEn = '1' else 'Z';
   -- On this carrier ASIC digital monitors are shared with SN device
   --iAsicDm1    <= snIoCarrier;
   --iAsicDm2    <= snIoCarrier;
   
end top_level;
