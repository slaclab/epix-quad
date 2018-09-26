-------------------------------------------------------------------------------
-- File       : AsicCoreTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-10
-------------------------------------------------------------------------------
-- Description: EPIX Quad Target's Top Level
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
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AsicCoreTop is
   generic (
      TPD_G                : time             := 1 ns;
      BANK_COLS_G          : natural          := 48;
      BANK_ROWS_G          : natural          := 178;
      AXI_BASE_ADDR_G      : slv(31 downto 0) := (others => '0')
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
      opCode               : in  slv(7 downto 0);
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
   
   constant NUM_AXI_MASTERS_C    : natural := 3;

   constant ASIC_ACQ_INDEX_C     : natural := 0;
   constant ASIC_RDOUT_INDEX_C   : natural := 1;
   constant SCOPE_INDEX_C        : natural := 2;

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

begin
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
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
   
   U_AcqCore : entity work.AcqCore
   generic map (
      TPD_G             => TPD_G,
      BANK_COLS_G       => BANK_COLS_G,
      BANK_ROWS_G       => BANK_ROWS_G
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
      roClkTail         => toSlv(10, 8),
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
   
   U_RdoutCore : entity work.RdoutCoreTop
   generic map (
      TPD_G             => TPD_G,
      BANK_COLS_G       => BANK_COLS_G,
      BANK_ROWS_G       => BANK_ROWS_G,
      LINE_REVERSE_G    => "1010"
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
      -- ADC stream input
      adcStream            => adcStream(63 downto 0),
      tpsStream            => adcStream(79 downto 64),
      -- Test stream input
      testStream           => testStream,
      -- Frame stream output (axisClk domain)
      axisClk              => sysClk,
      axisRst              => sysRst,
      axisMaster           => dataTxMaster,
      axisSlave            => dataTxSlave 
   );
   
   U_PseudoScopeCore : entity work.PseudoScopeCore
   generic map (
      TPD_G             => TPD_G,
      INPUT_CHANNELS_G  => 80,
      EXTTRIG_IN_G      => 6
   )
   port map ( 
      sysClk            => sysClk,
      sysClkRst         => sysRst,
      adcStream         => adcStream,
      arm               => acqStart,
      trigIn(0)         => acqStart,
      trigIn(1)         => iAsicAcq,
      trigIn(2)         => iAsicR0,
      trigIn(3)         => iAsicSync,
      trigIn(4)         => iAsicPpmat,
      trigIn(5)         => iAsicRoClk,
      mAxisMaster       => scopeTxMaster,
      mAxisSlave        => scopeTxSlave,
      axilClk           => sysClk,
      axilRst           => sysRst,
      sAxilWriteMaster  => axilWriteMasters(SCOPE_INDEX_C),
      sAxilWriteSlave   => axilWriteSlaves(SCOPE_INDEX_C),
      sAxilReadMaster   => axilReadMasters(SCOPE_INDEX_C),
      sAxilReadSlave    => axilReadSlaves(SCOPE_INDEX_C)
   );
   
   
   G_AsicEmuRdout : for i in 0 to 63 generate 
      
      U_AsicEmuRdout : entity work.AsicEmuRdout
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

end rtl;
