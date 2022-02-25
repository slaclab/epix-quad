-------------------------------------------------------------------------------
-- File       : EpixQuadPgp4Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: EPIX EpixQuadPgp4Core Target's Top Level
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
use surf.Pgp4Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadPgp4Core is
   generic (
      TPD_G             : time            := 1 ns;
      SIMULATION_G      : boolean         := false;
      SIM_SPEEDUP_G     : boolean         := false;
      RATE_G            : string          := "6.25Gbps");
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
end EpixQuadPgp4Core;

architecture top_level of EpixQuadPgp4Core is

   signal txMasters : AxiStreamMasterArray(3 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal rxMasters : AxiStreamMasterArray(3 downto 0);
   signal rxCtrl    : AxiStreamCtrlArray(3 downto 0);
   -- for simulation only
   signal rxSlaves  : AxiStreamSlaveArray(3 downto 0);

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

   signal pgpRxOut      : Pgp4RxOutType;

begin

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
         CLKFBOUT_MULT_F_G => 32.0,
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
      signal qpllLock   : Slv2Array(3 downto 0) := (others => "00");
      signal qpllClk    : Slv2Array(3 downto 0) := (others => "00");
      signal qpllRefclk : Slv2Array(3 downto 0) := (others => "00");
      signal qpllRst    : Slv2Array(3 downto 0) := (others => "00");
   begin

      U_QPLL : entity surf.Pgp3GthUsQpll
         generic map (
            TPD_G       => TPD_G,
            RATE_G      => RATE_G, -- "10.3125Gbps" or "6.25Gbps"
            EN_DRP_G    => true
         )
         port map (
            -- Stable Clock and Reset
            stableClk   => iSysClk,
            stableRst   => iSysRst,
            -- QPLL Clocking
            pgpRefClk   => pgpRefClk,
            qpllLock    => qpllLock,
            qpllClk     => qpllClk,
            qpllRefclk  => qpllRefclk,
            qpllRst     => qpllRst
         );

      U_PGP : entity surf.Pgp4GthUs
         generic map (
            TPD_G             => TPD_G,
            RATE_G            => RATE_G,
            NUM_VC_G          => 4,
            EN_DRP_G          => false,
            EN_PGP_MON_G      => true,
            AXIL_CLK_FREQ_G   => 100.0E+6
         )
         port map (
            -- Stable Clock and Reset
            stableClk         => iSysClk,
            stableRst         => iSysRst,
            -- QPLL Interface
            qpllLock          => qpllLock(0),
            qpllclk           => qpllClk(0),
            qpllrefclk        => qpllRefclk(0),
            qpllRst           => qpllRst(0),
            -- Gt Serial IO
            pgpGtTxP          => pgpTxP,
            pgpGtTxN          => pgpTxN,
            pgpGtRxP          => pgpRxP,
            pgpGtRxN          => pgpRxN,
            -- Clocking
            pgpClk            => pgpClk,
            pgpClkRst         => pgpReset,
            -- Non VC Rx Signals
            pgpRxIn           => PGP4_RX_IN_INIT_C,
            pgpRxOut          => pgpRxOut,
            -- Non VC Tx Signals
            pgpTxIn           => PGP4_TX_IN_INIT_C,
            pgpTxOut          => open,
            -- Frame Transmit Interface
            pgpTxMasters      => txMasters,
            pgpTxSlaves       => txSlaves,
            -- Frame Receive Interface
            pgpRxMasters      => rxMasters,
            pgpRxCtrl         => rxCtrl,
            -- AXI-Lite Register Interface (axilClk domain)
            axilClk           => iSysClk,
            axilRst           => iSysRst,
            axilReadMaster    => sAxilReadMaster,
            axilReadSlave     => sAxilReadSlave,
            axilWriteMaster   => sAxilWriteMaster,
            axilWriteSlave    => sAxilWriteSlave
         );

   end generate G_PGP;

   G_PGP_SIM : if SIMULATION_G = true generate

      U_Rogue : entity surf.RoguePgp4Sim
         generic map(
            TPD_G      => TPD_G,
            PORT_NUM_G => 8000,
            NUM_VC_G   => 4
         )
         port map(
            -- GT Ports
            pgpRefClk       => pgpRefClk,
            -- PGP Clock and Reset
            pgpClk          => pgpClk,
            pgpClkRst       => pgpRst,
            -- Non VC Rx Signals
            pgpRxIn           => PGP4_RX_IN_INIT_C,
            pgpRxOut          => pgpRxOut,
            -- Non VC Tx Signals
            pgpTxIn           => PGP4_TX_IN_INIT_C,
            pgpTxOut          => open,
            -- Frame Transmit Interface
            pgpTxMasters    => txMasters,
            pgpTxSlaves     => txSlaves,
            -- Frame Receive Interface
            pgpRxMasters    => rxMasters,
            pgpRxSlaves     => rxSlaves
         );

   end generate G_PGP_SIM;


   U_VcMapping : entity work.PgpVcMapping
      generic map (
         TPD_G                => TPD_G,
         SIMULATION_G         => SIMULATION_G,
         AXI_STREAM_CONFIG_G  => PGP4_AXIS_CONFIG_C
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
         din    => pgpRxOut.opCodeData(15 downto 8),
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
