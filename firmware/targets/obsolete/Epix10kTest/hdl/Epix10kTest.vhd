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
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
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

entity Epix10kTest is
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
      asic0Dm2            : in    std_logic;
      asic0Dm1            : in    std_logic;
      asic01RoClkP        : out   std_logic;
      asic01RoClkM        : out   std_logic;
      asic23RoClkP        : out   std_logic;
      asic23RoClkM        : out   std_logic;
      asicSync            : out   std_logic;

      -- ASIC digital outputs
      asic01DoutP         : in    std_logic;
      asic01DoutM         : in    std_logic;
      asic23DoutP         : in    std_logic;
      asic23DoutM         : in    std_logic

   );

end Epix10kTest;


-- Define architecture
architecture Epix10kTest of Epix10kTest is

   -- Local Signals
   signal serialIdOut         : std_logic_vector(1 downto 0);
   signal serialIdEn          : std_logic_vector(1 downto 0);
   signal serialIdIn          : std_logic_vector(1 downto 0);
   signal powerEnable         : std_logic_vector(7 downto 0);
   signal saciClk             : std_logic;
   signal saciSelL            : std_logic_vector(3 downto 0);
   signal saciCmd             : std_logic;
   signal saciRsp             : std_logic_vector(3 downto 0);
   signal adcSpiDataOut       : std_logic;
   signal adcSpiDataIn        : std_logic;
   signal adcSpiDataEn        : std_logic;
   signal adcPdwn             : std_logic_vector(2 downto 0);
   signal adcSpiCsb           : std_logic_vector(2 downto 0);
   signal iAdcSpiClk          : std_logic;   
   signal adcClkP             : std_logic_vector(2 downto 0);
   signal adcClkM             : std_logic_vector(2 downto 0);
   signal adcFClkP            : std_logic_vector(2 downto 0);
   signal adcFClkM            : std_logic_vector(2 downto 0);
   signal adcDClkP            : std_logic_vector(2 downto 0);
   signal adcDClkM            : std_logic_vector(2 downto 0);
   signal adcChP              : std_logic_vector(19 downto 0);
   signal adcChM              : std_logic_vector(19 downto 0);

   signal asicDout            : std_logic_vector(3 downto 0);

   signal iVguardDacSclk       : std_logic;
   signal iVguardDacDin        : std_logic;
   signal iVguardDacCsb        : std_logic;
   signal iVguardDacClrb       : std_logic;
      
   signal iSlowAdcSclk         : std_logic;
   signal iSlowAdcDin          : std_logic;
   signal iSlowAdcCsb          : std_logic;
   
   signal iMps                 : std_logic;
   signal iTgOut               : std_logic;
   
   signal outputEn            : std_logic;   
   
   signal iAsicR0             : std_logic;
   signal iAsicAcq            : std_logic;
   signal iAsicPpmat          : std_logic;
   signal iAsicPpbe           : std_logic;
   signal iAsicGlblRst        : std_logic;
   signal iAsicRoClk          : std_logic;
   signal iAsicSync           : std_logic;

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
         dacSclk              => iVguardDacSclk,
         dacDin               => iVguardDacDin,
         dacCsb               => iVguardDacCsb,
         dacClrb              => iVguardDacClrb,
         runTrigger           => runTg,
         daqTrigger           => daqTg,
         mpsOut               => iMps,
         triggerOut           => iTgOut,
         serialIdOut          => serialIdOut,
         serialIdEn           => serialIdEn,
         serialIdIn           => serialIdIn,
         powerEnable          => powerEnable,
         slowAdcSclk          => iSlowAdcSclk,
         slowAdcDin           => iSlowAdcDin,
         slowAdcCsb           => iSlowAdcCsb,
         slowAdcDout          => slowAdcDout,
         saciClk              => saciClk,
         saciSelL             => saciSelL,
         saciCmd              => saciCmd,
         saciRsp              => saciRsp,
         adcSpiClk            => iAdcSpiClk,
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
         adcChM               => adcChM,
         asicR0               => iAsicR0,
         asicPpmat            => iAsicPpmat,
         asicPpbe             => iAsicPpbe,
         asicGlblRst          => iAsicGlblRst,
         asicAcq              => iAsicAcq,
         asic0Dm2             => asic0Dm2,
         asic0Dm1             => asic0Dm1,
         asicRoClk            => iAsicRoClk,
         asicDout             => asicDout,
         asicSync             => iAsicSync
      );

   -- Serial ID
   serialIdIn(0)  <= serialNumberIo;
   serialNumberIo <= serialIdOut(0) when serialIdEn(0) = '0' else 'Z';
   serialIdIn(1)  <= snIoAdcCard;
   snIoAdcCard    <= serialIdOut(1) when serialIdEn(1) = '0' else 'Z';

   -- Power control
   analogCardDigPwrEn <= powerEnable(0);
   analogCardAnaPwrEn <= powerEnable(1);
   outputEn           <= powerEnable(2);

   -- Connector signals
   mps   <= iMps when outputEn = '1' else 'Z';
   tgOut <= iTgOut when outputEn = '1' else 'Z';   
   
   -- SACI
   asicSaciCmd    <= saciCmd when outputEn = '1' else 'Z';
   asicSaciClk    <= saciClk when outputEn = '1' else 'Z';
   asic0SaciSel   <= saciSelL(0) when outputEn = '1' else 'Z';
   asic1SaciSel   <= saciSelL(1) when outputEn = '1' else 'Z';
   asic2SaciSel   <= saciSelL(2) when outputEn = '1' else 'Z';
   asic3SaciSel   <= saciSelL(3) when outputEn = '1' else 'Z';
   saciRsp(0)     <= asic0SaciRsp;
   saciRsp(1)     <= asic1SaciRsp;
   saciRsp(2)     <= asic2SaciRsp;
   saciRsp(3)     <= asic3SaciRsp;

   -- Guard ring DAC
   vguardDacSclk  <= iVguardDacSclk when outputEn = '1' else 'Z';
   vguardDacDin   <= iVguardDacDin when outputEn = '1' else 'Z'; 
   vguardDacCsb   <= iVguardDacCsb when outputEn = '1' else 'Z'; 
   vguardDacClrb  <= iVguardDacClrb when outputEn = '1' else 'Z';   

   -- Slow ADC
   slowAdcSclk    <= iSlowAdcSclk when outputEn = '1' else 'Z';
   slowAdcDin     <= iSlowAdcDin when outputEn = '1' else 'Z';
   slowAdcCsb     <= iSlowAdcCsb when outputEn = '1' else 'Z';   
   
   -- ADC Configuration
   adcSpiClk    <= iAdcSpiClk when outputEn = '1' else 'Z';
   adcSpiData   <= '0' when adcSpiDataOut = '0' and adcSpiDataEn = '1' and outputEn = '1' else 'Z';
   adcSpiDataIn <= adcSpiData;
   adc0SpiCsb   <= adcSpiCsb(0) when outputEn = '1' else 'Z';
   adc1SpiCsb   <= adcSpiCsb(1) when outputEn = '1' else 'Z';
   adcMonSpiCsb <= adcSpiCsb(2) when outputEn = '1' else 'Z';
   adc0Pdwn     <= adcPdwn(0) when outputEn = '1' else '0';
   adc1Pdwn     <= adcPdwn(1) when outputEn = '1' else '0';
   adcMonPdwn   <= adcPdwn(2) when outputEn = '1' else '0';

   -- ADC 0 Connections
   adc0ClkP            <= adcClkP(0);
   adc0ClkM            <= adcClkM(0);
   adcDClkP(0)         <= adc0DoClkP;
   adcDClkM(0)         <= adc0DoClkM;
   adcFClkP(0)         <= adc0FrameClkP;
   adcFClkM(0)         <= adc0FrameClkM;
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
   adcDClkM(1)         <= adc1DoClkM;
   adcFClkP(1)         <= adc1FrameClkP;
   adcFClkM(1)         <= adc1FrameClkM;
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
   adcDClkM(2)         <= adcMonDoClkM;
   adcFClkP(2)         <= adcMonFrameClkP;
   adcFClkM(2)         <= adcMonFrameClkM;
   adcChP(16)          <= asic0AdcDoMonP;
   adcChM(16)          <= asic0AdcDoMonM;
   adcChP(17)          <= asic1AdcDoMonP;
   adcChM(17)          <= asic1AdcDoMonM;
   adcChP(18)          <= asic2AdcDoMonP;
   adcChM(18)          <= asic2AdcDoMonM;
   adcChP(19)          <= asic3AdcDoMonP;
   adcChM(19)          <= asic3AdcDoMonM;

   -- ASIC Connections

   -- ASIC control signals
   U_AsicClk01 : OBUFTDS port map ( I => iAsicRoClk, T => not(outputEn), O => asic01RoClkP, OB => asic01RoClkM );
   U_AsicClk23 : OBUFTDS port map ( I => iAsicRoClk, T => not(outputEn), O => asic23RoClkP, OB => asic23RoClkM );

   asicR0      <= iAsicR0      when outputEn = '1' else 'Z';
   asicAcq     <= iAsicAcq     when outputEn = '1' else 'Z';
   asicPpmat   <= iAsicPpmat   when outputEn = '1' else 'Z';
   asicPpbe    <= iAsicPpbe    when outputEn = '1' else 'Z';
   asicGlblRst <= iAsicGlblRst when outputEn = '1' else 'Z';
   asicSync    <= iAsicSync    when outputEn = '1' else 'Z';

   -- Buffers for the digital ASIC outputs
   -- On first carrier for ePix10k, ASICs 01 share a Dout, as do ASICs 23
   U_AsicDout0 : IBUFDS port map ( I => asic01DoutP, IB => asic01DoutM, O => asicDout(0) );
   asicDout(1) <= asicDout(0);
   U_AsicDout2 : IBUFDS port map ( I => asic23DoutP, IB => asic23DoutM, O => asicDout(2) );
   asicDout(3) <= asicDout(2);

end Epix10kTest;

