-------------------------------------------------------------------------------
-- Title         : Test-bench of the EPIX Register Control Unit
-- Project       : EPIX Detector
-------------------------------------------------------------------------------
-- File          : TB_RegControlGen2.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 01/27/2016
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Maciej Kwiatkowski. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/27/2016: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.EpixPkgGen2.all;
use work.ScopeTypes.all;
use work.Pgp2bPkg.all;

entity TB_RegControlGen2 is 

end TB_RegControlGen2;


-- Define architecture
architecture beh of TB_RegControlGen2 is

   signal sysClk               :  sl;
   signal sysRst               :  sl;
   signal rstL                 :  sl;
   
   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterArray(1 downto 0);
   signal sAxiReadSlave   : AxiLiteReadSlaveArray(1 downto 0);
   signal sAxiWriteMaster : AxiLiteWriteMasterArray(1 downto 0);
   signal sAxiWriteSlave  : AxiLiteWriteSlaveArray(1 downto 0);
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(2 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(2 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(2 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(2 downto 0); 
   
   
   signal pgpRxAxisMaster   : AxiStreamMasterType;
   signal pgpRxAxisSlave    : AxiStreamSlaveType;
   signal pgpTxAxisMaster   : AxiStreamMasterType;
   signal pgpTxAxisSlave    : AxiStreamSlaveType;
   signal pgpAxiReadMaster  : AxiReadMasterType;
   signal pgpAxiReadSlave   : AxiReadSlaveType;
   signal pgpAxiWriteMaster : AxiWriteMasterType;
   signal pgpAxiWriteSlave  : AxiWriteSlaveType;
   signal testIoWriteMaster : AxiLiteWriteMasterType;
   signal testIoWriteSlave  : AxiLiteWriteSlaveType;
   signal testIoReadMaster  : AxiLiteReadMasterType;
   signal testIoReadSlave   : AxiLiteReadSlaveType;
   
   signal epixStatus     : EpixStatusType;
   signal epixConfig     : EpixConfigType;
   signal scopeConfig    : ScopeConfigType;
   
   signal saciReadoutReq : std_logic;
   signal saciReadoutAck : std_logic;
   
   signal saciClk  : std_logic;
   signal saciRsp  : std_logic;
   signal saciCmd  : std_logic;
   signal saciSelL : std_logic_vector(3 downto 0);
   
   signal exec   : slv(3 downto 0);
   signal readL  : slv(3 downto 0);
   signal cmd    : Slv7Array(3 downto 0);
   signal addr   : Slv12Array(3 downto 0);
   signal wrData : Slv32Array(3 downto 0);

   constant EPIXREGS_AXI_INDEX_C : natural := 0;
   constant MULTIPIX_AXI_INDEX_C : natural := 1;
   constant SACIREGS_AXI_INDEX_C : natural := 2;
   
   constant EPIXREGS_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00000000";
   constant MULTIPIX_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00200000";
   constant SACIREGS_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"02000000";
   
   constant AXI_CROSSBAR_TB_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(2 downto 0) := (
      EPIXREGS_AXI_INDEX_C => (
         baseAddr       => EPIXREGS_AXI_BASE_ADDR_C,
         addrBits       => 20,
         connectivity   => x"FFFF"),
      MULTIPIX_AXI_INDEX_C => (
         baseAddr       => MULTIPIX_AXI_BASE_ADDR_C,
         addrBits       => 20,
         connectivity   => x"FFFF"),
      SACIREGS_AXI_INDEX_C => (
         baseAddr       => SACIREGS_AXI_BASE_ADDR_C,
         addrBits       => 24,
         connectivity   => x"FFFF")
   );

begin
   
   -- clocks and resets
   
   process
   begin
      sysClk <= '0';
      wait for 5 ns;
      sysClk <= '1';
      wait for 5 ns;
   end process;
   
   process
   begin
      sysRst <= '1';
      wait for 10 ns;
      sysRst <= '0';
      wait;
   end process;
   
   rstL <= not sysRst;
   
   -- prepare for readout request process
   
   process
   begin
      saciReadoutReq <= '0';
      wait for 100 us;
      saciReadoutReq <= '1';
      wait until saciReadoutAck = '0';
      --saciReadoutReq <= '0';
      --wait;
   end process;
   
   
   -- SACI slaves
   
   Slv_asic0_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(0),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp
   );
   
   Slv_asic1_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(1),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp
   );
   
   Slv_asic2_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(2),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp
   );
   
   Slv_asic3_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(3),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp
   );
   
   
   U_RegControlGen2_DUT : entity work.RegControl
   port map (
      -- Global Signals
      axiClk         => sysClk,
      axiRst         => open,
      sysRst         => sysRst, 
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(EPIXREGS_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(EPIXREGS_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(EPIXREGS_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(EPIXREGS_AXI_INDEX_C),
      -- Monitoring enable command incoming stream
      monEnAxisMaster => AXI_STREAM_MASTER_INIT_C,
      -- Register Inputs/Outputs (axiClk domain)
      epixStatus     => epixStatus,
      epixConfig     => epixConfig,
      scopeConfig    => scopeConfig,
      -- Guard ring DAC interfaces
      dacSclk        => open,
      dacDin         => open,
      dacCsb         => open,
      dacClrb        => open
   );
   
   epixStatus <= EPIX_STATUS_INIT_C;
   
   U_AxiLiteSaciMaster_DUT : entity work.AxiLiteSaciMaster
   generic map (
      AXIL_CLK_PERIOD_G  => 10.0E-9, -- In units of seconds
      AXIL_TIMEOUT_G     => 1.0E-3,  -- In units of seconds
      SACI_CLK_PERIOD_G  => 0.25E-6, -- In units of seconds
      SACI_CLK_FREERUN_G => false,
      SACI_RSP_BUSSED_G  => true,
      SACI_NUM_CHIPS_G   => 4)
   port map (
      -- SACI interface
      saciClk         => saciClk,
      saciCmd         => saciCmd,
      saciSelL        => saciSelL,
      saciRsp(0)      => saciRsp,
      -- AXI-Lite Register Interface
      axilClk           => sysClk,
      axilRst           => sysRst,
      axilReadMaster    => mAxiReadMasters(SACIREGS_AXI_INDEX_C),
      axilReadSlave     => mAxiReadSlaves(SACIREGS_AXI_INDEX_C),
      axilWriteMaster   => mAxiWriteMasters(SACIREGS_AXI_INDEX_C),
      axilWriteSlave    => mAxiWriteSlaves(SACIREGS_AXI_INDEX_C)
   );
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   -- Master 0 : PGP register controller     --
   -- Master 1 : SACI multipixel controller  --
   --------------------------------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
   generic map (
      NUM_SLAVE_SLOTS_G  => 2,
      NUM_MASTER_SLOTS_G => 3,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_TB_MASTERS_CONFIG_C)
   port map (
      sAxiWriteMasters    => sAxiWriteMaster,
      sAxiWriteSlaves     => sAxiWriteSlave,
      sAxiReadMasters     => sAxiReadMaster,
      sAxiReadSlaves      => sAxiReadSlave,
      mAxiWriteMasters    => mAxiWriteMasters,
      mAxiWriteSlaves     => mAxiWriteSlaves,
      mAxiReadMasters     => mAxiReadMasters,
      mAxiReadSlaves      => mAxiReadSlaves,
      axiClk              => sysClk,
      axiClkRst           => sysRst
   );
   
   
   U_SaciMultiPixel_DUT : entity work.SaciMultiPixel
   port map (
      axilClk           => sysClk,
      axilRst           => sysRst,
      
      -- AXI lite slave port
      sAxilWriteMaster => mAxiWriteMasters(MULTIPIX_AXI_INDEX_C),
      sAxilWriteSlave  => mAxiWriteSlaves(MULTIPIX_AXI_INDEX_C),
      sAxilReadMaster  => mAxiReadMasters(MULTIPIX_AXI_INDEX_C),
      sAxilReadSlave   => mAxiReadSlaves(MULTIPIX_AXI_INDEX_C),
      
      -- AXI lite master port
      mAxilWriteMaster  => sAxiWriteMaster(1),
      mAxilWriteSlave   => sAxiWriteSlave(1),
      mAxilReadMaster   => sAxiReadMaster(1),
      mAxilReadSlave    => sAxiReadSlave(1)
   );
   
   

   U_AxiSimMasterWrap : entity work.AxiSimMasterWrap
   port map (
      -- AXI Clock/Rst
      axiClk            => sysClk,
      -- Master
      mstAxiReadMaster  => pgpAxiReadMaster,
      mstAxiReadSlave   => pgpAxiReadSlave,
      mstAxiWriteMaster => pgpAxiWriteMaster,
      mstAxiWriteSlave  => pgpAxiWriteSlave
   );
   
   U_AxiToAxiLite : entity work.AxiToAxiLite
   port map (
      -- Clocks & Reset
      axiClk             => sysClk,
      axiClkRst          => sysRst,
      -- AXI Slave 
      axiReadMaster      => pgpAxiReadMaster,
      axiReadSlave       => pgpAxiReadSlave,
      axiWriteMaster     => pgpAxiWriteMaster,
      axiWriteSlave      => pgpAxiWriteSlave,
      -- AXI Lite
      axilWriteMaster    => testIoWriteMaster,
      axilWriteSlave     => testIoWriteSlave,
      axilReadMaster     => testIoReadMaster,
      axilReadSlave      => testIoReadSlave
   );
   
   U_SrpV0AxiLite : entity work.AxiLiteSrpV0
   generic map (
      AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
   )
   port map (

      -- AXIS Slave Interface (sAxisClk domain) 
      sAxisClk         => sysClk,
      sAxisRst         => sysRst,
      sAxisMaster      => pgpTxAxisMaster,
      sAxisSlave       => pgpTxAxisSlave,
      -- AXIS Master Interface (mAxisClk domain) 
      mAxisClk         => sysClk,
      mAxisRst         => sysRst,
      mAxisMaster      => pgpRxAxisMaster,
      mAxisSlave       => pgpRxAxisSlave,

      -- AXI Lite Bus Slave (axiLiteClk domain)
      axilClk          => sysClk,
      axilRst          => sysRst,
      sAxilWriteMaster => testIoWriteMaster,
      sAxilWriteSlave  => testIoWriteSlave,
      sAxilReadMaster  => testIoReadMaster,
      sAxilReadSlave   => testIoReadSlave
      );
   
   U_SsiAxiLiteMaster : entity work.SsiAxiLiteMaster
   generic map (
      EN_32BIT_ADDR_G     => true,
      AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C
   )
   port map (

      -- Streaming Slave (Rx) Interface (sAxisClk domain) 
      sAxisClk    => sysClk,
      sAxisRst    => sysRst,
      sAxisMaster => pgpRxAxisMaster,
      sAxisSlave  => pgpRxAxisSlave,

      -- Streaming Master (Tx) Data Interface (mAxisClk domain)
      mAxisClk    => sysClk,
      mAxisRst    => sysRst,
      mAxisMaster => pgpTxAxisMaster,
      mAxisSlave  => pgpTxAxisSlave,

      -- AXI Lite Bus (axiLiteClk domain)
      axiLiteClk           => sysClk,
      axiLiteRst           => sysRst,
      mAxiLiteReadMaster   => sAxiReadMaster(0),
      mAxiLiteReadSlave    => sAxiReadSlave(0),
      mAxiLiteWriteMaster  => sAxiWriteMaster(0),
      mAxiLiteWriteSlave   => sAxiWriteSlave(0)
   );

end beh;

