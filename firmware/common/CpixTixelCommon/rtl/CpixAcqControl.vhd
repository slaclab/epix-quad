-------------------------------------------------------------------------------
-- Title      : Cpix detector acquisition control
-------------------------------------------------------------------------------
-- File       : CpixAcqControl.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 01/19/2016
-- Last update: 01/19/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;


library unisim;
use unisim.vcomponents.all;

entity CpixAcqControl is
   generic (
      TPD_G                : time := 1 ns
   );
   port (
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      acqStart        : in  std_logic;

      acqBusy         : out std_logic;
      readDone        : in  std_logic;

      epixConfig      : in  epixConfigType;

      saciReadoutReq  : out std_logic;
      saciReadoutAck  : in  std_logic;

      asicEnA         : out std_logic;
      asicEnB         : out std_logic;
      asicVid         : out std_logic;
      asicPPbe        : out std_logic;
      asicPpmat       : out std_logic;
      asicR0          : out std_logic;
      asicSRO         : out std_logic;
      asicGlblRst     : out std_logic;
      asicSync        : out std_logic;
      asicAcq         : out std_logic
   );
end CpixAcqControl;

architecture rtl of CpixAcqControl is
   
   TYPE STATE_TYPE IS (IDLE_S, WAIT_SRO_S, SRO_S);
   signal state, next_state   : STATE_TYPE; 
   
   signal delayCnt         : natural;
   signal delaySet         : natural;
   signal delayCntRst      : std_logic;
   constant sroDly         : natural := 1000;
   signal acqStartSys      : std_logic;
   
begin

   U_AcqStartSys : entity work.SynchronizerEdge
   port map (
      clk        => sysClk,
      rst        => sysClkRst,
      dataIn     => acqStart,
      risingEdge => acqStartSys
   );

   acqBusy <= '0';
   saciReadoutReq <= '0';
   
   --MUXes for manual control of ASIC signals
   asicGlblRst <= '1'                    when epixConfig.manualPinControl(0) = '0' else
                  epixConfig.asicPins(0) when epixConfig.manualPinControl(0) = '1' else
                  'X';
   asicAcq     <= '0'                    when epixConfig.manualPinControl(1) = '0' else
                  epixConfig.asicPins(1) when epixConfig.manualPinControl(1) = '1' else
                  'X';
   asicR0      <= '1'                    when epixConfig.manualPinControl(2) = '0' else
                  epixConfig.asicPins(2) when epixConfig.manualPinControl(2) = '1' else
                  'X';
   asicPpmat   <= '1'                    when epixConfig.manualPinControl(3) = '0' else
                  epixConfig.asicPins(3) when epixConfig.manualPinControl(3) = '1' else
                  'X';
   asicPPbe    <= '1'                    when epixConfig.manualPinControl(4) = '0' else
                  epixConfig.asicPins(4) when epixConfig.manualPinControl(4) = '1' else
                  'X';
   
   
   
   asicEnA <= '0';
   asicEnB <= '0';
   asicVid <= '0';
   asicSync <= '0';
   
   
   fsm_seq_p: process ( sysClk ) 
   begin
      -- FSM state register
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            state <= IDLE_S               after TPD_G;
         else
            state <= next_state           after TPD_G;
         end if;
      end if;
      
      -- Generic delay counter
      if rising_edge(sysClk) then
         if delayCntRst = '1' then
            delayCnt <= delaySet          after TPD_G;
         elsif delayCnt /= 0 then
            delayCnt <= delayCnt - 1      after TPD_G;
         end if;
      end if;
      
   end process;
   

   fsm_cmb_p: process (state, acqStartSys, delayCnt) 
   begin
      next_state <= state;
      delayCntRst <= '1';
      delaySet <= 0;
      asicSRO <= '0';
      
      
      case state is
      
         when IDLE_S =>
            if acqStartSys = '1' then
               delayCntRst <= '1';
               delaySet <= sroDly;
               next_state <= WAIT_SRO_S;
            end if;
      
         when WAIT_SRO_S =>
            delayCntRst <= '0';
            if delayCnt = 0 then
               delayCntRst <= '1';
               delaySet <= sroDly;
               next_state <= SRO_S;
            end if;
         
         when SRO_S =>
            asicSRO <= '1';
            delayCntRst <= '0';
            if delayCnt = 0 then
               next_state <= IDLE_S;
            end if;
            
         when others =>
            next_state <= IDLE_S;
      
      end case;
      
   end process;
   
   
end rtl;
