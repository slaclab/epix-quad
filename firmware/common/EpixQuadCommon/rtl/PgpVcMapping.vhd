-------------------------------------------------------------------------------
-- File       : PgpVcMapping.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.AxiLitePkg.all;
use surf.Pgp2bPkg.all;
use surf.SsiCmdMasterPkg.all;

entity PgpVcMapping is
   generic (
      TPD_G                : time                  := 1 ns;
      SIMULATION_G         : boolean               := false;
      AXI_STREAM_CONFIG_G  : AxiStreamConfigType   := SSI_PGP2B_CONFIG_C
   );
   port (
      -- PGP Clock and Reset
      pgpClk          : in  sl;
      pgpRst          : in  sl;
      -- PGP AXIS interface
      txMasters       : out AxiStreamMasterArray(3 downto 0);
      txSlaves        : in  AxiStreamSlaveArray(3 downto 0);
      rxMasters       : in  AxiStreamMasterArray(3 downto 0);
      rxCtrl          : out AxiStreamCtrlArray(3 downto 0);
      -- for simulation only
      rxSlaves        : out AxiStreamSlaveArray(3 downto 0);
      -- System Clock and Reset
      sysClk          : in  sl;
      sysRst          : in  sl;
      -- Image Data Interface
      dataTxMaster    : in  AxiStreamMasterType;
      dataTxSlave     : out AxiStreamSlaveType;
      -- Scope Data Interface
      scopeTxMaster   : in  AxiStreamMasterType;
      scopeTxSlave    : out AxiStreamSlaveType;
      -- Monitor Data Interface
      monitorTxMaster : in  AxiStreamMasterType;
      monitorTxSlave  : out AxiStreamSlaveType;
      monitorEn       : out sl;
      -- AXI-Lite Interface
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      -- Software trigger interface
      swTrigOut       : out sl
   );
end PgpVcMapping;

architecture mapping of PgpVcMapping is

   signal ssiCmdVc0  : SsiCmdMasterType;
   signal ssiCmdVc3  : SsiCmdMasterType;
   signal monEn      : sl;
   signal monDis     : sl;
   
begin
   
   -- VC1 RX/TX, SRPv3 Register Module    
   U_VC1 : entity surf.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => SIMULATION_G,
         GEN_SYNC_FIFO_G     => false,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk         => pgpClk,
         sAxisRst         => pgpRst,
         sAxisMaster      => rxMasters(1),
         sAxisCtrl        => rxCtrl(1),
         sAxisSlave       => rxSlaves(1),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk         => pgpClk,
         mAxisRst         => pgpRst,
         mAxisMaster      => txMasters(1),
         mAxisSlave       => txSlaves(1),
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => sysClk,
         axilRst          => sysRst,
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave);

   -- VC0 TX, Image Data
   U_VC0_TX : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(8),
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => dataTxMaster,
         sAxisSlave  => dataTxSlave,
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => txMasters(0),
         mAxisSlave  => txSlaves(0));


   -- VC0 RX, Command processor
   U_VC0_RX : entity surf.SsiCmdMaster
      generic map (
         SLAVE_READY_EN_G    => SIMULATION_G,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Streaming Data Interface
         axisClk     => pgpClk,
         axisRst     => pgpRst,
         sAxisMaster => rxMasters(0),
         sAxisSlave  => rxSlaves(0),
         sAxisCtrl   => rxCtrl(0),
         -- Command signals
         cmdClk      => sysClk,
         cmdRst      => sysRst,
         cmdMaster   => ssiCmdVc0
         );
   -- Command opCode x00 - SW trigger
   U_TrigPulser : entity surf.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmdVc0,
         --addressed cmdOpCode
         opCode      => x"00",
         -- output pulse to sync module
         syncPulse   => swTrigOut,
         -- Local clock and reset
         locClk      => sysClk,
         locRst      => sysRst);
   
   
   -- VC2 TX, Scope Data
   rxCtrl(2)   <= AXI_STREAM_CTRL_UNUSED_C;
   rxSlaves(2) <= AXI_STREAM_SLAVE_INIT_C;
   U_VC2 : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => scopeTxMaster,
         sAxisSlave  => scopeTxSlave,
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => txMasters(2),
         mAxisSlave  => txSlaves(2));

   -- VC3 TX, Monitor Data
   U_VC3 : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
      port map (
         -- Slave Port
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => monitorTxMaster,
         sAxisSlave  => monitorTxSlave,
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpRst,
         mAxisMaster => txMasters(3),
         mAxisSlave  => txSlaves(3));
   
   -- VC3 RX, Command processor
   U_VC3_RX : entity surf.SsiCmdMaster
      generic map (
         SLAVE_READY_EN_G    => SIMULATION_G,
         AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_G
      )
      port map (
         -- Streaming Data Interface
         axisClk     => pgpClk,
         axisRst     => pgpRst,
         sAxisMaster => rxMasters(3),
         sAxisSlave  => rxSlaves(3),
         sAxisCtrl   => rxCtrl(3),
         -- Command signals
         cmdClk      => sysClk,
         cmdRst      => sysRst,
         cmdMaster   => ssiCmdVc3
         );
   -- Command opCode x00 - Disable Monitor Stream
   U_MonDisPulser : entity surf.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmdVc3,
         --addressed cmdOpCode
         opCode      => x"00",
         -- output pulse to sync module
         syncPulse   => monDis,
         -- Local clock and reset
         locClk      => sysClk,
         locRst      => sysRst);
   
   -- Command opCode x01 - Enable Monitor Stream
   U_MonEnPulser : entity surf.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmdVc3,
         --addressed cmdOpCode
         opCode      => x"01",
         -- output pulse to sync module
         syncPulse   => monEn,
         -- Local clock and reset
         locClk      => sysClk,
         locRst      => sysRst);
   
   process (sysClk) 
   begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            monitorEn <= '0';
         else
            if monEn = '1' then
               monitorEn <= '1';
            elsif monDis = '1' then
               monitorEn <= '0';
            end if;
         end if;
      end if;
   end process;

end mapping;
