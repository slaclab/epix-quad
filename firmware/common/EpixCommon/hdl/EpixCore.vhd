-------------------------------------------------------------------------------
-- Title         : EPIX Core Block
-- Project       : EPXI Readout
-------------------------------------------------------------------------------
-- File          : EpixCore.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- EPIX Core Block
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.EpixTypes.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity EpixCore is
   generic (
      InterfaceType       : string := "PGP" -- PGP or ETH
   );
   port (

      -- Clocks and reset
      sysRstL             : in    std_logic;
      pgpRefCLkP          : in    std_logic;
      pgpRefClkM          : in    std_logic;
      ethRefClkP          : in    std_logic;
      ethRefClkM          : in    std_logic;

      -- Fiber Interface
      fiberTxp            : out   std_logic;
      fiberTxn            : out   std_logic;
      fiberRxp            : in    std_logic;
      fiberRxn            : in    std_logic;

      -- DAC
      dacSclk             : out   std_logic;
      dacDin              : out   std_logic;
      dacCsb              : out   std_logic;
      dacClrb             : out   std_logic;

      -- External Signals
      runTrigger          : in    std_logic;
      daqTrigger          : in    std_logic;
      mpsOut              : out   std_logic;
      triggerOut          : out   std_logic;

      -- Board IDs
      serialIdOut         : out   std_logic_vector(1 downto 0);
      serialIdEn          : out   std_logic_vector(1 downto 0);
      serialIdIn          : in    std_logic_vector(1 downto 0);

      -- Power Control
      powerEnable         : out   std_logic_vector(1 downto 0);

      -- Slow ADC
      slowAdcSclk         : out   std_logic;
      slowAdcDin          : out   std_logic;
      slowAdcCsb          : out   std_logic;
      slowAdcDout         : in    std_logic;

      -- SACI
      saciClk             : out   std_logic;
      saciSelL            : out   std_logic_vector(3 downto 0);
      saciCmd             : out   std_logic;
      saciRsp             : in    std_logic_vector(3 downto 0);

      -- Fast ADC Control
      adcSpiClk           : out   std_logic;
      adcSpiDataOut       : out   std_logic;
      adcSpiDataIn        : in    std_logic;
      adcSpiDataEn        : out   std_logic;
      adcSpiCsb           : out   std_logic_vector(2 downto 0);
      adcPdwn             : out   std_logic_vector(2 downto 0);

      -- Fast ADC Readout
      adcClkP             : out   std_logic_vector(2 downto 0);
      adcClkM             : out   std_logic_vector(2 downto 0);
      adcFClkP            : in    std_logic_vector(2 downto 0);
      adcFClkM            : in    std_logic_vector(2 downto 0);
      adcDClkP            : in    std_logic_vector(2 downto 0);
      adcDClkM            : in    std_logic_vector(2 downto 0);
      adcChP              : in    std_logic_vector(23 downto 0);
      adcChM              : in    std_logic_vector(23 downto 0);

      -- ASIC Control
      asicR0              : out   std_logic;
      asicPpmat           : out   std_logic;
      asicPpbe            : out   std_logic;
      asicGlblRst         : out   std_logic;
      asicAcq             : out   std_logic;
      asic0Dm2            : in    std_logic;
      asic0Dm1            : in    std_logic;
      asicRoClkP          : out   std_logic_vector(3 downto 0);
      asicRoClkM          : out   std_logic_vector(3 downto 0)

   );
end EpixCore;


-- Define architecture
architecture EpixCore of EpixCore is

   -- Local Signals
   signal sysClk           : std_logic;
   signal sysClkRst        : std_logic;
   signal resetReq         : std_logic;
   signal pgpRegOut        : RegSlaveOutType;
   signal pgpRegIn         : RegSlaveInType;
   signal epixConfig       : EpixConfigType;
   signal acqCount         : std_logic_vector(31 downto 0);
   signal frameTxIn        : UsBuff32InType;
   signal frameTxOut       : UsBuffOutType;
   signal pgpCmd           : CmdSlaveOutType;
   signal acqStart         : std_logic;
   signal dataSend         : std_logic;
   signal readStart        : std_logic;
   signal adcValid         : std_logic_vector(23 downto 0);
   signal adcData          : word16_array(23 downto 0);
   signal slowAdcData      : word16_array(15 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin
   
   -- Trigger control
   U_TrigControl : entity work.TrigControl 
      port map ( 
         sysClk         => sysClk,
         sysClkRst      => sysClkRst,
         runTrigger     => runTrigger,
         daqTrigger     => daqTrigger,
         pgpCmd         => pgpCmd,
         epixConfig     => epixConfig,
         acqCount       => acqCount,
         acqStart       => acqStart,
         dataSend       => dataSend,
         triggerOut     => triggerOut
      );

   -- Acq Control
   U_AcqControl : entity work.AcqControl 
      port map (
         sysClk         => sysClk,
         sysClkRst      => sysClkRst,
         epixConfig     => epixConfig,
         acqStart       => acqStart,
         readStart      => readStart,
         saciReadoutReq => saciReadoutReq,
         saciReadoutAck => saciReadoutAck,
         adcClkP        => adcClkP,
         adcClkM        => adcClkM,
         asicR0         => asicR0,
         asicPpmat      => asicPpmat,
         asicPpbe       => asicPpbe,
         asicGlblRst    => asicGlblRst,
         asicAcq        => asicAcq,
         asicRoClkP     => asicRoClkP,
         asicRoClkM     => asicRoClkM
      );

   -- ADC Control
   U_AdcReadout3x : entity work.AdcReadout3x 
      port map ( 
         sysClk         => sysClk,
         sysClkRst      => sysClkRst,
         adcValid       => adcValid,
         adcData        => adcData,
         adcFClkP       => adcFClkP,
         adcFClkM       => adcFClkM,
         adcDClkP       => adcDClkP,
         adcDClkM       => adcDClkM,
         adcChP         => adcChP,
         adcChM         => adcChM
      );

   -- Readout Control
   U_ReadoutControl : entity work.ReadoutControl 
      port map (
         sysClk         => sysClk,
         sysClkRst      => sysClkRst,
         epixConfig     => epixConfig,
         readStart      => readStart,
         dataRead       => dataRead,
         adcValid       => adcValid,
         adcData        => adcData,
         frameTxIn      => frameTxIn,
         frameTxOut     => frameTxOut,
         mpsOut         => mpsOut
      );

   -- PGP Front End
   U_PgpFrontEnd : entity work.PgpFrontEnd 
      generic map (
         InterfaceType => InterfaceType 
      ) port map ( 
         pgpRefClkP     => pgpRefClkP,
         pgpRefClkM     => pgpRefClkM,
         ethRefClkP     => ethRefClkP,
         ethRefClkM     => ethRefClkM,
         ponResetL      => sysRstL,
         resetReq       => resetReq,
         sysClk         => sysClk,
         sysClkRst      => sysClkRst,
         pgpCmd         => pgpCmd,
         pgpRegOut      => pgpRegOut,
         pgpRegIn       => pgpRegIn,
         frameTxIn      => frameTxIn,
         frameTxOut     => frameTxOut,
         pgpRxN         => fiberRxn,
         pgpRxP         => fiberRxp,
         pgpTxN         => fiberTxn,
         pgpTxP         => fiberTxp
      );

   -- Register control block
   U_RegControl : entity work.RegControl
      port map ( 
         sysClk         => sysClk,
         sysClkRst      => sysClkRst,
         pgpRegOut      => pgpRegOut,
         pgpRegIn       => pgpRegIn,
         epixConfig     => epixConfig,
         resetReq       => resetReq,
         acqCount       => acqCount,
         saciReadoutReq => saciReadoutReq,
         saciReadoutAck => saciReadoutAck,
         saciClk        => saciClk,
         saciSelL       => saciSelL,
         saciCmd        => saciCmd,
         saciRsp        => saciRsp,
         dacSclk        => dacSclk,
         dacDin         => dacDin,
         dacCsb         => dacCsb,
         dacClrb        => dacClrb,
         serialIdOut    => serialIdOut,
         serialIdEn     => serialIdEn,
         serialIdIn     => serialIdIn,
         adcSpiClk      => adcSpiClk,
         adcSpiDataOut  => adcSpiDataOut,
         adcSpiDataIn   => adcSpiDataIn,
         adcSpiDataEn   => adcSpiDataEn,
         adcSpiCsb      => adcSpiCsb,
         adcPdwn        => adcPdwn,
         powerEnable    => powerEnable,
         slowAdcData    => slowAdcData
      );

   -- OTHER
   --asic0Dm2
   --asic0Dm1

   -- Slow ADC
   U_AdcCntrl : entity work.AdcCntrl 
      port map ( 
         sysClk        => sysClk,
         sysClkRst     => sysClkRst,
         adcChanCount  => "1111",
         adcStart      => '1',
         adcData       => slowAdcData,
         adcStrobe     => open,
         adcSclk       => slowAdcSclk,
         adcDout       => slowAdcDout,
         adcCsL        => slowAdcCsb,
         adcDin        => slowAdcDin
      );

end EpixCore;

