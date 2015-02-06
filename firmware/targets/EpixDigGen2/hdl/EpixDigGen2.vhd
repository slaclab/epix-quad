-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixDigGen2.vhd
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-12-11
-- Last update: 2014-12-11
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.CommonPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixDigGen2 is
   port (
      -- Debugging IOs
      led                 : out slv(3 downto 0);
      -- GT CLK Pins
      gtRefClk0P          : in  sl;
      gtRefClk0N          : in  sl;
      -- SFP TX/RX
      gtDataRxP           : in  sl;
      gtDataRxN           : in  sl;
      gtDataTxP           : out sl;
      gtDataTxN           : out sl;
      -- SFP control signals
      sfpDisable          : out sl
      -- -- Guard ring DAC
      -- vGuardDacSclk       : out sl;
      -- vGuardDacDin        : out sl;
      -- vGuardDacCsb        : out sl;
      -- vGuardDacClrb       : out sl;
      -- -- External Signals
      -- runTg               : in  sl;
      -- daqTg               : in  sl;
      -- mps                 : out sl;
      -- tgOut               : out sl;
      -- -- Board IDs
      -- snIoAdcCard         : inout sl;
      -- serialNumberIo      : inout sl;
      -- -- Power Control
      -- analogCardDigPwrEn  : out sl;
      -- analogCardAnaPwrEn  : out sl;
      -- -- Slow ADC
      -- slowAdcSclk         : out sl;
      -- slowAdcDin          : out sl;
      -- slowAdcCsb          : out sl;
      -- slowAdcDout         : in  sl;
      -- -- Fast ADC Control
      -- adcSpiClk           : out sl;
      -- adcSpiData          : inout sl;
      -- adc0SpiCsb          : out sl;
      -- adc1SpiCsb          : out sl;
      -- adcMonSpiCsb        : out sl;
      -- adc0Pdwn            : out sl;
      -- adc1Pdwn            : out sl;
      -- adcMonPdwn          : out sl;
      -- -- ASIC SACI Interface
      -- asicSaciCmd         : out sl;
      -- asicSaciClk         : out sl;
      -- asic3SaciSel        : out sl;
      -- asic2SaciSel        : out sl;
      -- asic1SaciSel        : out sl;
      -- asic0SaciSel        : out sl;
      -- asicAllSaciRsp      : in  sl;
      -- -- Monitoring ADCs
      -- adcMonClkP          : out sl;
      -- adcMonClkM          : out sl;
      -- adcMonDoClkP        : in  sl;
      -- adcMonDoClkM        : in  sl;
      -- adcMonFrameClkP     : in  sl;
      -- adcMonFrameClkM     : in  sl;
      -- asic0AdcDoMonP      : in  sl;
      -- asic0AdcDoMonM      : in  sl;
      -- asic1AdcDoMonP      : in  sl;
      -- asic1AdcDoMonM      : in  sl;
      -- asic2AdcDoMonP      : in  sl;
      -- asic2AdcDoMonM      : in  sl;
      -- asic3AdcDoMonP      : in  sl;
      -- asic3AdcDoMonM      : in  sl;
      -- -- ASIC 0/1 Data
      -- adc0ClkP            : out sl;
      -- adc0ClkM            : out sl;
      -- adc0DoClkP          : in  sl;
      -- adc0DoClkM          : in  sl;
      -- adc0FrameClkP       : in  sl;
      -- adc0FrameClkM       : in  sl;
      -- asic0AdcDoAP        : in  sl;
      -- asic0AdcDoAM        : in  sl;
      -- asic0AdcDoBP        : in  sl;
      -- asic0AdcDoBM        : in  sl;
      -- asic0AdcDoCP        : in  sl;
      -- asic0AdcDoCM        : in  sl;
      -- asic0AdcDoDP        : in  sl;
      -- asic0AdcDoDM        : in  sl;
      -- asic1AdcDoAP        : in  sl;
      -- asic1AdcDoAM        : in  sl;
      -- asic1AdcDoBP        : in  sl;
      -- asic1AdcDoBM        : in  sl;
      -- asic1AdcDoCP        : in  sl;
      -- asic1AdcDoCM        : in  sl;
      -- asic1AdcDoDP        : in  sl;
      -- asic1AdcDoDM        : in  sl;
      -- -- ASIC 2/3 Data
      -- adc1ClkP            : out sl;
      -- adc1ClkM            : out sl;
      -- adc1DoClkP          : in  sl;
      -- adc1DoClkM          : in  sl;
      -- adc1FrameClkP       : in  sl;
      -- adc1FrameClkM       : in  sl;
      -- asic2AdcDoAP        : in  sl;
      -- asic2AdcDoAM        : in  sl;
      -- asic2AdcDoBP        : in  sl;
      -- asic2AdcDoBM        : in  sl;
      -- asic2AdcDoCP        : in  sl;
      -- asic2AdcDoCM        : in  sl;
      -- asic2AdcDoDP        : in  sl;
      -- asic2AdcDoDM        : in  sl;
      -- asic3AdcDoAP        : in  sl;
      -- asic3AdcDoAM        : in  sl;
      -- asic3AdcDoBP        : in  sl;
      -- asic3AdcDoBM        : in  sl;
      -- asic3AdcDoCP        : in  sl;
      -- asic3AdcDoCM        : in  sl;
      -- asic3AdcDoDP        : in  sl;
      -- asic3AdcDoDM        : in  sl;
      -- -- ASIC Control
      -- asicR0              : out sl;
      -- asicPpmat           : out sl;
      -- asicPpbe            : out sl;
      -- asicGlblRst         : out sl;
      -- asicSync            : out sl;
      -- asicAcq             : out sl;
      -- asicAllDm2          : in  sl;
      -- asicAllDm1          : in  sl;
      -- asic0DoutP          : in  sl;
      -- asic0DoutM          : in  sl;
      -- asic1DoutP          : in  sl;
      -- asic1DoutM          : in  sl;
      -- asic2DoutP          : in  sl;
      -- asic2DoutM          : in  sl;
      -- asic3DoutP          : in  sl;
      -- asic3DoutM          : in  sl;
      -- asic0RoClkP         : out sl;
      -- asic0RoClkM         : out sl;
      -- asic1RoClkP         : out sl;
      -- asic1RoClkM         : out sl;
      -- asic2RoClkP         : out sl;
      -- asic2RoClkM         : out sl;
      -- asic3RoClkP         : out sl;
      -- asic3RoClkM         : out sl
   );
end EpixDigGen2;

architecture top_level of EpixDigGen2 is

   signal coreClk     : sl;
   signal sysRst      : sl;
   signal axiRst      : sl;
   signal heartBeat   : sl;
   signal txLinkReady : sl;
   signal rxLinkReady : sl;

   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterType;
   signal sAxiReadSlave   : AxiLiteReadSlaveType;
   signal sAxiWriteMaster : AxiLiteWriteMasterType;
   signal sAxiWriteSlave  : AxiLiteWriteSlaveType;
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 

   -- AXI-Stream signals
   signal userAxisMaster   : AxiStreamMasterType;
   signal userAxisSlave    : AxiStreamSlaveType;
   
   -- Command interface
   signal ssiCmd           : SsiCmdMasterType;
   
   -- Other signals
   signal cmdTrigger       : sl;
   signal fullTrigger      : sl;
   signal autoTrigger      : sl;
   signal ssiPrbsTxBusy    : sl;
   
   signal status           : CommonStatusType;
   signal config           : CommonConfigType;
   
begin

   -- Fixed state logic signals
   sfpDisable <= '0';

   -- Generate full trigger from all possible sources
   fullTrigger <= cmdTrigger or config.eventTrigger or autoTrigger;
   
   ---------------------
   -- Diagnostic LEDs --
   ---------------------
   led(3) <= ssiPrbsTxBusy;
   led(2) <= status.rxReady;
   led(1) <= status.txReady;
   led(0) <= heartBeat;
   ---------------------
   -- Heart beat LED  --
   ---------------------
   U_Heartbeat : entity work.Heartbeat
      generic map(
         PERIOD_IN_G => 6.4E-9
      )   
      port map (
         clk => coreClk,
         o   => heartBeat
      );    

   ---------------------
   -- PGP Front end   --
   ---------------------
   U_PgpFrontEnd : entity work.PgpFrontEnd
      port map (
         -- GTX 7 Ports
         gtClkP      => gtRefClk0P,
         gtClkN      => gtRefClk0N,
         gtRxP       => gtDataRxP,
         gtRxN       => gtDataRxN,
         gtTxP       => gtDataTxP,
         gtTxN       => gtDataTxN,
         -- Output reset
         pgpRst      => sysRst,
         -- Output status
         rxLinkReady => status.rxReady,
         txLinkReady => status.txReady,
         -- Output clocking
         pgpClk      => coreClk,
         stableClk   => open,--: out sl
         -- AXI clocking
         axiClk     => coreClk,
         axiRst     => axiRst,--: in  sl
         -- Axi Master Interface - Registers (axiClk domain)
         mAxiLiteReadMaster  => sAxiReadMaster,
         mAxiLiteReadSlave   => sAxiReadSlave,
         mAxiLiteWriteMaster => sAxiWriteMaster,
         mAxiLiteWriteSlave  => sAxiWriteSlave,
         -- Streaming data Links (axiClk domain)      
         userAxisMaster      => userAxisMaster,
         userAxisSlave       => userAxisSlave,
         userAxisCtrl        => open, --userAxisCtrl,
         -- Command interface
         ssiCmd              => ssiCmd
      );

   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   --------------------------------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         sAxiWriteMasters(0) => sAxiWriteMaster,
         sAxiWriteSlaves(0)  => sAxiWriteSlave,
         sAxiReadMasters(0)  => sAxiReadMaster,
         sAxiReadSlaves(0)   => sAxiReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves,
         axiClk              => coreClk,
         axiClkRst           => axiRst);
   
   --------------------------------------------
   --     AXI Lite Version Register          --
   --------------------------------------------   
   U_AxiVersion : entity work.AxiVersion
      generic map (
         EN_DEVICE_DNA_G => true
      )
      port map (
         axiReadMaster  => mAxiReadMasters(VERSION_AXI_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(VERSION_AXI_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(VERSION_AXI_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(VERSION_AXI_INDEX_C),
         axiClk         => coreClk,
         axiRst         => axiRst
      );    

   --------------------------------------------
   --     AXI Common Register                --
   --------------------------------------------   
   U_AxiCommonReg : entity work.AxiCommonReg
      port map (
         axiReadMaster  => mAxiReadMasters(COMMON_AXI_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(COMMON_AXI_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(COMMON_AXI_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(COMMON_AXI_INDEX_C),
         ssiCmd         => ssiCmd,
         status         => status,
         config         => config,
         axiClk         => coreClk,
         axiRst         => axiRst, --out
         sysRst         => sysRst  --in
      );          

   -------------------------------
   -- Triggering from SSI
   -------------------------------      
   U_CmdTrigger : entity work.SsiCmdMasterPulser
      generic map (
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1
      )   
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"00",
         -- output pulse to sync module
         syncPulse   => cmdTrigger,
         -- Local clock and reset
         locClk      => coreClk,
         locRst      => axiRst);      

   -------------------------------
   -- Autotrigger               --
   -------------------------------      
   U_AutoTrigger : entity work.AutoTrigger
      port map (
         sysClk        => coreClk,
         sysClkRst     => axiRst,
         runTrigIn     => '0',
         daqTrigIn     => '0',
         -- Number of clock cycles between triggers
         trigPeriod    => config.autoTrigPeriod,
         --Enable run and daq triggers
         runEn         => config.enAutoTrigger,
         daqEn         => '0',
         -- Outputs
         runTrigOut    => autoTrigger,
         daqTrigOut    => open);
         
   --------------------------------------------
   --     Streaming data out                 --
   --------------------------------------------   
   U_SsiPrbsTx : entity work.SsiPrbsTx
      generic map (
         GEN_SYNC_FIFO_G            => true,
         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)
      )
      port map (
         -- Master Port (mAxisClk)
         mAxisClk        => coreClk,
         mAxisRst        => axiRst,
         mAxisMaster     => userAxisMaster,
         mAxisSlave      => userAxisSlave,
         -- Trigger Signal (locClk domain)
         locClk          => coreClk,
         locRst          => axiRst,
         trig            => fullTrigger,
         packetLength    => config.packetSize,
         forceEofe       => '0',
         busy            => ssiPrbsTxBusy,
         tDest           => x"00",
         tId             => x"00");
         
end top_level;
