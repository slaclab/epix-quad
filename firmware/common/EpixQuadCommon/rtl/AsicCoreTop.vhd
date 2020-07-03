-------------------------------------------------------------------------------
-- File       : AsicCoreTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: EPIX Quad Target's Top Level
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
use surf.AxiPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AsicCoreTop is
   generic (
      TPD_G                : time             := 1 ns;
      AXI_CLK_FREQ_G       : real             := 100.00E+6;
      BANK_COLS_G          : natural          := 48;
      BANK_ROWS_G          : natural          := 178;
      AXI_BASE_ADDR_G      : slv(31 downto 0) := (others => '0');
      SIM_SPEEDUP_G        : boolean          := false
   );
   port (
      -- Clock and Reset
      sysClk               : in    sl;
      sysRst               : in    sl;
      -- AXI-Lite Register Interface (sysClk domain)
      mAxilReadMaster      : in    AxiLiteReadMasterType;
      mAxilReadSlave       : out   AxiLiteReadSlaveType;
      mAxilWriteMaster     : in    AxiLiteWriteMasterType;
      mAxilWriteSlave      : out   AxiLiteWriteSlaveType;
      -- AXI DDR Buffer Interface (sysClk domain)
      axiWriteMasters      : out   AxiWriteMasterArray(3 downto 0);
      axiWriteSlaves       : in    AxiWriteSlaveArray(3 downto 0);
      axiReadMaster        : out   AxiReadMasterType;
      axiReadSlave         : in    AxiReadSlaveType;
      buffersRdy           : in    sl;
      -- ADC stream input
      adcStream            : in    AxiStreamMasterArray(79 downto 0);
      -- Opcode to insert into frame
      opCode               : in    slv(7 downto 0);
      -- Monitor data for the image stream
      monData              : in    Slv16Array(37 downto 0);
      -- ASIC ACQ signals
      acqStart             : in    sl;
      asicAcq              : out   sl;
      asicR0               : out   sl;
      asicSync             : out   sl;
      asicPpmat            : out   sl;
      asicRoClk            : out   sl;
      asicDout             : in    slv(15 downto 0);
      -- ADC Clock Output
      adcClk               : out   sl;
      -- Image Data Stream
      dataTxMaster         : out   AxiStreamMasterType;
      dataTxSlave          : in    AxiStreamSlaveType;
      -- Scope Data Stream
      scopeTxMaster        : out   AxiStreamMasterType;
      scopeTxSlave         : in    AxiStreamSlaveType
   );
end AsicCoreTop;

architecture rtl of AsicCoreTop is
   
   constant LINE_REVERSE_C       : slv(3 downto 0) := "1010";
   
   constant NUM_AXI_MASTERS_C    : natural := 5;

   constant ASIC_ACQ_INDEX_C     : natural := 0;
   constant ASIC_RDOUT_INDEX_C   : natural := 1;
   constant SCOPE_INDEX_C        : natural := 2;
   constant AXIS_MON_INDEX_C     : natural := 3;
   constant AXIS_PRBS_INDEX_C    : natural := 4;

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   signal acqBusy          : sl;
   signal acqCount         : slv(31 downto 0);
   signal acqSmplEn        : sl;
   signal readDone         : sl;
   
   signal iAsicAcq         : sl;
   signal iAsicR0          : sl;
   signal iAsicSync        : sl;
   signal iAsicPpmat       : sl;
   signal iAsicRoClk       : sl;
   
   signal testStream       : AxiStreamMasterArray(63 downto 0);
   
   signal roClkTail        : slv(7 downto 0);
   signal asicDoutTest     : slv(15 downto 0);
   
   signal iDataTxMaster    : AxiStreamMasterType;
   signal axisMasterPRBS   : AxiStreamMasterType;
   signal axisMasterASIC   : AxiStreamMasterType;
   signal axisSlavePRBS    : AxiStreamSlaveType;
   signal axisSlaveASIC    : AxiStreamSlaveType;
   
   -- ADC signals
   signal adcValid         : slv(31 downto 0);
   signal adcData          : Slv16Array(31 downto 0);
   
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(8);
   
begin
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C
      )
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => mAxilWriteMaster,
         sAxiWriteSlaves(0)  => mAxilWriteSlave,
         sAxiReadMasters(0)  => mAxilReadMaster,
         sAxiReadSlaves(0)   => mAxilReadSlave,

         mAxiWriteMasters => axilWriteMasters,
         mAxiWriteSlaves  => axilWriteSlaves,
         mAxiReadMasters  => axilReadMasters,
         mAxiReadSlaves   => axilReadSlaves
      );
   
   ---------------------------------------------------------------
   -- Acquisition core
   --------------------- ------------------------------------------
   U_AcqCore : entity work.AcqCore
   generic map (
      TPD_G             => TPD_G,
      BANK_COLS_G       => BANK_COLS_G,
      BANK_ROWS_G       => BANK_ROWS_G,
      SIM_SPEEDUP_G     => SIM_SPEEDUP_G
   )
   port map (
      -- System Clock (100 MHz)
      sysClk            => sysClk,
      sysRst            => sysRst,
      -- AXI lite slave port for register access      
      sAxilWriteMaster  => axilWriteMasters(ASIC_ACQ_INDEX_C),
      sAxilWriteSlave   => axilWriteSlaves(ASIC_ACQ_INDEX_C),
      sAxilReadMaster   => axilReadMasters(ASIC_ACQ_INDEX_C),
      sAxilReadSlave    => axilReadSlaves(ASIC_ACQ_INDEX_C),
      -- Run control
      acqStart          => acqStart,
      acqBusy           => acqBusy,
      acqCount          => acqCount,
      acqSmplEn         => acqSmplEn,
      readDone          => readDone,
      roClkTail         => roClkTail,
      -- ASIC Control Ports
      asicAcq           => iAsicAcq,
      asicR0            => iAsicR0,
      asicSync          => iAsicSync,
      asicPpmat         => iAsicPpmat,
      asicRoClk         => iAsicRoClk,
      -- ADC Clock Output
      adcClk            => adcClk
   );
   asicAcq     <=  iAsicAcq;
   asicR0      <=  iAsicR0;
   asicSync    <=  iAsicSync;
   asicPpmat   <=  iAsicPpmat;
   asicRoClk   <=  iAsicRoClk;
   
   ---------------------------------------------------------------
   -- Readout core 
   --------------------- ------------------------------------------
   U_RdoutCore : entity work.RdoutCoreTop
   generic map (
      TPD_G             => TPD_G,
      BANK_COLS_G       => BANK_COLS_G,
      BANK_ROWS_G       => BANK_ROWS_G,
      LINE_REVERSE_G    => LINE_REVERSE_C
   )
   port map (
      -- ADC interface
      sysClk               => sysClk,
      sysRst               => sysRst,
      -- AXI-Lite Interface for local registers 
      sAxilReadMaster      => axilReadMasters(ASIC_RDOUT_INDEX_C),
      sAxilReadSlave       => axilReadSlaves(ASIC_RDOUT_INDEX_C),
      sAxilWriteMaster     => axilWriteMasters(ASIC_RDOUT_INDEX_C),
      sAxilWriteSlave      => axilWriteSlaves(ASIC_RDOUT_INDEX_C),
      -- AXI DDR Buffer Interface (sysClk domain)
      axiWriteMasters      => axiWriteMasters,
      axiWriteSlaves       => axiWriteSlaves,
      axiReadMaster        => axiReadMaster,
      axiReadSlave         => axiReadSlave,
      buffersRdy           => buffersRdy,
      -- Opcode to insert into frame
      opCode               => opCode,
      -- Run control
      acqBusy              => acqBusy,
      acqCount             => acqCount,
      acqSmplEn            => acqSmplEn,
      readDone             => readDone,
      -- Monitor data for the image stream
      monData              => monData,
      -- ADC stream input
      adcStream            => adcStream(63 downto 0),
      tpsStream            => adcStream(79 downto 64),
      -- Test stream input
      testStream           => testStream,
      -- ASIC digital data signals to/from deserializer
      asicDout             => asicDout,
      asicDoutTest         => asicDoutTest,
      asicRoClk            => iAsicRoClk,
      roClkTail            => roClkTail,
      -- Frame stream output (axisClk domain)
      axisClk              => sysClk,
      axisRst              => sysRst,
      axisMaster           => axisMasterASIC,
      axisSlave            => axisSlaveASIC 
   );
   
   
   ---------------------------------------------------------------
   -- PseudoScope Core
   --------------------- ------------------------------------------
   U_PseudoScopeCore : entity work.PseudoScope2Axi
   generic map (
      TPD_G                      => TPD_G,
      INPUTS_G                   => 80,
      MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)
   )
   port map ( 
      -- system clock
      clk               => sysClk,
      rst               => sysRst,
      -- input data
      dataIn            => adcData,
      dataValid         => adcValid,
      -- arm signal
      arm               => acqStart,
      -- input triggers
      triggerIn(0)      => acqStart,
      triggerIn(1)      => iAsicAcq,
      triggerIn(2)      => iAsicR0,
      triggerIn(3)      => iAsicSync,
      triggerIn(4)      => iAsicPpmat,
      triggerIn(5)      => iAsicRoClk,
      triggerIn(12 downto 6) => "0000000",
      -- AXI stream output
      axisClk           => sysClk,
      axisRst           => sysRst,
      axisMaster        => scopeTxMaster,
      axisSlave         => scopeTxSlave,
      -- AXI lite for register access
      axilClk           => sysClk,
      axilRst           => sysRst,
      sAxilWriteMaster  => axilWriteMasters(SCOPE_INDEX_C),
      sAxilWriteSlave   => axilWriteSlaves(SCOPE_INDEX_C),
      sAxilReadMaster   => axilReadMasters(SCOPE_INDEX_C),
      sAxilReadSlave    => axilReadSlaves(SCOPE_INDEX_C)
   );
   
   GenAdcTps : for i in 0 to 15 generate 
      adcData(i)  <= adcStream(64+i).tData(15 downto 0);
      adcValid(i) <= adcStream(64+i).tValid;
   end generate;
   GenAdcBanks : for i in 0 to 15 generate 
      adcData(16+i)  <= adcStream(i*8).tData(15 downto 0);
      adcValid(16+i) <= adcStream(i*8).tValid;
   end generate;
   
   ---------------------------------------------------------------
   -- ASIC Analog Test Data Generator
   --------------------- ------------------------------------------
   G_AsicEmuAout : for i in 0 to 63 generate 
      
      U_AsicEmuAout : entity work.AsicEmuAout
         generic map (
            TPD_G       => TPD_G,
            INDEX_G     => i
         )
         port map (
            -- System Clock (100 MHz)
            sysClk      => sysClk,
            sysRst      => sysRst,
            -- Run control
            acqBusy     => acqBusy,
            asicRoClk   => iAsicRoClk,
            -- Test data output
            testStream  => testStream(i)
         );
      
   end generate;
   
   ---------------------------------------------------------------
   -- ASIC Digital Test Data Generator
   --------------------- ------------------------------------------
   G_AsicEmuDout : for i in 0 to 15 generate 
      constant BANK_ROW_PAT_C : Slv64Array(15 downto 0) := (
         0  => toSlv( 1, 64), 1  => toSlv( 2, 64), 2  => toSlv( 3, 64), 3  => toSlv( 4, 64),
         4  => toSlv( 5, 64), 5  => toSlv( 6, 64), 6  => toSlv( 7, 64), 7  => toSlv( 8, 64),
         8  => toSlv( 9, 64), 9  => toSlv(11, 64), 10 => toSlv(11, 64), 11 => toSlv(12, 64),
         12 => toSlv(13, 64), 13 => toSlv(14, 64), 14 => toSlv(15, 64), 15 => toSlv(16, 64)
      );
   begin
      
      U_AsicEmuDout : entity work.AsicEmuDout
      generic map (
         TPD_G             => TPD_G,
         BANK_COLS_G       => BANK_COLS_G,
         BANK_REVERSE_G    => '0',
         BANK_ROW_PAT_G    => (others=>x"0000000000000002")
      )
      port map (
         -- System Clock (100 MHz)
         sysClk            => sysClk,
         sysRst            => sysRst,
         -- Run control
         acqBusy           => acqBusy,
         asicRoClk         => iAsicRoClk,
         roClkTail         => roClkTail,
         -- Test data output
         asicDoutTest      => asicDoutTest(i)
      );
      
   end generate;
   
   ---------------------------------------------------------------
   -- ASIC Stream Monitor
   --------------------- ------------------------------------------
   U_AXIS_MON : entity surf.AxiStreamMonAxiL
      generic map(
         TPD_G             => TPD_G,
         COMMON_CLK_G      => true,
         AXIS_CLK_FREQ_G   => AXI_CLK_FREQ_G, -- Units of Hz
         AXIS_NUM_SLOTS_G  => 1,
         AXIS_CONFIG_G     => ssiAxiStreamConfig(8) -- 64-bits
      ) 
      port map(
         -- AXIS Stream Interface
         axisClk           => sysClk,
         axisRst           => sysRst,
         axisMasters(0)    => iDataTxMaster,
         axisSlaves(0)     => dataTxSlave,
         -- AXI lite slave port for register access
         axilClk           => sysClk,
         axilRst           => sysRst,
         sAxilReadMaster   => axilReadMasters(AXIS_MON_INDEX_C),
         sAxilReadSlave    => axilReadSlaves(AXIS_MON_INDEX_C),
         sAxilWriteMaster  => axilWriteMasters(AXIS_MON_INDEX_C),
         sAxilWriteSlave   => axilWriteSlaves(AXIS_MON_INDEX_C)
      );
   
   
   ---------------------------------------------------------------
   -- PRBS Tx generator
   --------------------- -----------------------------------------
   U_AXI_PRBS : entity surf.SsiPrbsTx 
   generic map(         
      TPD_G                      => TPD_G,
      MASTER_AXI_PIPE_STAGES_G   => 1,
      PRBS_SEED_SIZE_G           => 128,
      MASTER_AXI_STREAM_CONFIG_G => MASTER_AXI_CONFIG_C
   )
   port map(
      -- Master Port (mAxisClk)
      mAxisClk        => sysClk,
      mAxisRst        => sysRst,
      mAxisMaster     => axisMasterPRBS,
      mAxisSlave      => axisSlavePRBS,
      -- Trigger Signal (locClk domain)
      locClk          => sysClk,
      locRst          => sysRst,
      trig            => acqStart,
      packetLength    => x"FFFFFFFF",
      busy            => open,
      -- Optional: Axi-Lite Register Interface (locClk domain)
      axilReadMaster  => axilReadMasters(AXIS_PRBS_INDEX_C),
      axilReadSlave   => axilReadSlaves(AXIS_PRBS_INDEX_C),
      axilWriteMaster => axilWriteMasters(AXIS_PRBS_INDEX_C),
      axilWriteSlave  => axilWriteSlaves(AXIS_PRBS_INDEX_C)
   );
   
   U_STREAM_MUX : entity surf.AxiStreamMux 
      generic map(
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => 2,
         PIPE_STAGES_G        => 0,
         MODE_G               =>"ROUTED",
         TDEST_ROUTES_G       => (0=>x"01", 1=>x"00"),
         TDEST_LOW_G          => 0,
         ILEAVE_EN_G          => false,
         ILEAVE_ON_NOTVALID_G => false,
         ILEAVE_REARB_G       => 0
      )
      port map(
         axisClk           => sysClk,
         axisRst           => sysRst,
         sAxisMasters(0)   => axisMasterPRBS,
         sAxisMasters(1)   => axisMasterASIC,
         sAxisSlaves(0)    => axisSlavePRBS,
         sAxisSlaves(1)    => axisSlaveASIC,
         mAxisMaster       => iDataTxMaster,
         mAxisSlave        => dataTxSlave
      );
   
   dataTxMaster   <= iDataTxMaster;
   
   
end rtl;
