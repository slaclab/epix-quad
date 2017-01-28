-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-01-25
-- Last update: 2017-01-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'Example Project Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Example Project Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.EpixPkgGen2.all;

entity PgpWrapper is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_OK_C);
   port (
      -- Clocks and Reset
      refClk     : in    sl;
      clk        : in    sl;
      rst        : in    sl;
      -- Non VC TX Signals
      pgpTxIn    : in    Pgp2bTxInType;
      pgpTxOut   : out   Pgp2bTxOutType;
      -- Non VC RX Signals
      pgpRxIn    : in    Pgp2bRxInType;
      pgpRxOut   : out   Pgp2bRxOutType;
      -- Streaming Interface
      txMaster   : in    AxiStreamMasterType;
      txSlave    : out   AxiStreamSlaveType;
      -- Register Inputs/Outputs
      epixStatus : in    EpixStatusType;
      epixConfig : out   EpixConfigType;
      -- 1-wire board ID interfaces
      serialIdIo : inout slv(1 downto 0);
      -- GT Pins
      gtTxP      : out   sl;
      gtTxN      : out   sl;
      gtRxP      : in    sl;
      gtRxN      : in    sl);
end PgpWrapper;

architecture mapping of PgpWrapper is

   constant RAM_WIDTH_C : positive := 12;
   constant SIZE_C      : positive := 1;
   constant ADDR_C : Slv32Array(SIZE_C-1 downto 0) := (
      0 => (VERSION_AXI_BASE_ADDR_C+4)  -- AxiVersion.scratchpad
      );
   constant DATA_C : Slv32Array(SIZE_C-1 downto 0) := (
      0 => x"BEEFCAFE"                  -- AxiVersion.scratchpad
      );

   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);

   signal txIn  : Pgp2bTxInType;
   signal txOut : Pgp2bTxOutType;

   signal rxIn  : Pgp2bRxInType;
   signal rxOut : Pgp2bRxOutType;

   signal sAxilReadMasters  : AxiLiteReadMasterArray(1 downto 0);
   signal sAxilReadSlaves   : AxiLiteReadSlaveArray(1 downto 0);
   signal sAxilWriteMasters : AxiLiteWriteMasterArray(1 downto 0);
   signal sAxilWriteSlaves  : AxiLiteWriteSlaveArray(1 downto 0);

   signal mAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0);
   signal mAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0);
   signal mAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0);
   signal mAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0);

begin

   txIn     <= pgpTxIn;
   pgpTxOut <= txOut;

   rxIn     <= pgpRxIn;
   pgpRxOut <= rxOut;

   U_Pgp2bGtx7VarLat : entity work.Pgp2bGtx7VarLat
      generic map (
         TPD_G             => TPD_G,
         -- CPLL Configurations
         TX_PLL_G          => "CPLL",
         RX_PLL_G          => "CPLL",
         CPLL_REFCLK_SEL_G => "001",
         CPLL_FBDIV_G      => 5,
         CPLL_FBDIV_45_G   => 5,
         CPLL_REFCLK_DIV_G => 1,
         -- MGT Configurations
         RXOUT_DIV_G       => 2,
         TXOUT_DIV_G       => 2,
         RX_CLK25_DIV_G    => 5,
         TX_CLK25_DIV_G    => 5,
         RX_OS_CFG_G       => "0000010000000",
         RXCDR_CFG_G       => x"03000023ff40200020",
         RXDFEXYDEN_G      => '1',
         RX_DFE_KL_CFG2_G  => x"301148AC",
         -- VC Configuration
         VC_INTERLEAVE_G   => 0,
         PAYLOAD_CNT_TOP_G => 7,
         NUM_VC_EN_G       => 4,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
         TX_ENABLE_G       => true,
         RX_ENABLE_G       => true)
      port map (
         -- GT Clocking
         stableClk        => clk,
         gtCPllRefClk     => refClk,
         gtCPllLock       => open,
         gtQPllRefClk     => '0',
         gtQPllClk        => '0',
         gtQPllLock       => '1',
         gtQPllRefClkLost => '0',
         gtQPllReset      => open,
         -- GT Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Tx Clocking
         pgpTxReset       => rst,
         pgpTxRecClk      => open,
         pgpTxClk         => clk,
         pgpTxMmcmReset   => open,
         pgpTxMmcmLocked  => '1',
         -- Rx clocking
         pgpRxReset       => rst,
         pgpRxRecClk      => open,
         pgpRxClk         => clk,
         pgpRxMmcmReset   => open,
         pgpRxMmcmLocked  => '1',
         -- Non VC TX Signals
         pgpTxIn          => txIn,
         pgpTxOut         => txOut,
         -- Non VC RX Signals
         pgpRxIn          => rxIn,
         pgpRxOut         => rxOut,
         -- Frame TX Interface
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame RX Interface
         pgpRxMasters     => pgpRxMasters,
         pgpRxCtrl        => pgpRxCtrl,
         -- Debug Interface 
         txPreCursor      => (others => '0'),
         txPostCursor     => (others => '0'),
         txDiffCtrl       => "1111");

   -- Lane 0, VC0 TX, streaming data out 
   U_Vc0SsiTxFifo : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
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
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => pgpTxMasters(0),
         mAxisSlave  => pgpTxSlaves(0));

   -- Lane 0, VC1 RX/TX, Register access control        
   U_Vc1AxiMasterRegisters : entity work.SsiAxiLiteMaster
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => true,
         USE_BUILT_IN_G      => false,
         EN_32BIT_ADDR_G     => true,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk            => clk,
         sAxisRst            => rst,
         sAxisMaster         => pgpRxMasters(1),
         sAxisSlave          => open,
         sAxisCtrl           => pgpRxCtrl(1),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk            => clk,
         mAxisRst            => rst,
         mAxisMaster         => pgpTxMasters(1),
         mAxisSlave          => pgpTxSlaves(1),
         -- AXI Lite Bus (axiLiteClk domain)
         axiLiteClk          => clk,
         axiLiteRst          => rst,
         mAxiLiteWriteMaster => sAxilWriteMasters(0),
         mAxiLiteWriteSlave  => sAxilWriteSlaves(0),
         mAxiLiteReadMaster  => sAxilReadMasters(0),
         mAxiLiteReadSlave   => sAxilReadSlaves(0));

   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTER_SLOTS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         sAxiWriteMasters => sAxilWriteMasters,
         sAxiWriteSlaves  => sAxilWriteSlaves,
         sAxiReadMasters  => sAxilReadMasters,
         sAxiReadSlaves   => sAxilReadSlaves,
         mAxiWriteMasters => mAxilWriteMasters,
         mAxiWriteSlaves  => mAxilWriteSlaves,
         mAxiReadMasters  => mAxilReadMasters,
         mAxiReadSlaves   => mAxilReadSlaves,
         axiClk           => clk,
         axiClkRst        => rst);

   U_RegControl : entity work.RegControl
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         EN_DEVICE_DNA_G  => false,
         HARD_RESET_G     => false,
         CLK_PERIOD_G     => 10.0e-9)
      port map (
         axiClk          => clk,
         axiRst          => open,
         sysRst          => rst,
         -- AXI-Lite Register Interface (axiClk domain)
         axiReadMaster   => mAxilReadMasters(EPIXREGS_AXI_INDEX_C),
         axiReadSlave    => mAxilReadSlaves(EPIXREGS_AXI_INDEX_C),
         axiWriteMaster  => mAxilWriteMasters(EPIXREGS_AXI_INDEX_C),
         axiWriteSlave   => mAxilWriteSlaves(EPIXREGS_AXI_INDEX_C),
         -- Monitoring enable command incoming stream
         monEnAxisMaster => AXI_STREAM_MASTER_INIT_C,
         -- Register Inputs/Outputs (axiClk domain)
         epixStatus      => epixStatus,
         epixConfig      => epixConfig,
         scopeConfig     => open,
         -- Guard ring DAC interfaces
         dacSclk         => open,
         dacDin          => open,
         dacCsb          => open,
         dacClrb         => open,
         -- 1-wire board ID interfaces
         serialIdIo      => serialIdIo);

   U_SaciPrepRdout : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         ADDR_WIDTH_G     => RAM_WIDTH_C,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => mAxilReadMasters(PREPRDOUT_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(PREPRDOUT_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(PREPRDOUT_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(PREPRDOUT_AXI_INDEX_C));

   U_SaciMultiPixel : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         ADDR_WIDTH_G     => RAM_WIDTH_C,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => mAxilReadMasters(MULTIPIX_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(MULTIPIX_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(MULTIPIX_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(MULTIPIX_AXI_INDEX_C));

   U_Pgp2bAxi : entity work.Pgp2bAxi
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         AXI_CLK_FREQ_G   => 156.25E+6)
      port map (
         pgpTxClk        => clk,
         pgpTxClkRst     => rst,
         pgpTxIn         => txIn,
         pgpTxOut        => txOut,
         pgpRxClk        => clk,
         pgpRxClkRst     => rst,
         pgpRxIn         => rxIn,
         pgpRxOut        => rxOut,
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => mAxilReadMasters(PGPSTAT_AXI_INDEX_C),
         axilReadSlave   => mAxilReadSlaves(PGPSTAT_AXI_INDEX_C),
         axilWriteMaster => mAxilWriteMasters(PGPSTAT_AXI_INDEX_C),
         axilWriteSlave  => mAxilWriteSlaves(PGPSTAT_AXI_INDEX_C));

   U_AxiLiteSaciMaster : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         ADDR_WIDTH_G     => RAM_WIDTH_C,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => mAxilReadMasters(SACIREGS_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(SACIREGS_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(SACIREGS_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(SACIREGS_AXI_INDEX_C));

   U_AxiVersion : entity work.AxiVersion
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         EN_DEVICE_DNA_G  => false)
      port map (
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxilReadMasters(VERSION_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(VERSION_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(VERSION_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(VERSION_AXI_INDEX_C),
         -- Clocks and Resets
         axiClk         => clk,
         axiRst         => rst);

   U_AxiMicronN25QCore : entity work.AxiMicronN25QCore
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         PIPE_STAGES_G    => 1,
         AXI_CLK_FREQ_G   => 156.25E+6,  -- units of Hz
         SPI_CLK_FREQ_G   => 25.0E+6)    -- units of Hz
      port map (
         -- FLASH Memory Ports
         csL            => open,
         sck            => open,
         mosi           => open,
         miso           => '1',
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxilReadMasters(BOOTMEM_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(BOOTMEM_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(BOOTMEM_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(BOOTMEM_AXI_INDEX_C),
         -- Clocks and Resets
         axiClk         => clk,
         axiRst         => rst);

   U_AdcTester : entity work.StreamPatternTester
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         NUM_CHANNELS_G   => 20)
      port map (
         -- Master system clock
         clk             => clk,
         rst             => rst,
         -- ADC data stream inputs
         adcStreams      => (others => AXI_STREAM_MASTER_INIT_C),
         -- Axi Interface
         axilReadMaster  => mAxilReadMasters(ADCTEST_AXI_INDEX_C),
         axilReadSlave   => mAxilReadSlaves(ADCTEST_AXI_INDEX_C),
         axilWriteMaster => mAxilWriteMasters(ADCTEST_AXI_INDEX_C),
         axilWriteSlave  => mAxilWriteSlaves(ADCTEST_AXI_INDEX_C));

   GEN_ADC :
   for i in 2 downto 0 generate
      U_ADC : entity work.AxiDualPortRam
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
            BRAM_EN_G        => true,
            REG_EN_G         => true,
            ADDR_WIDTH_G     => RAM_WIDTH_C,
            DATA_WIDTH_G     => 32)
         port map (
            axiClk         => clk,
            axiRst         => rst,
            axiReadMaster  => mAxilReadMasters(ADC0_RD_AXI_INDEX_C+i),
            axiReadSlave   => mAxilReadSlaves(ADC0_RD_AXI_INDEX_C+i),
            axiWriteMaster => mAxilWriteMasters(ADC0_RD_AXI_INDEX_C+i),
            axiWriteSlave  => mAxilWriteSlaves(ADC0_RD_AXI_INDEX_C+i));
   end generate GEN_ADC;

   U_AdcConf : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         ADDR_WIDTH_G     => RAM_WIDTH_C,
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => mAxilReadMasters(ADC_CFG_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(ADC_CFG_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(ADC_CFG_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(ADC_CFG_AXI_INDEX_C));

   U_LogMem : entity work.AxiDualPortRam
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         BRAM_EN_G        => true,
         REG_EN_G         => true,
         ADDR_WIDTH_G     => 10,        -- only 10-bits in orginal code
         DATA_WIDTH_G     => 32)
      port map (
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => mAxilReadMasters(MEM_LOG_AXI_INDEX_C),
         axiReadSlave   => mAxilReadSlaves(MEM_LOG_AXI_INDEX_C),
         axiWriteMaster => mAxilWriteMasters(MEM_LOG_AXI_INDEX_C),
         axiWriteSlave  => mAxilWriteSlaves(MEM_LOG_AXI_INDEX_C));

   U_StartupInit : entity work.SlvArraytoAxiLite
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => true,
         SIZE_G       => SIZE_C,
         ADDR_G       => ADDR_C)
      port map (
         -- SLV Array Interface
         clk             => clk,
         rst             => rst,
         input           => DATA_C,
         -- AXI-Lite Master Interface
         axilClk         => clk,
         axilRst         => rst,
         axilWriteMaster => sAxilWriteMasters(1),
         axilWriteSlave  => sAxilWriteSlaves(1),
         axilReadMaster  => sAxilReadMasters(1),
         axilReadSlave   => sAxilReadSlaves(1));

end mapping;
