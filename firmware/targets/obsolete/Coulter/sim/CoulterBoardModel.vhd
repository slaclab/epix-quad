-------------------------------------------------------------------------------
-- File       : CoulterBoardModel.vhd
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

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2bPkg.all;
use surf.AxiStreamPkg.all;
use surf.Gtp7CfgPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

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
   constant LINE_RATE_C   : real            := 2.5e9;
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
   U_ClkRst_1 : entity surf.ClkRst
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
         aOutAmp(i)(j) <= (eLineAOut(i)(j) * 0.8) + 1.0;
      end generate PREAMP_J;
   end generate PREAMP_I;

   -- Pullups for adcSpi
   adcSpiData <= 'H';

   U_Ad9249_1 : entity surf.Ad9249
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
--    U_ClkRst_2 : entity surf.ClkRst
--       generic map (
--          CLK_PERIOD_G      => 6.4 ns,
--          CLK_DELAY_G       => 1 ns,
--          RST_START_DELAY_G => 0 ns,
--          RST_HOLD_TIME_G   => 1 ns,
--          SYNC_RESET_G      => false)
--       port map (
--          clkP => gtRefClkP,             -- [out]
--          clkN => gtRefClkN);            -- [out]

   PwrUpRst_Inst : entity surf.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => true,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         arst   => '0',
         clk    => stableClk,
         rstOut => stableRst);


   U_Pgp2bGtp7FixedLatWrapper_1 : entity surf.Pgp2bGtp7FixedLatWrapper
      generic map (
         TPD_G                   => TPD_G,
         SIM_GTRESET_SPEEDUP_G   => true,
         SIM_VERSION_G           => "2.0",
         SIMULATION_G            => true,
         VC_INTERLEAVE_G         => 0,
         PAYLOAD_CNT_TOP_G       => 7,
         NUM_VC_EN_G             => 2,
         TX_ENABLE_G             => true,
         RX_ENABLE_G             => true,
         TX_CM_EN_G              => false,
         TX_CM_TYPE_G            => "MMCM",
         TX_CM_CLKIN_PERIOD_G    => 8.0,
         TX_CM_DIVCLK_DIVIDE_G   => 1,
         TX_CM_CLKFBOUT_MULT_F_G => 8.0,  --7.625,
         TX_CM_CLKOUT_DIVIDE_F_G => 8.0,  --7.625,
         RX_CM_EN_G              => false,
         RX_CM_TYPE_G            => "MMCM",
         RX_CM_CLKIN_PERIOD_G    => 8.0,
         RX_CM_DIVCLK_DIVIDE_G   => 1,
         RX_CM_CLKFBOUT_MULT_F_G => 12.75,
         RX_CM_CLKOUT_DIVIDE_F_G => 12.75,
         PMA_RSV_G               => X"00000333",
--          RX_OS_CFG_G             => RX_OS_CFG_G,
         RXCDR_CFG_G             => X"0000107FE206001041010",

--          RXDFEXYDEN_G            => RXDFEXYDEN_G,
         STABLE_CLK_SRC_G  => "gtClk0",
         TX_REFCLK_SRC_G   => "gtClk0",
         TX_USER_CLK_SRC_G => "txOutClk",
         RX_REFCLK_SRC_G   => "gtClk0",
         TX_PLL_CFG_G      => GTP_CFG_C,
         RX_PLL_CFG_G      => GTP_CFG_C,
         TX_PLL_G          => "PLL0",
         RX_PLL_G          => "PLL1")
      port map (
         stableClkIn  => '0',           --stableClkIn,       -- [in]
         extRst       => '0',     -- [in]
         pgpTxClkOut  => open,      -- [out]
         pgpTxRstOut  => open,      -- [out]
         pgpRxClkOut  => open,      -- [out] -- Fixed Latency recovered clock
         pgpRxRstOut  => open,      -- [out]
         pgpTxIn      => PGP2B_TX_IN_INIT_C,                    -- [in]
         pgpTxOut     => open,          -- [out]
         pgpRxIn      => PGP2B_RX_IN_INIT_C,                    -- [in]
         pgpRxOut     => open,          -- [out]
         pgpTxMasters => (others => AXI_STREAM_MASTER_INIT_C),  -- [in]
         pgpTxSlaves  => open,          -- [out]
         pgpRxMasters => open,          -- [out]
         pgpRxCtrl    => (others => AXI_STREAM_CTRL_INIT_C),    -- [in]
         gtClk0P       => gtRefClkP,     -- [in]
         gtClk0N       => gtRefClkN,     -- [in]
         gtTxP        => gtDataRxP,     -- [out]
         gtTxN        => gtDataRxN,     -- [out]
         gtRxP        => gtDataTxP,     -- [in]
         gtRxN        => gtDataTxN);    -- [in]


end architecture model;
