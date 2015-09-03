-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TixelP.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-12-11
-- Last update: 2014-12-11
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Modification history:
-- 09/01/2015: created.
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

entity TixelP is
   generic (
      TPD_G : time := 1 ns
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
      snIoCarrier         : inout sl;
      -- Slow ADC
      slowAdcSclk         : out sl;
      slowAdcDin          : out sl;
      slowAdcCsb          : out sl;
      slowAdcDout         : in  sl;
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiData          : inout sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn             : out slv(2 downto 0);
      -- ASIC SACI Interface
      asicSaciCmd         : out sl;
      asicSaciClk         : out sl;
      asicSaciSel         : out slv(3 downto 0);
      asicSaciRsp         : in  sl;
      -- ADC readout signals
      adcClkP             : out slv( 2 downto 0);
      adcClkM             : out slv( 2 downto 0);
      adcDoClkP           : in  slv( 2 downto 0);
      adcDoClkM           : in  slv( 2 downto 0);
      adcFrameClkP        : in  slv( 2 downto 0);
      adcFrameClkM        : in  slv( 2 downto 0);
      adcDoP              : in  slv(19 downto 0);
      adcDoM              : in  slv(19 downto 0);
      -- ASIC Control
      asic01DM1           : in sl;
      asic01DM2           : in sl;
      asicTpulse          : out sl;
      asicStart           : out sl;
      asicPPbe            : out sl;
      
      
      asicR0              : out sl;
      asicPpmat           : out sl;
      asicGlblRst         : out sl;
      asicSync            : out sl;
      asicAcq             : out sl;
      asicDoutP           : in  slv(1 downto 0);
      asicDoutM           : in  slv(1 downto 0);
      asicRoClkP          : out slv(1 downto 0);
      asicRoClkM          : out slv(1 downto 0);
      asicRefClkP         : out slv(1 downto 0);
      asicRefClkM         : out slv(1 downto 0)
      -- TODO: Add DDR pins
      -- TODO: Add I2C pins for SFP
      -- TODO: Add sync pins for DC/DCs
   );
end TixelP;

architecture RTL of TixelP is

    signal led_count    : natural;
    signal led_reg      : std_logic_vector(3 downto 0);

    signal syncSysRstIn : std_logic_vector(2 downto 0);
    signal sysRstCnt    : std_logic_vector(3 downto 0);
    signal sysDcmLock   : std_logic;
    signal sysResetIn   : std_logic;
    signal sysClkRst    : std_logic;
    signal sysClk       : std_logic;
    signal sysClkO      : std_logic;
    signal sysRefClk    : std_logic;
    signal tmpSysClk    : std_logic;
    signal sysOut0      : std_logic;
    signal sysFbIn      : std_logic;
    signal sysFbOut     : std_logic;
    signal sysStableRst : std_logic;
    signal sysStableClk : std_logic;

   
begin

    -----------------------------------------------------------------------------------------------------------------------
    --  System and GTX Clock 
    -----------------------------------------------------------------------------------------------------------------------

    -- GT Reference Clock
    SYS_IBUFDS_GTE2_I : IBUFDS_GTE2
    port map (
        I     => gtRefClk0P,
        IB    => gtRefClk0N,
        CEB   => '0',
        ODIV2 => open,
        O     => sysClkO);
    
    SYS_BUFG_G : BUFG
    port map (
        I => sysClkO,
        O => sysStableClk);
    
    -- Power Up Reset      
    SYS_PwrUpRst_I : entity work.PwrUpRst
    generic map (
        DURATION_G  => 156250000      -- 1 second
        )
    port map (
        arst   => '0',
        clk    => sysStableClk,
        rstOut => sysStableRst);
    
    SYS_MMCME2_ADV_I: MMCME2_ADV 
    generic map (
        BANDWIDTH            => "LOW",
        CLKOUT4_CASCADE      => FALSE,
        COMPENSATION         => "ZHOLD",
        STARTUP_WAIT         => FALSE,
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT_F      => 8.000,
        CLKFBOUT_PHASE       => 0.000,
        CLKFBOUT_USE_FINE_PS => FALSE,
        CLKOUT0_DIVIDE_F     => 8.0,
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.5,
        CLKOUT0_USE_FINE_PS  => FALSE,
        
        CLKOUT1_DIVIDE       => 8,
        CLKOUT1_PHASE        => 0.000,
        CLKOUT1_DUTY_CYCLE   => 0.500,
        CLKOUT1_USE_FINE_PS  => false,
        
        CLKIN1_PERIOD        => 6.4,
        REF_JITTER1          => 0.006
    )
    port map (
        CLKFBOUT             => sysFbOut,
        CLKFBOUTB            => open,
        CLKOUT0              => sysOut0, 
        CLKOUT0B             => open,
        CLKOUT1              => tmpSysClk,
        CLKOUT1B             => open,
        CLKOUT2              => open,
        CLKOUT2B             => open,
        CLKOUT3              => open,
        CLKOUT3B             => open,
        CLKOUT4              => open,
        CLKOUT5              => open,
        CLKOUT6              => open,
        CLKFBIN              => sysFbIn,
        CLKIN1               => sysStableClk,
        CLKIN2               => '0',
        CLKINSEL             => '1',
        DADDR                => (others => '0'),
        DCLK                 => '0',
        DEN                  => '0',
        DI                   => (others => '0'),
        DO                   => open,
        DRDY                 => open,
        DWE                  => '0',
        PSCLK                => '0',
        PSEN                 => '0',
        PSINCDEC             => '0',
        PSDONE               => open,
        LOCKED               => sysDcmLock,
        CLKINSTOPPED         => open,
        CLKFBSTOPPED         => open,
        PWRDWN               => '0',
        RST                  => sysStableRst
    );
    
    SYS_BUFH_1 : BUFH
    port map (
        I => sysFbOut,
        O => sysFbIn); 
    
    SYS_BUFG_2 : BUFG
    port map (
        I => sysOut0,
        O => sysRefClk); 
    
    
    -- reset input
    sysResetIn <= (not sysDcmLock); 


    -- Global Buffer For SYS Clock
    U_SysClkBuff: BUFG port map (
        O => sysClk,
        I => tmpSysClk
    );

    -----------------------------------------------------------------------------------------------------------------------
    --  System Reset 
    -----------------------------------------------------------------------------------------------------------------------

    -- SYS Clock Synced Reset
    process ( sysClk, sysResetIn ) begin
        if sysResetIn = '1' then
            syncSysRstIn <= (others=>'0') after tpd;
            sysRstCnt    <= (others=>'0') after tpd;
            sysClkRst    <= '1'           after tpd;
        elsif rising_edge(sysClk) then
        
            -- Sync local reset, lock and power on reset to local clock
            -- Negative asserted signal
            syncSysRstIn(0) <= '1'             after tpd;
            syncSysRstIn(1) <= syncSysRstIn(0) after tpd;
            syncSysRstIn(2) <= syncSysRstIn(1) after tpd;
        
            -- Reset counter on reset
            if syncSysRstIn(2) = '0' then
                sysRstCnt <= (others=>'0') after tpd;
                sysClkRst <= '1' after tpd;
                
            -- Count Up To Max Value
            elsif sysRstCnt = "1111" then
                sysClkRst <= '0' after tpd;
            
            -- Increment counter
            else
                sysClkRst <= '1'           after tpd;
                sysRstCnt <= sysRstCnt + 1 after tpd;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------------------------------------------------
    --  TPIX control 
    -----------------------------------------------------------------------------------------------------------------------
    
    
    
    
    
    
    
    
    -----------------------------------------------------------------------------------------------------------------------
    --  Test LED
    -----------------------------------------------------------------------------------------------------------------------
    
    ldcnt_p : process(sysClk)
    begin
        if rising_edge(sysClk) then 
            if sysClkRst = '1' then
                led_count <= 0;
                led_reg(0) <= '0';
                led_reg(1) <= '1';
                led_reg(2) <= '0';
                led_reg(3) <= '1';
            elsif led_count = 156000000 then
                led_count <= 0;
                led_reg(0) <= not led_reg(0);
                led_reg(1) <= not led_reg(1);
                led_reg(2) <= not led_reg(2);
                led_reg(3) <= not led_reg(3);
            else
                led_count <= led_count + 1;
            end if;
        end if;
    end process;
   
   led <= led_reg;
   
end RTL;
