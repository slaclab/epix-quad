-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : CoulterBoardModel.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-11-14
-- Last update: 2016-11-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'Coulter'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'Coulter', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library UNISIM;
use UNISIM.vcomponents.all;

use work.StdRtlPkg.all;

entity CoulterBoardModel is

   generic (
      TPD_G : time := 1 ns);
   port (
      led                : in    slv(3 downto 0);
      powerGood          : out   sl;
      analogCardDigPwrEn : in    sl;
      analogCardAnaPwrEn : in    sl;
      gtRefClk0P         : out   sl;
      gtRefClk0N         : out   sl;
      gtDataTxP          : in    sl;
      gtDataTxN          : in    sl;
      gtDataRxP          : out   sl := '0';
      gtDataRxN          : out   sl := '0';
      sfpDisable         : in    sl;
      runTg              : out   sl;
      daqTg              : out   sl;
      mps                : in    sl;
      tgOut              : in    sl;
      snIoAdcCard        : inout sl;
      adcSpiClk          : in    sl;
      adcSpiData         : inout sl;
      adcSpiCsb          : in    slv(2 downto 0) := (others => '1');
      adcPdwn01          : in    sl;
      adcPdwnMon         : in    sl              := '1';
      adcClkP            : in    sl;
      adcClkM            : in    sl;
      adcDoClkP          : out   slv(1 downto 0);
      adcDoClkM          : out   slv(1 downto 0);
      adcFrameClkP       : out   slv(1 downto 0);
      adcFrameClkM       : out   slv(1 downto 0);
      adcDoP             : out   slv6Array(1 downto 0);
      adcDoM             : out   slv6Array(1 downto 0);
      adcOverflow        : out   slv(1 downto 0);
      elineResetL        : in    sl;
      elineEnaAMon       : in    slv(1 downto 0);
      elineMckP          : in    slv(1 downto 0);
      elineMckN          : in    slv(1 downto 0);
      elineScP           : in    slv(1 downto 0);
      elineScN           : in    slv(1 downto 0);
      elineSclk          : in    slv(1 downto 0);
      elineRnW           : in    slv(1 downto 0);
      elineSen           : in    slv(1 downto 0);
      elineSdi           : in    slv(1 downto 0);
      elineSdo           : out   slv(1 downto 0));

end entity CoulterBoardModel;

architecture model of CoulterBoardModel is

begin

   -------------------------------------------------------------------------------------------------
   -- 156.25 MHZ oscillator
   -------------------------------------------------------------------------------------------------
   U_ClkRst_1: entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         CLK_DELAY_G       => 0 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 ns,
         SYNC_RESET_G      => false)
      port map (
         clkP => gtRefClk0P,                  -- [out]
         clkN => gtRefClk0N);                  -- [out]


   -------------------------------------------------------------------------------------------------
   -- ELINE100 Simulation Models
   -------------------------------------------------------------------------------------------------
   U_ELine100Sim_0 : entity work.ELine100Sim
      generic map (
         TPD_G            => TPD_G,
         ANALOG_LATENCY_G => ANALOG_LATENCY_G)
      port map (
         rstN => elineResetL,           -- [in]
         scP  => elineScP(0),           -- [in]
         scM  => elineScN(0),           -- [in]
         mckP => elineMckP(0),          -- [in]
         mckM => elineMckN(0),          -- [in]
         dOut => eLineDOut(0),          -- [out]
         aOut => eLineAOut(0),          -- [out]
         sclk => asicSclk(0),           -- [in]
         sdi  => asicSdi(0),            -- [in]
         sdo  => asicSdo(0),            -- [out]
         sen  => asicSen(0),            -- [in]
         rw   => asicRw(0));            -- [in]

   U_ELine100Sim_1 : entity work.ELine100Sim
      generic map (
         TPD_G            => TPD_G,
         ANALOG_LATENCY_G => ANALOG_LATENCY_G)
      port map (
         rstN => elineResetL,           -- [in]
         scP  => elineScP(1),           -- [in]
         scM  => elineScN(1),           -- [in]
         mckP => elineMckP(1),          -- [in]
         mckM => elineMckN(1),          -- [in]
         dOut => eLineDOut(1),          -- [out]
         aOut => eLineAOut(1),          -- [out]
         sclk => asicSclk(1),           -- [in]
         sdi  => asicSdi(1),            -- [in]
         sdo  => asicSdo(1),            -- [out]
         sen  => asicSen(1),            -- [in]
         rw   => asicRw(1));            -- [in]

   -------------------------------------------------------------------------------------------------
   -- OR together digital outs to create overflow signals
   -------------------------------------------------------------------------------------------------

   -------------------------------------------------------------------------------------------------
   -- Simulate ADC preamplifiers
   -- Gain is .8
   -------------------------------------------------------------------------------------------------
   PREAMP_I: for i in 1 downto 0 generate
      PREAMP_J: for j in 5 downto 0 generate
         aOutAmp(i)(j) <= eLineAOut(i)(j) * 0.8;
      end generate PREAMP_J;
   end generate PREAMP_I;


   U_Ad9249_1 : entity work.Ad9249
      generic map (
         TPD_G            => TPD_G,
         CLK_PERIOD_G     => 100 ns,
         DIVCLK_DIVIDE_G  => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_G  => CLKFBOUT_MULT_G,
         CLK_DCO_DIVIDE_G => CLK_DCO_DIVIDE_G,
         CLK_FCO_DIVIDE_G => CLK_FCO_DIVIDE_G)
      port map (
         clkP              => adcClkP,                 -- [in]
         clkN              => adcClkN,                 -- [in]
         vin(5 downto 0)   => aOutAmp(0),              -- [in]
         vin(7 downto 6)   => 1.0,
         vin(13 downto 8)  => aOutAmp(1),
         vin(15 downto 14) => 1.0,
         dP                => adcDoP,                  -- [out]
         dN                => adcDoM,                  -- [out]
         dcoP              => adcDoClkP,               -- [out]
         dcoN              => adcDoClkM,               -- [out]
         fcoP              => adcFrameClkP,            -- [out]
         fcoN              => adcFrameClkM,            -- [out]
         sclk              => adcSpiClk,               -- [in]
         sdio              => adcSpiData,              -- [inout]
         csb               => adcSpiCsb(1 downto 0));  -- [in]





end architecture model;
