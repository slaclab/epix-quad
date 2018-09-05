-------------------------------------------------------------------------------
-- File       : EpixQuadTb.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-05
-- Last update: 2017-07-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for EpixQuad top module
-------------------------------------------------------------------------------
-- This file is part of 'EPIX'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadTb is end EpixQuadTb;

architecture testbed of EpixQuadTb is
   
   constant DDR_WIDTH_C : integer := 32;
   
   constant DDRCLK_PER_C      : time    := 5 ns;
   constant PGPCLK_PER_C      : time    := 6.4 ns;
   constant TPD_C             : time    := 1 ns;
   constant SIM_SPEEDUP_C     : boolean := true;

   component Ddr4ModelWrapper
      generic (
         DDR_WIDTH_G : integer);
      port (
         c0_ddr4_dq       : inout slv(DDR_WIDTH_C-1 downto 0);
         c0_ddr4_dqs_c    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
         c0_ddr4_dqs_t    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
         c0_ddr4_adr      : in    slv(16 downto 0);
         c0_ddr4_ba       : in    slv(1 downto 0);
         c0_ddr4_bg       : in    slv(0 to 0);
         c0_ddr4_reset_n  : in    sl;
         c0_ddr4_act_n    : in    sl;
         c0_ddr4_ck_t     : in    slv(0 to 0);
         c0_ddr4_ck_c     : in    slv(0 to 0);
         c0_ddr4_cke      : in    slv(0 to 0);
         c0_ddr4_cs_n     : in    slv(0 to 0);
         c0_ddr4_dm_dbi_n : inout slv((DDR_WIDTH_C/8)-1 downto 0);
         c0_ddr4_odt      : in    slv(0 to 0));
   end component;

   signal pgpClkP : sl;
   signal pgpClkN : sl;
   signal ddrClkP : sl;
   signal ddrClkN : sl;

   signal c0_ddr4_dq       : slv(DDR_WIDTH_C-1 downto 0)     := (others => '0');
   signal c0_ddr4_dqs_c    : slv((DDR_WIDTH_C/8)-1 downto 0) := (others => '0');
   signal c0_ddr4_dqs_t    : slv((DDR_WIDTH_C/8)-1 downto 0) := (others => '0');
   signal c0_ddr4_adr      : slv(16 downto 0)                := (others => '0');
   signal c0_ddr4_ba       : slv(1 downto 0)                 := (others => '0');
   signal c0_ddr4_bg       : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_reset_n  : sl                              := '0';
   signal c0_ddr4_act_n    : sl                              := '0';
   signal c0_ddr4_ck_t     : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_ck_c     : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_cke      : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_cs_n     : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_dm_dbi_n : slv((DDR_WIDTH_C/8)-1 downto 0) := (others => '0');
   signal c0_ddr4_odt      : slv(0 to 0)                     := (others => '0');
   
   signal asicDmSn         : slv(3 downto 0)    := "0000";
   signal dacScl           : sl                 := '0';     
   signal dacSda           : sl                 := '0';     
   signal monScl           : sl                 := '0';     
   signal monSda           : sl                 := '0';     
   signal humScl           : sl                 := '0';     
   signal humSda           : sl                 := '0';     

begin

   -- Generate clocks and resets
   DdrClk_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => DDRCLK_PER_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => ddrClkP,
         clkN => ddrClkN,
         rst  => open,
         rstL => open);
   
   PgpClk_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => PGPCLK_PER_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => pgpClkP,
         clkN => pgpClkN,
         rst  => open,
         rstL => open);
   
   ------------------------------------------------
   -- Buffer Reader UUT
   ------------------------------------------------
   U_EpixQuad: entity work.EpixQuad
   generic map (
      TPD_G             => TPD_C,
      BUILD_INFO_G      => toSlv (BUILD_INFO_DEFAULT_C),
      SIMULATION_G      => true,
      SIM_SPEEDUP_G     => true
   )
   port map (
      -- DRR Memory interface ports
      c0_sys_clk_p      => ddrClkP,
      c0_sys_clk_n      => ddrClkN,
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
      asicAnaEn         => open,
      asicDigEn         => open,
      dcdcSync          => open,
      dcdcEn            => open,
      ddrVttEn          => open,
      ddrVttPok         => '1',
      -- ASIC Carrier IDs
      asicDmSn          => asicDmSn,
      -- FPGA temperature alert
      tempAlertL        => '1',
      -- I2C busses
      dacScl            => dacScl,
      dacSda            => dacSda,
      monScl            => monScl,
      monSda            => monSda,
      humScl            => humScl,
      humSda            => humSda,
      humRstN           => open,
      humAlert          => '0',
      -- PGP Ports
      pgpClkP           => pgpClkP,
      pgpClkN           => pgpClkN,
      pgpRxP            => '0',
      pgpRxN            => '1',
      pgpTxP            => open,
      pgpTxN            => open,
      -- SYSMON Ports
      vPIn              => '0',
      vNIn              => '1',
      -- ASIC SACI signals
      asicSaciResp      => "0000",
      asicSaciClk       => open,
      asicSaciCmd       => open,
      asicSaciSelL      => open,
      -- ASIC ACQ signals
      asicAcq           => open,
      asicR0            => open,
      asicGr            => open,
      asicSync          => open,
      asicPpmat         => open,
      asicRoClkP        => open,
      asicRoClkN        => open,
      asicDoutP         => x"0000",
      asicDoutN         => x"FFFF"
   );
   
   U_ddr4 : Ddr4ModelWrapper
      generic map (
         DDR_WIDTH_G => DDR_WIDTH_C)
      port map (
         c0_ddr4_adr      => c0_ddr4_adr,
         c0_ddr4_ba       => c0_ddr4_ba,
         c0_ddr4_cke      => c0_ddr4_cke,
         c0_ddr4_cs_n     => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n,
         c0_ddr4_dq       => c0_ddr4_dq,
         c0_ddr4_dqs_c    => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t    => c0_ddr4_dqs_t,
         c0_ddr4_odt      => c0_ddr4_odt,
         c0_ddr4_bg       => c0_ddr4_bg,
         c0_ddr4_reset_n  => c0_ddr4_reset_n,
         c0_ddr4_act_n    => c0_ddr4_act_n,
         c0_ddr4_ck_c     => c0_ddr4_ck_c,
         c0_ddr4_ck_t     => c0_ddr4_ck_t);
   
end testbed;
