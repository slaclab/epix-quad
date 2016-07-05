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
use work.EpixPkgGen2.all;
use work.ScopeTypes.all;

entity TB_RegControlGen2 is 

end TB_RegControlGen2;


-- Define architecture
architecture beh of TB_RegControlGen2 is

   signal sysClk               :  sl;
   signal sysRst               :  sl;
   signal rstL                 :  sl;
   
   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiReadSlave   : AxiLiteReadSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteMaster : AxiLiteWriteMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteSlave  : AxiLiteWriteSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   
   signal pgpAxiReadMaster  : AxiReadMasterType;
   signal pgpAxiReadSlave   : AxiReadSlaveType;
   signal pgpAxiWriteMaster : AxiWriteMasterType;
   signal pgpAxiWriteSlave  : AxiWriteSlaveType;
   
   signal epixStatus     : EpixStatusType;
   signal epixConfig     : EpixConfigType;
   signal scopeConfig    : ScopeConfigType;
   
   signal saciReadoutReq : std_logic;
   signal saciReadoutAck : std_logic;
   
   signal saciClk  : std_logic;
   signal saciRsp  : std_logic_vector(3 downto 0);
   signal saciCmd  : std_logic;
   signal saciSelL : std_logic_vector(3 downto 0);

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
    saciRsp  => saciRsp(0)
   );
   
   Slv_asic1_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(1),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp(1)
   );
   
   Slv_asic2_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(2),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp(2)
    --saciRsp  => open
   );
   
   --saciRsp(2) <= '0';
   
   Slv_asic3_i: entity work.SaciSlaveWrapper
   port map (
    asicRstL => rstL,
    saciClk  => saciClk,
    saciSelL => saciSelL(3),
    saciCmd  => saciCmd,
    saciRsp  => saciRsp(3)
   );
   
   
   
   U_RegControlGen2_DUT : entity work.RegControlGen2
   port map (
      -- Global Signals
      axiClk         => sysClk,
      axiRst         => open,
      sysRst         => sysRst, 
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(COMMON_AXI_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(COMMON_AXI_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(COMMON_AXI_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(COMMON_AXI_INDEX_C),
      -- Register Inputs/Outputs (axiClk domain)
      epixStatus     => epixStatus,
      epixConfig     => epixConfig,
      scopeConfig    => scopeConfig,
      -- SACI prep-for-readout command request
      saciReadoutReq => saciReadoutReq,
      saciReadoutAck => saciReadoutAck,
      -- SACI interfaces to ASIC(s)
      saciClk         => saciClk,
      saciSelL        => saciSelL,
      saciCmd         => saciCmd,
      saciRsp         => saciRsp ,
      -- Guard ring DAC interfaces
      dacSclk        => open,
      dacDin         => open,
      dacCsb         => open,
      dacClrb        => open
   );
   
   epixStatus <= EPIX_STATUS_INIT_C;
   
   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   -- Master 0 : PGP register controller     --
   -- Master 1 : Picoblaze reg controller    --
   --------------------------------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
   generic map (
      NUM_SLAVE_SLOTS_G  => NUM_AXI_SLAVE_SLOTS_C,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTER_SLOTS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
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
   
   -- no Picoblaze master in the test
   sAxiWriteMaster(1) <= AXI_LITE_WRITE_MASTER_INIT_C;
   sAxiReadMaster(1) <= AXI_LITE_READ_MASTER_INIT_C;
   
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
      axilReadMaster     => sAxiReadMaster(0),
      axilReadSlave      => sAxiReadSlave(0),
      axilWriteMaster    => sAxiWriteMaster(0),
      axilWriteSlave     => sAxiWriteSlave(0)
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

end beh;

