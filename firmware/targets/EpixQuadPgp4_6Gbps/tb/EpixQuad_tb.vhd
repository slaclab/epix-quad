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

end testbench;
