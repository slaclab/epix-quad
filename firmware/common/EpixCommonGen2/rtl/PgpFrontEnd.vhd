-------------------------------------------------------------------------------
-- Title      : PgpFrontEnd for ePix Gen 2
-------------------------------------------------------------------------------
-- File       : PgpFrontEnd.vhd
-- Author     : Kurtis Nishimura  <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-12-11
-- Last update: 2014-12-11
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: PgpFrontEnd for generation 2 ePix digital card
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;

entity PgpFrontEnd is
   port (
      -- GTX 7 Ports
      gtClkP      : in  sl;
      gtClkN      : in  sl;
      gtRxP       : in  sl;
      gtRxN       : in  sl;
      gtTxP       : out sl;
      gtTxN       : out sl;
      -- Output reset
      pgpRst      : out sl;
      -- Output status
      rxLinkReady : out sl;
      txLinkReady : out sl;
      -- Output clocking
      pgpClk      : out sl;
      stableClk   : out sl;
      -- AXI clocking
      axiClk      : in  sl;
      axiRst      : in  sl;
      -- Axi Master Interface - Registers (axiClk domain)
      mAxiLiteReadMaster  : out AxiLiteReadMasterType;
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveType;
      mAxiLiteWriteMaster : out AxiLiteWriteMasterType;
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveType
      -- -- Streaming data Links (axiClk domain)      
      -- userAxisMaster : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      -- userAxisSlave  : out AxiStreamSlaveType;
      -- Command interface
      -- ssiCmd         : out SsiCmdMasterType
   );        
end PgpFrontEnd;

architecture mapping of PgpFrontEnd is

   signal iStableClk : sl;
   signal stableRst : sl;
   signal iPgpClk   : sl;

   -- TX Interfaces - 1 lane, 4 VCs
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   -- RX Interfaces - 1 lane, 4 VCs
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);

   -- Pgp Rx/Tx types
   signal pgpRxIn     : Pgp2bRxInType;
   signal pgpRxOut    : Pgp2bRxOutType;
   signal pgpTxIn     : Pgp2bTxInType;
   signal pgpTxOut    : Pgp2bTxOutType;
   
begin
   
   -- Map to signals out
   rxLinkReady <= pgpRxOut.phyRxReady;
   txLinkReady <= pgpTxOut.phyTxReady;
   pgpRst      <= '0';
   pgpClk      <= iPgpClk;
   stableClk   <= iStableClk;
   
   -- Generate stable reset signal
   U_PwrUpRst : entity work.PwrUpRst
      port map (
         clk    => iStableClk,
         rstOut => stableRst);   

   U_Pgp2bVarLatWrapper : entity work.Pgp2bGtp7VarLatWrapper
      generic map (
         -- Configure Number of Lanes
         NUM_VC_EN_G          => 4,
         -- Quad PLL Configurations
         QPLL_FBDIV_IN_G      => 4,
         QPLL_FBDIV_45_IN_G   => 5,
         QPLL_REFCLK_DIV_IN_G => 1,
         -- MMCM Configurations
         MMCM_CLKIN_PERIOD_G  => 8.0,
         MMCM_CLKFBOUT_MULT_G => 8.000,
         MMCM_GTCLK_DIVIDE_G  => 8.000,
         MMCM_TXCLK_DIVIDE_G  => 8,
         -- MGT Configurations
         RXOUT_DIV_G          => 2,
         TXOUT_DIV_G          => 2,
         TX_PLL_G             => "PLL0",
         RX_PLL_G             => "PLL0"
      )
      port map (
         -- Manual Reset
         extRst           => '0',--: in  sl;
         -- Status and Clock Signals
         txPllLock        => open,--: out sl;
         rxPllLock        => open,--: out sl;
         locClk           => iPgpClk,--: out sl;
         locRst           => open,--: out sl;
         stableClk        => iStableClk,--: out sl;
         -- Non VC Rx Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame Receive Interface - 1 Lane, Array of 4 VCs
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => open,
         pgpRxCtrl        => pgpRxCtrl,
         -- GT Pins
         gtClkP           => gtClkP,
         gtClkN           => gtClkN,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN
      );   

   -- These should be replaced with Pgp2bAxi interface
   pgpRxIn <= PGP2B_RX_IN_INIT_C;
   pgpTxIn <= PGP2B_TX_IN_INIT_C;
   
   -- Lane 0, VC0 RX/TX, Register access control        
   U_AxiMasterRegisters : entity work.SsiAxiLiteMaster 
      generic map (
         USE_BUILT_IN_G      => false,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
      )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk    => iPgpClk,
         sAxisRst    => stableRst,
         sAxisMaster => pgpRxMasters(0),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(0),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(0),
         mAxisSlave  => pgpTxSlaves(0),
         -- AXI Lite Bus (axiLiteClk domain)
         axiLiteClk          => axiClk,
         axiLiteRst          => axiRst,
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave
      );

   -- -- Lane 0, VC1 TX, streaming data out 
   -- U_Vc1SsiTxFifo : entity work.SsiFifo
      -- generic map (
         -- EN_FRAME_FILTER_G   => true,
         -- CASCADE_SIZE_G      => 1,
         -- BRAM_EN_G           => true,
         -- USE_BUILT_IN_G      => false,  
         -- GEN_SYNC_FIFO_G     => false,    
         -- FIFO_ADDR_WIDTH_G   => 14,
         -- FIFO_FIXED_THRESH_G => true,
         -- FIFO_PAUSE_THRESH_G => 128,    
         -- SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         -- MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C) 
      -- port map (   
         -- -- Slave Port
         -- sAxisClk    => dataWrClk,
         -- sAxisRst    => stableRst,
         -- sAxisMaster => userAxisMaster,
         -- sAxisSlave  => userAxisSlave,
         -- -- Master Port
         -- mAxisClk    => iPgpClk,
         -- mAxisRst    => stableRst,
         -- mAxisMaster => pgpTxMasters(1),
         -- mAxisSlave  => pgpTxSlaves(1));     
   -- -- Lane 0, VC1 RX, Command processor
   -- U_Vc1SsiCmdMaster : entity work.SsiCmdMaster
      -- generic map (
         -- AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)   
      -- port map (
         -- -- Streaming Data Interface
         -- axisClk     => iPgpClk,
         -- axisRst     => stableRst,
         -- sAxisMaster => pgpRxMasters(1),
         -- sAxisSlave  => open,
         -- sAxisCtrl   => pgpRxCtrl(1),
         -- -- Command signals
         -- cmdClk      => axiClk,
         -- cmdRst      => axiRst,
         -- cmdMaster   => ssiCmd
      -- );     

   -- Lane 0, VC1 loopback
   U_Vc1SsiLoopbackFifo : entity work.SsiFifo
      generic map (
         EN_FRAME_FILTER_G   => true,
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
         sAxisClk    => iPgpClk,
         sAxisRst    => stableRst,
         sAxisMaster => pgpRxMasters(1),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(1),
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(1),
         mAxisSlave  => pgpTxSlaves(1));     

      
   -- Lane 0, VC2 loopback
   U_Vc2SsiLoopbackFifo : entity work.SsiFifo
      generic map (
         EN_FRAME_FILTER_G   => true,
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
         sAxisClk    => iPgpClk,
         sAxisRst    => stableRst,
         sAxisMaster => pgpRxMasters(2),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(2),
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(2),
         mAxisSlave  => pgpTxSlaves(2));     
   
   -- Lane 0, VC3 loopback
   U_Vc3SsiLoopbackFifo : entity work.SsiFifo
      generic map (
         EN_FRAME_FILTER_G   => true,
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
         sAxisClk    => iPgpClk,
         sAxisRst    => stableRst,
         sAxisMaster => pgpRxMasters(3),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(3),
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(3),
         mAxisSlave  => pgpTxSlaves(3));     


   -- If we have unused RX CTRL or TX MASTERS
   --
   --pgpRxCtrl(3) <= AXI_STREAM_CTRL_UNUSED_C;
   --pgpTxMasters(3) <= AXI_STREAM_MASTER_INIT_C;
      
end mapping;

