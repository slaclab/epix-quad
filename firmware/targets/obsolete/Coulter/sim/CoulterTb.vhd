-------------------------------------------------------------------------------
-- Title      : Testbench for design "Coulter"
-------------------------------------------------------------------------------
-- File       : CoulterTb.vhd
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

----------------------------------------------------------------------------------------------------

entity CoulterTb is

end entity CoulterTb;

----------------------------------------------------------------------------------------------------

architecture sim of CoulterTb is

   -- component generics
   constant TPD_G            : time    := 1 ns;
   constant ANALOG_LATENCY_G : time    := 2 ns;
   constant SIMULATION_G     : boolean := true;

   -- component ports
   signal led                : slv(3 downto 0);                     -- [out]
   signal powerGood          : sl;                                  -- [in]
   signal analogCardDigPwrEn : sl;                                  -- [out]
   signal analogCardAnaPwrEn : sl;                                  -- [out]
   signal gtRefClk0P         : sl;                                  -- [in]
   signal gtRefClk0N         : sl;                                  -- [in]
   signal gtDataTxP          : sl;                                  -- [out]
   signal gtDataTxN          : sl;                                  -- [out]
   signal gtDataRxP          : sl;                                  -- [in]
   signal gtDataRxN          : sl;                                  -- [in]
   signal sfpDisable         : sl;                                  -- [out]
   signal runTg              : sl;                                  -- [in]
   signal daqTg              : sl;                                  -- [in]
   signal mps                : sl;                                  -- [out]
   signal tgOut              : sl;                                  -- [out]
   signal snIoAdcCard        : sl;                                  -- [inout]
   signal adcSpiClk          : sl;                                  -- [out]
   signal adcSpiData         : sl;                                  -- [inout]
   signal adcSpiCsb          : slv(2 downto 0) := (others => '1');  -- [out]
   signal adcPdwn01          : sl;                                  -- [out]
   signal adcPdwnMon         : sl              := '1';              -- [out]
   signal adcClkP            : sl;                                  -- [out]
   signal adcClkM            : sl;                                  -- [out]
   signal adcDoClkP          : slv(1 downto 0);                     -- [in]
   signal adcDoClkM          : slv(1 downto 0);                     -- [in]
   signal adcFrameClkP       : slv(1 downto 0);                     -- [in]
   signal adcFrameClkM       : slv(1 downto 0);                     -- [in]
   signal adcDoP             : slv6Array(1 downto 0);               -- [in]
   signal adcDoM             : slv6Array(1 downto 0);               -- [in]
   signal adcOverflow        : slv(1 downto 0);                     -- [in]
   signal elineResetL        : sl;                                  -- [out]
   signal elineEnaAMon       : slv(1 downto 0);                     -- [out]
   signal elineMckP          : slv(1 downto 0);                     -- [out]
   signal elineMckN          : slv(1 downto 0);                     -- [out]
   signal elineScP           : slv(1 downto 0);                     -- [out]
   signal elineScN           : slv(1 downto 0);                     -- [out]
   signal elineSclk          : slv(1 downto 0);                     -- [out]
   signal elineRnW           : slv(1 downto 0);                     -- [out]
   signal elineSen           : slv(1 downto 0);                     -- [out]
   signal elineSdi           : slv(1 downto 0);                     -- [out]
   signal elineSdo           : slv(1 downto 0);                     -- [in]

begin

   -- component instantiation
   U_Coulter : entity work.Coulter
      generic map (
         TPD_G        => TPD_G,
         SIMULATION_G => SIMULATION_G)
      port map (
         led                => led,                 -- [out]
         powerGood          => powerGood,           -- [in]
         analogCardDigPwrEn => analogCardDigPwrEn,  -- [out]
         analogCardAnaPwrEn => analogCardAnaPwrEn,  -- [out]
         gtRefClk0P         => gtRefClk0P,          -- [in]
         gtRefClk0N         => gtRefClk0N,          -- [in]
         gtDataTxP          => gtDataTxP,           -- [out]
         gtDataTxN          => gtDataTxN,           -- [out]
         gtDataRxP          => gtDataRxP,           -- [in]
         gtDataRxN          => gtDataRxN,           -- [in]
         sfpDisable         => sfpDisable,          -- [out]
         runTg              => runTg,               -- [in]
         daqTg              => daqTg,               -- [in]
         mps                => mps,                 -- [out]
         tgOut              => tgOut,               -- [out]
         snIoAdcCard        => snIoAdcCard,         -- [inout]
         adcSpiClk          => adcSpiClk,           -- [out]
         adcSpiData         => adcSpiData,          -- [inout]
         adcSpiCsb          => adcSpiCsb,           -- [out]
         adcPdwn01          => adcPdwn01,           -- [out]
         adcPdwnMon         => adcPdwnMon,          -- [out]
         adcClkP            => adcClkP,             -- [out]
         adcClkM            => adcClkM,             -- [out]
         adcDoClkP          => adcDoClkP,           -- [in]
         adcDoClkM          => adcDoClkM,           -- [in]
         adcFrameClkP       => adcFrameClkP,        -- [in]
         adcFrameClkM       => adcFrameClkM,        -- [in]
         adcDoP             => adcDoP,              -- [in]
         adcDoM             => adcDoM,              -- [in]
         adcOverflow        => adcOverflow,         -- [in]
         elineResetL        => elineResetL,         -- [out]
         elineEnaAMon       => elineEnaAMon,        -- [out]
         elineMckP          => elineMckP,           -- [out]
         elineMckN          => elineMckN,           -- [out]
         elineScP           => elineScP,            -- [out]
         elineScN           => elineScN,            -- [out]
         elineSclk          => elineSclk,           -- [out]
         elineRnW           => elineRnW,            -- [out]
         elineSen           => elineSen,            -- [out]
         elineSdi           => elineSdi,            -- [out]
         elineSdo           => elineSdo);           -- [in]


   U_CoulterBoardModel_1 : entity work.CoulterBoardModel
      generic map (
         TPD_G => TPD_G)
      port map (
         led                => led,                 -- [in]
         powerGood          => powerGood,           -- [out]
         analogCardDigPwrEn => analogCardDigPwrEn,  -- [in]
         analogCardAnaPwrEn => analogCardAnaPwrEn,  -- [in]
         gtRefClk0P         => gtRefClk0P,          -- [out]
         gtRefClk0N         => gtRefClk0N,          -- [out]
         gtDataTxP          => gtDataTxP,           -- [in]
         gtDataTxN          => gtDataTxN,           -- [in]
         gtDataRxP          => gtDataRxP,           -- [out]
         gtDataRxN          => gtDataRxN,           -- [out]
         sfpDisable         => sfpDisable,          -- [in]
         runTg              => runTg,               -- [out]
         daqTg              => daqTg,               -- [out]
         mps                => mps,                 -- [in]
         tgOut              => tgOut,               -- [in]
         snIoAdcCard        => snIoAdcCard,         -- [inout]
         adcSpiClk          => adcSpiClk,           -- [in]
         adcSpiData         => adcSpiData,          -- [inout]
         adcSpiCsb          => adcSpiCsb,           -- [in]
         adcPdwn01          => adcPdwn01,           -- [in]
         adcPdwnMon         => adcPdwnMon,          -- [in]
         adcClkP            => adcClkP,             -- [in]
         adcClkM            => adcClkM,             -- [in]
         adcDoClkP          => adcDoClkP,           -- [out]
         adcDoClkM          => adcDoClkM,           -- [out]
         adcFrameClkP       => adcFrameClkP,        -- [out]
         adcFrameClkM       => adcFrameClkM,        -- [out]
         adcDoP             => adcDoP,              -- [out]
         adcDoM             => adcDoM,              -- [out]
         adcOverflow        => adcOverflow,         -- [out]
         elineResetL        => elineResetL,         -- [in]
         elineEnaAMon       => elineEnaAMon,        -- [in]
         elineMckP          => elineMckP,           -- [in]
         elineMckN          => elineMckN,           -- [in]
         elineScP           => elineScP,            -- [in]
         elineScN           => elineScN,            -- [in]
         elineSclk          => elineSclk,           -- [in]
         elineRnW           => elineRnW,            -- [in]
         elineSen           => elineSen,            -- [in]
         elineSdi           => elineSdi,            -- [in]
         elineSdo           => elineSdo);           -- [out]


end architecture sim;

----------------------------------------------------------------------------------------------------
