-------------------------------------------------------------------------------
-- File       : EpixQuadCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: EpixQuadCore Target's Top Level
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

library unisim;
use unisim.vcomponents.all;

entity EpixQuadCore is
   generic (
      TPD_G             : time            := 1 ns;
      BUILD_INFO_G      : BuildInfoType;
      AXI_CLK_FREQ_G    : real            := 100.00E+6;
      SIMULATION_G      : boolean         := false;
      SIM_SPEEDUP_G     : boolean         := false;
      MIG_CORE_EN       : boolean         := true;
      COM_TYPE_G        : string          := "PGPv2b";
      RATE_G            : string          := "6.25Gbps");
   port (
      -- DRR Memory interface ports
      c0_sys_clk_p      : in    sl;
      c0_sys_clk_n      : in    sl;
      c0_ddr4_dq        : inout slv(15 downto 0);
      c0_ddr4_dqs_c     : inout slv(1 downto 0);
      c0_ddr4_dqs_t     : inout slv(1 downto 0);
      c0_ddr4_adr       : out   slv(16 downto 0);
      c0_ddr4_ba        : out   slv(1 downto 0);
      c0_ddr4_bg        : out   slv(0 to 0);
      c0_ddr4_reset_n   : out   sl;
      c0_ddr4_act_n     : out   sl;
      c0_ddr4_ck_t      : out   slv(0 to 0);
      c0_ddr4_ck_c      : out   slv(0 to 0);
      c0_ddr4_cke       : out   slv(0 to 0);
      c0_ddr4_cs_n      : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n  : inout slv(1 downto 0);
      c0_ddr4_odt       : out   slv(0 to 0);
      -- Power Supply Cntrl Ports
      asicAnaEn         : out   sl;
      asicDigEn         : out   sl;
      dcdcSync          : out   slv(10 downto 0);
      dcdcEn            : out   slv(3 downto 0);
      ddrVttEn          : out   sl;
      ddrVttPok         : in    sl;
      -- ASIC Carrier IDs
      asicDmSn          : inout slv(3 downto 0);
      -- FPGA temperature alert
      tempAlertL        : in  sl;
      -- I2C busses
      dacScl            : inout sl;
      dacSda            : inout sl;
      monScl            : inout sl;
      monSda            : inout sl;
      humScl            : inout sl;
      humSda            : inout sl;
      humRstN           : out   sl;
      humAlert          : in    sl;
      -- monitor ADC bus
      envSck            : out   sl;
      envCnv            : out   sl;
      envDin            : out   sl;
      envSdo            : in    sl;
      -- PGP Ports
      pgpClkP           : in    sl;
      pgpClkN           : in    sl;
      pgpRxP            : in    sl;
      pgpRxN            : in    sl;
      pgpTxP            : out   sl;
      pgpTxN            : out   sl;
      -- SYSMON Ports
      vPIn              : in    sl;
      vNIn              : in    sl;
      -- ASIC SACI signals
      asicSaciResp      : in    slv(3 downto 0);
      asicSaciClk       : out   slv(3 downto 0);
      asicSaciCmd       : out   slv(3 downto 0);
      asicSaciSelL      : out   slv(15 downto 0);
      -- ASIC ACQ signals
      asicAcq           : out   slv(3 downto 0);
      asicR0            : out   slv(3 downto 0);
      asicGr            : out   slv(3 downto 0);
      asicSync          : out   slv(3 downto 0);
      asicPpmat         : out   slv(3 downto 0);
      asicRoClkP        : out   slv(1 downto 0);
      asicRoClkN        : out   slv(1 downto 0);
      asicDoutP         : in    slv(15 downto 0);
      asicDoutN         : in    slv(15 downto 0);
      -- Fast ADC Signals
      adcClkP           : out   slv(4 downto 0);
      adcClkN           : out   slv(4 downto 0);
      adcFClkP          : in    slv(9 downto 0);
      adcFClkN          : in    slv(9 downto 0);
      adcDClkP          : in    slv(9 downto 0);
      adcDClkN          : in    slv(9 downto 0);
      adcChP            : in    Slv8Array(9 downto 0);
      adcChN            : in    Slv8Array(9 downto 0);
      -- Fast ADC Config SPI
      adcSclk           : out   slv(2 downto 0);
      adcSdio           : inout slv(2 downto 0);
      adcCsb            : out   slv(9 downto 0);
      -- debug outputs
      dbgOut            : out   slv(2 downto 0);
      spareIo2v5        : out   slv(4 downto 0);
      -- ttl trigger
      trigTtl           : in    sl
   );
end EpixQuadCore;

architecture rtl of EpixQuadCore is
   
   --constant BANK_COLS_C          : natural      := ite(SIM_SPEEDUP_G, 24, 48);
   --constant BANK_ROWS_C          : natural      := ite(SIM_SPEEDUP_G, 48, 178);
   constant BANK_COLS_C          : natural      := ite(SIM_SPEEDUP_G, 48, 48);
   constant BANK_ROWS_C          : natural      := ite(SIM_SPEEDUP_G, 178, 178);
   
   constant NUM_AXI_MASTERS_C    : natural := 9;

   constant SYS_INDEX_C          : natural := 0;
   constant ASIC_INDEX_C         : natural := 1;
   constant ADC_INDEX_C          : natural := 2;
   constant PGP_INDEX_C          : natural := 3;
   constant ASIC_SACI0_INDEX_C   : natural := 4;
   constant ASIC_SACI1_INDEX_C   : natural := 5;
   constant ASIC_SACI2_INDEX_C   : natural := 6;
   constant ASIC_SACI3_INDEX_C   : natural := 7;
   constant SACI_CORE_INDEX_C    : natural := 8;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"00000000", 31, 24);
   
   constant SACI_CLK_PERIOD_C    : real := ite(SIM_SPEEDUP_G, 80.0E-9, 1.00E-6);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal sysClk           : sl;
   signal sysRst           : sl;
   
   signal axilWriteMaster  : AxiLiteWriteMasterType;
   signal axilWriteSlave   : AxiLiteWriteSlaveType;
   signal axilReadSlave    : AxiLiteReadSlaveType;
   signal axilReadMaster   : AxiLiteReadMasterType;
   
   signal mbReadMaster     : AxiLiteReadMasterType;
   signal mbReadSlave      : AxiLiteReadSlaveType;
   signal mbWriteMaster    : AxiLiteWriteMasterType;
   signal mbWriteSlave     : AxiLiteWriteSlaveType;

   signal dataTxMaster     : AxiStreamMasterType;
   signal dataTxSlave      : AxiStreamSlaveType;
   signal scopeTxMaster    : AxiStreamMasterType;
   signal scopeTxSlave     : AxiStreamSlaveType;
   signal monitorTxMaster  : AxiStreamMasterType;
   signal monitorTxSlave   : AxiStreamSlaveType;
   signal monitorEn        : sl;

   signal axiWriteMasters    : AxiWriteMasterArray(3 downto 0);
   signal axiWriteSlaves     : AxiWriteSlaveArray(3 downto 0);
   signal axiReadMaster      : AxiReadMasterType;
   signal axiReadSlave       : AxiReadSlaveType;
   
   signal buffersRdy  : sl;
   signal swTrigger   : sl;
   
   signal iAsicDigEn  : sl;
   signal iAsicDigEnL : sl;
   
   -- ASIC ACQ signals
   signal iAsicAcq      : sl;
   signal iAsicR0       : sl;
   signal iAsicGr       : sl;
   signal iAsicSync     : sl;
   signal iAsicPpmat    : sl;
   signal iAsicRoClk    : sl;
   signal iAsicDout     : slv(15 downto 0);
   signal iAsicSaciClk  : slv(3 downto 0);
   signal iAsicSaciCmd  : slv(3 downto 0);
   signal iAsicSaciSelL : slv(15 downto 0);
   signal iAdcClk       : sl;
   
   signal adcStream     : AxiStreamMasterArray(79 downto 0);
   
   signal acqStart      : sl;
   signal adcClkRst     : slv(9 downto 0);
   signal adcReqStart   : sl;
   signal iAdcReqStart  : sl;
   signal iDcDcEn2      : sl;
   signal adcReqTest    : sl;
   
   signal opCode        : slv(7 downto 0);
   signal opCodeEn      : sl;
   
   signal iDcdcEn       : slv(3 downto 0);
   signal mbIrq         : slv(7 downto 0) := (others => '0'); 
   
   signal monData       : Slv16Array(37 downto 0);
   
   signal iDbgOut       : slv(2 downto 0);
   
   signal iAdcSclk      : slv(2 downto 0);
   signal iAdcCsb       : slv(9 downto 0);
   
begin

   --------------------------------------------------------
   -- Communication Module
   --------------------------------------------------------
   
   U_PGP : entity work.EpixQuadPgpTop
      generic map (
         TPD_G             => TPD_G,
         SIMULATION_G      => SIMULATION_G,
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
         COM_TYPE_G        => COM_TYPE_G,
         RATE_G            => RATE_G)
      port map (
         -- Clock and Reset
         sysClk            => sysClk,
         sysRst            => sysRst,
         -- Data Streaming Interface
         dataTxMaster      => dataTxMaster,
         dataTxSlave       => dataTxSlave,
         -- Scope Data Interface
         scopeTxMaster     => scopeTxMaster,
         scopeTxSlave      => scopeTxSlave,
         -- Monitor Data Interface
         monitorTxMaster   => monitorTxMaster,
         monitorTxSlave    => monitorTxSlave,
         monitorEn         => monitorEn,
         -- AXI-Lite Register Interface
         mAxilReadMaster   => axilReadMaster,
         mAxilReadSlave    => axilReadSlave,
         mAxilWriteMaster  => axilWriteMaster,
         mAxilWriteSlave   => axilWriteSlave,
         -- Debug AXI-Lite Interface         
         sAxilReadMaster   => axilReadMasters(PGP_INDEX_C),
         sAxilReadSlave    => axilReadSlaves(PGP_INDEX_C),
         sAxilWriteMaster  => axilWriteMasters(PGP_INDEX_C),
         sAxilWriteSlave   => axilWriteSlaves(PGP_INDEX_C),
         -- Software trigger interface
         swTrigOut         => swTrigger,
         -- Fiber trigger interface
         opCode            => opCode,
         opCodeEn          => opCodeEn,
         -- PGP Ports
         pgpClkP           => pgpClkP,
         pgpClkN           => pgpClkN,
         pgpRxP            => pgpRxP,
         pgpRxN            => pgpRxN,
         pgpTxP            => pgpTxP,
         pgpTxN            => pgpTxN
      );
   
   --------------------------------
   -- Microblaze Embedded Processor
   --------------------------------
   U_CPU : entity surf.MicroblazeBasicCoreWrapper
      generic map (
         TPD_G           => TPD_G,
         AXIL_ADDR_MSB_G => false)      -- false = [0x00000000:0xFFFFFFFF]
      port map (
         -- Master AXI-Lite Interface: [0x00000000:0xFFFFFFFF]
         mAxilWriteMaster => mbWriteMaster,
         mAxilWriteSlave  => mbWriteSlave,
         mAxilReadMaster  => mbReadMaster,
         mAxilReadSlave   => mbReadSlave,
         -- IRQ
         interrupt        => mbIrq,
         -- Clock and Reset
         clk              => sysClk,
         rst              => sysRst);
   
   
   U_AdcStartEdge : entity surf.SynchronizerEdge
      port map (
         clk         => sysClk,
         rst         => sysRst,
         dataIn      => adcReqStart,
         risingEdge  => iAdcReqStart);
         
   U_DcdcEnEdge : entity surf.SynchronizerEdge
      port map (
         clk         => sysClk,
         rst         => sysRst,
         dataIn      => iDcdcEn(2),
         risingEdge  => iDcDcEn2);
   mbIrq(0) <= iDcDcEn2 or iAdcReqStart;
   
   U_AdcTestEdge : entity surf.SynchronizerEdge
      port map (
         clk         => sysClk,
         rst         => sysRst,
         dataIn      => adcReqTest,
         risingEdge  => mbIrq(1));
   
   mbIrq(2) <= acqStart;
   
   --------------------------------------------------------
   -- AXI-Lite: Crossbar
   --------------------------------------------------------
   U_XBAR0 : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteMasters(1) => mbWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiWriteSlaves(1)  => mbWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadMasters(1)  => mbReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         sAxiReadSlaves(1)   => mbReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   --------------------------------------------------------
   -- System Core
   --------------------------------------------------------
   U_SystemCore : entity work.SystemCore
      generic map (
         TPD_G             => TPD_G,
         BUILD_INFO_G      => BUILD_INFO_G,
         AXI_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         SIMULATION_G      => SIMULATION_G,
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
         AXI_BASE_ADDR_G   => AXI_CONFIG_C(SYS_INDEX_C).baseAddr,
         MIG_CORE_EN       => MIG_CORE_EN
      )
      port map (
         -- Clock and Reset
         sysClk               => sysClk,
         sysRst               => sysRst,
         -- ADC ISERDESE reset
         adcClkRst            => adcClkRst,
         -- ADC Startup Signals
         adcReqStart          => adcReqStart,
         adcReqTest           => adcReqTest,
         -- I2C busses
         dacScl               => dacScl,
         dacSda               => dacSda,
         monScl               => monScl,
         monSda               => monSda,
         humScl               => humScl,
         humSda               => humSda,
         humRstN              => humRstN,
         humAlert             => humAlert,
         -- monitor ADC bus
         envSck               => envSck,
         envCnv               => envCnv,
         envDin               => envDin,
         envSdo               => envSdo,
         -- DRR Memory interface ports
         c0_sys_clk_p         => c0_sys_clk_p,
         c0_sys_clk_n         => c0_sys_clk_n,
         c0_ddr4_dq           => c0_ddr4_dq,
         c0_ddr4_dqs_c        => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t        => c0_ddr4_dqs_t,
         c0_ddr4_adr          => c0_ddr4_adr,
         c0_ddr4_ba           => c0_ddr4_ba,
         c0_ddr4_bg           => c0_ddr4_bg,
         c0_ddr4_reset_n      => c0_ddr4_reset_n,
         c0_ddr4_act_n        => c0_ddr4_act_n,
         c0_ddr4_ck_t         => c0_ddr4_ck_t,
         c0_ddr4_ck_c         => c0_ddr4_ck_c,
         c0_ddr4_cke          => c0_ddr4_cke,
         c0_ddr4_cs_n         => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n     => c0_ddr4_dm_dbi_n,
         c0_ddr4_odt          => c0_ddr4_odt,
         -- AXI DDR Buffer Interface (sysClk domain)
         axiWriteMasters      => axiWriteMasters,
         axiWriteSlaves       => axiWriteSlaves,
         axiReadMaster        => axiReadMaster,
         axiReadSlave         => axiReadSlave,
         buffersRdy           => buffersRdy,
         -- AXI-Lite Register Interface (sysClk domain)
         mAxilReadMaster      => axilReadMasters(SYS_INDEX_C),
         mAxilReadSlave       => axilReadSlaves(SYS_INDEX_C),
         mAxilWriteMaster     => axilWriteMasters(SYS_INDEX_C),
         mAxilWriteSlave      => axilWriteSlaves(SYS_INDEX_C),
         -- SYSMON Ports
         vPIn                 => vPIn,
         vNIn                 => vNIn,
         -- Power Supply Cntrl Ports
         asicAnaEn            => asicAnaEn,
         asicDigEn            => iAsicDigEn,
         dcdcSync             => dcdcSync,
         dcdcEn               => iDcdcEn,
         ddrVttEn             => ddrVttEn,
         ddrVttPok            => ddrVttPok,
         -- FPGA temperature alert
         tempAlertL           => tempAlertL,
         -- ASIC Carrier IDs
         asicDmSn             => asicDmSn,
         -- ASIC Global Reset
         asicGr               => iAsicGr,
         -- ASIC mask output
         asicMask             => open,
         -- trigger inputs
         trigPgp              => opCodeEn,
         trigTtl              => trigTtl,
         trigCmd              => swTrigger,
         acqStart             => acqStart,
         -- Monitor data for the image stream
         monData              => monData,
         -- Monitor Data Interface
         monitorTxMaster      => monitorTxMaster,
         monitorTxSlave       => monitorTxSlave,
         monitorEn            => monitorEn
      );
   
   dcdcEn      <= iDcdcEn;
   asicDigEn   <= iAsicDigEn;
   iAsicDigEnL <= not iAsicDigEn;
   
   
   --------------------------------------------------------
   -- ASIC Acquisition Core
   --------------------------------------------------------
   U_AsicCore : entity work.AsicCoreTop
      generic map (
         TPD_G             => TPD_G,
         AXI_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         BANK_COLS_G       => BANK_COLS_C,
         BANK_ROWS_G       => BANK_ROWS_C,
         AXI_BASE_ADDR_G   => AXI_CONFIG_C(ASIC_INDEX_C).baseAddr,
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G
      )
      port map (
         -- Clock and Reset
         sysClk               => sysClk,
         sysRst               => sysRst,
         -- AXI-Lite Register Interface (sysClk domain)
         mAxilReadMaster      => axilReadMasters(ASIC_INDEX_C),
         mAxilReadSlave       => axilReadSlaves(ASIC_INDEX_C),
         mAxilWriteMaster     => axilWriteMasters(ASIC_INDEX_C),
         mAxilWriteSlave      => axilWriteSlaves(ASIC_INDEX_C),
         -- AXI DDR Buffer Interface (sysClk domain)
         axiWriteMasters      => axiWriteMasters,
         axiWriteSlaves       => axiWriteSlaves,
         axiReadMaster        => axiReadMaster,
         axiReadSlave         => axiReadSlave,
         buffersRdy           => buffersRdy,
         -- ADC stream input
         adcStream            => adcStream,
         -- Opcode to insert into frame
         opCode               => opCode,
         -- Monitor data for the image stream
         monData              => monData,
         -- ASIC ACQ signals
         acqStart             => acqStart,
         asicAcq              => iAsicAcq,
         asicR0               => iAsicR0,
         asicSync             => iAsicSync,
         asicPpmat            => iAsicPpmat,
         asicRoClk            => iAsicRoClk,
         asicDout             => iAsicDout,
         -- debug outputs
         dbgOut               => iDbgOut,
         -- ADC Clock Output
         adcClk               => iAdcClk,
         -- Image Data Stream
         dataTxMaster         => dataTxMaster,
         dataTxSlave          => dataTxSlave,
         -- Scope Data Stream
         scopeTxMaster        => scopeTxMaster,
         scopeTxSlave         => scopeTxSlave
      );
   
   dbgOut(0) <= not iDbgOut(0);
   dbgOut(1) <= not iDbgOut(1);
   dbgOut(2) <= not iDbgOut(2);
   
   ----------------------------------------------------
   -- SACI Core
   -- Register Access and Matrix Configurators
   ----------------------------------------------------             
   U_SaciConfigCore : entity work.SaciConfigCore
      generic map (
         TPD_G             => TPD_G,
         AXI_BASE_ADDR_G   => AXI_CONFIG_C(SACI_CORE_INDEX_C).baseAddr,
         SACI_CLK_PERIOD_G => SACI_CLK_PERIOD_C,
         AXI_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G
      )
      port map (
         -- clock and reset
         sysClk            => sysClk,
         sysRst            => sysRst,
         -- SACI interface
         saciClk           => iAsicSaciClk,
         saciCmd           => iAsicSaciCmd,
         saciSelL          => iAsicSaciSelL,
         saciRsp           => asicSaciResp,
         -- AXI-Lite Matrix Configuration Interface
         axilReadMaster    => axilReadMasters(SACI_CORE_INDEX_C),
         axilReadSlave     => axilReadSlaves(SACI_CORE_INDEX_C),
         axilWriteMaster   => axilWriteMasters(SACI_CORE_INDEX_C),
         axilWriteSlave    => axilWriteSlaves(SACI_CORE_INDEX_C),
         -- AXI-Lite Register Interfaces
         axilReadMasters   => axilReadMasters(ASIC_SACI3_INDEX_C downto ASIC_SACI0_INDEX_C),
         axilReadSlaves    => axilReadSlaves(ASIC_SACI3_INDEX_C downto ASIC_SACI0_INDEX_C),
         axilWriteMasters  => axilWriteMasters(ASIC_SACI3_INDEX_C downto ASIC_SACI0_INDEX_C),
         axilWriteSlaves   => axilWriteSlaves(ASIC_SACI3_INDEX_C downto ASIC_SACI0_INDEX_C)
      );
   
   --------------------------------------------------------
   -- ASIC ADCs Core
   --------------------------------------------------------
   U_AdcCore : entity work.AdcCore
      generic map (
         TPD_G             => TPD_G,
         AXI_CLK_FREQ_G    => AXI_CLK_FREQ_G,
         SIMULATION_G      => SIMULATION_G,
         SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
         AXI_BASE_ADDR_G   => AXI_CONFIG_C(ADC_INDEX_C).baseAddr
      )
      port map (
         -- Clock and Reset
         sysClk               => sysClk,
         sysRst               => sysRst,
         -- ADC ISERDESE reset
         adcClkRst            => adcClkRst,
         -- AXI-Lite Register Interface (sysClk domain)
         mAxilReadMaster      => axilReadMasters(ADC_INDEX_C),
         mAxilReadSlave       => axilReadSlaves(ADC_INDEX_C),
         mAxilWriteMaster     => axilWriteMasters(ADC_INDEX_C),
         mAxilWriteSlave      => axilWriteSlaves(ADC_INDEX_C),
         -- Fast ADC Config SPI
         adcSclk              => iAdcSclk,
         adcSdio              => adcSdio,
         adcCsb               => iAdcCsb,
         -- Fast ADC Signals
         adcFClkP             => adcFClkP,
         adcFClkN             => adcFClkN,
         adcDClkP             => adcDClkP,
         adcDClkN             => adcDClkN,
         adcChP               => adcChP,
         adcChN               => adcChN,
         adcClkP              => adcClkP,
         adcClkN              => adcClkN,
         -- ADC Output Streams
         adcStream            => adcStream,
         -- ADC clock enable
         adcClkEn             => iAdcClk
      );
   
   adcSclk  <= iAdcSclk;
   adcCsb   <= iAdcCsb;
   
   spareIo2v5(0) <= '0';
   spareIo2v5(1) <= '0'; --iAdcSclk(1);
   spareIo2v5(2) <= '0'; --iAdcCsb(5);
   spareIo2v5(3) <= '0'; --adcClkRst(5);
   
   --------------------------------------------------------
   -- ASIC Buffers (with tri-state outputs)
   --------------------------------------------------------
   
   GEN_VEC2 : for i in 1 downto 0 generate
      
      U_RoClkOutBufDiff : entity surf.OutputBufferReg
      generic map (
         TPD_G       => TPD_G,
         DIFF_PAIR_G => true
      )
      port map (
         I     => iAsicRoClk,
         C     => sysClk,
         T     => iAsicDigEnL,
         O     => asicRoClkP(i),
         OB    => asicRoClkN(i)
      );
      
   end generate GEN_VEC2;
   
   GEN_VEC4 : for i in 3 downto 0 generate
      
      asicSaciCmd(i) <= iAsicSaciCmd(i)   when iAsicDigEn = '1' else 'Z';
      asicSaciClk(i) <= iAsicSaciClk(i)   when iAsicDigEn = '1' else 'Z';
      asicAcq(i)     <= iAsicAcq          when iAsicDigEn = '1' else 'Z';
      asicR0(i)      <= iAsicR0           when iAsicDigEn = '1' else 'Z';
      asicGr(i)      <= iAsicGr           when iAsicDigEn = '1' else 'Z';
      asicSync(i)    <= iAsicSync         when iAsicDigEn = '1' else 'Z';
      asicPpmat(i)   <= iAsicPpmat        when iAsicDigEn = '1' else 'Z';
      
   end generate GEN_VEC4;
   
   GEN_VEC16 : for i in 15 downto 0 generate
      
      U_IBUFDS : IBUFDS
      port map (
         I  => asicDoutP(i),
         IB => asicDoutN(i),
         O  => iAsicDout(i)
      );
      
      asicSaciSelL(i) <= iAsicSaciSelL(i) when iAsicDigEn = '1' else 'Z';
      
   end generate GEN_VEC16;
   
   ----------------------------------------------------------
   ---- ADC Clock Output Buffers
   ----------------------------------------------------------
   --
   --GEN_VEC5 : for i in 4 downto 0 generate
   --   
   --   U_AdcClkOutBufDiff : entity surf.OutputBufferReg
   --   generic map (
   --      TPD_G       => TPD_G,
   --      DIFF_PAIR_G => true
   --   )
   --   port map (
   --      I     => iAdcClk,
   --      C     => sysClk,
   --      O     => adcClkP(i),
   --      OB    => adcClkN(i)
   --   );
   --   
   --end generate GEN_VEC5;
   

end rtl;
