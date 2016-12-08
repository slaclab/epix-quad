-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : CoulterBoardModel.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-11-14
-- Last update: 2016-12-06
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
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.Gtp7CfgPkg.all;

entity CoulterBoardModel is

   generic (
      TPD_G            : time := 1 ns;
      ANALOG_LATENCY_G : time := 2 ns);
   port (
      led                : in    slv(3 downto 0);
      powerGood          : out   sl;
      analogCardDigPwrEn : in    sl;
      analogCardAnaPwrEn : in    sl;
      gtRefClk0P         : out   sl;
      gtRefClk0N         : out   sl;
      gtDataTxP          : in    sl;
      gtDataTxN          : in    sl;
      gtDataRxP          : out   sl              := '0';
      gtDataRxN          : out   sl              := '0';
      sfpDisable         : in    sl;
      runTg              : out   sl              := '0';
      daqTg              : out   sl              := '0';
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

   constant REFCLK_FREQ_C : real            := 156.25e6;
   constant LINE_RATE_C   : real            := 3.125e9;
   constant GTP_CFG_C     : Gtp7QPllCfgType := getGtp7QPllCfg(REFCLK_FREQ_C, LINE_RATE_C);

   signal eLineDOut : slv6Array(1 downto 0);
   type Real6Array is array (natural range <>) of RealArray(5 downto 0);
   signal eLineAOut : Real6Array(1 downto 0);

   signal aOutAmp : Real6Array(1 downto 0);

   signal iAdcDoP : slv(15 downto 0);
   signal iAdcDoM : slv(15 downto 0);

   signal gtRefClkP : sl;
   signal gtRefClkN : sl;
   signal stableClk : sl;
   signal stableRst : sl;

begin

   -------------------------------------------------------------------------------------------------
   -- 156.25 MHZ oscillator
   -------------------------------------------------------------------------------------------------
   U_ClkRst_1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         CLK_DELAY_G       => 0 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 ns,
         SYNC_RESET_G      => false)
      port map (
         clkP => gtRefClkP,             -- [out]
         clkN => gtRefClkN);            -- [out]

   gtRefClk0P <= gtRefClkP;
   gtRefClk0N <= gtRefClkN;

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
         sclk => elineSclk(0),          -- [in]
         sdi  => elineSdi(0),           -- [in]
         sdo  => elineSdo(0),           -- [out]
         sen  => elineSen(0),           -- [in]
         rw   => elineRnW(0));          -- [in]

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
         sclk => elineSclk(1),          -- [in]
         sdi  => elineSdi(1),           -- [in]
         sdo  => elineSdo(1),           -- [out]
         sen  => elineSen(1),           -- [in]
         rw   => elineRnW(1));          -- [in]

   -------------------------------------------------------------------------------------------------
   -- OR together digital outs to create overflow signals
   -------------------------------------------------------------------------------------------------

   -------------------------------------------------------------------------------------------------
   -- Simulate ADC preamplifiers
   -- Gain is .8
   -------------------------------------------------------------------------------------------------
   PREAMP_I : for i in 1 downto 0 generate
      PREAMP_J : for j in 5 downto 0 generate
         aOutAmp(i)(j) <= eLineAOut(i)(j) * 0.8;
      end generate PREAMP_J;
   end generate PREAMP_I;

   -- Pullups for adcSpi
   adcSpiData  <= 'H';

   U_Ad9249_1 : entity work.Ad9249
      generic map (
         TPD_G            => TPD_G,
         CLK_PERIOD_G     => 100 ns,
         DIVCLK_DIVIDE_G  => 1,
         CLKFBOUT_MULT_G  => 63,
         CLK_DCO_DIVIDE_G => 9,
         CLK_FCO_DIVIDE_G => 63)
      port map (
         clkP              => adcClkP,                 -- [in]
         clkN              => adcClkM,                 -- [in]
         vin(5 downto 0)   => aOutAmp(0),              -- [in]
         vin(7 downto 6)   => (others => 1.0),         -- [in]
         vin(13 downto 8)  => aOutAmp(1),              -- [in]
         vin(15 downto 14) => (others => 1.0),         -- [in]
         dP                => iAdcDoP,                 -- [out]
         dN                => iAdcDoM,                 -- [out]
         dcoP              => adcDoClkP,               -- [out]
         dcoN              => adcDoClkM,               -- [out]
         fcoP              => adcFrameClkP,            -- [out]
         fcoN              => adcFrameClkM,            -- [out]
         sclk              => adcSpiClk,               -- [in]
         sdio              => adcSpiData,              -- [inout]
         csb               => adcSpiCsb(1 downto 0));  -- [in]


   adcDoP(0) <= iAdcDoP(5 downto 0);
   adcDoM(0) <= iAdcDoM(5 downto 0);
   adcDoP(1) <= iAdcDoP(13 downto 8);
   adcDoM(1) <= iAdcDoM(13 downto 8);

   -------------------------------------------------------------------------------------------------
   -- PGP
   -------------------------------------------------------------------------------------------------
--    U_ClkRst_2 : entity work.ClkRst
--       generic map (
--          CLK_PERIOD_G      => 6.4 ns,
--          CLK_DELAY_G       => 1 ns,
--          RST_START_DELAY_G => 0 ns,
--          RST_HOLD_TIME_G   => 1 ns,
--          SYNC_RESET_G      => false)
--       port map (
--          clkP => gtRefClkP,             -- [out]
--          clkN => gtRefClkN);            -- [out]

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => true,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         arst   => '0',
         clk    => stableClk,
         rstOut => stableRst);


--    U_Pgp2bGtp7VarLatWrapper_1 : entity work.Pgp2bGtp7VarLatWrapper
--       generic map (
--          TPD_G                => TPD_G,
--          CLKIN_PERIOD_G       => (6.4*2),
--          DIVCLK_DIVIDE_G      => 1,
--          CLKFBOUT_MULT_F_G    => 12.75,
--          CLKOUT0_DIVIDE_F_G   => 6.375,
--          QPLL_REFCLK_SEL_G    => "001",
--          QPLL_FBDIV_IN_G      => GTP_CFG_C.QPLL_FBDIV_G,
--          QPLL_FBDIV_45_IN_G   => GTP_CFG_C.QPLL_FBDIV_45_G,
--          QPLL_REFCLK_DIV_IN_G => GTP_CFG_C.QPLL_REFCLK_DIV_G,
--          RXOUT_DIV_G          => GTP_CFG_C.OUT_DIV_G,
--          TXOUT_DIV_G          => GTP_CFG_C.OUT_DIV_G,
--          RX_CLK25_DIV_G       => GTP_CFG_C.CLK25_DIV_G,
--          TX_CLK25_DIV_G       => GTP_CFG_C.CLK25_DIV_G,
--          RX_OS_CFG_G          => X"0000010000000",
--          RXCDR_CFG_G          => X"0000107FE206001041010",

-- --          RXLPM_INCM_CFG_G     => RXLPM_INCM_CFG_G,
-- --          RXLPM_IPCM_CFG_G     => RXLPM_IPCM_CFG_G,
--          RX_ENABLE_G       => true,
--          TX_ENABLE_G       => true,
--          PAYLOAD_CNT_TOP_G => 7,
--          VC_INTERLEAVE_G   => 0,
--          NUM_VC_EN_G       => 4)
--       port map (
--          extRst       => stableRst,                             -- [in]
--          pgpClk       => open,                                  -- [out]
--          pgpRst       => open,                                  -- [out]
--          stableClk    => stableClk,                             -- [out]
--          pgpTxIn      => PGP2B_TX_IN_INIT_C,                    -- [in]
--          pgpTxOut     => open,                                  -- [out]
--          pgpRxIn      => PGP2B_RX_IN_INIT_C,                    -- [in]
--          pgpRxOut     => open,                                  -- [out]
--          pgpTxMasters => (others => AXI_STREAM_MASTER_INIT_C),  -- [in]
--          pgpTxSlaves  => open,                                  -- [out]
--          pgpRxMasters => open,                                  -- [out]
--          pgpRxCtrl    => (others => AXI_STREAM_CTRL_INIT_C),    -- [in]
--          gtClkP       => gtRefClkP,                             -- [in]
--          gtClkN       => gtRefClkN,                             -- [in]
--          gtTxP        => gtDataRxP,                             -- [out]
--          gtTxN        => gtDataRxN,                             -- [out]
--          gtRxP        => gtDataTxP,                             -- [in]
--          gtRxN        => gtDataTxN);                            -- [in]


end architecture model;
