-------------------------------------------------------------------------------
-- Title      : Coulter PGP 
-------------------------------------------------------------------------------
-- File       : CoulterPgp.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-03
-- Last update: 2016-11-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of Coulter. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of Coulter, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Gtp7CfgPkg.all;
use work.Pgp2bPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;

use work.CoulterPkg.all;

entity CoulterPgp is
   generic (
      TPD_G        : time    := 1 ns;
      SIMULATION_G : boolean := false);
   port (
      -- GTX 7 Ports
      gtClkP           : in  sl;
      gtClkN           : in  sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl;
      gtTxP            : out sl;
      gtTxN            : out sl;
      -- Input power on reset (Do we want this...?)
      powerBad         : in  sl                  := '0';
      -- Output status
      rxLinkReady      : out sl;
      txLinkReady      : out sl;
      -- Recovered clock and trigger
      distClk          : out sl;
      distRst          : out sl;
      distOpCodeEn     : out sl;
      distOpCode       : out slv(7 downto 0);
      -- AXIL Interface
      axilClk          : out sl;
      axilRst          : out sl;
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- Slave AXIL interface for PGP and GTP
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Streaming data Links (axiClk domain)      
      userAxisMaster   : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      userAxisSlave    : out AxiStreamSlaveType;
      userAxisCtrl     : out AxiStreamCtrlType;
      -- VC Command interface
      ssiCmd           : out SsiCmdMasterType;
      debug            : out slv(31 downto 0)    := (others => '0'));
end CoulterPgp;

architecture mapping of CoulterPgp is

   constant REFCLK_FREQ_C : real            := 156.25e6;
   constant LINE_RATE_C   : real            := 3.125e9;
   constant GTP_CFG_C     : Gtp7QPllCfgType := getGtp7QPllCfg(REFCLK_FREQ_C, LINE_RATE_C);

--    signal stableClk  : sl;
--    signal stableRst  : sl;
--   signal powerUpRst : sl;

   signal pgpTxClk     : sl;
   signal pgpTxRst     : sl;
   signal pgpRxClk     : sl;
   signal pgpRxRst     : sl;
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);
   signal pgpRxIn      : Pgp2bRxInType;
   signal pgpRxOut     : Pgp2bRxOutType;
   signal pgpTxIn      : Pgp2bTxInType;
   signal pgpTxOut     : Pgp2bTxOutType;

   -- AXIL
   constant AXIL_MASTERS_C  : integer := 2;
   constant PGP_AXI_INDEX_C : integer := 0;
   constant GTP_AXI_INDEX_C : integer := 1;

   constant AXIL_XBAR_CFG_C : AxiLiteCrossbarMasterConfigArray(AXIL_MASTERS_C-1 downto 0) := (
      PGP_AXI_INDEX_C => (
         baseAddr     => X"10000000",
         addrBits     => 8,
         connectivity => X"0001"),
      GTP_AXI_INDEX_C => (
         baseAddr     => X"10010000",
         addrBits     => 16,
         connectivity => X"0001"));

   signal srpAxilReadMaster   : AxiLiteReadMasterType;
   signal srpAxilReadSlave    : AxiLiteReadSlaveType;
   signal srpAxilWriteMaster  : AxiLiteWriteMasterType;
   signal srpAxilWriteSlave   : AxiLiteWriteSlaveType;
   signal locAxilReadMasters  : AxiLiteReadMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilReadSlaves   : AxiLiteReadSlaveArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteMasters : AxiLiteWriteMasterArray(AXIL_MASTERS_C-1 downto 0);
   signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(AXIL_MASTERS_C-1 downto 0);

begin

   -- Map to signals out
   rxLinkReady  <= pgpRxOut.remLinkReady;
   txLinkReady  <= pgpTxOut.linkReady;
   distClk      <= pgpRxClk;
   distRst      <= pgpRxRst;
   distOpCodeEn <= pgpRxOut.opCodeEn;
   distOpCode   <= pgpRxOut.opCode;
   axilClk      <= pgpTxClk;
   axilRst      <= pgpTxRst;


   -------------------------------------------------------------------------------------------------
   -- AXI Lite crossbar
   -------------------------------------------------------------------------------------------------
   U_AxiLiteCrossbar_1 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => AXIL_MASTERS_C,
         DEC_ERROR_RESP_G   => AXI_RESP_DECERR_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CFG_C,
         DEBUG_G            => true)
      port map (
         axiClk              => pgpTxClk,             -- [in]
         axiClkRst           => pgpTxRst,             -- [in]
         sAxiWriteMasters(0) => sAxilWriteMaster,     -- [in]
         sAxiWriteSlaves(0)  => sAxilWriteSlave,      -- [out]
         sAxiReadMasters(0)  => sAxilReadMaster,      -- [in]
         sAxiReadSlaves(0)   => sAxilReadSlave,       -- [out]
         mAxiWriteMasters    => locAxilWriteMasters,  -- [out]
         mAxiWriteSlaves     => locAxilWriteSlaves,   -- [in]
         mAxiReadMasters     => locAxilReadMasters,   -- [out]
         mAxiReadSlaves      => locAxilReadSlaves);   -- [in]

   -------------------------------
   --       PGP Core            --
   -------------------------------
   U_Pgp2bGtp7FixedLatWrapper_1 : entity work.Pgp2bGtp7FixedLatWrapper
      generic map (
         TPD_G                   => TPD_G,
         SIM_GTRESET_SPEEDUP_G   => SIMULATION_G,
--         SIM_VERSION_G           => SIM_VERSION_G,
         SIMULATION_G            => SIMULATION_G,
         VC_INTERLEAVE_G         => 0,
         PAYLOAD_CNT_TOP_G       => 7,
         NUM_VC_EN_G             => 4,
         AXIL_ERROR_RESP_G       => AXI_RESP_DECERR_C,
         AXIL_BASE_ADDR_G        => AXIL_XBAR_CFG_C(GTP_AXI_INDEX_C).baseAddr,
         TX_ENABLE_G             => true,
         RX_ENABLE_G             => true,
         TX_CM_EN_G              => true,
         TX_CM_TYPE_G            => "MMCM",
         TX_CM_CLKIN_PERIOD_G    => 6.4,
         TX_CM_DIVCLK_DIVIDE_G   => 1,
         TX_CM_CLKFBOUT_MULT_F_G => 7.625,
         TX_CM_CLKOUT_DIVIDE_F_G => 7.625,
         RX_CM_EN_G              => true,
         RX_CM_TYPE_G            => "MMCM",
         RX_CM_CLKIN_PERIOD_G    => 6.4,
         RX_CM_DIVCLK_DIVIDE_G   => 1,
         RX_CM_CLKFBOUT_MULT_F_G => 7.625,
         RX_CM_CLKOUT_DIVIDE_F_G => 7.625,
--          PMA_RSV_G               => PMA_RSV_G,
--          RX_OS_CFG_G             => RX_OS_CFG_G,
--          RXCDR_CFG_G             => RXCDR_CFG_G,
--          RXDFEXYDEN_G            => RXDFEXYDEN_G,
         STABLE_CLK_SRC_G        => "gtClk0",
         TX_REFCLK_SRC_G         => "gtClk0",
         RX_REFCLK_SRC_G         => "gtClk0",
         TX_PLL_CFG_G            => GTP_CFG_C,
         RX_PLL_CFG_G            => GTP_CFG_C,
         TX_PLL_G                => "PLL0",
         RX_PLL_G                => "PLL0")
      port map (
         stableClkIn     => '0',        --stableClkIn,       -- [in]
         extRst          => '0',        --extRst,            -- [in]
         txPllLock       => debug(0),   --txPllLock,         -- [out]
         rxPllLock       => debug(1),   --rxPllLock,         -- [out]
         pgpTxClkOut     => pgpTxClk,   -- [out]
         pgpTxRstOut     => pgpTxRst,   -- [out]
         pgpRxClkOut     => pgpRxClk,   -- [out] -- Fixed Latency recovered clock
         pgpRxRstOut     => pgpRxRst,   -- [out]
         stableClkOut    => open,       --stableClkOut,      -- [out]
         pgpRxIn         => pgpRxIn,    -- [in]
         pgpRxOut        => pgpRxOut,   -- [out]
         pgpTxIn         => pgpTxIn,    -- [in]
         pgpTxOut        => pgpTxOut,   -- [out]
         pgpTxMasters    => pgpTxMasters,                          -- [in]
         pgpTxSlaves     => pgpTxSlaves,                           -- [out]
         pgpRxMasters    => pgpRxMasters,                          -- [out]
         pgpRxCtrl       => pgpRxCtrl,  -- [in]
--         gtgClk           => gtgClk,            -- [in]
         gtClk0P         => gtClkP,     -- [in]
         gtClk0N         => gtClkN,     -- [in]
--          gtClk1P          => gtClk1P,           -- [in]
--          gtClk1N          => gtClk1N,           -- [in]
         gtTxP           => gtTxP,      -- [out]
         gtTxN           => gtTxN,      -- [out]
         gtRxP           => gtRxP,      -- [in]
         gtRxN           => gtRxN,      -- [in]
--          txPreCursor      => txPreCursor,       -- [in]
--          txPostCursor     => txPostCursor,      -- [in]
--          txDiffCtrl       => txDiffCtrl,        -- [in]
         axilClk         => pgpTxClk,   -- [in]
         axilRst         => pgpTxRst,   -- [in]
         axilReadMaster  => locAxilReadMasters(GTP_AXI_INDEX_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(GTP_AXI_INDEX_C),    -- [out]
         axilWriteMaster => locAxilWriteMasters(GTP_AXI_INDEX_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(GTP_AXI_INDEX_C));  -- [out]


--    U_Pgp2bGtp7VarLatWrapper_1 : entity work.Pgp2bGtp7VarLatWrapper
--       generic map (
--          TPD_G                => TPD_G,
--          CLKIN_PERIOD_G       => (2.0e9/REFCLK_FREQ_C),
--          DIVCLK_DIVIDE_G      => 1,
--          CLKFBOUT_MULT_F_G    => 12.75,
--          CLKOUT0_DIVIDE_F_G   => 6.375,
--          QPLL_REFCLK_SEL_G    => "001",
--          QPLL_FBDIV_IN_G      => GTP_CFG_C.QPLL_FBDIV_G,
--          QPLL_FBDIV_45_IN_G   => GTP_CFG_C.QPLL_FBDIV_45_G,
--          QPLL_REFCLK_DIV_IN_G => GTP_CFG_C.QPLL_REFCLK_DIV_G,
--          RXOUT_DIV_G          => GTP_CFG_C.OUT_DIV_G,
--          TXOUT_DIV_G          => GTP_CFG_C.OUT_DIV_G,
--          RX_CLK25_DIV_G       => GTP_CFG_C.CLK25_DIV_G,
--          TX_CLK25_DIV_G       => GTP_CFG_C.CLK25_DIV_G,
-- --          RX_OS_CFG_G          => RX_OS_CFG_G,
-- --          RXCDR_CFG_G          => RXCDR_CFG_G,
-- --          RXLPM_INCM_CFG_G     => RXLPM_INCM_CFG_G,
-- --          RXLPM_IPCM_CFG_G     => RXLPM_IPCM_CFG_G,
--          RX_ENABLE_G          => true,
--          TX_ENABLE_G          => true,
--          PAYLOAD_CNT_TOP_G    => 7,
--          VC_INTERLEAVE_G      => 0,
--          NUM_VC_EN_G          => 4)
--       port map (
--          extRst       => stableRst,     -- [in]
--          pgpClk       => pgpClk,        -- [out]
--          pgpRst       => pgpRst,        -- [out]
--          stableClk    => stableClk,     -- [out]
--          pgpTxIn      => pgpTxIn,       -- [in]
--          pgpTxOut     => pgpTxOut,      -- [out]
--          pgpRxIn      => pgpRxIn,       -- [in]
--          pgpRxOut     => pgpRxOut,      -- [out]
--          pgpTxMasters => pgpTxMasters,  -- [in]
--          pgpTxSlaves  => pgpTxSlaves,   -- [out]
--          pgpRxMasters => pgpRxMasters,  -- [out]
--          pgpRxCtrl    => pgpRxCtrl,     -- [in]
--          gtClkP       => gtClkP,        -- [in]
--          gtClkN       => gtClkN,        -- [in]
--          gtTxP        => gtTxP,         -- [out]
--          gtTxN        => gtTxN,         -- [out]
--          gtRxP        => gtRxP,         -- [in]
--          gtRxN        => gtRxN);        -- [in]


   -------------------------------------------------------------------------------------------------
   -- PGP monitor
   -------------------------------------------------------------------------------------------------
   CntlPgp2bAxi : entity work.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => true,
         COMMON_RX_CLK_G    => false,
         WRITE_EN_G         => false,
         AXI_CLK_FREQ_G     => 156.25E+6,
         STATUS_CNT_WIDTH_G => 32,
         ERROR_CNT_WIDTH_G  => 16,
         AXI_ERROR_RESP_G   => AXI_RESP_DECERR_C)
      port map (
         pgpTxClk        => pgpTxClk,                              -- [in]
         pgpTxClkRst     => pgpTxRst,                              -- [in]
         pgpTxIn         => pgpTxIn,                               -- [out]
         pgpTxOut        => pgpTxOut,                              -- [in]
         pgpRxClk        => pgpRxClk,                              -- [in]
         pgpRxClkRst     => pgpRxRst,                              -- [in]
         pgpRxIn         => pgpRxIn,                               -- [out]
         pgpRxOut        => pgpRxOut,                              -- [in]
         axilClk         => pgpTxClk,                              -- [in]
         axilRst         => pgpTxRst,                              -- [in]
         axilReadMaster  => locAxilReadMasters(PGP_AXI_INDEX_C),   -- [in]
         axilReadSlave   => locAxilReadSlaves(PGP_AXI_INDEX_C),    -- [out]
         axilWriteMaster => locAxilWriteMasters(PGP_AXI_INDEX_C),  -- [in]
         axilWriteSlave  => locAxilWriteSlaves(PGP_AXI_INDEX_C));  -- [out]

   -- Lane 0, VC0 RX/TX, Register access control        
   U_Vc0AxiMasterRegisters : entity work.SrpV0AxiLite
      generic map (
         TPD_G               => TPD_G,
         RESP_THOLD_G        => 1,
         SLAVE_READY_EN_G    => false,
         EN_32BIT_ADDR_G     => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 2**8,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
         )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk            => pgpRxClk,
         sAxisRst            => pgpRxRst,
         sAxisMaster         => pgpRxMasters(0),
         sAxisSlave          => open,
         sAxisCtrl           => pgpRxCtrl(0),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk            => pgpTxClk,
         mAxisRst            => pgpTxRst,
         mAxisMaster         => pgpTxMasters(0),
         mAxisSlave          => pgpTxSlaves(0),
         -- AXI Lite Bus (axiLiteClk domain)
         axiLiteClk          => pgpTxClk,
         axiLiteRst          => pgpTxRst,
         mAxiLiteWriteMaster => mAxilWriteMaster,
         mAxiLiteWriteSlave  => mAxilWriteSlave,
         mAxiLiteReadMaster  => mAxilReadMaster,
         mAxiLiteReadSlave   => mAxilReadSlave);

   -- Lane 0, VC1 TX, streaming data out
   U_AxiStreamFifoV2_1 : entity work.AxiStreamFifoV2
      generic map (
         TPD_G                  => TPD_G,
         INT_PIPE_STAGES_G      => 1,
         PIPE_STAGES_G          => 1,
         SLAVE_READY_EN_G       => false,
         VALID_THOLD_G          => 1,
         VALID_BURST_MODE_G     => false,
         BRAM_EN_G              => true,
         USE_BUILT_IN_G         => false,
         GEN_SYNC_FIFO_G        => true,
         CASCADE_SIZE_G         => 2,
         CASCADE_PAUSE_SEL_G    => 1,
         FIFO_ADDR_WIDTH_G      => 13,
         FIFO_FIXED_THRESH_G    => true,
         FIFO_PAUSE_THRESH_G    => 2**13-6200,
         INT_WIDTH_SELECT_G     => "WIDE",
--         INT_DATA_WIDTH_G       => INT_DATA_WIDTH_G,
         LAST_FIFO_ADDR_WIDTH_G => 0,
         SLAVE_AXI_CONFIG_G     => COULTER_AXIS_CFG_C,
         MASTER_AXI_CONFIG_G    => SSI_PGP2B_CONFIG_C)
      port map (
         sAxisClk    => pgpTxClk,         -- [in]
         sAxisRst    => pgpTxRst,         -- [in]
         sAxisMaster => userAxisMaster,   -- [in]
         sAxisSlave  => userAxisSlave,    -- [out]
         sAxisCtrl   => userAxisCtrl,     -- [out]
         mAxisClk    => pgpTxClk,         -- [in]
         mAxisRst    => pgpTxRst,         -- [in]
         mAxisMaster => pgpTxMasters(1),  -- [out]
         mAxisSlave  => pgpTxSlaves(1));  -- [in]


--    U_Vc1SsiTxFifo : entity work.AxiStreamFifo
--       generic map (
--          --EN_FRAME_FILTER_G   => true,
--          CASCADE_SIZE_G      => 1,
--          BRAM_EN_G           => true,
--          USE_BUILT_IN_G      => false,
--          GEN_SYNC_FIFO_G     => true,
--          FIFO_ADDR_WIDTH_G   => 14,
--          FIFO_FIXED_THRESH_G => true,
--          FIFO_PAUSE_THRESH_G => 128,
--          SLAVE_AXI_CONFIG_G  => COULTER_AXIS_CFG_C,
--          MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
--       port map (
--          -- Slave Port
--          sAxisClk    => pgpTxClk,
--          sAxisRst    => pgpTxRst,
--          sAxisMaster => userAxisMaster,
--          sAxisSlave  => userAxisSlave,
--          sAxisCtrl => userAxisCtrl,
--          -- Master Port
--          mAxisClk    => pgpTxClk,
--          mAxisRst    => pgpTxRst,
--          mAxisMaster => pgpTxMasters(1),
--          mAxisSlave  => pgpTxSlaves(1));

   -- Lane 0, VC1 RX, Command processor
   U_Vc1SsiCmdMaster : entity work.SsiCmdMaster
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         BRAM_EN_G           => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 8,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Streaming Data Interface
         axisClk     => pgpRxClk,
         axisRst     => pgpRxRst,
         sAxisMaster => pgpRxMasters(1),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(1),
         -- Command signals
         cmdClk      => pgpTxClk,
         cmdRst      => pgpTxRst,
         cmdMaster   => ssiCmd);


   -- Lane 0, VC2 Loopback
   U_Vc2SsiLoopbackFifo : entity work.AxiStreamFifo
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpRxClk,
         sAxisRst    => pgpRxRst,
         sAxisMaster => pgpRxMasters(2),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(2),
         -- Master Port
         mAxisClk    => pgpTxClk,
         mAxisRst    => pgpTxRst,
         mAxisMaster => pgpTxMasters(2),
         mAxisSlave  => pgpTxSlaves(2));

   -- Lane 0, VC3 TX/RX loopback (reserved for telemetry)
   U_Vc3SsiLoopbackFifo : entity work.AxiStreamFifo
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpRxClk,
         sAxisRst    => pgpRxRst,
         sAxisMaster => pgpRxMasters(3),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(3),
         -- Master Port
         mAxisClk    => pgpTxClk,
         mAxisRst    => pgpTxRst,
         mAxisMaster => pgpTxMasters(3),
         mAxisSlave  => pgpTxSlaves(3));

end mapping;

