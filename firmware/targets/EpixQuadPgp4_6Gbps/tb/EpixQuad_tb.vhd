library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

library unisim;
use unisim.vcomponents.all;

use work.ad9249_pkg.all;

entity EpixQuad_tb is end EpixQuad_tb;

architecture testbench of EpixQuad_tb is

   constant TPD_G : time := 1 ns;

   constant GET_BUILD_INFO_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);
   constant MOD_BUILD_INFO_C : BuildInfoRetType := (
      buildString => GET_BUILD_INFO_C.buildString,
      fwVersion   => GET_BUILD_INFO_C.fwVersion,
      gitHash     => x"1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA");  -- Force githash
   constant SIM_BUILD_INFO_C : slv(2239 downto 0) := toSlv(MOD_BUILD_INFO_C);
   
   -- Power Supply Cntrl Ports
   signal asicAnaEn         : sl;
   signal asicDigEn         : sl;
   signal dcdcSync          : slv(10 downto 0);
   signal dcdcEn            : slv(3 downto 0);
   signal ddrVttEn          : sl;
   signal ddrVttPok         : sl;
   
   -- ASIC Carrier IDs
   signal asicDmSn          : slv(3 downto 0);
   
   -- FPGA temperature alert
   signal tempAlertL        : sl;
   
   -- I2C busses
   signal dacScl            : sl;
   signal dacSda            : sl;
   signal monScl            : sl;
   signal monSda            : sl;
   signal humScl            : sl;
   signal humSda            : sl;
   signal humRstN           : sl;
   signal humAlert          : sl;
   
   -- monitor ADC bus
   signal envSck            : sl;
   signal envCnv            : sl;
   signal envDin            : sl;
   signal envSdo            : sl;
   
   -- PGP Ports
   signal pgpClkP           : sl;
   signal pgpClkN           : sl;
   signal pgpRxP            : sl;
   signal pgpRxN            : sl;
   signal pgpTxP            : sl;
   signal pgpTxN            : sl;
   
   -- SYSMON Ports
   signal vPIn              : sl;
   signal vNIn              : sl;
   
   -- ASIC SACI signals
   signal asicSaciResp      : slv(3 downto 0);
   signal asicSaciClk       : slv(3 downto 0);
   signal asicSaciCmd       : slv(3 downto 0);
   signal asicSaciSelL      : slv(15 downto 0);
   
   -- ASIC ACQ signals
   signal asicAcq           : slv(3 downto 0);
   signal asicR0            : slv(3 downto 0);
   signal asicGr            : slv(3 downto 0);
   signal asicSync          : slv(3 downto 0);
   signal asicPpmat         : slv(3 downto 0);
   signal asicRoClkP        : slv(1 downto 0);
   signal asicRoClkN        : slv(1 downto 0);
   signal asicDoutP         : slv(15 downto 0);
   signal asicDoutN         : slv(15 downto 0);
   
   -- Fast ADC Signals
   signal adcClkP           : slv(4 downto 0);
   signal adcClkN           : slv(4 downto 0);
   signal adcFClkP          : slv(9 downto 0);
   signal adcFClkN          : slv(9 downto 0);
   signal adcDClkP          : slv(9 downto 0);
   signal adcDClkN          : slv(9 downto 0);
   signal adcChP            : Slv8Array(9 downto 0);
   signal adcChN            : Slv8Array(9 downto 0);
   
   -- Fast ADC Config SPI
   signal adcSclk           : slv(2 downto 0);
   signal adcSdio           : slv(2 downto 0);
   signal adcCsb            : slv(9 downto 0);
   
   -- debug outputs
   signal dbgOut            : slv(2 downto 0);
   signal spareIo2v5        : slv(4 downto 0);
   
   -- ttl trigger
   signal inputTtl          : slv(2 downto 0) := (others => '0');

   signal iAasicSaciResp   : slv(15 downto 0);
   
   signal aInP     : real;
   signal aInN     : real;
   signal aInArrP  : RealArray(7 downto 0);
   signal aInArrN  : RealArray(7 downto 0);
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

   -------------
   -- OSC Module
   -------------
   U_clkPgp : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,   -- 156.25 MHz
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => pgpClkP,
         clkN => pgpClkN);

   u_epixQuad: entity work.EpixQuadCore
    generic map (
            TPD_G           => TPD_G,
            BUILD_INFO_G    => BUILD_INFO_C,
            AXI_CLK_FREQ_G  => 100.00E+6,
            SIMULATION_G    => true,
            SIM_SPEEDUP_G   => true,
            MIG_CORE_EN     => false,
            COM_TYPE_G      => "PGPv4",
            RATE_G          => "6.25Gbps"
            )
    port map(
             --DRR Memory interface ports
            c0_sys_clk_p      => open,
            c0_sys_clk_n      => open,
            c0_ddr4_dq        => open,
            c0_ddr4_dqs_c     => open,
            c0_ddr4_dqs_t     => open,
            c0_ddr4_adr       => open,
            c0_ddr4_ba        => open,
            c0_ddr4_bg        => open,
            c0_ddr4_reset_n   => open,
            c0_ddr4_act_n     => open,
            c0_ddr4_ck_t      => open,
            c0_ddr4_ck_c      => open,
            c0_ddr4_cke       => open,
            c0_ddr4_cs_n      => open,
            c0_ddr4_dm_dbi_n  => open,
            c0_ddr4_odt       => open,
             --Power Supply Cntrl Ports
            asicAnaEn         => asicAnaEn,
            asicDigEn         => asicDigEn,
            dcdcSync          => dcdcSync,
            dcdcEn            => dcdcEn ,
            ddrVttEn          => ddrVttEn,
            ddrVttPok         => ddrVttPok,
             --ASIC Carrier IDs
            asicDmSn          => asicDmSn,
             --FPGA temperature alert
            tempAlertL        => tempAlertL,
             --I2C busses
            dacScl            => dacScl,
            dacSda            => dacSda,
            monScl            => monScl,
            monSda            => monSda,
            humScl            => humScl,
            humSda            => humSda,
            humRstN           => humRstN,
            humAlert          => humAlert,
             --monitor ADC bus
            envSck            => envSck,
            envCnv            => envCnv,
            envDin            => envDin,
            envSdo            => envSdo,
             --PGP Ports
            pgpClkP           => pgpClkP,
            pgpClkN           => pgpClkN,
            pgpRxP            => pgpRxP,
            pgpRxN            => pgpRxN,
            pgpTxP            => pgpTxP,
            pgpTxN            => pgpTxN,
             --SYSMON Ports
            vPIn              => vPIn,
            vNIn              => vNIn,
             --ASIC SACI signals
            asicSaciResp      => asicSaciResp,
            asicSaciClk       => asicSaciClk,
            asicSaciCmd       => asicSaciCmd,
            asicSaciSelL      => asicSaciSelL,
             --ASIC ACQ signals
            asicAcq           => asicAcq,
            asicR0            => asicR0,
            asicGr            => asicGr,
            asicSync          => asicSync,
            asicPpmat         => asicPpmat ,
            asicRoClkP        => asicRoClkP,
            asicRoClkN        => asicRoClkN,
            asicDoutP         => asicDoutP,
            asicDoutN         => asicDoutN,
             --Fast ADC Signals
            adcClkP           => adcClkP,
            adcClkN           => adcClkN,
            adcFClkP          => adcFClkP,
            adcFClkN          => adcFClkN,
            adcDClkP          => adcDClkP,
            adcDClkN          => adcDClkN,
            adcChP            => adcChP, 
            adcChN            => adcChN,
             --Fast ADC Config SPI
            adcSclk           => adcSclk,
            adcSdio           => adcSdio,
            adcCsb            => adcCsb,
             --debug outputs
            dbgOut            => dbgOut,
            spareIo2v5        => spareIo2v5,
             --ttl trigger
            inputTtl          => inputTtl);



      G_ADC : for i in 0 to 9 generate 
        U_ADC : entity work.ad9249_group
        generic map (
           --OUTPUT_TYPE_G     => (others=>COUNT_OUT),
           OUTPUT_TYPE_G     => (others=>NOISE_OUT),
           NOISE_BASELINE_G  => ADC_BASELINE_C(7+i*8 downto 0+i*8),
           NOISE_VPP_G       => (others=> 5.0e-3),
           PATTERN_G         => (others=>x"2F7C"),
           COUNT_MIN_G       => (others=>x"0000"),
           COUNT_MAX_G       => (others=>x"000F"),
           COUNT_MASK_G      => COUNT_MASK_C(7+i*8 downto 0+i*8),
           INDEX_G           => i
          )
        port map (
         aInP     => aInArrP,
         aInN     => aInArrN,
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
   
   -----------------------------------------------------------------------
   -- process to mimick ASIC analog signal
   -----------------------------------------------------------------------
   process(asicRoClkP(0), adcClkP(0))
      constant aInPStart      : real := 0.0;
      constant aInNStart      : real := 0.0;
      constant digMax         : real := real(2**14-1);
      constant aInStep        : real := 2.0/digMax/2.0;
      variable clkDivCnt      : integer := 0;
   begin
      
      if rising_edge(asicRoClkP(0)) then
         if clkDivCnt = 0 then
            aInP <= aInPStart;
            aInN <= aInNStart;
            clkDivCnt := clkDivCnt + 1;
         else
            if clkDivCnt < 3 then
               clkDivCnt := clkDivCnt + 1;
            else
               clkDivCnt := 0;
            end if;
         end if;
      elsif falling_edge(adcClkP(0)) then
         aInP <= aInP + aInStep;
         aInN <= aInN - aInStep;
      end if;
      
   end process;
   aInArrP(0) <= aInP;
   aInArrP(1) <= aInP;
   aInArrP(2) <= aInP;
   aInArrP(3) <= aInP;
   aInArrP(4) <= aInP;
   aInArrP(5) <= aInP;
   aInArrP(6) <= aInP;
   aInArrP(7) <= aInP;
   aInArrN(0) <= aInN;
   aInArrN(1) <= aInN;
   aInArrN(2) <= aInN;
   aInArrN(3) <= aInN;
   aInArrN(4) <= aInN;
   aInArrN(5) <= aInN;
   aInArrN(6) <= aInN;
   aInArrN(7) <= aInN;
   
   -- need Pll to create ADC readout clock (350 MHz)
   -- must be in phase with adcClk (50 MHz)
   U_PLLAdc : entity surf.ClockManagerUltraScale
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



    GEN_SACI_SLAVE : for i in 15 downto 0 generate
    signal asicSaciSel : slv(15 downto 0);
      begin
      
      asicSaciSel(i) <= not asicSaciSelL(i);
      
      U_SaciSlave : entity surf.SaciSlaveWrapper
         generic map (
            TPD_G    => TPD_G
         )
         port map (
            asicRstL => asicSaciSel(i),
            saciClk  => asicSaciClk(i/4),
            saciSelL => asicSaciSelL(i), 
            saciCmd  => asicSaciCmd(i/4),
            saciRsp  => iAasicSaciResp(i)
         );

   end generate GEN_SACI_SLAVE;
   
   saciSel_p : process (asicSaciSelL, iAasicSaciResp) is
   begin
      if asicSaciSelL(0) = '0' then
         asicSaciResp(0) <= iAasicSaciResp(0);
      elsif asicSaciSelL(1) = '0' then
         asicSaciResp(0) <= iAasicSaciResp(1);
      elsif asicSaciSelL(2) = '0' then
         asicSaciResp(0) <= iAasicSaciResp(2);
      elsif asicSaciSelL(3) = '0' then
         asicSaciResp(0) <= iAasicSaciResp(3);
      end if;
      
      if asicSaciSelL(4) = '0' then
         asicSaciResp(1) <= iAasicSaciResp(4);
      elsif asicSaciSelL(5) = '0' then
         asicSaciResp(1) <= iAasicSaciResp(5);
      elsif asicSaciSelL(6) = '0' then
         asicSaciResp(1) <= iAasicSaciResp(6);
      elsif asicSaciSelL(7) = '0' then
         asicSaciResp(1) <= iAasicSaciResp(7);
      end if;
      
      if asicSaciSelL(8) = '0' then
         asicSaciResp(2) <= iAasicSaciResp(8);
      elsif asicSaciSelL(9) = '0' then
         asicSaciResp(2) <= iAasicSaciResp(9);
      elsif asicSaciSelL(10) = '0' then
         asicSaciResp(2) <= iAasicSaciResp(10);
      elsif asicSaciSelL(11) = '0' then
         asicSaciResp(2) <= iAasicSaciResp(11);
      end if;
      
      if asicSaciSelL(12) = '0' then
         asicSaciResp(3) <= iAasicSaciResp(12);
      elsif asicSaciSelL(13) = '0' then
         asicSaciResp(3) <= iAasicSaciResp(13);
      elsif asicSaciSelL(14) = '0' then
         asicSaciResp(3) <= iAasicSaciResp(14);
      else
         asicSaciResp(3) <= iAasicSaciResp(15);
      end if;
      
   end process saciSel_p;
end testbench;
