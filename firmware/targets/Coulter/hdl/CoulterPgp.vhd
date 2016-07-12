-------------------------------------------------------------------------------
-- Title      : Coulter PGP 
-------------------------------------------------------------------------------
-- File       : CoulterPgp.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-03
-- Last update: 2016-06-06
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
      -- AXIL clocking
      axilClk          : out sl;
      axilRst          : out sl;
      -- Axil Master Interface - Registers (axilClk domain)
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- PGP monitor 
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Streaming data Links (axiClk domain)      
      userAxisMaster   : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      userAxisSlave    : out AxiStreamSlaveType;
      -- Scope streaming data Links (axiClk domain)      
--       scopeAxisMaster  : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
--       scopeAxisSlave   : out AxiStreamSlaveType;
      -- VC Command interface
      ssiCmd           : out SsiCmdMasterType
      -- Sideband commands?

      );
end CoulterPgp;

architecture mapping of CoulterPgp is

   constant REFCLK_FREQ_C : real            := 156.25e6;
   constant LINE_RATE_C   : real            := 3.125e9;
   constant GTP_CFG_C     : Gtp7QPllCfgType := getGtp7QPllCfg(REFCLK_FREQ_C, LINE_RATE_C);

   signal stableClk  : sl;
   signal stableRst  : sl;
   signal powerUpRst : sl;
   signal pgpClk     : sl;
   signal pgpRst     : sl;

   -- TX Interfaces - 1 lane, 4 VCs
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   -- RX Interfaces - 1 lane, 4 VCs
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);

   -- Pgp Rx/Tx types
   signal pgpRxIn  : Pgp2bRxInType;
   signal pgpRxOut : Pgp2bRxOutType;
   signal pgpTxIn  : Pgp2bTxInType;
   signal pgpTxOut : Pgp2bTxOutType;

begin

   -- Map to signals out
   rxLinkReady <= pgpRxOut.remLinkReady;
   txLinkReady <= pgpTxOut.linkReady;
   axilClk     <= pgpClk;
   axilRst     <= pgpRst;

   -- Generate stable reset signal
   U_PwrUpRst : entity work.PwrUpRst
      generic map (
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => SIMULATION_G)
      port map (
         clk    => stableClk,
         rstOut => powerUpRst
         );
   stableRst <= powerUpRst or powerBad;

   -------------------------------
   --       PGP Core            --
   -------------------------------
   U_Pgp2bGtp7VarLatWrapper_1 : entity work.Pgp2bGtp7VarLatWrapper
      generic map (
         TPD_G                => TPD_G,
         CLKIN_PERIOD_G       => (2.0e9/REFCLK_FREQ_C),
         DIVCLK_DIVIDE_G      => 1,
         CLKFBOUT_MULT_F_G    => 12.75,
         CLKOUT0_DIVIDE_F_G   => 6.375,
         QPLL_REFCLK_SEL_G    => "001",
         QPLL_FBDIV_IN_G      => GTP_CFG_C.QPLL_FBDIV_G,
         QPLL_FBDIV_45_IN_G   => GTP_CFG_C.QPLL_FBDIV_45_G,
         QPLL_REFCLK_DIV_IN_G => GTP_CFG_C.QPLL_REFCLK_DIV_G,
         RXOUT_DIV_G          => GTP_CFG_C.OUT_DIV_G,
         TXOUT_DIV_G          => GTP_CFG_C.OUT_DIV_G,
         RX_CLK25_DIV_G       => GTP_CFG_C.CLK25_DIV_G,
         TX_CLK25_DIV_G       => GTP_CFG_C.CLK25_DIV_G,
--          RX_OS_CFG_G          => RX_OS_CFG_G,
--          RXCDR_CFG_G          => RXCDR_CFG_G,
--          RXLPM_INCM_CFG_G     => RXLPM_INCM_CFG_G,
--          RXLPM_IPCM_CFG_G     => RXLPM_IPCM_CFG_G,
         PGP_RX_ENABLE_G      => true,
         PGP_TX_ENABLE_G      => true,
         PAYLOAD_CNT_TOP_G    => 7,
         VC_INTERLEAVE_G      => 0,
         NUM_VC_EN_G          => 4)
      port map (
         extRst       => stableRst,     -- [in]
         pgpClk       => pgpClk,        -- [out]
         pgpRst       => pgpRst,        -- [out]
         stableClk    => stableClk,     -- [out]
         pgpTxIn      => pgpTxIn,       -- [in]
         pgpTxOut     => pgpTxOut,      -- [out]
         pgpRxIn      => pgpRxIn,       -- [in]
         pgpRxOut     => pgpRxOut,      -- [out]
         pgpTxMasters => pgpTxMasters,  -- [in]
         pgpTxSlaves  => pgpTxSlaves,   -- [out]
         pgpRxMasters => pgpRxMasters,  -- [out]
         pgpRxCtrl    => pgpRxCtrl,     -- [in]
         gtClkP       => gtClkP,        -- [in]
         gtClkN       => gtClkN,        -- [in]
         gtTxP        => gtTxP,         -- [out]
         gtTxN        => gtTxN,         -- [out]
         gtRxP        => gtRxP,         -- [in]
         gtRxN        => gtRxN);        -- [in]


   -------------------------------------------------------------------------------------------------
   -- PGP monitor
   -------------------------------------------------------------------------------------------------
   CntlPgp2bAxi : entity work.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => true,
         COMMON_RX_CLK_G    => true,
         WRITE_EN_G         => false,
         AXI_CLK_FREQ_G     => 156.25E+6,
         STATUS_CNT_WIDTH_G => 32,
         ERROR_CNT_WIDTH_G  => 16)
      port map (
         pgpTxClk        => pgpClk,
         pgpTxClkRst     => pgpRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpRxClk        => pgpClk,
         pgpRxClkRst     => pgpRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         axilClk         => pgpClk,
         axilRst         => pgpRst,
         axilReadMaster  => sAxilReadMaster,
         axilReadSlave   => sAxilReadSlave,
         axilWriteMaster => sAxilWriteMaster,
         axilWriteSlave  => sAxilWriteSlave);



   -- Lane 0, VC0 TX, streaming data out 
   U_Vc0SsiTxFifo : entity work.AxiStreamFifo
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 14,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpClk,
         sAxisRst    => pgpRst,
         sAxisMaster => userAxisMaster,
         sAxisSlave  => userAxisSlave,
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => pgpTxMasters(0),
         mAxisSlave  => pgpTxSlaves(0));
   -- Lane 0, VC0 RX, Command processor
   U_Vc0SsiCmdMaster : entity work.SsiCmdMaster
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         BRAM_EN_G           => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 8,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Streaming Data Interface
         axisClk     => pgpClk,
         axisRst     => pgpRst,
         sAxisMaster => pgpRxMasters(0),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(0),
         -- Command signals
         cmdClk      => pgpClk,
         cmdRst      => pgpRst,
         cmdMaster   => ssiCmd
         );

   -- Lane 0, VC1 RX/TX, Register access control        
   U_Vc1AxiMasterRegisters : entity work.SrpV0AxiLite
      generic map (
         TPD_G               => TPD_G,
         RESP_THOLD_G        => 1,
         SLAVE_READY_EN_G    => false,
         EN_32BIT_ADDR_G     => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 2**8,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
         )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk            => pgpClk,
         sAxisRst            => pgpRst,
         sAxisMaster         => pgpRxMasters(1),
         sAxisSlave          => open,
         sAxisCtrl           => pgpRxCtrl(1),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk            => pgpClk,
         mAxisRst            => pgpRst,
         mAxisMaster         => pgpTxMasters(1),
         mAxisSlave          => pgpTxSlaves(1),
         -- AXI Lite Bus (axiLiteClk domain)
         axiLiteClk          => pgpClk,
         axiLiteRst          => pgpRst,
         mAxiLiteWriteMaster => mAxilWriteMaster,
         mAxiLiteWriteSlave  => mAxilWriteSlave,
         mAxiLiteReadMaster  => mAxilReadMaster,
         mAxiLiteReadSlave   => mAxilReadSlave
         );

   -- Lane 0, VC2 Loopback
   U_Vc2SsiOscilloscopeFifo : entity work.AxiStreamFifo
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 14,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpClk,
         sAxisRst    => pgpRst,
         sAxisMaster => pgpRxMasters(2),
         sAxisSlave  => open,
         sAxisCtrl    => pgpRxCtrl(2),
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => pgpTxMasters(2),
         mAxisSlave  => pgpTxSlaves(2));

   -- Lane 0, VC3 TX/RX loopback (reserved for telemetry)
   U_Vc3SsiLoopbackFifo : entity work.AxiStreamFifo
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 14,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpClk,
         sAxisRst    => pgpRst,
         sAxisMaster => pgpRxMasters(3),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(3),
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => pgpTxMasters(3),
         mAxisSlave  => pgpTxSlaves(3));

end mapping;

