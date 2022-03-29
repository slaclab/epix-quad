-------------------------------------------------------------------------------
-- File       : EpixQuadPgp4_10Gbps.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: EpixQuadPgp4_10Gbps Target's Top Level
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadPgp4_10Gbps is
   generic (
      TPD_G             : time            := 1 ns;
      BUILD_INFO_G      : BuildInfoType;
      SIMULATION_G      : boolean         := false;
      SIM_SPEEDUP_G     : boolean         := false);
   port (
      -- DRR Memory interface ports
      c0_sys_clk_p      : in    sl;
      c0_sys_clk_n      : in    sl;
      c0_ddr4_dq        : inout slv(15 downto 0);
      c0_ddr4_dqs_c     : inout slv(1 downto 0);
      c0_ddr4_dqs_t     : inout slv(1 downto 0);
      c0_ddr4_adr       : out   slv(16 downto 0);
      c0_ddr4_ba        : out   slv(1 downto 0);
      c0_ddr4_bg        : out   slv(0 to 0);
      c0_ddr4_reset_n   : out   sl;
      c0_ddr4_act_n     : out   sl;
      c0_ddr4_ck_t      : out   slv(0 to 0);
      c0_ddr4_ck_c      : out   slv(0 to 0);
      c0_ddr4_cke       : out   slv(0 to 0);
      c0_ddr4_cs_n      : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n  : inout slv(1 downto 0);
      c0_ddr4_odt       : out   slv(0 to 0);
      -- Power Supply Cntrl Ports
      asicAnaEn         : out   sl;
      asicDigEn         : out   sl;
      dcdcSync          : out   slv(10 downto 0);
      dcdcEn            : out   slv(3 downto 0);
      ddrVttEn          : out   sl;
      ddrVttPok         : in    sl;
      -- ASIC Carrier IDs
      asicDmSn          : inout slv(3 downto 0);
      -- FPGA temperature alert
      tempAlertL        : in  sl;
      -- I2C busses
      dacScl            : inout sl;
      dacSda            : inout sl;
      monScl            : inout sl;
      monSda            : inout sl;
      humScl            : inout sl;
      humSda            : inout sl;
      humRstN           : out   sl;
      humAlert          : in    sl;
      -- monitor ADC bus
      envSck            : out   sl;
      envCnv            : out   sl;
      envDin            : out   sl;
      envSdo            : in    sl;
      -- PGP Ports
      pgpClkP           : in    sl;
      pgpClkN           : in    sl;
      pgpRxP            : in    sl;
      pgpRxN            : in    sl;
      pgpTxP            : out   sl;
      pgpTxN            : out   sl;
      -- SYSMON Ports
      vPIn              : in    sl;
      vNIn              : in    sl;
      -- ASIC SACI signals
      asicSaciResp      : in    slv(3 downto 0);
      asicSaciClk       : out   slv(3 downto 0);
      asicSaciCmd       : out   slv(3 downto 0);
      asicSaciSelL      : out   slv(15 downto 0);
      -- ASIC ACQ signals
      asicAcq           : out   slv(3 downto 0);
      asicR0            : out   slv(3 downto 0);
      asicGr            : out   slv(3 downto 0);
      asicSync          : out   slv(3 downto 0);
      asicPpmat         : out   slv(3 downto 0);
      asicRoClkP        : out   slv(1 downto 0);
      asicRoClkN        : out   slv(1 downto 0);
      asicDoutP         : in    slv(15 downto 0);
      asicDoutN         : in    slv(15 downto 0);
      -- Fast ADC Signals
      adcClkP           : out   slv(4 downto 0);
      adcClkN           : out   slv(4 downto 0);
      adcFClkP          : in    slv(9 downto 0);
      adcFClkN          : in    slv(9 downto 0);
      adcDClkP          : in    slv(9 downto 0);
      adcDClkN          : in    slv(9 downto 0);
      adcChP            : in    Slv8Array(9 downto 0);
      adcChN            : in    Slv8Array(9 downto 0);
      -- Fast ADC Config SPI
      adcSclk           : out   slv(2 downto 0);
      adcSdio           : inout slv(2 downto 0);
      adcCsb            : out   slv(9 downto 0);
      -- debug outputs
      dbgOut            : out   slv(2 downto 0);
      spareIo2v5        : out   slv(4 downto 0);
      -- ttl Trigger
      inputTtl          : in    slv(2 downto 0)
  );
end EpixQuadPgp4_10Gbps;

architecture top_level of EpixQuadPgp4_10Gbps is

begin

   U_CORE : entity work.EpixQuadCore
      generic map (
         TPD_G             => TPD_G,
         BUILD_INFO_G      => BUILD_INFO_G,
         SIMULATION_G      => SIMULATION_G,
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
         MIG_CORE_EN       => false,
         COM_TYPE_G        => "PGPv4",
         RATE_G            => "10.3125Gbps"
      )
      port map (
         -- DRR Memory interface ports
         c0_sys_clk_p      => c0_sys_clk_p    ,
         c0_sys_clk_n      => c0_sys_clk_n    ,
         c0_ddr4_dq        => c0_ddr4_dq      ,
         c0_ddr4_dqs_c     => c0_ddr4_dqs_c   ,
         c0_ddr4_dqs_t     => c0_ddr4_dqs_t   ,
         c0_ddr4_adr       => c0_ddr4_adr     ,
         c0_ddr4_ba        => c0_ddr4_ba      ,
         c0_ddr4_bg        => c0_ddr4_bg      ,
         c0_ddr4_reset_n   => c0_ddr4_reset_n ,
         c0_ddr4_act_n     => c0_ddr4_act_n   ,
         c0_ddr4_ck_t      => c0_ddr4_ck_t    ,
         c0_ddr4_ck_c      => c0_ddr4_ck_c    ,
         c0_ddr4_cke       => c0_ddr4_cke     ,
         c0_ddr4_cs_n      => c0_ddr4_cs_n    ,
         c0_ddr4_dm_dbi_n  => c0_ddr4_dm_dbi_n,
         c0_ddr4_odt       => c0_ddr4_odt     ,
         -- Power Supply Cntrl Ports
         asicAnaEn         => asicAnaEn,
         asicDigEn         => asicDigEn,
         dcdcSync          => dcdcSync ,
         dcdcEn            => dcdcEn   ,
         ddrVttEn          => ddrVttEn ,
         ddrVttPok         => ddrVttPok,
         -- ASIC Carrier IDs
         asicDmSn          => asicDmSn,
         -- FPGA temperature alert
         tempAlertL        => tempAlertL,
         -- I2C busses
         dacScl            => dacScl  ,
         dacSda            => dacSda  ,
         monScl            => monScl  ,
         monSda            => monSda  ,
         humScl            => humScl  ,
         humSda            => humSda  ,
         humRstN           => humRstN ,
         humAlert          => humAlert,
         -- monitor ADC bus
         envSck            => envSck,
         envCnv            => envCnv,
         envDin            => envDin,
         envSdo            => envSdo,
         -- PGP Ports
         pgpClkP           => pgpClkP,
         pgpClkN           => pgpClkN,
         pgpRxP            => pgpRxP ,
         pgpRxN            => pgpRxN ,
         pgpTxP            => pgpTxP ,
         pgpTxN            => pgpTxN ,
         -- SYSMON Ports
         vPIn              => vPIn,
         vNIn              => vNIn,
         -- ASIC SACI signals
         asicSaciResp      => asicSaciResp,
         asicSaciClk       => asicSaciClk ,
         asicSaciCmd       => asicSaciCmd ,
         asicSaciSelL      => asicSaciSelL,
         -- ASIC ACQ signals
         asicAcq           => asicAcq   ,
         asicR0            => asicR0    ,
         asicGr            => asicGr    ,
         asicSync          => asicSync  ,
         asicPpmat         => asicPpmat ,
         asicRoClkP        => asicRoClkP,
         asicRoClkN        => asicRoClkN,
         asicDoutP         => asicDoutP ,
         asicDoutN         => asicDoutN ,
         -- Fast ADC Signals
         adcClkP           => adcClkP ,
         adcClkN           => adcClkN ,
         adcFClkP          => adcFClkP,
         adcFClkN          => adcFClkN,
         adcDClkP          => adcDClkP,
         adcDClkN          => adcDClkN,
         adcChP            => adcChP  ,
         adcChN            => adcChN  ,
         -- Fast ADC Config SPI
         adcSclk           => adcSclk,
         adcSdio           => adcSdio,
         adcCsb            => adcCsb,
         -- debug outputs
         dbgOut            => dbgOut,
         spareIo2v5        => spareIo2v5,
         -- ttl Trigger
         inputTtl          => inputTtl
     );

end top_level;
