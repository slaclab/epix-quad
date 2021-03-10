-------------------------------------------------------------------------------
-- Title      : Pgp3FrontEnd for ePix Gen 2
-------------------------------------------------------------------------------
-- File       : Pgp3FrontEnd.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Pgp3FrontEnd for generation 2 ePix digital card
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

library surf;
use surf.StdRtlPkg.all;
use surf.Pgp3Pkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SsiCmdMasterPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp3FrontEnd is
   generic (
      TPD_G             : time            := 1 ns;
      SIMULATION_G      : boolean         := false;
      AXI_CLK_FREQ_G    : real            := 100.00E+6;
      AXI_BASE_ADDR_G   : slv(31 downto 0) := (others => '0')
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
      -- Axi Slave Interface - PGP Status Registers (axiClk domain)
      sAxiLiteReadMaster  : in  AxiLiteReadMasterType;
      sAxiLiteReadSlave   : out AxiLiteReadSlaveType;
      sAxiLiteWriteMaster : in  AxiLiteWriteMasterType;
      sAxiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      -- Acquisition streaming data Links (axiClk domain)      
      dataAxisMaster    : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      dataAxisSlave     : out AxiStreamSlaveType;
      -- Scope streaming data Links (axiClk domain)      
      scopeAxisMaster   : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      scopeAxisSlave    : out AxiStreamSlaveType;
      -- Monitoring streaming data Links (axiClk domain)      
      monitorAxisMaster : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
      monitorAxisSlave  : out AxiStreamSlaveType;
      -- Monitoring enable command incoming stream
      monEnAxisMaster   : out AxiStreamMasterType;
      -- VC Command interface
      swRun             : out sl;
      -- To access sideband commands
      pgpOpCode         : out  slv(7 downto 0);
      pgpOpCodeEn       : out  sl
   );        
end Pgp3FrontEnd;

architecture mapping of Pgp3FrontEnd is

   signal iPgpClk       : sl;
   signal iPgpRst       : sl;
   signal pgpRefClk     : sl;
   signal pgpRefClkBufg : sl;
   signal pgpRefClkRst  : sl;
   
   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);
   -- for simulation only
   signal pgpRxSlaves  : AxiStreamSlaveArray(3 downto 0);
   
   signal iSsiCmd      : SsiCmdMasterType;
   signal iPgpRxOut    : Pgp3RxOutType;
   
begin
   
   
   U_BUFG : BUFG
      port map (
         I => pgpRefClk,
         O => pgpRefClkBufg);
   
   pgpClk <= pgpRefClkBufg;
   pgpRst <= pgpRefClkRst;
   
   U_PwrUpRst : entity surf.PwrUpRst
      generic map(
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => SIMULATION_G)
      port map (
         clk    => pgpRefClkBufg,
         rstOut => pgpRefClkRst
      );
   
   U_Pgp3Gtp7Wrapper : entity surf.Pgp3Gtp7Wrapper
      generic map (
         TPD_G                       => TPD_G,
         ROGUE_SIM_EN_G              => SIMULATION_G,
         ROGUE_SIM_PORT_NUM_G        => 8000,
         RATE_G                      => "3.125Gbps",
         REFCLK_FREQ_G               => 156.25E+6,
         EN_PGP_MON_G                => true,
         EN_GT_DRP_G                 => false,
         EN_QPLL_DRP_G               => false,
         AXIL_BASE_ADDR_G            => AXI_BASE_ADDR_G,
         AXIL_CLK_FREQ_G             => AXI_CLK_FREQ_G
      )
      port map (
         -- Stable Clock and Reset
         stableClk         => axiClk,
         stableRst         => axiRst,
         -- Gt Serial IO
         pgpGtTxP(0)       => gtTxP,
         pgpGtTxN(0)       => gtTxN,
         pgpGtRxP(0)       => gtRxP,
         pgpGtRxN(0)       => gtRxN,
         -- GT Clocking
         pgpRefClkP        => gtClkP,
         pgpRefClkN        => gtClkN,
         pgpRefClkOut      => pgpRefClk,
         -- Clocking
         pgpClk(0)         => iPgpClk,
         pgpClkRst(0)      => iPgpRst,
         -- Non VC Rx Signals
         pgpRxIn(0)        => PGP3_RX_IN_INIT_C,
         pgpRxOut(0)       => iPgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn(0)        => PGP3_TX_IN_INIT_C,
         pgpTxOut(0)       => open,
         -- Frame Transmit Interface
         pgpTxMasters      => pgpTxMasters,
         pgpTxSlaves       => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters      => pgpRxMasters,
         pgpRxCtrl         => pgpRxCtrl,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk           => axiClk,
         axilRst           => axiRst,
         axilReadMaster    => sAxiLiteReadMaster,
         axilReadSlave     => sAxiLiteReadSlave,
         axilWriteMaster   => sAxiLiteWriteMaster,
         axilWriteSlave    => sAxiLiteWriteSlave
      );
   
   -----------------------------------------
   -- PGP Sideband Triggers:
   -- Any op code is a trigger
   -- actual opcode is the fiducial.
   -----------------------------------------
   U_PgpSideBandTrigger : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8
      )
      port map (
         rst    => iPgpRst,
         wr_clk => iPgpClk,
         wr_en  => iPgpRxOut.opCodeEn,
         din    => iPgpRxOut.opCodeData(7 downto 0), -- this needs to be revised when PGP3 is used for triggernig
         rd_clk => axiClk,
         rd_en  => '1',
         valid  => pgpOpCodeEn,
         dout   => pgpOpCode
      );
   
   -- Lane 0, VC0 RX/TX, Register access control        
   U_Vc0AxiMasterRegisters : entity surf.SsiAxiLiteMaster 
      generic map (
         EN_32BIT_ADDR_G     => true,
         AXI_STREAM_CONFIG_G => PGP3_AXIS_CONFIG_C,
         SLAVE_READY_EN_G    => SIMULATION_G
      )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk    => iPgpClk,
         sAxisRst    => iPgpRst,
         sAxisMaster => pgpRxMasters(0),
         sAxisSlave  => pgpRxSlaves(0),
         sAxisCtrl   => pgpRxCtrl(0),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk    => iPgpClk,
         mAxisRst    => iPgpRst,
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
   
   -- Lane 0, VC1 TX, streaming data out 
   U_Vc0SsiTxFifo : entity surf.AxiStreamFifoV2
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 14,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,    
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C) 
      port map (   
         -- Slave Port
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => dataAxisMaster,
         sAxisSlave  => dataAxisSlave,
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => iPgpRst,
         mAxisMaster => pgpTxMasters(1),
         mAxisSlave  => pgpTxSlaves(1));     
   -- Lane 0, VC1 RX, Command processor
   U_Vc0SsiCmdMaster : entity surf.SsiCmdMaster
      generic map (
         SLAVE_READY_EN_G    => SIMULATION_G,
         AXI_STREAM_CONFIG_G => PGP3_AXIS_CONFIG_C)   
      port map (
         -- Streaming Data Interface
         axisClk     => iPgpClk,
         axisRst     => iPgpRst,
         sAxisMaster => pgpRxMasters(1),
         sAxisSlave  => pgpRxSlaves(1),
         sAxisCtrl   => pgpRxCtrl(1),
         -- Command signals
         cmdClk      => axiClk,
         cmdRst      => axiRst,
         cmdMaster   => iSsiCmd
      );
   -----------------------------------
   -- SW Triggers:
   -- Run trigger is opCode x00
   -----------------------------------
   U_TrigPulser : entity surf.SsiCmdMasterPulser
      generic map (
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1
      )
      port map (
          -- Local command signal
         cmdSlaveOut => iSsiCmd,
         --addressed cmdOpCode
         opCode      => x"00",
         -- output pulse to sync module
         syncPulse   => swRun,
         -- Local clock and reset
         locClk      => axiClk,
         locRst      => axiRst              
      );
      
   -- Lane 0, VC2 TX oscilloscope data stream
   U_Vc2SsiOscilloscopeFifo : entity surf.AxiStreamFifoV2
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,    
         FIFO_ADDR_WIDTH_G   => 14,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,    
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C) 
      port map (   
         -- Slave Port
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => scopeAxisMaster,
         sAxisSlave  => scopeAxisSlave,
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => iPgpRst,
         mAxisMaster => pgpTxMasters(2),
         mAxisSlave  => pgpTxSlaves(2));     
   
   -- Lane 0, VC3 TX monitoring data stream
   U_Vc3SsiMonitorFifo : entity surf.AxiStreamFifoV2
   generic map (
      --EN_FRAME_FILTER_G   => true,
      CASCADE_SIZE_G      => 1,
      MEMORY_TYPE_G       => "block",
      GEN_SYNC_FIFO_G     => false,    
      FIFO_ADDR_WIDTH_G   => 9,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 128,    
      SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
      MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C) 
   port map (   
      -- Slave Port
      sAxisClk    => axiClk,
      sAxisRst    => axiRst,
      sAxisMaster => monitorAxisMaster,
      sAxisSlave  => monitorAxisSlave,
      -- Master Port
      mAxisClk    => iPgpClk,
      mAxisRst    => iPgpRst,
      mAxisMaster => pgpTxMasters(3),
      mAxisSlave  => pgpTxSlaves(3)
   );
   -- Lane 0, VC3 RX monitoring stream enable command fifo
   U_Vc3SsiMonitorCmd : entity surf.AxiStreamFifoV2
   generic map (
      --EN_FRAME_FILTER_G   => true,
      CASCADE_SIZE_G      => 1,
      MEMORY_TYPE_G       => "block",
      GEN_SYNC_FIFO_G     => false,    
      FIFO_ADDR_WIDTH_G   => 9,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 128,    
      SLAVE_AXI_CONFIG_G  => PGP3_AXIS_CONFIG_C,
      MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(4)) 
   port map (   
      -- Slave Port
      sAxisClk    => iPgpClk,
      sAxisRst    => iPgpRst,
      sAxisMaster => pgpRxMasters(3),
      sAxisSlave  => open,
      -- Master Port
      mAxisClk    => axiClk,
      mAxisRst    => axiRst,
      mAxisMaster => monEnAxisMaster,
      mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C
   );
   
   -- If we have unused RX CTRL
   pgpRxCtrl(3) <= AXI_STREAM_CTRL_UNUSED_C;
      
end mapping;

