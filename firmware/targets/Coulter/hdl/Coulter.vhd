-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Coulter.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 09/30/2015
-- Last update: 2016-09-21
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Ad9249Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity Coulter is
   generic (
      TPD_G        : time    := 1 ns;
      SIMULATION_G : boolean := false);
   port (
      -- Debugging IOs
      led                : out   slv(3 downto 0);
      -- Power good
      powerGood          : in    sl;
      -- Power Control
      analogCardDigPwrEn : out   sl;
      analogCardAnaPwrEn : out   sl;
      -- GT CLK Pins
      gtRefClk0P         : in    sl;
      gtRefClk0N         : in    sl;
      -- SFP TX/RX
      gtDataTxP          : out   sl;
      gtDataTxN          : out   sl;
      gtDataRxP          : in    sl;
      gtDataRxN          : in    sl;
      -- SFP control signals
      sfpDisable         : out   sl;
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
      adcDoP             : in    slv(15 downto 0);
      adcDoM             : in    slv(15 downto 0);
      adcOverflow        : in    slv(1 downto 0);
      -- ELine100 Config
      elineResetL        : out   sl;
      elineEnaAMon       : out   slv(1 downto 0);
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
   constant AXIL_MASTERS_C       : integer      := 8;
   constant VERSION_AXIL_C       : integer      := 0;
   constant ASIC_CONFIG_AXIL_C   : IntegerArray := (0 => 1, 1 => 2);
   constant ADC_CONFIG_AXIL_C    : integer      := 3;
   constant ADC_READOUT_0_AXIL_C : integer      := 4;
   constant ADC_READOUT_1_AXIL_C : integer      := 5;
   constant ACQ_CTRL_AXIL_C      : integer      := 6;
   constant PGP_AXIL_C           : integer      := 7;

   constant AXIL_CROSSBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(AXIL_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(AXIL_MASTERS_C, X"00000000", 16, 12);

   constant AXIL_CLK_PERIOD_C  : real := 6.4e-9;
   constant ASIC_SCLK_PERIOD_C : real := 1.0e-6;
   constant ADC_SCLK_PERIOD_C  : real := 1.0e-6;

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

   signal adcSerial  : Ad9249SerialGroupArray(1 downto 0);
   signal adcStreams : AxiStreamMasterArray(15 downto 0);

   signal userAxisMaster : AxiStreamMasterType;
   signal userAxisSlave  : AxiStreamSlaveType;

   -- Led signals
   signal iLed   : slv(3 downto 0);
   signal iLedEn : sl;

   -- External trigger signals
   signal iRunTg : sl;
   signal iDaqTg : sl;
   signal iMps   : sl;
   signal iTgOut : sl;

   signal userValues : Slv32Array(0 to 63) := (others => X"00000000");

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

begin

   -------------------------------------------------------------------------------------------------
   -- PGP
   -------------------------------------------------------------------------------------------------
   U_CoulterPgp_1 : entity work.CoulterPgp
      generic map (
         TPD_G => TPD_G)
      port map (
         gtClkP           => gtRefClk0P,                       -- [in]
         gtClkN           => gtRefClk0N,                       -- [in]
         gtRxP            => gtDataRxP,                        -- [in]
         gtRxN            => gtDataRxN,                        -- [in]
         gtTxP            => gtDataTxP,                        -- [out]
         gtTxN            => gtDataTxN,                        -- [out]
         powerBad         => '0',                              -- [in]
         rxLinkReady      => open,                             -- [out]
         txLinkReady      => open,                             -- [out]
         axilClk          => axilClk,                          -- [out]
         axilRst          => axilRst,                          -- [out]
         mAxilReadMaster  => srpAxilReadMaster,                -- [out]
         mAxilReadSlave   => srpAxilReadSlave,                 -- [in]
         mAxilWriteMaster => srpAxilWriteMaster,               -- [out]
         mAxilWriteSlave  => srpAxilWriteSlave,                -- [in]
         sAxilReadMaster  => locAxilReadMasters(PGP_AXIL_C),   -- [out]
         sAxilReadSlave   => locAxilReadSlaves(PGP_AXIL_C),    -- [in]
         sAxilWriteMaster => locAxilWriteMasters(PGP_AXIL_C),  -- [out]
         sAxilWriteSlave  => locAxilWriteSlaves(PGP_AXIL_C),   -- [in]
         userAxisMaster   => userAxisMaster,                   -- [in]
         userAxisSlave    => userAxisSlave,                    -- [out]
         ssiCmd           => ssiCmd);                          -- [out]

   -------------------------------------------------------------------------------------------------
   -- Clock Manager (create 250 Mhz clock and 200 MHz clock)
   -- Could bring out stableClk to drive this.
   -------------------------------------------------------------------------------------------------
   U_CtrlClockManager7 : entity work.ClockManager7
      generic map (
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         NUM_CLOCKS_G       => 3,
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 6.4,
         DIVCLK_DIVIDE_G    => 5,
         CLKFBOUT_MULT_F_G  => 32.0,
         CLKOUT0_DIVIDE_F_G => 4.0,
         CLKOUT1_DIVIDE_G   => 5,
         CLKOUT2_DIVIDE_G   => 10)
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
         MASTERS_CONFIG_G   => AXIL_CROSSBAR_CONFIG_C,
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
         EN_DS2411_G      => false,
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
         userValues     => userValues);                          -- [in] Bring Board ID's in here

   U_DS2411_ADC_BOARD : entity work.DS2411Core
      generic map (
         TPD_G        => TPD_G,
         CLK_PERIOD_G => AXIL_CLK_PERIOD_C)
      port map (
         clk                    => axilClk,
         rst                    => axilRst,  -- might need special reset
         fdSerSdio              => snIoAdcCard,
         fdSerial(31 downto 0)  => userValues(1),
         fdSerial(63 downto 32) => userValues(2),
         fdValid                => userValues(0)(0));

--    U_DS2411_CARRIER_BOARD : entity work.DS2411Core
--       generic map (
--          TPD_G        => TPD_G,
--          CLK_PERIOD_G => AXIL_CLK_PERIOD_C)
--       port map (
--          clk                    => axilClk,
--          rst                    => axilRst,
--          fdSerSdio              => snIoCarrier,
--          fdSerial(31 downto 0)  => userValues(4),
--          fdSerial(63 downto 32) => userValues(5),
--          fdValid                => userValues(3)(0));

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
            asicSclk        => elineSclk(i),                                -- [out]
            asicSdi         => elineSdi(i),                                 -- [out]
            asicSdo         => elineSdo(i),                                 -- [in]
            asicSen         => elineSen(i),                                 -- [out]
            asicRw          => elineRnW(i));                                -- [out]
   end generate ELINE_CFG_GEN;


   -------------------------------------------------------------------------------------------------
   -- Adc Config (12 bits total)
   -------------------------------------------------------------------------------------------------
   U_Ad9249Config_1 : entity work.Ad9249ConfigNoPullup
      generic map (
         TPD_G           => TPD_G,
         NUM_CHIPS_G     => 1,
         DEN_POLARITY_G => '0',
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
   
--    adcSpiData   <= adcSpiDataOut when adcSpiDataEn = '1' else 'Z';
--    adcSpiDataIn <= adcSpiData;

   -------------------------------------------------------------------------------------------------
   -- ADC Readout (8 bits each)
   -------------------------------------------------------------------------------------------------
   -- Map raw IO into record structures
   AdcLvdsMap : for i in 1 downto 0 generate
      adcSerial(i).fClkP <= adcFrameClkP(i);
      adcSerial(i).fClkN <= adcFrameClkM(i);
      adcSerial(i).dClkP <= adcDoClkP(i);
      adcSerial(i).dClkN <= adcDoClkM(i);
      adcSerial(i).chP   <= adcDoP((i+1)*8-1 downto i*8);
      adcSerial(i).chN   <= adcDoM((i+1)*8-1 downto i*8);
   end generate AdcLvdsMap;

   IDELAYCTRL_0 : IDELAYCTRL
      port map (
         RDY    => open,
         REFCLK => clk200,
         RST    => rst200);

   U_Ad9249ReadoutGroup_0 : entity work.Ad9249ReadoutGroup
      generic map (
         TPD_G             => TPD_G,
         NUM_CHANNELS_G    => 8,
         IODELAY_GROUP_G   => "DEFAULT_GROUP",
         IDELAYCTRL_FREQ_G => 200.0,
         DEFAULT_DELAY_G   => "00000",
         ADC_INVERT_CH_G   => X"00")
      port map (
         axilClk         => axilClk,                                    -- [in]
         axilRst         => axilRst,                                    -- [in]
         axilWriteMaster => locAxilWriteMasters(ADC_READOUT_0_AXIL_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(ADC_READOUT_0_AXIL_C),   -- [out]
         axilReadMaster  => locAxilReadMasters(ADC_READOUT_0_AXIL_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(ADC_READOUT_0_AXIL_C),    -- [out]
         adcClkRst       => adcClkRst,                                  -- [in]
         adcSerial       => adcSerial(0),                               -- [in]
         adcStreamClk    => clk250,                                    -- [in]
         adcStreams      => adcStreams(7 downto 0));                    -- [out]

   U_Ad9249ReadoutGroup_1 : entity work.Ad9249ReadoutGroup
      generic map (
         TPD_G             => TPD_G,
         NUM_CHANNELS_G    => 8,
         IODELAY_GROUP_G   => "DEFAULT_GROUP",
         IDELAYCTRL_FREQ_G => 200.0,
         DEFAULT_DELAY_G   => "00000",
         ADC_INVERT_CH_G   => X"00")
      port map (
         axilClk         => axilClk,                                    -- [in]
         axilRst         => axilRst,                                    -- [in]
         axilWriteMaster => locAxilWriteMasters(ADC_READOUT_1_AXIL_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(ADC_READOUT_1_AXIL_C),   -- [out]
         axilReadMaster  => locAxilReadMasters(ADC_READOUT_1_AXIL_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(ADC_READOUT_1_AXIL_C),    -- [out]
         adcClkRst       => adcClkRst,                                  -- [in]
         adcSerial       => adcSerial(1),                               -- [in]
         adcStreamClk    => clk250,                                    --[in]
         adcStreams      => adcStreams(15 downto 8));                   -- [out]

   -------------------------------------------------------------------------------------------------
   -- Acquisition Control (8 bits)
   -------------------------------------------------------------------------------------------------
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
         clk250          => clk250,                                -- [in]
         rst250          => rst250,                                -- [in]
         trigger         => ssiCmd.valid,                          -- [in]
         elineRst        => elineRst,                              -- [out]
         elineSc         => elineSc,                               -- [out]
         elineMck        => elineMck,                              -- [out]
         adcValid        => adcValid,                              -- [out]
         adcDone         => adcDone,                               -- [out]
         adcClk          => adcClk,                                -- [out]
         adcClkRst       => adcClkRst);                            -- [out]

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

end top_level;
