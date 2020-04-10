-------------------------------------------------------------------------------
-- File       : AsicCore.vhd
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
use surf.SsiCmdMasterPkg.all;


library unisim;
use unisim.vcomponents.all;

entity AsicCore is
   generic (
      TPD_G                : time             := 1 ns;
      FPGA_BASE_CLOCK_G    : slv(31 downto 0);
      AXI_CLK_FREQ_G       : real             := 100.00E+6;
      AXI_BASE_ADDR_G      : slv(31 downto 0) := (others => '0')
   );
   port (
      -- Clock and Reset
      sysClk               : in    sl;
      sysRst               : in    sl;
      -- ADC signals
      adcStreams           : in    AxiStreamMasterArray(1 downto 0);
      -- AXI-Lite Register Interface (sysClk domain)
      mAxilReadMaster      : in    AxiLiteReadMasterType;
      mAxilReadSlave       : out   AxiLiteReadSlaveType;
      mAxilWriteMaster     : in    AxiLiteWriteMasterType;
      mAxilWriteSlave      : out   AxiLiteWriteSlaveType;
      -- ASIC Control
      asicGR              : out sl;
      asicCk              : out sl;
      asicRst             : out sl;
      asicCdsBline        : out sl;
      asicRstComp         : out sl;
      asicSampleN         : out sl;
      asicDinjEn          : out sl;
      asicCKinjEn         : out sl;
      -- ADC clock
      adcClk              : out sl;
      -- DACs
      dacSclk             : out sl;
      dacDin              : out sl;
      dacCs               : out slv(1 downto 0);
      -- External Signals
      runTrigger           : in  sl;
      daqTrigger           : in  sl;
      mpsOut               : out sl;
      triggerOut           : out sl;
      -- SW and fiber trigger
      swRun                : in  sl;
      pgpOpCode            : in  slv(7 downto 0);
      pgpOpCodeEn          : in  sl;
      -- Power enables
      digitalPowerEn       : out sl;
      analogPowerEn        : out sl;
      fpgaOutputEn         : out sl;
      ledEn                : out sl;
      adcCardPowerUp       : out sl;
      delayCtrlRdy         : in  sl;
      requestStartupCal    : out sl;
      acqStartOut          : out sl;
      -- env data
      envData              : in    Slv32Array(8 downto 0);
      -- Image Data Stream
      dataAxisMaster       : out   AxiStreamMasterType;
      dataAxisSlave        : in    AxiStreamSlaveType;
      -- Scope Data Stream
      scopeAxisMaster      : out   AxiStreamMasterType;
      scopeAxisSlave       : in    AxiStreamSlaveType
   );
end AsicCore;

architecture rtl of AsicCore is
   
   constant NUM_AXI_MASTERS_C    : natural := 3;

   constant REGS_INDEX_C         : natural := 0;
   constant TRIG_INDEX_C         : natural := 1;
   constant SCOPE_INDEX_C        : natural := 2;

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   -- Triggers and associated signals
   signal iDaqTrigger      : sl;
   signal iRunTrigger      : sl;
   signal opCode           : slv(7 downto 0);
   
   -- Interfaces between blocks
   signal acqStart           : sl;
   signal adcSample          : sl;
   
   -- ADC signals
   signal adcValid         : slv(1 downto 0);
   signal adcData          : Slv16Array(1 downto 0);
   
   signal iAsicGR          : sl;
   signal iAsicCk          : sl;
   signal iAsicRst         : sl;
   signal iAsicCdsBline    : sl;
   signal iAsicRstComp     : sl;
   signal iAsicSampleN     : sl;
   signal iAsicDinjEn      : sl;
   signal iAsicCKinjEn     : sl;
   
begin
   
   acqStartOut <= acqStart;
   
   GenAdcStr : for i in 0 to 1 generate 
      adcData(i)  <= adcStreams(i).tData(15 downto 0);
      adcValid(i) <= adcStreams(i).tValid;
   end generate;
   
   -- Triggers in
   iRunTrigger    <= runTrigger;
   iDaqTrigger    <= daqTrigger;
   
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

         mAxiWriteMasters => mAxiWriteMasters,
         mAxiWriteSlaves  => mAxiWriteSlaves,
         mAxiReadMasters  => mAxiReadMasters,
         mAxiReadSlaves   => mAxiReadSlaves
      );
   
   
   --------------------------------------------
   --     Master Register Controller         --
   --------------------------------------------   
   U_RegControl : entity work.RegControl
   generic map (
      TPD_G                => TPD_G,
      FPGA_BASE_CLOCK_G    => FPGA_BASE_CLOCK_G
   )
   port map (
      axiClk         => sysClk,
      axiRst         => sysRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => mAxiReadMasters(REGS_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(REGS_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(REGS_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(REGS_INDEX_C),
      -- acquisition trigger
      acqStart       => acqStart,
      -- ASIC signals
      asicGR         => iAsicGR,
      asicCk         => iAsicCk,
      asicRst        => iAsicRst,
      asicCdsBline   => iAsicCdsBline,
      asicRstComp    => iAsicRstComp,
      asicSampleN    => iAsicSampleN,
      asicDinjEn     => iAsicDinjEn,
      asicCKinjEn    => iAsicCKinjEn,
      -- debug outputs
      dbgOut(0)      => mpsOut,
      dbgOut(1)      => triggerOut,
      -- Map out power enables
      digPowerEn     => digitalPowerEn,
      anaPowerEn     => analogPowerEn,
      fpgaOutEn      => fpgaOutputEn,
      ledEn          => ledEn,
      -- Slow ADC env data
      envData        => envData,
      -- ADC signals
      adcClk         => adcClk,
      reqStartupCal  => requestStartupCal,
      adcCardPowerUp => adcCardPowerUp,
      adcData        => adcData,
      adcValid       => adcValid,
      -- AxiStream output
      axisClk        => sysClk,
      axisRst        => sysRst,
      axisMaster     => dataAxisMaster,
      axisSlave      => dataAxisSlave
   );
   
   asicGR         <= iAsicGR;
   asicCk         <= iAsicCk;
   asicRst        <= iAsicRst;
   asicCdsBline   <= iAsicCdsBline;
   asicRstComp    <= iAsicRstComp;
   asicSampleN    <= iAsicSampleN;
   asicDinjEn     <= iAsicDinjEn;
   asicCKinjEn    <= iAsicCKinjEn;
   
   ---------------------
   -- Trig control    --
   ---------------------
   U_TrigControl : entity work.TrigControlAxi 
   generic map ( 
      TPD_G             => TPD_G
   )
   port map ( 
      -- Core clock, reset
      sysClk            => sysClk,
      sysRst            => sysRst,
      -- TTL triggers in 
      runTrigger        => iRunTrigger,
      daqTrigger        => iDaqTrigger,
      -- SW trigger in (from VC)
      swRun             => swRun,
      pgpOpCode         => pgpOpCode,
      pgpOpCodeEn       => pgpOpCodeEn,
      -- Opcode associated with this trigger
      opCodeOut         => opCode,
      -- Interface to other blocks
      acqStart          => acqStart,
      dataSend          => open,
      -- AXI lite slave port for register access
      axilClk           => sysClk,
      axilRst           => sysRst,
      sAxilReadMaster   => mAxiReadMasters(TRIG_INDEX_C),
      sAxilReadSlave    => mAxiReadSlaves(TRIG_INDEX_C),
      sAxilWriteMaster  => mAxiWriteMasters(TRIG_INDEX_C),
      sAxilWriteSlave   => mAxiWriteSlaves(TRIG_INDEX_C)
      
   );   
   
   ---------------------------------------------------------------
   -- PseudoScope Core
   --------------------- ------------------------------------------
   U_PseudoScopeCore : entity work.PseudoScope2Axi
   generic map (
      TPD_G             => TPD_G,
      INPUTS_G          => 2
   )
   port map ( 
      clk               => sysClk,
      rst               => sysRst,
      dataIn            => adcData,
      dataValid         => adcValid,
      arm               => acqStart,
      triggerIn(0)      => acqStart,
      triggerIn(1)      => iAsicCk,
      triggerIn(2)      => iAsicRst,
      triggerIn(3)      => iAsicCdsBline,
      triggerIn(4)      => iAsicRstComp,
      triggerIn(5)      => iAsicSampleN,
      triggerIn(6)      => iAsicDinjEn,
      triggerIn(7)      => iAsicCKinjEn,
      triggerIn(8)      => '0',
      triggerIn(9)      => '0',
      triggerIn(10)     => '0',
      triggerIn(11)     => '0',
      triggerIn(12)     => '0',
      axisClk           => sysClk,
      axisRst           => sysRst,
      axisMaster        => scopeAxisMaster,
      axisSlave         => scopeAxisSlave,
      axilClk           => sysClk,
      axilRst           => sysRst,
      sAxilWriteMaster  => mAxiWriteMasters(SCOPE_INDEX_C),
      sAxilWriteSlave   => mAxiWriteSlaves(SCOPE_INDEX_C),
      sAxilReadMaster   => mAxiReadMasters(SCOPE_INDEX_C),
      sAxilReadSlave    => mAxiReadSlaves(SCOPE_INDEX_C)
   );
   
end rtl;
