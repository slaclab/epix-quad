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
use work.SaciMasterPkg.all;
use work.Pgp2bPkg.all;


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
      --adcClkP             : out slv( 2 downto 0);
      --adcClkM             : out slv( 2 downto 0);
      --adcDoClkP           : in  slv( 2 downto 0);
      --adcDoClkM           : in  slv( 2 downto 0);
      --adcFrameClkP        : in  slv( 2 downto 0);
      --adcFrameClkM        : in  slv( 2 downto 0);
      --adcDoP              : in  slv(19 downto 0);
      --adcDoM              : in  slv(19 downto 0);
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
      --asicDoutP           : in  slv(1 downto 0);
      --asicDoutM           : in  slv(1 downto 0);
      asicDout1P          : in  sl;
      asicDout1M          : in  sl;
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

    attribute keep :string;

    constant tpd        : time := 0.5 ns;

    signal led_count    : natural;
    signal led_reg      : std_logic_vector(3 downto 0);

    signal syncSysRstIn : std_logic_vector(2 downto 0);
    signal sysRstCnt    : unsigned(3 downto 0);
    signal sysDcmLock   : std_logic;
    signal sysResetIn   : std_logic;
    signal sysClkRst    : std_logic;
    signal sysClk       : std_logic;
    signal roClk        : std_logic;
    signal powerUpRst   : std_logic;
    signal sysRefClk    : std_logic;
    signal tmpSysClk    : std_logic;
    signal tmpRoClk     : std_logic;
    signal sysOut0      : std_logic;
    signal sysFbIn      : std_logic;
    signal sysFbOut     : std_logic;
    signal sysStableRst : std_logic;
    signal sysStableClk : std_logic;
    signal asicRoClkEn  : std_logic;
    signal asicRefClkEn : std_logic;
    signal asicRoClk    : std_logic;
    signal asicRefClk   : std_logic;
    
    signal tmpSampleClk : std_logic;
    signal sampleClk    : std_logic;
    signal asicDout1    : std_logic;
    
    
    attribute keep of sysStableClk : signal is "true";
    attribute keep of sampleClk : signal is "true";
    attribute keep of asicDout1 : signal is "true";
    
    -- TX Interfaces - 1 lane, 4 VCs
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   -- RX Interfaces - 1 lane, 4 VCs
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);
   
   -- Pgp Rx/Tx types
   signal pgpRxIn     : Pgp2bRxInType;
   signal pgpRxOut   : Pgp2bRxOutType;
   signal pgpTxIn     : Pgp2bTxInType;
   signal pgpTxOut    : Pgp2bTxOutType;
    
    
    signal saciMasterIn  : SaciMasterInType;
    signal saciMasterOut : SaciMasterOutType;

   
begin

    -----------------------------------------------------------------------------------------------------------------------
    --  System and GTX Clock 
    -----------------------------------------------------------------------------------------------------------------------

    
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
        CLKOUT0_DIVIDE_F     => 64.0,
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.5,
        CLKOUT0_USE_FINE_PS  => FALSE,
        
        CLKOUT1_DIVIDE       => 50,
        CLKOUT1_PHASE        => 0.000,
        CLKOUT1_DUTY_CYCLE   => 0.500,
        CLKOUT1_USE_FINE_PS  => false,
        
        CLKOUT2_DIVIDE       => 4,
        CLKOUT2_PHASE        => 0.000,
        CLKOUT2_DUTY_CYCLE   => 0.500,
        CLKOUT2_USE_FINE_PS  => false,
        
        CLKIN1_PERIOD        => 6.4,
        REF_JITTER1          => 0.006
    )
    port map (
        CLKFBOUT             => sysFbOut,
        CLKFBOUTB            => open,
        CLKOUT0              => tmpSysClk, 
        CLKOUT0B             => open,
        CLKOUT1              => tmpRoClk,
        CLKOUT1B             => open,
        CLKOUT2              => tmpSampleClk,
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
    
    
    -- reset input
    sysResetIn <= (not sysDcmLock); 


    -- Global Buffer For SYS Clock
    U_SysClkBuff: BUFG port map (
        O => sysClk,
        I => tmpSysClk
    );
    
    U_RoBuff: BUFG port map (
        O => roClk,
        I => tmpRoClk
    );
    
    U_SmplBuff: BUFG port map (
        O => sampleClk,
        I => tmpSampleClk
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
    
    mps     <= asic01DM1;
    tgOut   <= asic01DM2;
    
    U_Saci : entity work.SaciMaster 
    port map (
       clk           => sysClk,
       rst           => sysClkRst,
       saciClk       => asicSaciClk,
       saciSelL      => asicSaciSel,
       saciCmd       => asicSaciCmd,
       saciRsp       => asicSaciRsp,
       saciMasterIn  => saciMasterIn,
       saciMasterOut => saciMasterOut
   );
   
   saci_vio_i : ENTITY work.saci_vio
   PORT MAP (
      clk         => sysClk,
      probe_in0(0)=> saciMasterOut.ack,
      probe_in1(0)=> saciMasterOut.fail,
      probe_in2   => saciMasterOut.rdData,
      probe_out0(0)=> saciMasterIn.req,
      probe_out1(0)=> saciMasterIn.reset,
      probe_out2  => saciMasterIn.chip,
      probe_out3(0)=> saciMasterIn.op,
      probe_out4  => saciMasterIn.cmd,
      probe_out5  => saciMasterIn.addr,
      probe_out6  => saciMasterIn.wrData
   );
   
   asic_vio_i : ENTITY work.asic_vio
   PORT MAP(
      clk         => sysClk,
      probe_out0(0)  => asicTpulse,
      probe_out1(0)  => asicStart,
      probe_out2(0)  => asicPPbe,
      probe_out3(0)  => asicR0,
      probe_out4(0)  => asicPpmat,
      probe_out5(0)  => asicGlblRst,
      probe_out6(0)  => asicSync,
      probe_out7(0)  => asicAcq,
      probe_out8(0)  => asicRoClkEn,
      probe_out9(0)  => asicRefClkEn
   );
   
   power_vio_i : ENTITY work.power_vio
   PORT MAP(
      clk         => sysClk,
      probe_in0(0)   => powerGood,
      probe_out0(0)  => analogCardDigPwrEn,
      probe_out1(0)  => analogCardAnaPwrEn
   );
   
   asicRefClk <= asicRefClkEn and sysClk;
   asicRoClk <= asicRoClkEn and roClk;
   
   refclk0_i : OBUFDS
   port map (
       I => asicRefClk,
       O  => asicRefClkP(0),
       OB => asicRefClkM(0));
   
   refclk1_i : OBUFDS
   port map (
       I => asicRefClk,
       O  => asicRefClkP(1),
       OB => asicRefClkM(1));
       
   roclk0_i : OBUFDS
   port map (
       I => asicRoClk,
       O  => asicRoClkP(0),
       OB => asicRoClkM(0));
   
   roclk1_i : OBUFDS
   port map (
       I => asicRoClk,
       O  => asicRoClkP(1),
       OB => asicRoClkM(1));
   
   --roclk1_i : IBUFDS
   --port map (
   --    I    => asicDout1P,
   --    IB   => asicDout1M,
   --    O    => asicDout1);
    
    asicDout1 <= asicDout1P;
    
    
   U_Pgp2bVarLatWrapper : entity work.EpixPgp2bGtp7Wrapper
     generic map (
        TPD_G                => TPD_G,
        -- MMCM Configurations (Defaults: gtClkP = 125 MHz Configuration)
        CLKIN_PERIOD_G       => 6.4, -- gtClkP/2
        DIVCLK_DIVIDE_G      => 1,
        CLKFBOUT_MULT_F_G    => 6.375,
        CLKOUT0_DIVIDE_F_G   => 6.375,
        -- Quad PLL Configurations
        QPLL_REFCLK_SEL_G    => "001",
        QPLL_FBDIV_IN_G      => 4,
        QPLL_FBDIV_45_IN_G   => 5,
        QPLL_REFCLK_DIV_IN_G => 1,
        -- MGT Configurations
        RXOUT_DIV_G          => 2,
        TXOUT_DIV_G          => 2,
        -- Configure Number of Lanes
        NUM_VC_EN_G          => 4,
        -- Interleave configure
        VC_INTERLEAVE_G      => 0
     )
     port map (
        -- Manual Reset
        extRst           => powerUpRst,
        -- Clocks and Reset
        pgpClk           => sysStableClk,
        pgpRst           => sysStableRst,
        stableClk        => open,
        -- Non VC Tx Signals
        pgpTxIn          => pgpTxIn,
        pgpTxOut         => pgpTxOut,
        -- Non VC Rx Signals
        pgpRxIn          => pgpRxIn,
        pgpRxOut         => pgpRxOut,
        -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
        pgpTxMasters     => pgpTxMasters,
        pgpTxSlaves      => pgpTxSlaves,
        -- Frame Receive Interface - 1 Lane, Array of 4 VCs
        pgpRxMasters     => pgpRxMasters,
        pgpRxCtrl        => pgpRxCtrl,
        -- GT Pins
        gtClkP           => gtRefClk0P,
        gtClkN           => gtRefClk0N,
        gtTxP            => gtDataTxP,
        gtTxN            => gtDataTxN,
        gtRxP            => gtDataRxP,
        gtRxN            => gtDataRxN
     );   
    
     -- Generate stable reset signal
     U_PwrUpRst : entity work.PwrUpRst
        port map (
           clk    => sysStableClk,
           rstOut => powerUpRst
        ); 
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
            elsif led_count = 20000000 then
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
