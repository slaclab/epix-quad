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
      slowAdcRefClk       : out sl;
      slowAdcDout         : in  sl;
      slowAdcDrdy         : in  sl;
      slowAdcSync         : out sl; --unconnected by default
      -- Fast ADC Control
      adcSpiClk           : out sl;
      adcSpiData          : inout sl;
      adcSpiCsb           : out slv(2 downto 0);
      adcPdwn01           : out sl;
      adcPdwnMon          : out sl;
      -- ASIC SACI Interface
      asicSaciCmd         : out sl;
      asicSaciClk         : out sl;
      asicSaciSel         : out slv(3 downto 0);
      asicSaciRsp         : in  sl;
      -- ADC readout signals
      --adcClkP             : out slv( 1 downto 0);
      --adcClkM             : out slv( 1 downto 0);
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

   attribute keep :string;

   constant tpd        : time := 0.5 ns;

   signal led_count    : natural;
   signal led_reg      : std_logic_vector(3 downto 0);

   signal stableClk    : std_logic;
   signal powerUpRst   : std_logic;
   signal asicRoClkEn  : std_logic;
   signal asicRefClkEn : std_logic;
   signal asicRoClk    : std_logic_vector(1 downto 0);
   signal asicRefClk   : std_logic_vector(1 downto 0);
   
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
   
   signal ddrBitClk     : std_logic;
   signal idelayeClk    : std_logic;
   signal idelayeRst    : std_logic;
   signal resync        : std_logic_vector(1 downto 0);
   signal sync          : std_logic_vector(1 downto 0);
   signal delay         : Slv5Array(1 downto 0);
   signal asicD10bit    : Slv10Array(1 downto 0);
   signal asicD8bit     : Slv8Array(1 downto 0);
   signal asicD8bitK    : Slv1Array(1 downto 0);
   signal asicD8bitCErr : Slv1Array(1 downto 0);
   signal asicD8bitDErr : Slv1Array(1 downto 0);
   
   signal pgpClk        : std_logic;
   signal sysClk        : std_logic;
   signal tixBitClk     : std_logic;
   signal tixWrdClk     : std_logic;
   signal idlyClk       : std_logic;
   signal tixRoClk      : std_logic;
   signal tixRefClk     : std_logic;
   signal pgpRst        : std_logic;
   signal sysRst        : std_logic;
   signal tixBitRst     : std_logic;
   signal tixWrdRst     : std_logic;
   signal idlyRst       : std_logic;
   signal tixRoRst      : std_logic;
   signal tixRefRst     : std_logic;
   
   
   signal decodeErr        : std_logic_vector(1 downto 0);
   signal sync_cnt_en      : std_logic_vector(1 downto 0);
   constant oosync_cnt_max : integer := 1;
   constant sync_cnt_max   : integer := 1;
   signal oosync_cnt       : IntegerArray(0 to 1);
   signal sync_cnt         : IntegerArray(0 to 1);
   
   
   signal re_sync          : std_logic_vector(1 downto 0);
   signal testDone         : std_logic_vector(1 downto 0);
   signal set_delay        : Slv5Array(1 downto 0);
   signal patternCnt       : Slv32Array(1 downto 0);
   
   
   attribute keep of sysClk : signal is "true";
   attribute keep of asicD10bit : signal is "true";
   attribute keep of resync : signal is "true";
   attribute keep of sync : signal is "true";
   attribute keep of delay : signal is "true";
   attribute keep of oosync_cnt : signal is "true";
   attribute keep of sync_cnt : signal is "true";
   attribute keep of asicD8bit : signal is "true";
   attribute keep of asicD8bitK : signal is "true";
   attribute keep of asicD8bitCErr : signal is "true";
   attribute keep of asicD8bitDErr : signal is "true";

   
begin

   -----------------------------------------------------------------------------------------------------------------------
   --  Clocks generation
   -----------------------------------------------------------------------------------------------------------------------
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 400 MHz Idelaye2 calibration clock
   -- clkOut(1) : 250 MHz Tixel bit clock
   -- clkOut(2) : 50 MHz Tixel 10b word clock
   -- clkOut(3) : 100 MHz sysClk
   -- clkOut(4) : 25 MHz Tixel readout clock
   -- clkOut(5) : 20 MHz Tixel reference clock
   clockGen_i : entity work.ClockManager7
   generic map (
      BANDWIDTH_G          => "LOW",
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 6,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 5,
      CLKFBOUT_MULT_F_G    => 32.0,
      CLKOUT0_DIVIDE_F_G   => 2.5,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5,
      CLKOUT1_DIVIDE_G     => 4,
      CLKOUT1_PHASE_G      => 0.0,
      CLKOUT1_DUTY_CYCLE_G => 0.5,
      CLKOUT2_DIVIDE_G     => 20,
      CLKOUT2_PHASE_G      => 0.0,
      CLKOUT2_DUTY_CYCLE_G => 0.5,
      CLKOUT3_DIVIDE_G     => 10,
      CLKOUT3_PHASE_G      => 0.0,
      CLKOUT3_DUTY_CYCLE_G => 0.5,
      CLKOUT4_DIVIDE_G     => 40,
      CLKOUT4_PHASE_G      => 0.0,
      CLKOUT4_DUTY_CYCLE_G => 0.5,
      CLKOUT5_DIVIDE_G     => 50,
      CLKOUT5_PHASE_G      => 0.0,
      CLKOUT5_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => pgpRst,
      clkOut(0) => idlyClk,
      clkOut(1) => tixBitClk,
      clkOut(2) => tixWrdClk,
      clkOut(3) => sysClk,
      clkOut(4) => open,
      --clkOut(4) => tixRoClk,
      clkOut(5) => tixRefClk,
      rstOut(0) => idlyRst,
      rstOut(1) => tixBitRst,
      rstOut(2) => tixWrdRst,
      rstOut(3) => sysRst,
      rstOut(4) => open,
      --rstOut(4) => tixRoRst,
      rstOut(5) => tixRefRst,
      locked    => open
   );
   
   -- clkOut(0) : 5 MHz Cpix readout clock
   clockGen2_i : entity work.ClockManager7
   generic map (
      BANDWIDTH_G          => "LOW",
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 1,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 10,
      CLKFBOUT_MULT_F_G    => 38.4,
      CLKOUT0_DIVIDE_F_G   => 120.0,
      CLKOUT0_PHASE_G      => 0.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => pgpRst,
      clkOut(0) => tixRoClk,
      rstOut(0) => tixRoRst,
      locked    => open
   );
    
   
   -----------------------------------------------------------------------------------------------------------------------
   --  TPIX control 
   -----------------------------------------------------------------------------------------------------------------------
   
   mps     <= asic01DM1;
   tgOut   <= asic01DM2;
   
   U_Saci : entity work.SaciMaster 
   port map (
      clk           => tixRefClk,
      rst           => tixRefRst,
      saciClk       => asicSaciClk,
      saciSelL      => asicSaciSel,
      saciCmd       => asicSaciCmd,
      saciRsp       => asicSaciRsp,
      saciMasterIn  => saciMasterIn,
      saciMasterOut => saciMasterOut
   );
   
   saci_vio_i : ENTITY work.saci_vio
   PORT MAP (
      clk            => tixRefClk,
      probe_in0(0)   => saciMasterOut.ack,
      probe_in1(0)   => saciMasterOut.fail,
      probe_in2      => saciMasterOut.rdData,
      probe_out0(0)  => saciMasterIn.req,
      probe_out1(0)  => saciMasterIn.reset,
      probe_out2     => saciMasterIn.chip,
      probe_out3(0)  => saciMasterIn.op,
      probe_out4     => saciMasterIn.cmd,
      probe_out5     => saciMasterIn.addr,
      probe_out6     => saciMasterIn.wrData
   );
   
   asic_vio_i : ENTITY work.asic_vio
   PORT MAP(
      clk            => sysClk,
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
      clk            => sysClk,
      probe_in0(0)   => powerGood,
      probe_out0(0)  => analogCardDigPwrEn,
      probe_out1(0)  => analogCardAnaPwrEn
   );
   
   asic_clk_gen: for i in 0 to 1 generate 
   
      refClkDdr_i : ODDR 
      port map ( 
         Q  => asicRefClk(i),
         C  => tixRefClk,
         CE => asicRefClkEn,
         D1 => '1',
         D2 => '0',
         R  => '0',
         S  => '0'
      );
   
      refclk_i : OBUFDS
      port map (
         I => asicRefClk(i),
         O  => asicRefClkP(i),
         OB => asicRefClkM(i)
      );
          
      
      roClkDdr_i : ODDR 
      port map ( 
         Q  => asicRoClk(i),
         C  => tixRoClk,
         CE => asicRoClkEn,
         D1 => '1',
         D2 => '0',
         R  => '0',
         S  => '0'
      );
      
      roclk_i : OBUFDS
      port map (
         I => asicRoClk(i),
         O  => asicRoClkP(i),
         OB => asicRoClkM(i)
      );
   
   end generate;
   
   
   
   -- tap delay calibration 
   inDlyCali_i : IDELAYCTRL
   port map (
      REFCLK => idlyClk,
      RST    => idlyRst,
      RDY    => open
   );
   
   tixDecode_gen : for i in 0 to 1 generate 
   
      ---- 10b encoded stream deserializer
      --tixDeser_i: entity work.TixelDeser
      --generic map (
      --   IDELAYCTRL_FREQ_G => 400.0
      --)
      --port map ( 
      --   slowRst        => tixWrdRst,
      --   slowClk        => tixWrdClk,
      --   fastClk        => tixBitClk,
      --   
      --   asicDoutP      => asicDoutP(i),
      --   asicDoutM      => asicDoutM(i),
      --   
      --   dataOut        => asicD10bit(i),
      --   
      --   resync         => resync(i),
      --   sync           => sync(i),
      --   delay          => delay(i)
      --);
      
      tixDeser_i: entity work.TixelDeserTest 
      generic map (
         IDELAYCTRL_FREQ_G => 400.0
      )
      port map ( 
         slowRst        => tixWrdRst,
         slowClk        => tixWrdClk,
         fastClk        => tixBitClk,
         
         asicDoutP      => asicDoutP(i),
         asicDoutM      => asicDoutM(i),
         
         --status
         patternCnt     => patternCnt(i),
         testDone       => testDone(i),
         in_sync        => sync(i),
         
         --control
         resync         => re_sync(i),
         delay          => set_delay(i)
      );
      
      sync_vio_i : ENTITY work.sync_vio
      PORT MAP(
         clk            => tixWrdClk,
         probe_in0      => patternCnt(i),
         probe_in1(0)   => testDone(i),
         probe_in2(0)   => sync(i),
         probe_out0(0)  => re_sync(i),
         probe_out1     => set_delay(i)
      );
      
      --10b8b decoder
      tixDecode_i: entity work.Decoder8b10b
      generic map (
         NUM_BYTES_G => 1,
         RST_POLARITY_G => '0'
      )
      port map (
         clk      => tixWrdClk,
         clkEn    => '1',
         rst      => sync(i),
         dataIn   => asicD10bit(i),
         dataOut  => asicD8bit(i),
         dataKOut => asicD8bitK(i),
         codeErr  => asicD8bitCErr(i),
         dispErr  => asicD8bitDErr(i)
      );
      
      decodeErr(i) <= asicD8bitCErr(i)(0) or asicD8bitDErr(i)(0);
      
      -- out of sync counters
      oosync_cnt_p: process ( tixWrdClk ) 
      begin
         if rising_edge(tixWrdClk) then
            if tixWrdRst = '1' or sync(i) = '0' or sync_cnt_en(i) = '1' then
               oosync_cnt(i) <= 0 after TPD_G;
            elsif decodeErr(i) = '1' and oosync_cnt(i) < oosync_cnt_max then
               oosync_cnt(i) <= oosync_cnt(i) + 1 after TPD_G;
            end if;
         end if;
      end process;
      
      resync(i) <= '1' when oosync_cnt(i) = oosync_cnt_max else '0';
      
      -- in sync counters
      sync_cnt_p: process ( tixWrdClk ) 
      begin
         if rising_edge(tixWrdClk) then
            if tixWrdRst = '1' or sync(i) = '0' or decodeErr(i) = '1' then
               sync_cnt(i) <= 0 after TPD_G;
            elsif sync_cnt(i) < sync_cnt_max then
               sync_cnt(i) <= sync_cnt(i) + 1 after TPD_G;
            end if;
         end if;
      end process;
      
      sync_cnt_en(i) <= '1' when sync_cnt(i) = sync_cnt_max else '0';
      
   end generate;
    
    
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
        pgpClk           => pgpClk,
        pgpRst           => pgpRst,
        stableClk        => stableClk,
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
    
     -- Generate power-up reset signal
     U_PwrUpRst : entity work.PwrUpRst
        port map (
           clk    => stableClk,
           rstOut => powerUpRst
        ); 
    -----------------------------------------------------------------------------------------------------------------------
    --  Test LED
    -----------------------------------------------------------------------------------------------------------------------
    
    ldcnt_p : process(sysClk)
    begin
        if rising_edge(sysClk) then 
            if sysRst = '1' then
                led_count <= 0;
                led_reg(0) <= '0';
                led_reg(1) <= '1';
                led_reg(2) <= '0';
                led_reg(3) <= '1';
            elsif led_count = 20000000 and asicD8bit(0) = "10101010" and asicD8bit(1) = "10101010" and asicD8bitK(1) = "0" and asicD8bitK(0) = "0" then
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
