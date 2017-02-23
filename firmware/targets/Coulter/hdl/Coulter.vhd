-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Coulter.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 09/30/2015
-- Last update: 2017-02-17
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- Surf Packages
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Ad9249Pkg.all;

-- Coulter Packages
use work.AcquisitionControlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Coulter is
   generic (
      TPD_G                  : time    := 1 ns;
      SIMULATION_G           : boolean := false;
      FIXED_LATENCY_G        : boolean := true;
      ADC_CONFIG_NO_PULLUP_G : boolean := false);
   port (
      -- Debugging IOs
      led                : out   slv(3 downto 0) := (others => '0');
      -- Power good
      powerGood          : in    sl;
      -- Power Control
      analogCardDigPwrEn : out   sl              := '1';
      analogCardAnaPwrEn : out   sl              := '1';
      -- GT CLK Pins
      gtRefClk0P         : in    sl;
      gtRefClk0N         : in    sl;
      -- SFP TX/RX
      gtDataTxP          : out   sl;
      gtDataTxN          : out   sl;
      gtDataRxP          : in    sl;
      gtDataRxN          : in    sl;
      -- SFP control signals
      sfpDisable         : out   sl              := '0';
      -- External Signals
      runTg              : in    sl;
      daqTg              : in    sl;
      mps                : out   sl;
      tgOut              : out   sl;
      -- Board IDs
      snIoAdcCard        : inout sl;
--      snIoCarrier        : inout sl;
      -- Slow ADC
--       slowAdcSclk        : out   sl;
--       slowAdcDin         : out   sl;
--       slowAdcCsb         : out   sl;
--       slowAdcRefClk      : out   sl;
--       slowAdcDout        : in    sl;
--       slowAdcDrdy        : in    sl;
--       slowAdcSync        : out   sl;    --unconnected by default
      -- Fast ADC Control
      adcSpiClk          : out   sl;
      adcSpiData         : inout sl;
      adcSpiCsb          : out   slv(2 downto 0) := (others => '1');
      adcPdwn01          : out   sl;
      adcPdwnMon         : out   sl              := '1';
      -- ADC readout signals
      adcClkP            : out   sl;
      adcClkM            : out   sl;
      adcDoClkP          : in    slv(1 downto 0);
      adcDoClkM          : in    slv(1 downto 0);
      adcFrameClkP       : in    slv(1 downto 0);
      adcFrameClkM       : in    slv(1 downto 0);
      adcDoP             : in    slv6Array(1 downto 0);
      adcDoM             : in    slv6Array(1 downto 0);
      adcOverflow        : in    slv(1 downto 0);
      -- ELine100 Config
      elineResetL        : out   sl;
      elineEnaAMon       : out   slv(1 downto 0) := (others => '0');
      elineMckP          : out   slv(1 downto 0);
      elineMckN          : out   slv(1 downto 0);
      elineScP           : out   slv(1 downto 0);
      elineScN           : out   slv(1 downto 0);
      elineSclk          : out   slv(1 downto 0);
      elineRnW           : out   slv(1 downto 0);
      elineSen           : out   slv(1 downto 0);
      elineSdi           : out   slv(1 downto 0);
      elineSdo           : in    slv(1 downto 0));
end Coulter;

architecture top_level of Coulter is

   -------------------------------------------------------------------------------------------------
   -- AXI-Lite config
   -------------------------------------------------------------------------------------------------
   constant AXIL_MASTERS_C       : integer      := 10;
   constant VERSION_AXIL_C       : integer      := 0;
   constant ASIC_CONFIG_AXIL_C   : IntegerArray := (0 => 1, 1 => 2);
   constant ADC_CONFIG_AXIL_C    : integer      := 3;
   constant ADC_READOUT_0_AXIL_C : integer      := 4;
   constant ADC_READOUT_1_AXIL_C : integer      := 5;
   constant ACQ_CTRL_AXIL_C      : integer      := 6;
   constant PGP_AXIL_C           : integer      := 7;
   constant XADC_AXIL_C          : integer      := 8;
   constant RING_BUF_AXIL_C      : integer      := 9;

   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(AXIL_MASTERS_C, X"00000000", 20, 16);

   constant AXIL_CLK_PERIOD_C  : real := 8.0e-9;
   constant ASIC_SCLK_PERIOD_C : real := ite(SIMULATION_G, 100.0e-9, 1.0e-6);
   constant ADC_SCLK_PERIOD_C  : real := ite(SIMULATION_G, 100.0e-9, 1.0e-6);

   signal srpAxilWriteMaster : AxiLiteWriteMasterType;
   signal srpAxilWriteSlave  : AxiLiteWriteSlaveType;
   signal srpAxilReadMaster  : AxiLiteReadMasterType;
   signal srpAxilReadSlave   : AxiLiteReadSlaveType;

   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_MASTERS_C-1 downto 0);

   signal axilClk : sl;
   signal axilRst : sl;

   signal ssiCmd : SsiCmdMasterType;

   signal adcSpiDataIn  : sl;
   signal adcSpiDataOut : sl;
   signal adcSpiDataEn  : sl;

   signal adcSerial     : Ad9249SerialGroupArray(1 downto 0);
   signal adcStreams    : AxiStreamMasterArray(11 downto 0);
   signal unusedStreams : AxiStreamMasterArray(3 downto 0);

   signal userAxisMaster : AxiStreamMasterType;
   signal userAxisSlave  : AxiStreamSlaveType;
   signal userAxisCtrl   : AxiStreamCtrlType;

   -- Led signals
   signal iLed   : slv(3 downto 0);
   signal iLedEn : sl;

   signal acqStatus : AcquisitionStatusType;

   signal userValues : Slv32Array(0 to 63) := (others => X"00000000");

   -- Recovered PGP clk
   signal distClk      : sl;
   signal distRst      : sl;
   signal distOpCodeEn : sl;
   signal distOpCode   : slv(7 downto 0);

   -- 250 MHz clk drives ASIC readout signals
   signal clk250 : sl;
   signal rst250 : sl;

   signal elineRst  : sl;
   signal elineSc   : sl;
   signal elineMck  : sl;
   signal adcValid  : sl;
   signal adcDone   : sl;
   signal adcClk    : sl;
   signal adcClkRst : sl;

   -- 200 Mhz clock drives IDELAY_CTRL
   signal clk200 : sl;
   signal rst200 : sl;

   -- 100 Mhz clock for IPROG and DeviceDna
   signal clk100 : sl;
   signal rst100 : sl;

   signal debug       : slv(31 downto 0) := (others => '0');
   signal txLinkReady : sl;
   signal rxLinkReady : sl;

   signal trigger   : sl;
   signal stableClk : sl;

   signal bufDataValid : sl;

   attribute mark_debug              : string;
   attribute mark_debug of elineSclk : signal is "TRUE";
   attribute mark_debug of elineRnW  : signal is "TRUE";
   attribute mark_debug of elineSen  : signal is "TRUE";
   attribute mark_debug of elineSdi  : signal is "TRUE";
   attribute mark_debug of elineSdo  : signal is "TRUE";
begin

   U_Heartbeat_stableClk : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 6.4e-9,
         PERIOD_OUT_G => 6.4e-3)
      port map (
         clk => stableClk,              -- [in]
         o   => led(1));                -- [out]

   U_Heartbeat_1 : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 8.0e-9,
         PERIOD_OUT_G => 8.0e-3)
      port map (
         clk => axilClk,                -- [in]
         rst => axilRst,                -- [in]
         o   => led(0));                -- [out]

   U_Heartbeat_2 : entity work.Heartbeat
      generic map (
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 8.0e-9,
         PERIOD_OUT_G => 8.0e-6)
      port map (
         clk => distClk,                -- [in]
         rst => distOpCodeEn,           -- [in]
         o   => tgOut);                 -- [out]

   mps <= '0';                          --debug(2);
--   tgOut <= debug(3);

   -------------------------------------------------------------------------------------------------
   -- PGP
   -------------------------------------------------------------------------------------------------
   U_CoulterPgp_1 : entity work.CoulterPgp
      generic map (
         TPD_G            => TPD_G,
         SIMULATION_G     => SIMULATION_G,
         FIXED_LATENCY_G  => FIXED_LATENCY_G,
         AXIL_BASE_ADDR_G => AXIL_XBAR_CONFIG_C(PGP_AXIL_C).baseAddr)
      port map (
         gtClkP           => gtRefClk0P,                       -- [in]
         gtClkN           => gtRefClk0N,                       -- [in]
         gtRxP            => gtDataRxP,                        -- [in]
         gtRxN            => gtDataRxN,                        -- [in]
         gtTxP            => gtDataTxP,                        -- [out]
         gtTxN            => gtDataTxN,                        -- [out]
         stableClkOut     => stableClk,                        -- [out]
         powerGood        => powerGood,                        -- [in]
         rxLinkReady      => rxLinkReady,                      -- [out]
         txLinkReady      => txLinkReady,                      -- [out]
         distClk          => distClk,                          -- [out]
         distRst          => distRst,                          -- [out]
         distOpCodeEn     => distOpCodeEn,                     -- [out]
         distOpCode       => distOpCode,                       -- [out]
         axilClk          => axilClk,                          -- [out]
         axilRst          => axilRst,                          -- [out]
         mAxilReadMaster  => srpAxilReadMaster,                -- [out]
         mAxilReadSlave   => srpAxilReadSlave,                 -- [in]
         mAxilWriteMaster => srpAxilWriteMaster,               -- [out]
         mAxilWriteSlave  => srpAxilWriteSlave,                -- [in]
         sAxilReadMaster  => locAxilReadMasters(PGP_AXIL_C),   -- [in]
         sAxilReadSlave   => locAxilReadSlaves(PGP_AXIL_C),    -- [out]
         sAxilWriteMaster => locAxilWriteMasters(PGP_AXIL_C),  -- [in]
         sAxilWriteSlave  => locAxilWriteSlaves(PGP_AXIL_C),   -- [out]
         userAxisMaster   => userAxisMaster,                   -- [in]
         userAxisSlave    => userAxisSlave,                    -- [out]
         userAxisCtrl     => userAxisCtrl,                     -- [out]
         ssiCmd           => ssiCmd,                           -- [out]
         debug            => debug);

   -------------------------------------------------------------------------------------------------
   -- Clock Manager (create 250 Mhz clock and 200 MHz clock)
   -------------------------------------------------------------------------------------------------
   U_CtrlClockManager7 : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 3,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 8.0,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => 8.0,
         CLKOUT0_DIVIDE_F_G => 4.0,
         CLKOUT1_DIVIDE_G   => 5,
         CLKOUT2_DIVIDE_G   => 20)
      port map (
         clkIn     => axilClk,
         rstIn     => axilRst,
         clkOut(0) => clk250,
         clkOut(1) => clk200,
         clkOut(2) => clk100,
         rstOut(0) => rst250,
         rstOut(1) => rst200,
         rstOut(2) => rst100);


   -------------------------------------------------------------------------------------------------
   -- Crossbar
   -------------------------------------------------------------------------------------------------
   U_AxiLiteCrossbar_1 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_MASTERS_C,
         DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C,
         DEBUG_G            => true)
      port map (
         axiClk              => axilClk,              -- [in]
         axiClkRst           => axilRst,              -- [in]
         sAxiWriteMasters(0) => srpAxilWriteMaster,   -- [in]
         sAxiWriteSlaves(0)  => srpAxilWriteSlave,    -- [out]
         sAxiReadMasters(0)  => srpAxilReadMaster,    -- [in]
         sAxiReadSlaves(0)   => srpAxilReadSlave,     -- [out]
         mAxiWriteMasters    => locAxilWriteMasters,  -- [out]
         mAxiWriteSlaves     => locAxilWriteSlaves,   -- [in]
         mAxiReadMasters     => locAxilReadMasters,   -- [out]
         mAxiReadSlaves      => locAxilReadSlaves);   -- [in]

   -------------------------------------------------------------------------------------------------
   -- Version (12-bits)
   -------------------------------------------------------------------------------------------------
   U_AxiVersion_1 : entity work.AxiVersion
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_RESP_DECERR_C,
         CLK_PERIOD_G     => AXIL_CLK_PERIOD_C,
         XIL_DEVICE_G     => "7SERIES",
         EN_DEVICE_DNA_G  => true,
         EN_DS2411_G      => true,
         EN_ICAP_G        => true,
         USE_SLOWCLK_G    => true,
         BUFR_CLK_DIV_G   => 8,
         AUTO_RELOAD_EN_G => false)
      port map (
         axiClk         => axilClk,                              -- [in]
         axiRst         => axilRst,                              -- [in]
         axiReadMaster  => locAxilReadMasters(VERSION_AXIL_C),   -- [in]
         axiReadSlave   => locAxilReadSlaves(VERSION_AXIL_C),    -- [out]
         axiWriteMaster => locAxilWriteMasters(VERSION_AXIL_C),  -- [in]
         axiWriteSlave  => locAxilWriteSlaves(VERSION_AXIL_C),   -- [out]
         slowClk        => clk100,
         fdSerSdio      => snIoAdcCard);

--    U_AxiLiteEmpty_1 : entity work.AxiLiteEmpty
--       generic map (
--          TPD_G            => TPD_G,
--          AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
--          NUM_WRITE_REG_G  => 1,
--          NUM_READ_REG_G   => 1)
--       port map (
--          axiClk              => axilClk,                             -- [in]
--          axiClkRst           => axilRst,                             -- [in]
--          axiReadMaster       => locAxilReadMasters(CONFIG_AXIL_C),   -- [in]
--          axiReadSlave        => locAxilReadSlaves(CONFIG_AXIL_C),    -- [out]
--          axiWriteMaster      => locAxilWriteMasters(CONFIG_AXIL_C),  -- [in]
--          axiWriteSlave       => locAxilWriteSlaves(CONFIG_AXIL_C),   -- [out]
--          writeRegister(0)(0) => analogCardDigPwrEn,                  -- [out]
--          writeRegister(0)(1) => analogCardAnaPwrEn);                 -- [out]         


   -------------------------------------------------------------------------------------------------
   -- ASIC config (8 bits each)
   -------------------------------------------------------------------------------------------------
   ELINE_CFG_GEN : for i in 1 downto 0 generate
      U_ELine100Config_1 : entity work.ELine100Config
         generic map (
            TPD_G              => TPD_G,
            AXIL_ERR_RESP_G    => AXI_RESP_DECERR_C,
            AXIL_CLK_PERIOD_G  => AXIL_CLK_PERIOD_C,
            ASIC_SCLK_PERIOD_G => ASIC_SCLK_PERIOD_C)
         port map (
            axilClk         => axilClk,                                     -- [in]
            axilRst         => axilRst,                                     -- [in]
            axilWriteMaster => locAxilWriteMasters(ASIC_CONFIG_AXIL_C(i)),  -- [in]
            axilWriteSlave  => locAxilWriteSlaves(ASIC_CONFIG_AXIL_C(i)),   -- [out]
            axilReadMaster  => locAxilReadMasters(ASIC_CONFIG_AXIL_C(i)),   -- [in]
            axilReadSlave   => locAxilReadSlaves(ASIC_CONFIG_AXIL_C(i)),    -- [out]
            asicEnaAMon     => elineEnaAMon(i),                             -- [out]
            asicSclk        => elineSclk(i),                                -- [out]
            asicSdi         => elineSdi(i),                                 -- [out]
            asicSdo         => elineSdo(i),                                 -- [in]
            asicSen         => elineSen(i),                                 -- [out]
            asicRw          => elineRnW(i));                                -- [out]
   end generate ELINE_CFG_GEN;


   -------------------------------------------------------------------------------------------------
   -- Adc Config (12 bits total)
   -------------------------------------------------------------------------------------------------
   ADC_CONFIG_NO_PULLUP : if (ADC_CONFIG_NO_PULLUP_G) generate
      U_Ad9249Config_1 : entity work.Ad9249ConfigNoPullup
         generic map (
            TPD_G           => TPD_G,
            NUM_CHIPS_G     => 1,
            DEN_POLARITY_G  => '0',
            CLK_EN_PERIOD_G => AXIL_CLK_PERIOD_C*2.0,
            CLK_PERIOD_G    => AXIL_CLK_PERIOD_C,
            AXIL_ERR_RESP_G => AXI_RESP_DECERR_C)
         port map (
            axilClk         => axilClk,                                 -- [in]
            axilRst         => axilRst,                                 -- [in]
            axilReadMaster  => locAxilReadMasters(ADC_CONFIG_AXIL_C),   -- [in]
            axilReadSlave   => locAxilReadSlaves(ADC_CONFIG_AXIL_C),    -- [out]
            axilWriteMaster => locAxilWriteMasters(ADC_CONFIG_AXIL_C),  -- [in]
            axilWriteSlave  => locAxilWriteSlaves(ADC_CONFIG_AXIL_C),   -- [out]
            adcPdwn(0)      => adcPdwn01,                               -- [out]
            adcSclk         => adcSpiClk,                               -- [out]
            adcSDin         => adcSpiDataIn,                            -- [in]
            adcSDout        => adcSpiDataOut,                           -- [out]
            adcSDEn         => adcSpiDataEn,                            -- [out]
            adcCsb          => adcSpiCsb(1 downto 0));                  -- [out]

      U_AdcConfigDataIobuf : IOBUF
         port map (
            O  => adcSpiDataIn,
            IO => adcSpiData,
            I  => adcSpiDataOut,
            T  => adcSpiDataEn);

--    Equivalent of:
--    adcSpiData   <= adcSpiDataOut when adcSpiDataEn = '1' else 'Z';
--    adcSpiDataIn <= adcSpiData;
   end generate ADC_CONFIG_NO_PULLUP;

   ADC_CONFIG_NORMAL : if (not ADC_CONFIG_NO_PULLUP_G) generate
      U_Ad9249Config_2 : entity work.Ad9249Config
         generic map (
            TPD_G             => TPD_G,
            NUM_CHIPS_G       => 1,
            SCLK_PERIOD_G     => ADC_SCLK_PERIOD_C,
            AXIL_CLK_PERIOD_G => AXIL_CLK_PERIOD_C,
            AXIL_ERR_RESP_G   => AXI_RESP_DECERR_C)
         port map (
            axilClk         => axilClk,                                 -- [in]
            axilRst         => axilRst,                                 -- [in]
            axilReadMaster  => locAxilReadMasters(ADC_CONFIG_AXIL_C),   -- [in]
            axilReadSlave   => locAxilReadSlaves(ADC_CONFIG_AXIL_C),    -- [out]
            axilWriteMaster => locAxilWriteMasters(ADC_CONFIG_AXIL_C),  -- [in]
            axilWriteSlave  => locAxilWriteSlaves(ADC_CONFIG_AXIL_C),   -- [out]
            adcPdwn(0)      => adcPdwn01,                               -- [out]
            adcSclk         => adcSpiClk,                               -- [out]
            adcSdio         => adcSpiData,                              -- [inout]
            adcCsb          => adcSpiCsb(1 downto 0));                  -- [out]
   end generate ADC_CONFIG_NORMAL;
   -------------------------------------------------------------------------------------------------
   -- ADC Readout (8 bits each)
   -------------------------------------------------------------------------------------------------
   -- Map raw IO into record structures
   AdcLvdsMap : for i in 1 downto 0 generate
      adcSerial(i).fClkP           <= adcFrameClkP(i);
      adcSerial(i).fClkN           <= adcFrameClkM(i);
      adcSerial(i).dClkP           <= adcDoClkP(i);
      adcSerial(i).dClkN           <= adcDoClkM(i);
      adcSerial(i).chP(5 downto 0) <= adcDoP(i);
      adcSerial(i).chN(5 downto 0) <= adcDoM(i);
   end generate AdcLvdsMap;

   IDELAYCTRL_0 : IDELAYCTRL
      port map (
         RDY    => open,
         REFCLK => clk200,
         RST    => rst200);

   U_Ad9249ReadoutGroup_0 : entity work.Ad9249ReadoutGroup
      generic map (
         TPD_G             => TPD_G,
         NUM_CHANNELS_G    => 6,
         IODELAY_GROUP_G   => "DEFAULT_GROUP",
         IDELAYCTRL_FREQ_G => 200.0,
         DEFAULT_DELAY_G   => "00000",
         ADC_INVERT_CH_G   => X"00")
      port map (
         axilClk                => axilClk,                                    -- [in]
         axilRst                => axilRst,                                    -- [in]
         axilWriteMaster        => locAxilWriteMasters(ADC_READOUT_0_AXIL_C),  -- [in]
         axilWriteSlave         => locAxilWriteSlaves(ADC_READOUT_0_AXIL_C),   -- [out]
         axilReadMaster         => locAxilReadMasters(ADC_READOUT_0_AXIL_C),   -- [in]
         axilReadSlave          => locAxilReadSlaves(ADC_READOUT_0_AXIL_C),    -- [out]
         adcClkRst              => adcClkRst,                                  -- [in]
         adcSerial              => adcSerial(0),                               -- [in]
         adcStreamClk           => clk250,                                     -- [in]
         adcStreams(5 downto 0) => adcStreams(5 downto 0));                    -- [out]

   U_Ad9249ReadoutGroup_1 : entity work.Ad9249ReadoutGroup
      generic map (
         TPD_G             => TPD_G,
         NUM_CHANNELS_G    => 6,
         IODELAY_GROUP_G   => "DEFAULT_GROUP",
         IDELAYCTRL_FREQ_G => 200.0,
         DEFAULT_DELAY_G   => "00000",
         ADC_INVERT_CH_G   => X"00")
      port map (
         axilClk                => axilClk,                                    -- [in]
         axilRst                => axilRst,                                    -- [in]
         axilWriteMaster        => locAxilWriteMasters(ADC_READOUT_1_AXIL_C),  -- [in]
         axilWriteSlave         => locAxilWriteSlaves(ADC_READOUT_1_AXIL_C),   -- [out]
         axilReadMaster         => locAxilReadMasters(ADC_READOUT_1_AXIL_C),   -- [in]
         axilReadSlave          => locAxilReadSlaves(ADC_READOUT_1_AXIL_C),    -- [out]
         adcClkRst              => adcClkRst,                                  -- [in]
         adcSerial              => adcSerial(1),                               -- [in]
         adcStreamClk           => clk250,                                     --[in]
         adcStreams(5 downto 0) => adcStreams(11 downto 6));                   -- [out]

   bufDataValid <= adcStreams(0).tvalid and toSl(adcStreams(0).tdata(15 downto 0) /= X"2000");
   U_AxiLiteRingBuffer_1 : entity work.AxiLiteRingBuffer
      generic map (
         TPD_G            => TPD_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         DATA_WIDTH_G     => 16,
         RAM_ADDR_WIDTH_G => 5)
      port map (
         dataClk         => clk250,                                -- [in]
         dataRst         => rst250,                                -- [in]
         dataValid       => bufDataValid,                          -- [in]
         dataValue       => adcStreams(0).tdata(15 downto 0),      -- [in]
         bufferEnable    => '1',                                   -- [in]
         bufferClear     => '0',                                   -- [in]
         axilClk         => axilClk,                               -- [in]
         axilRst         => axilRst,                               -- [in]
         axilReadMaster  => locAxilReadMasters(RING_BUF_AXIL_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(RING_BUF_AXIL_C),    -- [out]
         axilWriteMaster => locAxilWriteMasters(RING_BUF_AXIL_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(RING_BUF_AXIL_C));  -- [out]


   -------------------------------------------------------------------------------------------------
   -- Acquisition Control (8 bits)
   -------------------------------------------------------------------------------------------------
   trigger <= toSl(distOpCodeEn = '1' and distOpCode = X"55");
   U_AcquisitionControl_1 : entity work.AcquisitionControl
      generic map (
         TPD_G => TPD_G)
      port map (
         axilClk         => axilClk,                               -- [in]
         axilRst         => axilRst,                               -- [in]
         axilReadMaster  => locAxilReadMasters(ACQ_CTRL_AXIL_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(ACQ_CTRL_AXIL_C),    -- [out]
         axilWriteMaster => locAxilWriteMasters(ACQ_CTRL_AXIL_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(ACQ_CTRL_AXIL_C),   -- [out]
         distClk         => distClk,                               -- [in]
         distRst         => distRst,                               -- [in]
         trigger         => trigger,                               -- [in]
         elineRst        => elineRst,                              -- [out]
         elineSc         => elineSc,                               -- [out]
         elineMck        => elineMck,                              -- [out]
         adcClk          => adcClk,                                -- [out]
         adcClkRst       => adcClkRst,                             -- [out]
         acqStatus       => acqStatus);                            -- [out]

   U_ReadoutControl_1 : entity work.ReadoutControl
      generic map (
         TPD_G => TPD_G)
      port map (
         adcStreamClk   => clk250,          -- [in]
         adcStreamRst   => rst250,          -- [in]
         adcStreams     => adcStreams,      -- [in]
         distClk        => distClk,         -- [in]
         distRst        => distRst,         -- [in]
         distTrigger    => trigger,         -- [in]
         clk            => axilClk,         -- [in]
         rst            => axilRst,         -- [in]
         acqStatus      => acqStatus,       -- [in]
         dataAxisMaster => userAxisMaster,  -- [out]
         dataAxisSlave  => userAxisSlave,   -- [in]
         dataAxisCtrl   => userAxisCtrl);   -- [in]

   elineResetL <= not elineRst;

   SC_MCK_OBUF_GEN : for i in 1 downto 0 generate
      SC_OBUF : OBUFDS
         port map (
            I  => elineSc,
            O  => elineScP(i),
            OB => elineScN(i));

      MCK_OBUF : OBUFDS
         port map (
            I  => elineMck,
            O  => elineMckP(i),
            OB => elineMckN(i));

   end generate SC_MCK_OBUF_GEN;

   ADCCLK_OBUF : OBUFDS
      port map (
         I  => adcClk,
         O  => adcClkP,
         OB => adcClkM);

   U_XadcSimpleCore_1 : entity work.XadcSimpleCore
      generic map (
         TPD_G                => TPD_G,
         SEQUENCER_MODE_G     => "DEFAULT",
         SAMPLING_MODE_G      => "CONTINUOUS",
         ADCCLK_RATIO_G       => 7,
         SAMPLE_AVG_G         => "11",                         -- 256 samples
         COEF_AVG_EN_G        => true,
         OVERTEMP_AUTO_SHDN_G => true,
         OVERTEMP_ALM_EN_G    => false,
         OVERTEMP_LIMIT_G     => 125.0,
         OVERTEMP_RESET_G     => 50.0,
         TEMP_ALM_EN_G        => false,
         TEMP_UPPER_G         => 80.0,
         TEMP_LOWER_G         => 70.0)
      port map (
         axilClk         => axilClk,                           -- [in]
         axilRst         => axilRst,                           -- [in]
         axilReadMaster  => locAxilReadMasters(XADC_AXIL_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(XADC_AXIL_C),    -- [out]
         axilWriteMaster => locAxilWriteMasters(XADC_AXIL_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(XADC_AXIL_C));  -- [out]


end top_level;
