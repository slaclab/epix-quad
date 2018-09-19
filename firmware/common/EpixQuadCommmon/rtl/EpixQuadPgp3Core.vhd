-------------------------------------------------------------------------------
-- File       : EpixQuadPgp3Core.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-02-04
-- Last update: 2018-10-05
-------------------------------------------------------------------------------
-- Description: EPIX EpixQuadPgp3Core Target's Top Level
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Pgp3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadPgp3Core is
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
      -- PGP Ports
      pgpClkP           : in  sl;
      pgpClkN           : in  sl;
      pgpRxP            : in  sl;
      pgpRxN            : in  sl;
      pgpTxP            : out sl;
      pgpTxN            : out sl);
end EpixQuadPgp3Core;

architecture top_level of EpixQuadPgp3Core is

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

   U_PwrUpRst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIM_SPEEDUP_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => fabClk,
         rstOut => fabRst);
   
   -- clkOut(0) - 100.00 MHz
   U_PLL1 : entity work.ClockManagerUltraScale
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

   U_RstPipeline : entity work.RstPipeline
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
      
      U_QPLL : entity work.Pgp3GthUsQpll
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
   
      U_PGP : entity work.Pgp3GthUs
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
            pgpRxIn           => PGP3_RX_IN_INIT_C,
            pgpRxOut          => open,
            -- Non VC Tx Signals
            pgpTxIn           => PGP3_TX_IN_INIT_C,
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
      G_DESTS : for j in 3 downto 0 generate
         U_PGP_SIM : entity work.RogueStreamSimWrap
            generic map (
               TPD_G               => TPD_G,
               DEST_ID_G           => j,
               USER_ID_G           => 1,
               COMMON_MASTER_CLK_G => true,
               COMMON_SLAVE_CLK_G  => true,
               AXIS_CONFIG_G       => PGP3_AXIS_CONFIG_C
            )
            port map (
               clk         => pgpClk,           
               rst         => pgpRst,           
               sAxisClk    => pgpClk,           
               sAxisRst    => pgpRst,           
               sAxisMaster => txMasters(j),
               sAxisSlave  => txSlaves(j), 
               mAxisClk    => pgpClk,           
               mAxisRst    => pgpRst,           
               mAxisMaster => rxMasters(j),
               mAxisSlave  => rxSlaves(j)
            );  
      end generate G_DESTS;
         
      -- clkOut(0) - 156.25 MHz
      U_PLL0 : entity work.ClockManagerUltraScale
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
            
   end generate G_PGP_SIM;
   
   
   U_VcMapping : entity work.PgpVcMapping
      generic map (
         TPD_G          => TPD_G,
         SIMULATION_G   => SIMULATION_G
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

end top_level;
