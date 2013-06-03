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
use work.Pgp2AppTypesPkg.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity PgpFrontEnd is 
   port ( 
      
      -- Reference Clock, Power on Reset
      pgpRefClk        : in  std_logic;
      ponResetL        : in  std_logic;
      resetReq         : in  std_logic;

      -- Local clock and reset
      sysClk           : out std_logic;
      sysClkRst        : out std_logic;

      -- Local command signal
      pgpCmd           : out CmdSlaveOutType;

      -- Local register control signals
      pgpRegOut        : out RegSlaveOutType;
      pgpRegIn         : in  RegSlaveInType;

      -- Local data transfer signals
      frameTxIn        : in  UsBuff32InType;
      frameTxOut       : in  UsBuffOutType;

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
   signal pgpTxVcIn          : PgpTxVcQuadInType;
   signal pgpTxVcOut         : PgpTxVcQuadOutType;
   signal pgpRxVcCommon      : PgpRxVcCommonOutType;
   signal pgpRxVcOut         : PgpRxVcQuadOutType;
   signal intRefClkOut       : std_logic;
   signal ipgpClk            : std_logic;
   signal ipgpClk2x          : std_logic;
   signal ipgpClkRst         : std_logic;
   signal isysClk            : std_logic;
   signal isysClkRst         : std_logic;

begin

   -- Outputs
   sysClk     <= isysClk;
   sysClkRst  <= isysClkRst;

   -- Clock generation
   U_PgpClk: entity work.Pgp2GtpClk
      generic map (
         UserFxDiv  => 5,
         UserFxMult => 4
      )
      port map (
         pgpRefClk     => intRefClkOut,
         ponResetL     => ponResetL,
         locReset      => resetReq,
         pgpClk        => ipgpClk,
         pgpReset      => ipgpClkRst,
         pgpClk2x      => ipgpClk2x,
         userClk       => isysClk,
         userReset     => isysClkRst,
         pgpClkIn      => ipgpClk,
         userClkIn     => isysClk
      );

   -- PGP Core
   U_Pgp2Gtp16: entity work.Pgp2Gtp16
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
         vc0FrameTxValid   => pgpTxVcIn(0).frameTxValid,
         vc0FrameTxReady   => pgpTxVcOut(0).frameTxReady,
         vc0FrameTxSOF     => pgpTxVcIn(0).frameTxSOF,
         vc0FrameTxEOF     => pgpTxVcIn(0).frameTxEOF,
         vc0FrameTxEOFE    => pgpTxVcIn(0).frameTxEOFE,
         vc0FrameTxData    => pgpTxVcIn(0).frameTxData,
         vc0LocBuffAFull   => pgpTxVcIn(0).locBuffAFull,
         vc0LocBuffFull    => pgpTxVcIn(0).locBuffFull,
         vc1FrameTxValid   => pgpTxVcIn(1).frameTxValid,
         vc1FrameTxReady   => pgpTxVcOut(1).frameTxReady,
         vc1FrameTxSOF     => pgpTxVcIn(1).frameTxSOF,
         vc1FrameTxEOF     => pgpTxVcIn(1).frameTxEOF,
         vc1FrameTxEOFE    => pgpTxVcIn(1).frameTxEOFE,
         vc1FrameTxData    => pgpTxVcIn(1).frameTxData,
         vc1LocBuffAFull   => pgpTxVcIn(1).locBuffAFull,
         vc1LocBuffFull    => pgpTxVcIn(1).locBuffFull,
         vc2FrameTxValid   => pgpTxVcIn(2).frameTxValid,
         vc2FrameTxReady   => pgpTxVcOut(2).frameTxReady,
         vc2FrameTxSOF     => pgpTxVcIn(2).frameTxSOF,
         vc2FrameTxEOF     => pgpTxVcIn(2).frameTxEOF,
         vc2FrameTxEOFE    => pgpTxVcIn(2).frameTxEOFE,
         vc2FrameTxData    => pgpTxVcIn(2).frameTxData,
         vc2LocBuffAFull   => pgpTxVcIn(2).locBuffAFull,
         vc2LocBuffFull    => pgpTxVcIn(2).locBuffFull,
         vc3FrameTxValid   => pgpTxVcIn(3).frameTxValid,
         vc3FrameTxReady   => pgpTxVcOut(3).frameTxReady,
         vc3FrameTxSOF     => pgpTxVcIn(3).frameTxSOF,
         vc3FrameTxEOF     => pgpTxVcIn(3).frameTxEOF,
         vc3FrameTxEOFE    => pgpTxVcIn(3).frameTxEOFE,
         vc3FrameTxData    => pgpTxVcIn(3).frameTxData,
         vc3LocBuffAFull   => pgpTxVcIn(3).locBuffAFull,
         vc3LocBuffFull    => pgpTxVcIn(3).locBuffFull,
         vcFrameRxSOF      => pgpRxVcCommon.frameRxSOF,
         vcFrameRxEOF      => pgpRxVcCommon.frameRxEOF,
         vcFrameRxEOFE     => pgpRxVcCommon.frameRxEOFE,
         vcFrameRxData     => pgpRxVcCommon.frameRxData,
         vc0FrameRxValid   => pgpRxVcOut(0).frameRxValid,
         vc0RemBuffAFull   => pgpRxVcOut(0).remBuffAFull,
         vc0RemBuffFull    => pgpRxVcOut(0).remBuffFull,
         vc1FrameRxValid   => pgpRxVcOut(1).frameRxValid,
         vc1RemBuffAFull   => pgpRxVcOut(1).remBuffAFull,
         vc1RemBuffFull    => pgpRxVcOut(1).remBuffFull,
         vc2FrameRxValid   => pgpRxVcOut(2).frameRxValid,
         vc2RemBuffAFull   => pgpRxVcOut(2).remBuffAFull,
         vc2RemBuffFull    => pgpRxVcOut(2).remBuffFull,
         vc3FrameRxValid   => pgpRxVcOut(3).frameRxValid,
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
   U_PgpCmd: entity work.Pgp2CmdSlave 
      generic map ( 
         DestId    => 0,
         DestMask  => 1,
         FifoType  => "V5"
      ) port map ( 
         pgpRxClk       => ipgpClk,          
         pgpRxReset     => ipgpClkRst,
         locClk         => isysClk,          
         locReset       => isysClkRst,
         vcFrameRxValid => pgpRxVcOut(0).frameRxValid, 
         vcFrameRxSOF   => pgpRxVcCommon.frameRxSOF,
         vcFrameRxEOF   => pgpRxVcCommon.frameRxEOF,    
         vcFrameRxEOFE  => pgpRxVcCommon.frameRxEOFE,
         vcFrameRxData  => pgpRxVcCommon.frameRxData,   
         vcLocBuffAFull => pgpTxVcIn(0).locBuffAFull,
         vcLocBuffFull  => pgpTxVcIn(0).locBuffFull,  
         cmdEn          => pgpCmd.cmdEn,
         cmdOpCode      => pgpCmd.cmdOpCode,        
         cmdCtxOut      => pgpCmd.cmdCtxOut
      );

   -- Return data, Lane 0, VC0
   U_DataBuff: entity work.Pgp2Us32Buff 
      generic map ( 
         FifoType => "V5" 
      ) 
      port map ( 
         pgpClk           => ipgpClk,
         pgpReset         => ipgpClkRst,
         locClk           => isysClk,
         locReset         => isysClkRst,
         frameTxValid     => frameTxIn.frameTxEnable,
         frameTxSOF       => frameTxIn.frameTxSOF,
         frameTxEOF       => frameTxIn.frameTxEOF,
         frameTxEOFE      => frameTxIn.frameTxEOFE,
         frameTxData      => frameTxIn.frameTxData,
         frameTxAFull     => frameTxOut.frameTxAFull,
         vcFrameTxValid   => pgpTxVcIn(0).frameTxValid,
         vcFrameTxReady   => pgpTxVcOut(0).frameTxReady,
         vcFrameTxSOF     => pgpTxVcIn(0).frameTxSOF,
         vcFrameTxEOF     => pgpTxVcIn(0).frameTxEOF,
         vcFrameTxEOFE    => pgpTxVcIn(0).frameTxEOFE,
         vcFrameTxData    => pgpTxVcIn(0).frameTxData,
         vcRemBuffAFull   => pgpRxVcOut(0).remBuffAFull,
         vcRemBuffFull    => pgpRxVcOut(0).remBuffFull
      );

   -- Lane 0, VC1, Register access control
   U_PgpReg: entity work.Pgp2RegSlave 
      generic map ( 
         FifoType => "V5" 
      ) 
      port map (
         pgpRxClk        => ipgpClk,
         pgpRxReset      => ipgpClkRst,
         pgpTxClk        => ipgpClk,
         pgpTxReset      => ipgpClkRst,
         locClk          => isysClk,
         locReset        => isysClkRst,
         vcFrameTxValid  => pgpTxVcIn(1).frameTxValid,
         vcFrameTxReady  => pgpTxVcOut(1).frameTxReady,
         vcFrameTxSOF    => pgpTxVcIn(1).frameTxSOF,
         vcFrameTxEOF    => pgpTxVcIn(1).frameTxEOF,
         vcFrameTxEOFE   => pgpTxVcIn(1).frameTxEOFE,
         vcFrameTxData   => pgpTxVcIn(1).frameTxData,
         vcRemBuffAFull  => pgpRxVcOut(1).remBuffAFull,
         vcRemBuffFull   => pgpRxVcOut(1).remBuffFull
         vcFrameRxValid  => pgpRxVcOut(1).frameRxValid, 
         vcFrameRxSOF    => pgpRxVcCommon.frameRxSOF,
         vcFrameRxEOF    => pgpRxVcCommon.frameRxEOF,    
         vcFrameRxEOFE   => pgpRxVcCommon.frameRxEOFE,
         vcFrameRxData   => pgpRxVcCommon.frameRxData,   
         vcLocBuffAFull  => pgpTxVcIn(1).locBuffAFull,
         vcLocBuffFull   => pgpTxVcIn(1).locBuffFull,  
         regInp          => pgpRegOut.regInp,
         regReq          => pgpRegOut.regReq,
         regOp           => pgpRegOut.regOp,
         regAck          => pgpRegIn.regAck,
         regFail         => pgpRegIn.regFail,
         regAddr         => pgpRegOut.regAddr,
         regDataOut      => pgpRegOut.regDataOut,
         regDataIn       => pgpRegIn.regDataIn
      );

   -- VC2 Unused
   pgpTxVcIn(2).frameTxValid  <= '0';
   pgpTxVcIn(2).frameTxSOF    <= '0';
   pgpTxVcIn(2).frameTxEOF    <= '0';
   pgpTxVcIn(2).frameTxEOFE   <= '0';
   pgpTxVcIn(2).frameTxData   <= (others=>'0');
   pgpTxVcIn(2).locBuffAFull  <= '0';
   pgpTxVcIn(2).locBuffFull   <= '0';
   --pgpTxVcOut(2).frameTxReady
   --pgpRxVcOut(2).remBuffAFull
   --pgpRxVcOut(2).remBuffFull
   --pgpRxVcOut(2).frameRxValid,

   -- VC3 Unused
   pgpTxVcIn(3).frameTxValid  <= '0';
   pgpTxVcIn(3).frameTxSOF    <= '0';
   pgpTxVcIn(3).frameTxEOF    <= '0';
   pgpTxVcIn(3).frameTxEOFE   <= '0';
   pgpTxVcIn(3).frameTxData   <= (others=>'0');
   pgpTxVcIn(3).locBuffAFull  <= '0';
   pgpTxVcIn(3).locBuffFull   <= '0';
   --pgpTxVcOut(3).frameTxReady
   --pgpRxVcOut(3).remBuffAFull
   --pgpRxVcOut(3).remBuffFull
   --pgpRxVcOut(3).frameRxValid,

end PgpFrontEnd;

