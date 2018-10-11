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
use work.ad9249_pkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadTb is end EpixQuadTb;

architecture testbed of EpixQuadTb is
   
   constant DDR_WIDTH_C : integer := 16;
   
   constant DDRCLK_PER_C      : time    := 5 ns;
   constant PGPCLK_PER_C      : time    := 6.4 ns;
   constant TPD_C             : time    := 1 ns;
   constant SIM_SPEEDUP_C     : boolean := true;
   
   constant BUILD_INFO_TB_C : BuildInfoRetType := (
      buildString =>  (others => (others => '0')),
      fwVersion => X"EA040000",
      gitHash => (others => '0'));

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

   signal pgpClkP    : sl;
   signal pgpClkN    : sl;
   signal ddrClkP    : sl;
   signal ddrClkN    : sl;
   signal adcClkP    : slv(4 downto 0);
   signal adcClkN    : slv(4 downto 0);
   signal adcFClkP   : slv(9 downto 0);
   signal adcFClkN   : slv(9 downto 0);
   signal adcDClkP   : slv(9 downto 0);
   signal adcDClkN   : slv(9 downto 0);
   signal adcChP     : Slv8Array(9 downto 0);
   signal adcChN     : Slv8Array(9 downto 0);

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
   
   signal tempAlertL       : sl                 := '1';
   
   signal adcDoutClk       : sl;
   
   constant ADC_BASELINE_C  : RealArray(79 downto 0)    := (
      0 =>0.5+0 *1.0/80, 1 =>0.5+1 *1.0/80, 2 =>0.5+2 *1.0/80, 3 =>0.5+3 *1.0/80, 4 =>0.5+4 *1.0/80, 5 =>0.5+5 *1.0/80, 6 =>0.5+6 *1.0/80, 7 =>0.5+7 *1.0/80,
      8 =>0.5+8 *1.0/80, 9 =>0.5+9 *1.0/80, 10=>0.5+10*1.0/80, 11=>0.5+11*1.0/80, 12=>0.5+12*1.0/80, 13=>0.5+13*1.0/80, 14=>0.5+14*1.0/80, 15=>0.5+15*1.0/80,
      16=>0.5+16*1.0/80, 17=>0.5+17*1.0/80, 18=>0.5+18*1.0/80, 19=>0.5+19*1.0/80, 20=>0.5+20*1.0/80, 21=>0.5+21*1.0/80, 22=>0.5+22*1.0/80, 23=>0.5+23*1.0/80,
      24=>0.5+24*1.0/80, 25=>0.5+25*1.0/80, 26=>0.5+26*1.0/80, 27=>0.5+27*1.0/80, 28=>0.5+28*1.0/80, 29=>0.5+29*1.0/80, 30=>0.5+30*1.0/80, 31=>0.5+31*1.0/80,
      32=>0.5+32*1.0/80, 33=>0.5+33*1.0/80, 34=>0.5+34*1.0/80, 35=>0.5+35*1.0/80, 36=>0.5+36*1.0/80, 37=>0.5+37*1.0/80, 38=>0.5+38*1.0/80, 39=>0.5+39*1.0/80,
      40=>0.5+40*1.0/80, 41=>0.5+41*1.0/80, 42=>0.5+42*1.0/80, 43=>0.5+43*1.0/80, 44=>0.5+44*1.0/80, 45=>0.5+45*1.0/80, 46=>0.5+46*1.0/80, 47=>0.5+47*1.0/80,
      48=>0.5+48*1.0/80, 49=>0.5+49*1.0/80, 50=>0.5+50*1.0/80, 51=>0.5+51*1.0/80, 52=>0.5+52*1.0/80, 53=>0.5+53*1.0/80, 54=>0.5+54*1.0/80, 55=>0.5+55*1.0/80,
      56=>0.5+56*1.0/80, 57=>0.5+57*1.0/80, 58=>0.5+58*1.0/80, 59=>0.5+59*1.0/80, 60=>0.5+60*1.0/80, 61=>0.5+61*1.0/80, 62=>0.5+62*1.0/80, 63=>0.5+63*1.0/80,
      64=>0.5+64*1.0/80, 65=>0.5+65*1.0/80, 66=>0.5+66*1.0/80, 67=>0.5+67*1.0/80, 68=>0.5+68*1.0/80, 69=>0.5+69*1.0/80, 70=>0.5+70*1.0/80, 71=>0.5+71*1.0/80,
      72=>0.5+72*1.0/80, 73=>0.5+73*1.0/80, 74=>0.5+74*1.0/80, 75=>0.5+75*1.0/80, 76=>0.5+76*1.0/80, 77=>0.5+77*1.0/80, 78=>0.5+78*1.0/80, 79=>0.5+79*1.0/80
   );
   
   constant COUNT_MASK_C  : Slv16Array(79 downto 0)    := (
      0 =>x"0000", 1 =>x"0100", 2 =>x"0200", 3 =>x"0300", 4 =>x"0400", 5 =>x"0500", 6 =>x"0600", 7 =>x"0700",
      8 =>x"0800", 9 =>x"0900", 10=>x"0a00", 11=>x"0b00", 12=>x"0c00", 13=>x"0d00", 14=>x"0e00", 15=>x"0f00",
      16=>x"1000", 17=>x"1100", 18=>x"1200", 19=>x"1300", 20=>x"1400", 21=>x"1500", 22=>x"1600", 23=>x"1700",
      24=>x"1800", 25=>x"1900", 26=>x"1a00", 27=>x"1b00", 28=>x"1c00", 29=>x"1d00", 30=>x"1e00", 31=>x"1f00",
      32=>x"2000", 33=>x"2100", 34=>x"2200", 35=>x"2300", 36=>x"2400", 37=>x"2500", 38=>x"2600", 39=>x"2700",
      40=>x"2800", 41=>x"2900", 42=>x"2a00", 43=>x"2b00", 44=>x"2c00", 45=>x"2d00", 46=>x"2e00", 47=>x"2f00",
      48=>x"3000", 49=>x"3100", 50=>x"3200", 51=>x"3300", 52=>x"3400", 53=>x"3500", 54=>x"3600", 55=>x"3700",
      56=>x"3800", 57=>x"3900", 58=>x"3a00", 59=>x"3b00", 60=>x"3c00", 61=>x"3d00", 62=>x"3e00", 63=>x"3f00",
      64=>x"0000", 65=>x"0100", 66=>x"0200", 67=>x"0300", 68=>x"0400", 69=>x"0500", 70=>x"0600", 71=>x"0700",
      72=>x"0800", 73=>x"0900", 74=>x"0a00", 75=>x"0b00", 76=>x"0c00", 77=>x"0d00", 78=>x"0e00", 79=>x"0f00"
   );

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
   U_EpixQuad: entity work.EpixQuadCore
   generic map (
      TPD_G             => TPD_C,
      BUILD_INFO_G      => toSlv (BUILD_INFO_TB_C),
      SIMULATION_G      => true,
      SIM_SPEEDUP_G     => true,
      COM_TYPE_G        => "PGPv3",
      RATE_G            => "6.25Gbps"
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
      tempAlertL        => tempAlertL,
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
      asicDoutN         => x"FFFF",
      -- Fast ADC Signals
      adcClkP           => adcClkP,
      adcClkN           => adcClkN,
      adcFClkP          => adcFClkP,
      adcFClkN          => adcFClkN,
      adcDClkP          => adcDClkP,
      adcDClkN          => adcDClkN,
      adcChP            => adcChP,
      adcChN            => adcChN
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
   
   
   G_ADC : for i in 0 to 9 generate 
      U_ADC : entity work.ad9249_group
      generic map (
         OUTPUT_TYPE_G     => (others=>COUNT_OUT),
         NOISE_BASELINE_G  => ADC_BASELINE_C(7+i*8 downto 0+i*8),
         NOISE_VPP_G       => (others=> 5.0e-3),
         PATTERN_G         => (others=>x"2F7C"),
         COUNT_MIN_G       => (others=>x"0000"),
         COUNT_MAX_G       => (others=>x"000F"),
         COUNT_MASK_G      => COUNT_MASK_C(7+i*8 downto 0+i*8),
         INDEX_G           => i
      )
      port map (
         aInP     => (others=>0.0),
         aInN     => (others=>0.0),
         sClk     => adcClkP(0),
         dClk     => adcDoutClk,
         fcoP     => adcFClkP(i),
         fcoN     => adcFClkN(i),
         dcoP     => adcDClkP(i),
         dcoN     => adcDClkN(i),
         dP       => adcChP(i),
         dN       => adcChN(i)
      );
   end generate;
   
   -- need Pll to create ADC readout clock (350 MHz)
   -- must be in phase with adcClk (50 MHz)
   U_PLLAdc : entity work.ClockManagerUltraScale
   generic map(
      TYPE_G            => "MMCM",
      INPUT_BUFG_G      => true,
      FB_BUFG_G         => true,
      RST_IN_POLARITY_G => '1',
      NUM_CLOCKS_G      => 1,
      -- MMCM attributes
      BANDWIDTH_G       => "OPTIMIZED",
      CLKIN_PERIOD_G    => 20.0,
      DIVCLK_DIVIDE_G   => 1,
      CLKFBOUT_MULT_G   => 14,
      CLKOUT0_DIVIDE_G  => 2
   )
   port map(
      -- Clock Input
      clkIn     => adcClkP(0),
      -- Clock Outputs
      clkOut(0) => adcDoutClk
   );
   
   -----------------------------------------------------------------------
   -- Sim process
   -----------------------------------------------------------------------
   process
   begin
      
      --tempAlertL <= '1';
      --
      --wait for 100 us;
      --
      --tempAlertL <= '0';
      --
      --wait for 100 us;
      --
      --tempAlertL <= '1';
      
      --wait;
      
      --acqStart <= not acqStart;
      
      wait for 100 us;
         
      
   end process;
   
   
   -----------------------------------------------------------------------
   -- I2C verification process
   -----------------------------------------------------------------------
   process
   begin
   
      wait for 100 ns;
      
      humScl <= 'H';
      humSda <= 'H';
      
      loop 
         -----------------------------------------------------------------------
         -- send sht31 command
         -----------------------------------------------------------------------
         
         -- wait for start
         wait until falling_edge(humScl) and humSda = '0';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         
         -----------------------------------------------------------------------
         -- read sht31 data
         -----------------------------------------------------------------------
         
         -- wait for start
         wait until falling_edge(humScl) and humSda = '0';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- ACK
         humSda <= 'L';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         wait until falling_edge(humScl);
         
         -- NACK
         humSda <= 'H';
         wait until falling_edge(humScl);
         humSda <= 'H';
         
         for i in 2 downto 0 loop
         
            -----------------------------------------------------------------------
            -- write nct218 pointer
            -----------------------------------------------------------------------
            
            -- wait for start
            wait until falling_edge(humScl) and humSda = '0';
            
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            
            -- ACK
            humSda <= 'L';
            wait until falling_edge(humScl);
            humSda <= 'H';
            
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            
            -- ACK
            humSda <= 'L';
            wait until falling_edge(humScl);
            humSda <= 'H';
            
            -----------------------------------------------------------------------
            -- read nct218 data
            -----------------------------------------------------------------------
            
            -- wait for start
            wait until falling_edge(humScl) and humSda = '0';
            
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            
            -- ACK
            humSda <= 'L';
            wait until falling_edge(humScl);
            humSda <= 'H';
            
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            wait until falling_edge(humScl);
            
            -- NACK
            humSda <= 'H';
            wait until falling_edge(humScl);
            humSda <= 'H';
         
         end loop;
      
      end loop;
      
      wait;
         
      
   end process;
   
   
end testbed;
