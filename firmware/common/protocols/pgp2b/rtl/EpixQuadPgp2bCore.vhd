-------------------------------------------------------------------------------
-- File       : EpixQuadPgp2bCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: EPIX EpixQuadPgp2bCore Target's Top Level
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadPgp2bCore is
   generic (
      TPD_G             : time            := 1 ns;
      SIMULATION_G      : boolean         := false;
      SIM_SPEEDUP_G     : boolean         := false);
   port (
      -- Clock and Reset
      sysClk            : out sl;
      sysRst            : out sl;
      -- Image Data Streaming Interface
      dataTxMaster      : in  AxiStreamMasterType;
      dataTxSlave       : out AxiStreamSlaveType;
      -- Scope Data Interface
      scopeTxMaster     : in  AxiStreamMasterType;
      scopeTxSlave      : out AxiStreamSlaveType;
      -- Monitor Data Interface
      monitorTxMaster   : in  AxiStreamMasterType;
      monitorTxSlave    : out AxiStreamSlaveType;
      monitorEn         : out sl;
      -- AXI-Lite Register Interface
      mAxilReadMaster   : out AxiLiteReadMasterType;
      mAxilReadSlave    : in  AxiLiteReadSlaveType;
      mAxilWriteMaster  : out AxiLiteWriteMasterType;
      mAxilWriteSlave   : in  AxiLiteWriteSlaveType;
      -- Debug AXI-Lite Interface
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      -- Software trigger interface
      swTrigOut         : out sl;
      -- Fiber trigger interface
      opCode            : out slv(7 downto 0);
      opCodeEn          : out sl;
      -- PGP Ports
      pgpClkP           : in  sl;
      pgpClkN           : in  sl;
      pgpRxP            : in  sl;
      pgpRxN            : in  sl;
      pgpTxP            : out sl;
      pgpTxN            : out sl);
end EpixQuadPgp2bCore;

architecture top_level of EpixQuadPgp2bCore is

   signal txMasters : AxiStreamMasterArray(3 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal rxMasters : AxiStreamMasterArray(3 downto 0);
   signal rxCtrl    : AxiStreamCtrlArray(3 downto 0);
   -- for simulation only
   signal rxSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal pgpTxIn  : Pgp2bTxInType;
   signal pgpTxOut : Pgp2bTxOutType;
   signal pgpRxIn  : Pgp2bRxInType;
   signal pgpRxOut : Pgp2bRxOutType;

   signal pgpRefClk     : sl;
   signal pgpRefClkDiv2 : sl;
   signal fabClk        : sl;
   signal fabRst        : sl;
   signal pgpClk        : sl;
   signal pgpRst        : sl;
   signal pgpReset      : sl;
   signal iSysClk       : sl;
   signal iSysRst       : sl;
   
   signal iOpCode       : slv(7 downto 0);
   signal iOpCodeEn     : sl;

begin
   
   U_BUFG_GT : BUFG_GT
      port map (
         I       => pgpRefClkDiv2,
         CE      => '1',
         CLR     => '0',
         CEMASK  => '1',
         CLRMASK => '1',
         DIV     => "000",              -- Divide by 1
         O       => fabClk);            -- 156.25MHz (Divide by 1)

   U_PwrUpRst : entity surf.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIM_SPEEDUP_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => fabClk,
         rstOut => fabRst);

   -- clkOut(0) - 156.25 MHz
   U_PLL0 : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => true,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- MMCM attributes
         BANDWIDTH_G       => "OPTIMIZED",
         CLKIN_PERIOD_G    => 6.4,
         DIVCLK_DIVIDE_G   => 1,
         CLKFBOUT_MULT_G   => 4,
         CLKOUT0_DIVIDE_G  => 4)
      port map(
         -- Clock Input
         clkIn     => fabClk,
         rstIn     => fabRst,
         -- Clock Outputs
         clkOut(0) => pgpClk,
         -- Reset Outputs
         rstOut(0) => pgpReset);
   
   -- clkOut(0) - 100.00 MHz
   U_PLL1 : entity surf.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "MMCM",
         INPUT_BUFG_G      => true,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- MMCM attributes
         BANDWIDTH_G       => "OPTIMIZED",
         CLKIN_PERIOD_G    => 6.4,
         DIVCLK_DIVIDE_G   => 5,
         CLKFBOUT_MULT_G   => 32,
         CLKOUT0_DIVIDE_G  => 10)
      port map(
         -- Clock Input
         clkIn     => fabClk,
         rstIn     => fabRst,
         -- Clock Outputs
         clkOut(0) => iSysClk,
         -- Reset Outputs
         rstOut(0) => iSysRst);
   
   
   sysClk <= iSysClk;
   sysRst <= iSysRst;

   U_RstPipeline : entity surf.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => pgpClk,
         rstIn  => pgpReset,
         rstOut => pgpRst);
   
   G_PGP : if SIMULATION_G = false generate
      
      U_IBUFDS_GTE3 : IBUFDS_GTE3
         generic map (
            REFCLK_EN_TX_PATH  => '0',
            REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
            REFCLK_ICNTL_RX    => "00")
         port map (
            I     => pgpClkP,
            IB    => pgpClkN,
            CEB   => '0',
            ODIV2 => pgpRefClkDiv2,        -- 156.25MHz (Divide by 1)
            O     => pgpRefClk);           -- 156.25MHz
      
      U_PGP : entity surf.Pgp2bGthUltra
         generic map (
            TPD_G             => TPD_G,
            PAYLOAD_CNT_TOP_G => 7,
            VC_INTERLEAVE_G   => 0,
            NUM_VC_EN_G       => 4
         )
         port map (
            stableClk         => pgpClk,
            stableRst         => pgpRst,
            gtRefClk          => pgpRefClk,
            pgpGtTxP          => pgpTxP,
            pgpGtTxN          => pgpTxN,
            pgpGtRxP          => pgpRxP,
            pgpGtRxN          => pgpRxN,
            pgpTxReset        => pgpRst,
            pgpTxResetDone    => open,
            pgpTxOutClk       => open,
            pgpTxClk          => pgpClk,
            pgpTxMmcmLocked   => '1',
            pgpRxReset        => pgpRst,
            pgpRxResetDone    => open,
            pgpRxOutClk       => open,
            pgpRxClk          => pgpClk,
            pgpRxMmcmLocked   => '1',
            pgpTxIn           => pgpTxIn,
            pgpTxOut          => pgpTxOut,
            pgpRxIn           => pgpRxIn,
            pgpRxOut          => pgpRxOut,
            pgpTxMasters      => txMasters,
            pgpTxSlaves       => txSlaves,
            pgpRxMasters      => rxMasters,
            pgpRxMasterMuxed  => open,
            pgpRxCtrl         => rxCtrl,
            axilClk           => '0',
            axilRst           => '0',
            axilReadMaster    => AXI_LITE_READ_MASTER_INIT_C,
            axilReadSlave     => open,
            axilWriteMaster   => AXI_LITE_WRITE_MASTER_INIT_C,
            axilWriteSlave    => open
         );
   end generate G_PGP;
   
   G_PGP_SIM : if SIMULATION_G = true generate
      U_PGP_SIM : entity surf.RoguePgp2bSim
         generic map (
            TPD_G      => TPD_G,
            PORT_NUM_G => 8000,
            NUM_VC_G   => 4
         )
         port map (
            -- PGP Clock and Reset
            pgpClk            => fabClk,
            pgpClkRst         => fabRst,
            -- Non VC Rx Signals
            pgpRxIn           => PGP2B_RX_IN_INIT_C,
            pgpRxOut          => pgpRxOut,
            -- Non VC Tx Signals
            pgpTxIn           => PGP2B_TX_IN_INIT_C,
            pgpTxOut          => open,
            -- Frame Transmit Interface
            pgpTxMasters    => txMasters,
            pgpTxSlaves     => txSlaves,
            -- Frame Receive Interface
            pgpRxMasters    => rxMasters,
            pgpRxSlaves     => rxSlaves
         );
      pgpRefClk <= '0';
   end generate G_PGP_SIM;
   
   
   U_VcMapping : entity work.PgpVcMapping
      generic map (
         TPD_G                => TPD_G,
         SIMULATION_G         => SIMULATION_G,
         AXI_STREAM_CONFIG_G  => SSI_PGP2B_CONFIG_C
      )
      port map (
         -- PGP Clock and Reset
         pgpClk          => pgpClk,
         pgpRst          => pgpRst,
         -- AXIS interface
         txMasters       => txMasters,
         txSlaves        => txSlaves,
         rxMasters       => rxMasters,
         rxCtrl          => rxCtrl,
         -- for simulation only
         rxSlaves        => rxSlaves,
         -- System Clock and Reset
         sysClk          => iSysClk,
         sysRst          => iSysRst,
         -- Data Interface
         dataTxMaster    => dataTxMaster,
         dataTxSlave     => dataTxSlave,
         -- Scope Data Interface
         scopeTxMaster   => scopeTxMaster,
         scopeTxSlave    => scopeTxSlave,
         -- Monitor Data Interface
         monitorTxMaster => monitorTxMaster,
         monitorTxSlave  => monitorTxSlave,
         monitorEn       => monitorEn,
         -- AXI-Lite Interface
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave,
         -- Software trigger interface
         swTrigOut       => swTrigOut
      );

   U_PgpMon : entity surf.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => true,
         COMMON_RX_CLK_G    => true,
         WRITE_EN_G         => false,
         AXI_CLK_FREQ_G     => 100.00E+6,
         STATUS_CNT_WIDTH_G => 32,
         ERROR_CNT_WIDTH_G  => 16)
      port map (
         -- TX PGP Interface (pgpTxClk)
         pgpTxClk        => pgpClk,
         pgpTxClkRst     => pgpRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         -- RX PGP Interface (pgpRxClk)
         pgpRxClk        => pgpClk,
         pgpRxClkRst     => pgpRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => iSysClk,
         axilRst         => iSysRst,
         axilReadMaster  => sAxilReadMaster,
         axilReadSlave   => sAxilReadSlave,
         axilWriteMaster => sAxilWriteMaster,
         axilWriteSlave  => sAxilWriteSlave);
   
   -----------------------------------------
   -- PGP Sideband Triggers:
   -- Any op code is a trigger, actual op
   -- code is the fiducial.
   -----------------------------------------
   U_PgpSideBandTrigger : entity surf.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 8
      )
      port map (
         rst    => pgpRst,
         wr_clk => pgpClk,
         wr_en  => pgpRxOut.opCodeEn,
         din    => pgpRxOut.opCode,
         rd_clk => iSysClk,
         rd_en  => '1',
         valid  => iOpCodeEn,
         dout   => iOpCode
      );
   
   -- register opCode
   process(iSysClk) begin
      if rising_edge(iSysClk) then
         if iSysRst = '1' then
            opCode <= (others => '0') after TPD_G;
         elsif iOpCodeEn = '1' then
            opCode <= iOpCode after TPD_G;
         end if;
      end if;
   end process;
   opCodeEn <= iOpCodeEn;

end top_level;
