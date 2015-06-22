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
   generic (
      TPD_G       : time := 1 ns
   );
   port (
      -- GTX 7 Ports
      gtClkP      : in  sl;
      gtClkN      : in  sl;
      gtRxP       : in  sl;
      gtRxN       : in  sl;
      gtTxP       : out sl;
      gtTxN       : out sl;
      -- Input power on reset (Do we want this...?)
      powerBad    : in  sl := '0';
      -- Output reset
      pgpRst      : out sl;
      -- Output status
      rxLinkReady : out sl;
      txLinkReady : out sl;
      -- Output clocking
      pgpClk      : out sl;
      -- AXI clocking
      axiClk      : in  sl;
      axiRst      : in  sl;
      -- Axi Master Interface - Registers (axiClk domain)
      mAxiLiteReadMaster  : out AxiLiteReadMasterType;
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveType;
      mAxiLiteWriteMaster : out AxiLiteWriteMasterType;
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveType;
      -- Streaming data Links (axiClk domain)      
      userAxisMaster  : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      userAxisSlave   : out AxiStreamSlaveType;
      -- Scope streaming data Links (axiClk domain)      
      scopeAxisMaster : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      scopeAxisSlave  : out AxiStreamSlaveType;
      -- VC Command interface
      ssiCmd         : out SsiCmdMasterType;
      -- To access sideband commands
      pgpRxOut       : out Pgp2bRxOutType
   );        
end PgpFrontEnd;

architecture mapping of PgpFrontEnd is

   signal iStableClk : sl;
   signal stableRst  : sl;
   signal powerUpRst : sl;
   signal iPgpClk    : sl;

   -- TX Interfaces - 1 lane, 4 VCs
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   -- RX Interfaces - 1 lane, 4 VCs
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);

   -- Pgp Rx/Tx types
   signal pgpRxIn     : Pgp2bRxInType;
   signal iPgpRxOut   : Pgp2bRxOutType;
   signal pgpTxIn     : Pgp2bTxInType;
   signal pgpTxOut    : Pgp2bTxOutType;
   
begin
   
   -- Map to signals out
   pgpRxOut    <= iPgpRxOut;
   rxLinkReady <= iPgpRxOut.remLinkReady;
   txLinkReady <= pgpTxOut.linkReady;
   pgpClk      <= iPgpClk;
   
   -- Generate stable reset signal
   U_PwrUpRst : entity work.PwrUpRst
      port map (
         clk    => iStableClk,
         rstOut => powerUpRst
      ); 
   stableRst <= powerUpRst or powerBad;

   -------------------------------
   --       PGP Core            --
   -------------------------------
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
         extRst           => stableRst,
         -- Clocks and Reset
         pgpClk           => iPgpClk,
         pgpRst           => pgpRst,
         stableClk        => iStableClk,
         -- Non VC Tx Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Non VC Rx Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => iPgpRxOut,
         -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame Receive Interface - 1 Lane, Array of 4 VCs
         pgpRxMasters     => pgpRxMasters,
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

   -- Lane 0, VC0 TX, streaming data out 
   U_Vc0SsiTxFifo : entity work.AxiStreamFifo
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,  
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 14,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,    
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C) 
      port map (   
         -- Slave Port
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => userAxisMaster,
         sAxisSlave  => userAxisSlave,
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(0),
         mAxisSlave  => pgpTxSlaves(0));     
   -- Lane 0, VC0 RX, Command processor
   U_Vc0SsiCmdMaster : entity work.SsiCmdMaster
      generic map (
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)   
      port map (
         -- Streaming Data Interface
         axisClk     => iPgpClk,
         axisRst     => stableRst,
         sAxisMaster => pgpRxMasters(0),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(0),
         -- Command signals
         cmdClk      => axiClk,
         cmdRst      => axiRst,
         cmdMaster   => ssiCmd
      );     
   
   -- Lane 0, VC1 RX/TX, Register access control        
   U_Vc1AxiMasterRegisters : entity work.SsiAxiLiteMaster 
      generic map (
         USE_BUILT_IN_G      => false,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
      )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk    => iPgpClk,
         sAxisRst    => stableRst,
         sAxisMaster => pgpRxMasters(1),
         sAxisSlave  => open,
         sAxisCtrl   => pgpRxCtrl(1),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(1),
         mAxisSlave  => pgpTxSlaves(1),
         -- AXI Lite Bus (axiLiteClk domain)
         axiLiteClk          => axiClk,
         axiLiteRst          => axiRst,
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave
      );
      
   -- Lane 0, VC2 TX oscilloscope data stream
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
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => scopeAxisMaster,
         sAxisSlave  => scopeAxisSlave,
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(2),
         mAxisSlave  => pgpTxSlaves(2));     
   -- Lane 0, VC2 RX unused (reserved for programming via fiber?)
   
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
   pgpRxCtrl(2) <= AXI_STREAM_CTRL_UNUSED_C;
   --pgpRxCtrl(3) <= AXI_STREAM_CTRL_UNUSED_C;
   --pgpTxMasters(3) <= AXI_STREAM_MASTER_INIT_C;
      
end mapping;

