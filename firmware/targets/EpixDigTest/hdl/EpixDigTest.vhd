-------------------------------------------------------------------------------
-- Title         : EPIX Digital Test Top Level Block
-- Project       : EPXI Readout
-------------------------------------------------------------------------------
-- File          : EpixDigTop.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 06/03/2013
-------------------------------------------------------------------------------
-- Description:
-- EPIX Digital Test Top Level Block
-------------------------------------------------------------------------------
-- Copyright (c) 2013 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 06/03/2013: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity EpixDigTest is
   port ( 

      -- Clocks and reset
      sysRstL             : in    std_logic;
      refClk156_25mhzP    : in    std_logic;
      refClk156_25mhzM    : in    std_logic;
      refClk125mhzP       : in    std_logic;
      refClk125mhzM       : in    std_logic;

      -- Fiber Interface
      fiberTxp            : out   std_logic;
      fiberTxn            : out   std_logic;
      fiberRxp            : in    std_logic;
      fiberRxn            : in    std_logic;

      -- DAC
      vguardDacSclk       : out   std_logic;
      vguardDacDin        : out   std_logic;
      vguardDacCsb        : out   std_logic;
      vguardDacClrb       : out   std_logic;

      -- External Signals
      runTg               : in    std_logic;
      daqTg               : in    std_logic;
      mps                 : out   std_logic;
      tgOut               : out   std_logic;

      -- Board IDs
      snIoAdcCard         : inout std_logic;
      serialNumberIo      : inout std_logic;

      -- Power Control
      analogCardDigPwrEn  : out   std_logic;
      analogCardAnaPwrEn  : out   std_logic;

      -- Slow ADC
      slowAdcSclk         : out   std_logic;
      slowAdcDin          : out   std_logic;
      slowAdcCsb          : out   std_logic;
      slowAdcDout         : in    std_logic;

      -- Fast ADC Control
      adcSpiClk           : out   std_logic;
      adcSpiData          : inout std_logic;
      adc0SpiCsb          : out   std_logic;
      adc1SpiCsb          : out   std_logic;
      adcMonSpiCsb        : out   std_logic;
      adc0Pdwn            : out   std_logic;
      adc1Pdwn            : out   std_logic;
      adcMonPdwn          : out   std_logic;

      -- ASIC SACI Interface
      asicSaciCmd         : out   std_logic;
      asicSaciClk         : out   std_logic;
      asic3SaciSel        : out   std_logic;
      asic3SaciRsp        : in    std_logic;
      asic2SaciSel        : out   std_logic;
      asic2SaciRsp        : in    std_logic;
      asic1SaciSel        : out   std_logic;
      asic1SaciRsp        : in    std_logic;
      asic0SaciSel        : out   std_logic;
      asic0SaciRsp        : in    std_logic;

      -- Monitoring ADCs
      adcMonClkP          : out   std_logic;
      adcMonClkM          : out   std_logic;
      adcMonDoClkP        : in    std_logic;
      adcMonDoClkM        : in    std_logic;
      adcMonFrameClkP     : in    std_logic;
      adcMonFrameClkM     : in    std_logic;
      asic0AdcDoMonP      : in    std_logic;
      asic0AdcDoMonM      : in    std_logic;
      asic1AdcDoMonP      : in    std_logic;
      asic1AdcDoMonM      : in    std_logic;
      asic2AdcDoMonP      : in    std_logic;
      asic2AdcDoMonM      : in    std_logic;
      asic3AdcDoMonP      : in    std_logic;
      asic3AdcDoMonM      : in    std_logic;

      -- ASIC 0/1 Data
      adc0ClkP            : out   std_logic;
      adc0ClkM            : out   std_logic;
      adc0DoClkP          : in    std_logic;
      adc0DoClkM          : in    std_logic;
      adc0FrameClkP       : in    std_logic;
      adc0FrameClkM       : in    std_logic;
      asic0AdcDoAP        : in    std_logic;
      asic0AdcDoAM        : in    std_logic;
      asic0AdcDoBP        : in    std_logic;
      asic0AdcDoBM        : in    std_logic;
      asic0AdcDoCP        : in    std_logic;
      asic0AdcDoCM        : in    std_logic;
      asic0AdcDoDP        : in    std_logic;
      asic0AdcDoDM        : in    std_logic;
      asic1AdcDoAP        : in    std_logic;
      asic1AdcDoAM        : in    std_logic;
      asic1AdcDoBP        : in    std_logic;
      asic1AdcDoBM        : in    std_logic;
      asic1AdcDoCP        : in    std_logic;
      asic1AdcDoCM        : in    std_logic;
      asic1AdcDoDP        : in    std_logic;
      asic1AdcDoDM        : in    std_logic;

      -- ASIC 2/3 Data
      adc1ClkP            : out   std_logic;
      adc1ClkM            : out   std_logic;
      adc1DoClkP          : in    std_logic;
      adc1DoClkM          : in    std_logic;
      adc1FrameClkP       : in    std_logic;
      adc1FrameClkM       : in    std_logic;
      asic2AdcDoAP        : in    std_logic;
      asic2AdcDoAM        : in    std_logic;
      asic2AdcDoBP        : in    std_logic;
      asic2AdcDoBM        : in    std_logic;
      asic2AdcDoCP        : in    std_logic;
      asic2AdcDoCM        : in    std_logic;
      asic2AdcDoDP        : in    std_logic;
      asic2AdcDoDM        : in    std_logic;
      asic3AdcDoAP        : in    std_logic;
      asic3AdcDoAM        : in    std_logic;
      asic3AdcDoBP        : in    std_logic;
      asic3AdcDoBM        : in    std_logic;
      asic3AdcDoCP        : in    std_logic;
      asic3AdcDoCM        : in    std_logic;
      asic3AdcDoDP        : in    std_logic;
      asic3AdcDoDM        : in    std_logic;

      -- ASIC Control
      asicR0              : out   std_logic;
      asicPpmat           : out   std_logic;
      asicPpbe            : out   std_logic;
      asicGlblRst         : out   std_logic;
      asicAcq             : out   std_logic;
      asic0Dm2            : out   std_logic;
      asic0Dm1            : out   std_logic;
      asic0RoClkP         : out   std_logic;
      asic0RoClkM         : out   std_logic;
      asic1RoClkP         : out   std_logic;
      asic1RoClkM         : out   std_logic;
      asic2RoClkP         : out   std_logic;
      asic2RoClkM         : out   std_logic;
      asic3RoClkP         : out   std_logic;
      asic3RoClkM         : out   std_logic
   );

end EpixDigTest;


-- Define architecture
architecture EpixDigTest of EpixDigTest is

   -- Local Signals
   signal serialIdOut         : std_logic_vector(1 downto 0);
   signal serialIdEn          : std_logic_vector(1 downto 0);
   signal serialIdIn          : std_logic_vector(1 downto 0);
   signal powerEnable         : std_logic_vector(1 downto 0);
   signal saciClk             : std_logic;
   signal saciSelL            : std_logic_vector(3 downto 0);
   signal saciCmd             : std_logic;
   signal saciRsp             : std_logic_vector(3 downto 0);
   signal adcSpiDataOut       : std_logic;
   signal adcSpiDataIn        : std_logic;
   signal adcSpiDataEn        : std_logic;
   signal adcPdwn             : std_logic_vector(2 downto 0);
   signal adcSpiCsb           : std_logic_vector(2 downto 0);
   signal adcClkP             : std_logic_vector(2 downto 0);
   signal adcClkM             : std_logic_vector(2 downto 0);
   signal adcFClkP            : std_logic_vector(2 downto 0);
   signal adcFClkM            : std_logic_vector(2 downto 0);
   signal adcDClkP            : std_logic_vector(2 downto 0);
   signal adcDClkM            : std_logic_vector(2 downto 0);
   signal adcChP              : std_logic_vector(23 downto 0);
   signal adcChM              : std_logic_vector(23 downto 0);
   signal asicRoClkP          : std_logic_vector(3 downto 0);
   signal asicRoClkM          : std_logic_vector(3 downto 0)

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Core
   U_EpixCore: entity work.EpixCore
      generic map (
         InterfaceType => "PGP"
      ) port map (
         sysRstL              => sysRstL,
         pgpRefCLkP           => refClk156_25mhzP,
         pgpRefClkM           => refClk156_25mhzM,
         ethRefClkP           => refClk125mhzP,
         ethRefClkM           => refClk125mhzM,
         fiberTxp             => fiberTxp,
         fiberTxn             => fiberTxn,
         fiberRxp             => fiberRxp,
         fiberRxn             => fiberRxn,
         dacSclk              => vguardDacSclk,
         dacDin               => vguardDacDin,
         dacCsb               => vguardDacCsb,
         dacClrb              => vguardDacClrb,
         runTrigger           => runTg,
         daqTrigger           => daqTg,
         mpsOut               => mps,
         triggerOut           => tgOut,
         serialIdOut          => serialIdOut,
         serialIdEn           => serialIdEn,
         serialIdIn           => serialIdIn,
         powerEnable          => powerEnable,
         slowAdcSclk          => slowAdcSclk,
         slowAdcDin           => slowAdcDin,
         slowAdcCsb           => slowAdcCsb,
         slowAdcDout          => slowAdcDout,
         saciClk              => saciClk,
         saciSelL             => saciSelL,
         saciCmd              => saciCmd,
         saciRsp              => saciRsp,
         adcSpiClk            => adcSpiClk,
         adcSpiDataOut        => adcSpiDataOut,
         adcSpiDataEn         => adcSpiDataEn,
         adcSpiDataIn         => adcSpiDataIn,
         adcSpiCsb            => adcSpiCsb,
         adcPdwn              => adcPdwn,
         adcClkP              => adcClkP,
         adcClkM              => adcClkM,
         adcFClkP             => adcFClkP,
         adcFClkM             => adcFClkM,
         adcDClkP             => adcDClkP,
         adcDClkM             => adcDClkM,
         adcChP               => adcChP,
         adcChM               => adcChM
         asicR0               => asicR0,
         asicPpmat            => asicPpmat,
         asicPpbe             => asicPpbe,
         asicGlblRst          => asicGlblRst,
         asicAcq              => asicAcq,
         asic0Dm2             => asic0Dm2,
         asic0Dm1             => asic0Dm1,
         asicRoClkP           => asicRoClkP,
         asicRoClkM           => asicRoClkM
      );

   -- Serial ID
   serialIdIn(0)  <= serialNumberIo;
   serialNumberIo <= serialIdOut(0) when serialIdEn = '1' else 'Z';
   serialIdIn(1)  <= snIoAdcCard;
   snIoAdcCard    <= serialIdOut(1) when serialIdEn = '1' else 'Z';

   -- Power control
   analogCardDigPwrEn <= powerEnable(0);
   analogCardAnaPwrEn <= powerEnable(1);

   -- SACI
   asicSaciCmd    <= saciCmd;
   asicSaciClk    <= saciClk;
   asic0SaciSel   <= saciSelL(0);
   asic1SaciSel   <= saciSelL(1);
   asic2SaciSel   <= saciSelL(2);
   asic3SaciSel   <= saciSelL(3);
   saciRsp(0)     <= asic0SaciRsp;
   saciRsp(0)     <= asic1SaciRsp;
   saciRsp(0)     <= asic2SaciRsp;
   saciRsp(0)     <= asic3SaciRsp;

   -- ADC Configuration
   ascSpiData   <= '0' when adcSpiDataOut = '0' and adcSpiDataEn = '1' else 'Z';
   adcSpiDataIn <= adcSpiData;
   adc0SpiCsb   <= adcSpiCsb(0);
   adc1SpiCsb   <= adcSpiCsb(1);
   adcMonSpiCsb <= adcSpiCsb(2);
   adc0Pdwn     <= adcPdwn(0);
   adc1Pdwn     <= adcPdwn(1);
   adcMonPdwn   <= adcPdwn(2);

   -- ADC 0 Connections
   adc0ClkP            <= adcClkP(0);
   adc0ClkM            <= adcClkM(0);
   adcDClkP(0)         <= adc0DoClkP;
   adcDClkP(0)         <= adc0DoClkM;
   adcFClkP(0)         <= adc0FrameClkP;
   adcFClkP(0)         <= adc0FrameClkM;
   adcChP(0)           <= asic0AdcDoAP;
   adcChM(0)           <= asic0AdcDoAM;
   adcChP(1)           <= asic0AdcDoBP;
   adcChM(1)           <= asic0AdcDoBM;
   adcChP(2)           <= asic0AdcDoCP;
   adcChM(2)           <= asic0AdcDoCM;
   adcChP(3)           <= asic0AdcDoDP;
   adcChM(3)           <= asic0AdcDoDM;
   adcChP(4)           <= asic1AdcDoAP;
   adcChM(4)           <= asic1AdcDoAM;
   adcChP(5)           <= asic1AdcDoBP;
   adcChM(5)           <= asic1AdcDoBM;
   adcChP(6)           <= asic1AdcDoCP;
   adcChM(6)           <= asic1AdcDoCM;
   adcChP(7)           <= asic1AdcDoDP;
   adcChM(7)           <= asic1AdcDoDM;

   -- ADC 1 Connections
   adc1ClkP            <= adcClkP(1);
   adc1ClkM            <= adcClkM(1);
   adcDClkP(1)         <= adc1DoClkP;
   adcDClkP(1)         <= adc1DoClkM;
   adcFClkP(1)         <= adc1FrameClkP;
   adcFClkP(1)         <= adc1FrameClkM;
   adcChP(8)           <= asic2AdcDoAP;
   adcChM(8)           <= asic2AdcDoAM;
   adcChP(9)           <= asic2AdcDoBP;
   adcChM(9)           <= asic2AdcDoBM;
   adcChP(10)          <= asic2AdcDoCP;
   adcChM(10)          <= asic2AdcDoCM;
   adcChP(11)          <= asic2AdcDoDP;
   adcChM(11)          <= asic2AdcDoDM;
   adcChP(12)          <= asic3AdcDoAP;
   adcChM(12)          <= asic3AdcDoAM;
   adcChP(13)          <= asic3AdcDoBP;
   adcChM(13)          <= asic3AdcDoBM;
   adcChP(14)          <= asic3AdcDoCP;
   adcChM(14)          <= asic3AdcDoCM;
   adcChP(15)          <= asic3AdcDoDP;
   adcChM(15)          <= asic3AdcDoDM;

   -- ADC 2 Connections
   adcMonClkP          <= adcClkP(2);
   adcMonClkM          <= adcClkM(2);
   adcDClkP(2)         <= adcMonDoClkP;
   adcDClkP(2)         <= adcMonDoClkM;
   adcFClkP(2)         <= adcMonFrameClkP;
   adcFClkP(2)         <= adcMonFrameClkM;
   adcChP(16)          <= asic0AdcDoMonP;
   adcChM(16)          <= asic0AdcDoMonM;
   adcChP(17)          <= asic1AdcDoMonP;
   adcChM(17)          <= asic1AdcDoMonM;
   adcChP(18)          <= asic2AdcDoMonP;
   adcChM(18)          <= asic2AdcDoMonM;
   adcChP(19)          <= asic3AdcDoMonP;
   adcChM(19)          <= asic3AdcDoMonM;
   adcChP(20)          <= '0';
   adcChM(20)          <= '1';
   adcChP(21)          <= '0';
   adcChM(21)          <= '1';
   adcChP(22)          <= '0';
   adcChM(22)          <= '1';
   adcChP(23)          <= '0';
   adcChM(23)          <= '1';

   -- ASIC Connections
   asic0RoClkP         <= asicRoClkP(0);
   asic0RoClkM         <= asicRoClkM(0);
   asic1RoClkP         <= asicRoClkP(1);
   asic1RoClkM         <= asicRoClkM(1);
   asic2RoClkP         <= asicRoClkP(2);
   asic2RoClkM         <= asicRoClkM(2);
   asic3RoClkP         <= asicRoClkP(3);
   asic3RoClkM         <= asicRoClkM(3);

end EpixDigTest;

