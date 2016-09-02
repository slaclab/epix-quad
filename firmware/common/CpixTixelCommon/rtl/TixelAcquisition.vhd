-------------------------------------------------------------------------------
-- Title      : Tixel detector acquisition control
-------------------------------------------------------------------------------
-- File       : TixelAcquisition.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 01/19/2016
-- Last update: 01/19/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixPkgGen2.all;
use work.TixelPkg.all;


library unisim;
use unisim.vcomponents.all;

entity TixelAcquisition is
   generic (
      TPD_G           : time := 1 ns;
      NUMBER_OF_ASICS : natural := 2
   );
   port (
   
      -- global signals
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;
      
      -- trigger
      acqStart        : in  std_logic;

      -- control/status signals (byteClk)
      cntAcquisition  : out std_logic_vector(31 downto 0);
      cntSequence     : out std_logic_vector(31 downto 0);
      cntReadout      : out std_logic_vector( 3 downto 0);
      frameReq        : out std_logic;
      frameAck        : in  std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
      frameErr        : in  std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
      headerAck       : in  std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
      timeoutReq      : out std_logic;
      epixConfig      : in  EpixConfigType;
      tixelConfig     : in  TixelConfigType;
      saciReadoutReq  : out std_logic;
      saciReadoutAck  : in  std_logic;
      
      -- ASICs signals
      asicPPbe        : out std_logic;
      asicPpmat       : out std_logic;
      asicTpulse      : out std_logic;
      asicStart       : out std_logic;
      asicR0          : out std_logic;
      asicGlblRst     : out std_logic;
      asicSync        : out std_logic;
      asicAcq         : out std_logic
   );
end TixelAcquisition;

architecture rtl of TixelAcquisition is
   
   constant ASIC_TIMEOUT_C    : natural := 50000; --500 us at 100 MHz
   
   TYPE STATE_TYPE IS (
      IDLE_S, 
      WAIT_R0_S, 
      R0_S, 
      WAIT_START_S, 
      START_S, 
      WAIT_TPULSE_S, 
      TPULSE_S, 
      WAIT_ACQ_S, 
      ACQ_S, 
      WAIT_READOUT_S, 
      SYNC_S, 
      SACI_SYNC_S,
      TIMEOUT_S,
      WAIT_HDR_TX_S
   );
   signal state, next_state   : STATE_TYPE; 
   
   signal rdoutCnt      : natural;
   signal rdoutCntEn    : std_logic;
   signal rdoutCntRst   : std_logic;
   signal delayCnt      : natural;
   signal delayCntRst   : std_logic;
   signal acqStartSys   : std_logic;
   
   signal frameAckSync  : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal frameErrSync  : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal headerAckSync : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   
   signal frameAckMask  : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal frameErrMask  : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal headerAckMask : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   
   signal acqCnt     : unsigned(31 downto 0);
   signal seqCnt     : unsigned(31 downto 0);
   signal acqCntEn   : std_logic;
   signal seqCntEn   : std_logic;
   
   signal readouts      : unsigned(3 downto 0);
   signal runToR0       : unsigned(31 downto 0);
   signal r0ToStart     : unsigned(31 downto 0);
   signal startToTpulse : unsigned(31 downto 0);
   signal tpulseToAcq   : unsigned(31 downto 0);
   
   signal iAsicR0       : std_logic;
   signal iAsicStart    : std_logic;
   signal iAsicTpulse   : std_logic;
   signal iAsicAcq      : std_logic;
   signal iAsicSync     : std_logic;
   
begin

   cntAcquisition  <= std_logic_vector(acqCnt);
   cntSequence     <= std_logic_vector(seqCnt);

   U_AcqStartSys : entity work.SynchronizerEdge
   port map (
      clk        => sysClk,
      rst        => sysClkRst,
      dataIn     => acqStart,
      risingEdge => acqStartSys
   );
   
   --MUXes for manual control of ASIC signals
   asicGlblRst <= 
      '1'                     when tixelConfig.tixelAsicPinControl(0) = '0' else
      tixelConfig.tixelAsicPins(0);
   asicAcq <= 
      iAsicAcq                when tixelConfig.tixelAsicPinControl(1) = '0' else
      tixelConfig.tixelAsicPins(1);
   asicR0 <=   
      iAsicR0                 when tixelConfig.tixelAsicPinControl(2) = '0' else
      tixelConfig.tixelAsicPins(2);
   asicTpulse <=   
      iAsicTpulse             when tixelConfig.tixelAsicPinControl(3) = '0' else
      tixelConfig.tixelAsicPins(3);
   asicStart <=   
      iAsicStart              when tixelConfig.tixelAsicPinControl(4) = '0' else
      tixelConfig.tixelAsicPins(4);
   asicPpmat <=
      '1'                     when tixelConfig.tixelAsicPinControl(5) = '0' else
      tixelConfig.tixelAsicPins(5);
   asicPPbe <= 
      '1'                     when tixelConfig.tixelAsicPinControl(6) = '0' else
      tixelConfig.tixelAsicPins(6);
   
   asicSync <= 
      iAsicSync               when tixelConfig.tixelSyncMode = "00" else      -- sync pin used as ASIC sync
      '0'                     when tixelConfig.tixelSyncMode = "01" else      -- saci command used as ASIC sync
      '1'                     when tixelConfig.tixelSyncMode = "10" else      -- saci command used as ASIC sync
      '0';
   
   -- apply ASIC mask to handshake signals
   Mask_gen: for i in NUMBER_OF_ASICS-1 downto 0 generate
      frameAckMask(i) <= frameAck(i) or not epixConfig.asicMask(i);
      headerAckMask(i) <= headerAck(i) or not epixConfig.asicMask(i);
      frameErrMask(i) <= frameErr(i) and epixConfig.asicMask(i);
   end generate;
   
   
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
      
      -- synchronizers
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            frameAckSync <= (others=>'0')    after TPD_G;
            frameErrSync <= (others=>'0')    after TPD_G;
            headerAckSync <= (others=>'0')   after TPD_G;
         else
            frameAckSync <= frameAckMask     after TPD_G;
            frameErrSync <= frameErrMask     after TPD_G;
            headerAckSync <= headerAckMask   after TPD_G;
         end if;
      end if;
      
      -- acquisition counter
      if rising_edge(sysClk) then
         if epixConfig.acqCountReset = '1' or sysClkRst = '1' then
            acqCnt <= (others=>'0')          after TPD_G;
         elsif acqCntEn = '1' then
            acqCnt <= acqCnt + 1             after TPD_G;
         end if;
      end if;
      
      -- sequence counter
      if rising_edge(sysClk) then
         if epixConfig.seqCountReset = '1' or sysClkRst = '1' then
            seqCnt <= (others=>'0')          after TPD_G;
         elsif seqCntEn = '1' then
            seqCnt <= seqCnt + 1             after TPD_G;
         end if;
      end if;
      
      -- Generic delay counter
      if rising_edge(sysClk) then
         if delayCntRst = '1' then
            delayCnt <= 0                 after TPD_G;
         else
            delayCnt <= delayCnt + 1      after TPD_G;
         end if;
      end if;
      
      -- readouts counter
      if rising_edge(sysClk) then
         if rdoutCntRst = '1' then
            rdoutCnt <= 0                  after TPD_G;
         elsif rdoutCntEn = '1' then
            rdoutCnt <= rdoutCnt + 1        after TPD_G;
         end if;
      end if;
      
   end process;
   
   readouts <= unsigned(tixelConfig.tixelReadouts);
   runToR0 <= unsigned(tixelConfig.tixelRunToR0);
   r0ToStart <= unsigned(tixelConfig.tixelR0ToStart);
   startToTpulse <= unsigned(tixelConfig.tixelStartToTpulse);
   tpulseToAcq <= unsigned(tixelConfig.tixelTpulseToAcq);
   
   cntReadout <= std_logic_vector(to_unsigned(rdoutCnt,4));

   fsm_cmb_p: process (
      state, acqStartSys, frameAckSync, headerAckSync, frameErrSync, delayCnt, rdoutCnt,
      readouts, runToR0, r0ToStart, startToTpulse, tpulseToAcq, saciReadoutAck, epixConfig
   ) 
   begin
      next_state <= state;
      delayCntRst <= '0';
      rdoutCntRst <= '0';
      rdoutCntEn <= '0';
      iAsicR0 <= '1';
      iAsicStart <= '0';
      iAsicTpulse <= '0';
      iAsicAcq <= '0';
      iAsicSync <= '0';
      saciReadoutReq <= '0';
      seqCntEn <= '0';
      acqCntEn <= '0';
      frameReq <= '0';
      timeoutReq <= '0';
      
      
      case state is
         
         when IDLE_S =>
            if acqStartSys = '1' then
               next_state <= WAIT_R0_S;
            end if;
         
         when WAIT_R0_S =>
            if delayCnt >= to_integer(runToR0) then
               delayCntRst <= '1';
               next_state <= R0_S;
            end if;
         
         when R0_S =>
            iAsicR0 <= '0';
            if delayCnt >= 4 then
               delayCntRst <= '1';
               next_state <= WAIT_START_S;
            end if;
         
         when WAIT_START_S =>
            if delayCnt >= to_integer(r0ToStart) then
               delayCntRst <= '1';
               next_state <= START_S;
            end if;
         
         when START_S =>
            iAsicStart <= '1';
            if delayCnt >= 4 then
               acqCntEn <= '1';        -- acq counts ASIC's ACQ pulses
               delayCntRst <= '1';
               next_state <= WAIT_TPULSE_S;
            end if;
         
         when WAIT_TPULSE_S =>
            if delayCnt >= to_integer(startToTpulse) then
               delayCntRst <= '1';
               next_state <= TPULSE_S;
            end if;
            
         when TPULSE_S =>
            iAsicTpulse <= '1';
            if delayCnt >= 4 then
               delayCntRst <= '1';
               rdoutCntRst <= '1';
               if tixelConfig.tixelSyncMode = "01" then
                  next_state <= SACI_SYNC_S;
               else
                  next_state <= SYNC_S;
               end if;
            end if;
         
         
         when SYNC_S =>
            iAsicSync <= '1';
            if delayCnt >= 1000 then
               if epixConfig.daqTriggerEnable = '1' then
                  delayCntRst <= '1';
                  next_state <= WAIT_ACQ_S;
               else
                  next_state <= IDLE_S;
               end if;
            end if;
         
         when SACI_SYNC_S =>
            saciReadoutReq <= '1';
            if saciReadoutAck = '1' then
               saciReadoutReq <= '0';
               if epixConfig.daqTriggerEnable = '1' then
                  delayCntRst <= '1';
                  next_state <= WAIT_ACQ_S;
               else
                  next_state <= IDLE_S;
               end if;
            end if;
         
         when WAIT_ACQ_S =>
            if delayCnt >= to_integer(tpulseToAcq) then
               delayCntRst <= '1';
               next_state <= WAIT_HDR_TX_S;
            end if;
         
         when WAIT_HDR_TX_S =>
            delayCntRst <= '1';
            frameReq <= '1';
            -- wait for the headers to be transmitted before requesting the ASIC to start the readout
            if unsigned(headerAckSync) = to_unsigned(2**NUMBER_OF_ASICS-1, NUMBER_OF_ASICS) then
               next_state <= ACQ_S;
            end if;
         
         when ACQ_S =>
            iAsicAcq <= '1';
            if delayCnt >= 4 then
               seqCntEn <= '1';        -- sequence counter counts all ACQ pulses, even when EOFE will be asserted
               delayCntRst <= '1';
               next_state <= WAIT_READOUT_S;
            end if;
            
         when WAIT_READOUT_S =>
            -- wait for all Framers to complete the ASIC readout or timeout
            if delayCnt >= ASIC_TIMEOUT_C then
               next_state <= TIMEOUT_S;
            elsif unsigned(frameAckSync) = to_unsigned(2**NUMBER_OF_ASICS-1, NUMBER_OF_ASICS) then
               if rdoutCnt < to_integer(readouts) then
                  rdoutCntEn <= '1';
                  delayCntRst <= '1';
                  if tixelConfig.tixelSyncMode = "01" then
                     next_state <= SACI_SYNC_S;
                  else
                     next_state <= SYNC_S;
                  end if;
               else
                  next_state <= IDLE_S;
               end if;
            end if;  
         
         when TIMEOUT_S =>
            timeoutReq <= '1';
            -- wait for all stuck framers to timeout
            if unsigned(frameAckSync) = to_unsigned(2**NUMBER_OF_ASICS-1, NUMBER_OF_ASICS) then
               --if rdoutCnt < to_integer(readouts) then
                  --rdoutCntEn <= '1';
                  delayCntRst <= '1';
                  if tixelConfig.tixelSyncMode = "01" then
                     next_state <= SACI_SYNC_S;
                  else
                     next_state <= SYNC_S;
                  end if;
               --else
               --   next_state <= IDLE_S;
               --end if;
            end if;
            
         
         
            
         when others =>
            next_state <= IDLE_S;
      
      end case;
      
   end process;
   
end rtl;
