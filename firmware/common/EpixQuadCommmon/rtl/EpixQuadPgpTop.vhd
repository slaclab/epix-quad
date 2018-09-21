-------------------------------------------------------------------------------
-- File       : EpixQuadPgpTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-02-04
-- Last update: 2018-10-05
-------------------------------------------------------------------------------
-- Description: EPIX EpixQuadPgpTop Target's Top Level
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
use work.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixQuadPgpTop is
   generic (
      TPD_G             : time            := 1 ns;
      SIMULATION_G      : boolean         := false;
      SIM_SPEEDUP_G     : boolean         := false;
      COM_TYPE_G        : string          := "PGPv3";
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
end EpixQuadPgpTop;

architecture top_level of EpixQuadPgpTop is

begin
   
   assert COM_TYPE_G = "PGPv3" or COM_TYPE_G = "PGPv2b"
      report "COM_TYPE_G must be set to PGPv3 or PGPv2b"
      severity failure;

   --------------------------------------------------------
   -- Communication Module
   --------------------------------------------------------
   G_PGPv3 : if COM_TYPE_G = "PGPv3" generate
   
      U_PGP : entity work.EpixQuadPgp3Core
         generic map (
            TPD_G             => TPD_G,
            SIMULATION_G      => SIMULATION_G,
            SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
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
            mAxilReadMaster   => mAxilReadMaster ,
            mAxilReadSlave    => mAxilReadSlave  ,
            mAxilWriteMaster  => mAxilWriteMaster,
            mAxilWriteSlave   => mAxilWriteSlave ,
            -- Debug AXI-Lite Interface         
            sAxilReadMaster   => sAxilReadMaster ,
            sAxilReadSlave    => sAxilReadSlave  ,
            sAxilWriteMaster  => sAxilWriteMaster,
            sAxilWriteSlave   => sAxilWriteSlave ,
            -- Software trigger interface
            swTrigOut         => swTrigOut,
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
      
   end generate G_PGPv3;
   
   G_PGPv2b : if COM_TYPE_G = "PGPv2b" generate
   
      U_PGP : entity work.EpixQuadPgp2bCore
         generic map (
            TPD_G             => TPD_G,
            SIMULATION_G      => SIMULATION_G,
            SIM_SPEEDUP_G     => SIM_SPEEDUP_G)
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
            mAxilReadMaster   => mAxilReadMaster ,
            mAxilReadSlave    => mAxilReadSlave  ,
            mAxilWriteMaster  => mAxilWriteMaster,
            mAxilWriteSlave   => mAxilWriteSlave ,
            -- Debug AXI-Lite Interface         
            sAxilReadMaster   => sAxilReadMaster ,
            sAxilReadSlave    => sAxilReadSlave  ,
            sAxilWriteMaster  => sAxilWriteMaster,
            sAxilWriteSlave   => sAxilWriteSlave ,
            -- Software trigger interface
            swTrigOut         => swTrigOut,
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
      
   end generate G_PGPv2b;

end top_level;
