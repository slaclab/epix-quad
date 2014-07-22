-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol Applications, Front End Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : PgpFrontEnd.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 03/29/2011
-------------------------------------------------------------------------------
-- Description:
-- Wrapper for front end logic connection to the PGP card.
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/29/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use work.VcPkg.all;
use work.Pgp2CoreTypesPkg.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity PgpFrontEnd is 
   generic (
      InterfaceType       : string := "PGP" -- PGP or ETH
   );
   port ( 
      
      -- Reference Clock, Power on Reset
      pgpRefClkP       : in  std_logic;
      pgpRefClkM       : in  std_logic;
      ethRefClkP       : in  std_logic;
      ethRefClkM       : in  std_logic;
      ponResetL        : in  std_logic;
      resetReq         : in  std_logic;

      -- Local clock and reset
      sysClk           : out std_logic;
      sysClkRst        : out std_logic;

      -- Local command signal
      pgpCmd           : out VcCmdSlaveOutType;

      -- Local register control signals
      pgpRegOut        : out VcRegSlaveOutType;
      pgpRegIn         : in  VcRegSlaveInType;

      -- Local data transfer signals
      frameTxIn        : in  VcUsBuff32InType;
      frameTxOut       : out VcUsBuff32OutType;

      -- Oscillscope channel data transfer signals
      scopeTxIn        : in  VcUsBuff32InType;
      scopeTxOut       : out VcUsBuff32OutType;

      -- Gtp Serial Pins
      pgpRxN           : in  std_logic;
      pgpRxP           : in  std_logic;
      pgpTxN           : out std_logic;
      pgpTxP           : out std_logic
   );
end PgpFrontEnd;


-- Define architecture
architecture PgpFrontEnd of PgpFrontEnd is

   -- Local Signals
   signal pgpTxVcIn          : VcTxQuadInType;
   signal pgpTxVcOut         : VcTxQuadOutType;
   signal pgpRxVcCommon      : VcRxCommonOutType;
   signal pgpRxVcOut         : VcRxQuadOutType;
   signal intRefClkOut       : std_logic;
   signal ipgpClk            : std_logic;
   signal ipgpClk2x          : std_logic;
   signal ipgpClkRst         : std_logic;
   signal isysClk            : std_logic;
   signal isysClkRst         : std_logic;
   signal pgpRefClk          : std_logic;
   signal ethRefClk          : std_logic;
   signal resetReqPgpSync    : std_logic;

begin

   -- Outputs
   sysClk     <= isysClk;
   sysClkRst  <= isysClkRst;

   -- Reference Clock
   U_PgpRefClk : IBUFDS port map ( I => pgpRefClkP, IB => pgpRefClkM, O => pgpRefClk );
   U_EthRefClk : IBUFDS port map ( I => ethRefClkP, IB => ethRefClkM, O => ethRefClk );

   -- Synchronize the register reset
   U_SyncReset : entity work.Synchronizer
      generic map (
         TPD_G          => 1 ns,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => true,
         STAGES_G       => 2,
         BYPASS_SYNC_G  => false,
         INIT_G         => "0"
      )
      port map (
         clk     => ipgpClk,
         rst     => '0',
         dataIn  => resetReq,
         dataOut => resetReqPgpSync
      );

   -- Clock generation
   U_PgpClk: Pgp2GtpPackage.Pgp2GtpClk
      generic map (
         UserFxDiv  => 5,
         UserFxMult => 4
      )
      port map (
         pgpRefClk     => intRefClkOut,
         ponResetL     => ponResetL,
         locReset      => resetReqPgpSync,
         pgpClk        => ipgpClk,
         pgpReset      => ipgpClkRst,
         pgpClk2x      => ipgpClk2x,
         userClk       => isysClk,
         userReset     => isysClkRst,
         pgpClkIn      => ipgpClk,
         userClkIn     => isysClk
      );

   -- PGP Core
   U_Pgp2Gtp16: Pgp2GtpPackage.Pgp2Gtp16
      generic map ( 
         EnShortCells => 1, 
         VcInterleave => 0
      )
      port map (
         pgpClk            => ipgpClk,
         pgpClk2x          => ipgpClk2x,
         pgpReset          => ipgpClkRst,
         pgpFlush          => '0',
         pllTxRst          => '0',
         pllRxRst          => '0',
         pllRxReady        => open,
         pllTxReady        => open,
         pgpRemData        => open,
         pgpLocData        => (others=>'0'),
         pgpTxOpCodeEn     => '0',
         pgpTxOpCode       => (others=>'0'),
         pgpRxOpCodeEn     => open,
         pgpRxOpCode       => open,
         pgpLocLinkReady   => open,
         pgpRemLinkReady   => open,
         pgpRxCellError    => open,
         pgpRxLinkDown     => open,
         pgpRxLinkError    => open,
         vc0FrameTxValid   => pgpTxVcIn(0).valid,
         vc0FrameTxReady   => pgpTxVcOut(0).ready,
         vc0FrameTxSOF     => pgpTxVcIn(0).sof,
         vc0FrameTxEOF     => pgpTxVcIn(0).eof,
         vc0FrameTxEOFE    => pgpTxVcIn(0).eofe,
         vc0FrameTxData    => pgpTxVcIn(0).data(0),
         vc0LocBuffAFull   => pgpTxVcIn(0).locBuffAFull,
         vc0LocBuffFull    => pgpTxVcIn(0).locBuffFull,
         vc1FrameTxValid   => pgpTxVcIn(1).valid,
         vc1FrameTxReady   => pgpTxVcOut(1).ready,
         vc1FrameTxSOF     => pgpTxVcIn(1).sof,
         vc1FrameTxEOF     => pgpTxVcIn(1).eof,
         vc1FrameTxEOFE    => pgpTxVcIn(1).eofe,
         vc1FrameTxData    => pgpTxVcIn(1).data(0),
         vc1LocBuffAFull   => pgpTxVcIn(1).locBuffAFull,
         vc1LocBuffFull    => pgpTxVcIn(1).locBuffFull,
         vc2FrameTxValid   => pgpTxVcIn(2).valid,
         vc2FrameTxReady   => pgpTxVcOut(2).ready,
         vc2FrameTxSOF     => pgpTxVcIn(2).sof,
         vc2FrameTxEOF     => pgpTxVcIn(2).eof,
         vc2FrameTxEOFE    => pgpTxVcIn(2).eofe,
         vc2FrameTxData    => pgpTxVcIn(2).data(0),
         vc2LocBuffAFull   => pgpTxVcIn(2).locBuffAFull,
         vc2LocBuffFull    => pgpTxVcIn(2).locBuffFull,
         vc3FrameTxValid   => pgpTxVcIn(3).valid,
         vc3FrameTxReady   => pgpTxVcOut(3).ready,
         vc3FrameTxSOF     => pgpTxVcIn(3).sof,
         vc3FrameTxEOF     => pgpTxVcIn(3).eof,
         vc3FrameTxEOFE    => pgpTxVcIn(3).eofe,
         vc3FrameTxData    => pgpTxVcIn(3).data(0),
         vc3LocBuffAFull   => pgpTxVcIn(3).locBuffAFull,
         vc3LocBuffFull    => pgpTxVcIn(3).locBuffFull,
         vcFrameRxSOF      => pgpRxVcCommon.sof,
         vcFrameRxEOF      => pgpRxVcCommon.eof,
         vcFrameRxEOFE     => pgpRxVcCommon.eofe,
         vcFrameRxData     => pgpRxVcCommon.data(0),
         vc0FrameRxValid   => pgpRxVcOut(0).valid,
         vc0RemBuffAFull   => pgpRxVcOut(0).remBuffAFull,
         vc0RemBuffFull    => pgpRxVcOut(0).remBuffFull,
         vc1FrameRxValid   => pgpRxVcOut(1).valid,
         vc1RemBuffAFull   => pgpRxVcOut(1).remBuffAFull,
         vc1RemBuffFull    => pgpRxVcOut(1).remBuffFull,
         vc2FrameRxValid   => pgpRxVcOut(2).valid,
         vc2RemBuffAFull   => pgpRxVcOut(2).remBuffAFull,
         vc2RemBuffFull    => pgpRxVcOut(2).remBuffFull,
         vc3FrameRxValid   => pgpRxVcOut(3).valid,
         vc3RemBuffAFull   => pgpRxVcOut(3).remBuffAFull,
         vc3RemBuffFull    => pgpRxVcOut(3).remBuffFull,
			gtpLoopback       => '0',
         gtpClkIn          => pgpRefClk,
         gtpRefClkOut      => intRefClkOut,
         gtpRxRecClk       => open,
         gtpRxN            => pgpRxN,
         gtpRxP            => pgpRxP,
         gtpTxN            => pgpTxN,
         gtpTxP            => pgpTxP,
         debug             => open
      );

   -- Lane 0, VC0, Command processor
   U_PgpCmd : entity work.VcCmdSlave 
      generic map (
         TPD_G           => 1 ns,
         RST_ASYNC_G     => false,
         RX_LANE_G       => 0,
         DEST_ID_G       => 0,
         DEST_MASK_G     => 0,
         GEN_SYNC_FIFO_G => false,
         USE_DSP48_G     => "no",
         ALTERA_SYN_G    => false,
         ALTERA_RAM_G    => "M9K",
         USE_BUILT_IN_G  => false,
         XIL_DEVICE_G    => "VIRTEX5",   
         SYNC_STAGES_G   => 3,
         ETH_MODE_G      => false
      )
      port map (
         -- RX VC Signals (vcRxClk domain)
         vcRxOut             => pgpRxVcOut(0),
         vcRxCommonOut       => pgpRxVcCommon,
         vcTxIn_locBuffAFull => pgpTxVcIn(0).locBuffAFull,
         vcTxIn_locBuffFull  => pgpTxVcIn(0).locBuffFull,
         -- Command Signals (locClk domain)
         cmdSlaveOut         => pgpCmd,
         -- Local clock and resets
         locClk              => isysClk,
         locRst              => isysClkRst,
         -- VC Rx Clock And Resets
         vcRxClk             => ipgpClk,
         vcRxRst             => ipgpClkRst
      );

   -- Return data, Lane 0, VC0
   U_DataBuff : entity work.VcUsBuff32
      generic map (
         TPD_G              => 1 ns,
         RST_ASYNC_G        => false,
         TX_LANES_G         => 1,
         GEN_SYNC_FIFO_G    => false,
         BRAM_EN_G          => true,
         FIFO_ADDR_WIDTH_G  => 9,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => false,
         ALTERA_RAM_G       => "M9K",
         USE_BUILT_IN_G     => false, 
         LITTLE_ENDIAN_G    => false,
         XIL_DEVICE_G       => "VIRTEX5",    
         FIFO_SYNC_STAGES_G => 3,
         FIFO_INIT_G        => "0",
         FIFO_FULL_THRES_G  => 256,  -- Almost full at 1/2 capacity
         FIFO_EMPTY_THRES_G => 1
      )
      port map (
         -- TX VC Signals (vcTxClk domain)
         vcTxIn      => pgpTxVcIn(0),
         vcTxOut     => pgpTxVcOut(0),
         vcRxOut     => pgpRxVcOut(0),
         -- UP signals  (locClk domain)
         usBuff32In  => frameTxIn,
         usBuff32Out => frameTxOut,
         -- Local clock and resets
         locClk      => isysClk,
         locRst      => isysClkRst,
         -- VC Tx Clock And Resets
         vcTxClk     => ipgpClk,
         vcTxRst     => ipgpClkRst
     ); 

   -- Lane 0, VC1, Register access control
   U_PgpReg : entity work.VcRegSlave
      generic map (
         TPD_G           => 1 ns,
         LANE_G          => 0,
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => false,
         BRAM_EN_G       => true,
         USE_DSP48_G     => "no",
         ALTERA_SYN_G    => false,
         ALTERA_RAM_G    => "M9K",
         USE_BUILT_IN_G  => false,
         XIL_DEVICE_G    => "VIRTEX5",
         SYNC_STAGES_G   => 3,
         ETH_MODE_G      => false
      )
      port map (
         -- PGP Receive Signals
         vcRxOut       => pgpRxVcOut(1),
         vcRxCommonOut => pgpRxVcCommon,
         -- PGP Transmit Signals
         vcTxIn        => pgpTxVcIn(1),
         vcTxOut       => pgpTxVcOut(1),
         -- REG Signals (locClk domain)
         regSlaveIn    => pgpRegIn,
         regSlaveOut   => pgpRegOut,
         -- Local clock and reset
         locClk        => isysClk,
         locRst        => isysClkRst,
         -- PGP Rx Clock And Reset
         vcTxClk       => ipgpClk,
         vcTxRst       => ipgpClkRst,
         -- PGP Rx Clock And Reset
         vcRxClk       => ipgpClk,
         vcRxRst       => ipgpClkRst);

   -- Lane 0, VC2, Virtual oscillope channel
   U_ScopeBuff : entity work.VcUsBuff32
      generic map (
         TPD_G              => 1 ns,
         RST_ASYNC_G        => false,
         TX_LANES_G         => 1,
         GEN_SYNC_FIFO_G    => false,
         BRAM_EN_G          => true,
         FIFO_ADDR_WIDTH_G  => 9,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => false,
         ALTERA_RAM_G       => "M9K",
         USE_BUILT_IN_G     => false, 
         LITTLE_ENDIAN_G    => false,
         XIL_DEVICE_G       => "VIRTEX5",    
         FIFO_SYNC_STAGES_G => 3,
         FIFO_INIT_G        => "0",
         FIFO_FULL_THRES_G  => 256,  -- Almost full at 1/2 capacity
         FIFO_EMPTY_THRES_G => 1
      )
      port map (
         -- TX VC Signals (vcTxClk domain)
         vcTxIn      => pgpTxVcIn(2),
         vcTxOut     => pgpTxVcOut(2),
         vcRxOut     => pgpRxVcOut(2),
         -- UP signals  (locClk domain)
         usBuff32In  => scopeTxIn,
         usBuff32Out => scopeTxOut,
         -- Local clock and resets
         locClk      => isysClk,
         locRst      => isysClkRst,
         -- VC Tx Clock And Resets
         vcTxClk     => ipgpClk,
         vcTxRst     => ipgpClkRst
     ); 
   -- No corresponding receiver for VC2
   pgpTxVcIn(2).locBuffAFull  <= '0';
   pgpTxVcIn(2).locBuffFull   <= '0';
   --pgpRxVcOut(2).valid,

   -- VC3 Unused
   pgpTxVcIn(3).valid  <= '0';
   pgpTxVcIn(3).sof    <= '0';
   pgpTxVcIn(3).eof    <= '0';
   pgpTxVcIn(3).eofe   <= '0';
   pgpTxVcIn(3).data   <= (others=>(others=>'0'));
   pgpTxVcIn(3).locBuffAFull  <= '0';
   pgpTxVcIn(3).locBuffFull   <= '0';
   --pgpTxVcOut(3).ready
   --pgpRxVcOut(3).remBuffAFull
   --pgpRxVcOut(3).remBuffFull
   --pgpRxVcOut(3).valid,

end PgpFrontEnd;

