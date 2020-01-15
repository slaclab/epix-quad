-------------------------------------------------------------------------------
-- Title      : PgpFrontEnd for ePix Gen 2
-------------------------------------------------------------------------------
-- File       : PgpFrontEnd.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: PgpFrontEnd for generation 2 ePix digital card
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
use surf.Pgp2bPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.SsiCmdMasterPkg.all;

library unisim;
use unisim.vcomponents.all;

entity PgpFrontEnd is
   generic (
      TPD_G          : time      := 1 ns;
      SIMULATION_G   : boolean   := false
   );
   port (
      -- Output status
      rxLinkReady : out sl;
      txLinkReady : out sl;
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
      -- Command Interface
      ssiCmd            : out SsiCmdMasterType;
      -- Sideband interface
      pgpRxOut          : out Pgp2bRxOutType;
      -- To access sideband commands
      pgpOpCode         : out  slv(7 downto 0);
      pgpOpCodeEn       : out  sl
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
   -- for simulation only
   signal pgpRxSlaves  : AxiStreamSlaveArray(3 downto 0);

   -- Pgp Rx/Tx types
   signal pgpRxIn     : Pgp2bRxInType;
   signal iPgpRxOut   : Pgp2bRxOutType;
   signal pgpTxIn     : Pgp2bTxInType;
   signal pgpTxOut    : Pgp2bTxOutType;
   
   signal iSsiCmd      : SsiCmdMasterType;
   
begin
   
   -- Map to signals out
   pgpClk      <= iPgpClk;
   
   rxLinkReady <= iPgpRxOut.linkReady;
   txLinkReady <= pgpTxOut.linkReady;   
   
   ssiCmd <= iSsiCmd;   
   
   pgpRxOut <= iPgpRxOut;   

   -------------------------------
   --       PGP Core            --
   -------------------------------
   
   G_PGP : if SIMULATION_G = false generate
      
      -- Generate stable reset signal
      U_PwrUpRst : entity surf.PwrUpRst
         port map (
            clk    => iStableClk,
            rstOut => powerUpRst
         ); 
      stableRst <= powerUpRst or powerBad;
      
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
   end generate G_PGP;
   
   G_PGP_SIM : if SIMULATION_G = true generate
      
      -- Generate stable reset signal
      U_PwrUpRst : entity surf.PwrUpRst
         generic map (
            SIM_SPEEDUP_G => true
         )
         port map (
            clk    => iPgpClk,
            rstOut => stableRst
         ); 
      
      pgpRst <= stableRst;
      
      U_Sim_IBUFDS : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0', 
         O     => iPgpClk);  
      
      U_PGP_SIM : entity surf.RoguePgp2bSim
         generic map (
            TPD_G           => TPD_G,
            PORT_NUM_G      => 8000,
            NUM_VC_G        => 4
         )
         port map (
            pgpClk         => iPgpClk,
            pgpClkRst      => stableRst,
            pgpTxIn        => pgpTxIn,
            pgpTxOut       => pgpTxOut,
            pgpTxMasters   => pgpTxMasters,
            pgpTxSlaves    => pgpTxSlaves,
            pgpRxIn        => pgpRxIn,
            pgpRxOut       => iPgpRxOut,
            pgpRxMasters   => pgpRxMasters,
            pgpRxSlaves    => pgpRxSlaves
         );
      
   end generate G_PGP_SIM;
   
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
         rst    => stableRst,
         wr_clk => iPgpClk,
         wr_en  => iPgpRxOut.opCodeEn,
         din    => iPgpRxOut.opCode,
         rd_clk => axiClk,
         rd_en  => '1',
         valid  => pgpOpCodeEn,
         dout   => pgpOpCode
      );
   
   U_Pgp2bAxi : entity surf.Pgp2bAxi
   generic map (
      AXI_CLK_FREQ_G     => 100.0E+6
   )
   port map (
      pgpTxClk         => iPgpClk,
      pgpTxClkRst      => stableRst,
      pgpTxIn          => pgpTxIn,
      pgpTxOut         => pgpTxOut,
      pgpRxClk         => iPgpClk,
      pgpRxClkRst      => stableRst,
      pgpRxIn          => pgpRxIn,
      pgpRxOut         => iPgpRxOut,
      axilClk          => axiClk,
      axilRst          => axiRst,
      axilReadMaster   => sAxiLiteReadMaster,
      axilReadSlave    => sAxiLiteReadSlave,
      axilWriteMaster  => sAxiLiteWriteMaster,
      axilWriteSlave   => sAxiLiteWriteSlave
   );   
   
   
   -- Lane 0, VC0 RX/TX, Register access control        
   U_Vc0AxiMasterRegisters : entity surf.SsiAxiLiteMaster 
      generic map (
         EN_32BIT_ADDR_G     => true,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C,
         SLAVE_READY_EN_G    => SIMULATION_G
      )
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk    => iPgpClk,
         sAxisRst    => stableRst,
         sAxisMaster => pgpRxMasters(0),
         sAxisSlave  => pgpRxSlaves(0),
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
   
   -- Lane 0, VC1 TX, streaming data out 
   U_Vc1SsiTxFifo : entity surf.AxiStreamFifoV2
      generic map (
         --EN_FRAME_FILTER_G   => true,
         CASCADE_SIZE_G      => 1,
         MEMORY_TYPE_G       => "block",
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
         sAxisMaster => dataAxisMaster,
         sAxisSlave  => dataAxisSlave,
         -- Master Port
         mAxisClk    => iPgpClk,
         mAxisRst    => stableRst,
         mAxisMaster => pgpTxMasters(1),
         mAxisSlave  => pgpTxSlaves(1));     
   -- Lane 0, VC1 RX, Command processor
   U_Vc1SsiCmdMaster : entity surf.SsiCmdMaster
      generic map (
         SLAVE_READY_EN_G    => SIMULATION_G,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)   
      port map (
         -- Streaming Data Interface
         axisClk     => iPgpClk,
         axisRst     => stableRst,
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
      MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C) 
   port map (   
      -- Slave Port
      sAxisClk    => axiClk,
      sAxisRst    => axiRst,
      sAxisMaster => monitorAxisMaster,
      sAxisSlave  => monitorAxisSlave,
      -- Master Port
      mAxisClk    => iPgpClk,
      mAxisRst    => stableRst,
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
      SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
      MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(4)) 
   port map (   
      -- Slave Port
      sAxisClk    => iPgpClk,
      sAxisRst    => stableRst,
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

