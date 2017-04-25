-------------------------------------------------------------------------------
-- Title      : Frame grabber module
-------------------------------------------------------------------------------
-- File       : FramerExtended.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 01/19/2016
-- Last update: 01/19/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Extended framer streams extra 16 bits per entry with 8b10b error bits
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Change log:
-- [MK] 05/18/2016 - Added an option to force reading a frame if only a SOF was
--                   detected. When activated the pixels may be erroneous but
--                   less frames will be dropped. That mode is useful and should
--                   be used only with the prototype ASICs.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EpixPkgGen2.all;
use work.CpixPkg.all;

library unisim;
use unisim.vcomponents.all;

entity FramerExtended is
   generic (
      TPD_G                : time                  := 1 ns;
      FRAME_WORDS_G        : natural               := 2304;
      ASIC_NUMBER_G        : slv(3 downto 0)       := "0000"
   );
   port (
      -- global signals
      byteClk        : in  sl;
      byteClkRst     : in  sl;
      sysClk         : in  sl;
      sysRst         : in  sl;
      
      -- control/status signals (byteClk)
      forceFrameRead : in  sl;
      cntAcquisition : in  slv(31 downto 0);
      cntSequence    : in  slv(31 downto 0);
      cntReadout     : in  slv( 3 downto 0);
      frameReq       : in  sl;
      frameAck       : out sl;
      frameErr       : out sl;
      headerAck      : out sl;
      timeoutReq     : in  sl;
      cntFrameDone   : out slv(31 downto 0);
      cntFrameError  : out slv(31 downto 0);
      cntCodeError   : out slv(31 downto 0);
      cntToutError   : out slv(31 downto 0);
      cntReset       : in  sl;
      asicMask       : in  slv(1 downto 0);
      
      -- decoded data input stream (byteClk)
      sAxisMaster    : in  AxiStreamMasterType;
      
      -- AXI Stream Master Port (sysClk)
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType
   );
end FramerExtended;

architecture rtl of FramerExtended is

   constant SOF_C                : slv(15 downto 0)       := x"F7" & x"4A";
   constant EOF_C                : slv(15 downto 0)       := x"FD" & x"4A";
   constant HEADER_WORDS_C       : natural               := 15;
   constant LANE_C               : slv( 1 downto 0)      := "00";
   constant VC_C                 : slv( 1 downto 0)      := "00";
   constant ZEROWORD_C           : slv(15 downto 0)      := x"0000";
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType   := ssiAxiStreamConfig(4, TKEEP_COMP_C);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType   := ssiAxiStreamConfig(4, TKEEP_COMP_C);
   
   signal sFifoAxisMaster  : AxiStreamMasterType;
   signal sFifoAxisSlave   : AxiStreamSlaveType;
   
   signal frameCnt         : unsigned(31 downto 0);
   signal frameErrCnt      : unsigned(31 downto 0);
   signal codeErrCnt       : unsigned(31 downto 0);
   signal timeoutErrCnt    : unsigned(31 downto 0);
   signal frameCntEn       : sl;
   signal frameErrCntEn    : sl;
   signal codeErrCntEn     : sl;
   signal timeoutErrCntEn  : sl;
   
   signal frameReqSync     : sl;
   signal frameReqMask     : sl;
   signal timeoutReqSync   : sl;
   signal cntResetSync     : sl;
   
   signal headerData       : slv(31 downto 0);
   signal channelID        : slv(31 downto 0);
   
   TYPE STATE_TYPE IS (IDLE_S, HEADER_S, WAIT_DATA_S, DATA_IN_S, EOF_S, ERROR_S, DONE_S);
   signal state, next_state : STATE_TYPE; 
   signal wordCnt    : unsigned(31 downto 0); 
   signal wordCntEn  : sl; 
   signal wordCntRst : sl;  
   
   attribute keep : string;
   attribute keep of state : signal is "true";
   attribute keep of frameErrCntEn : signal is "true";
   
begin
   
   -----------------------------------------------
   -- AXI stream FIFO instantiation
   -----------------------------------------------   
   
   U_AsicFifo : entity work.AxiStreamFifo
   generic map(
      TPD_G                => TPD_G,
      FIFO_ADDR_WIDTH_G    => 11,
      SLAVE_AXI_CONFIG_G   => SLAVE_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G  => MASTER_AXI_CONFIG_C
   )
   port map(
      -- Slave Port
      sAxisClk    => byteClk,
      sAxisRst    => byteClkRst,
      sAxisMaster => sFifoAxisMaster,
      sAxisSlave  => sFifoAxisSlave,
      sAxisCtrl   => open,
      -- Master Port
      mAxisClk    => sysClk,
      mAxisRst    => sysRst,
      mAxisMaster => mAxisMaster,
      mAxisSlave  => mAxisSlave,
      mTLastTUser => open
   );
   
   -----------------------------------------------
   -- Data save FSM
   -----------------------------------------------
   
   fsm_seq_p: process ( byteClk ) 
   begin
      -- FSM state register
      if rising_edge(byteClk) then
         if byteClkRst = '1' then
            state <= IDLE_S               after TPD_G;
         else
            state <= next_state           after TPD_G;         
         end if;
      end if;
      
      -- synchronizers
      if rising_edge(byteClk) then
         if byteClkRst = '1' then
            frameReqSync <= '0'           after TPD_G;
            timeoutReqSync <= '0'         after TPD_G;
            cntResetSync <= '0'           after TPD_G;
         else
            frameReqSync <= frameReqMask  after TPD_G;
            timeoutReqSync <= timeoutReq  after TPD_G;
            cntResetSync <= cntReset      after TPD_G;
         end if;
      end if;
      
      -- word counter
      if rising_edge(byteClk) then
         if wordCntRst = '1' then
            wordCnt <= (others=>'0')      after TPD_G;
         elsif wordCntEn = '1' then
            wordCnt <= wordCnt + 1        after TPD_G;
         end if;
      end if;
      
      -- frame counter
      if rising_edge(byteClk) then
         if byteClkRst = '1' or cntResetSync = '1' then
            frameCnt <= (others=>'0')     after TPD_G;
         elsif frameCntEn = '1' then
            frameCnt <= frameCnt + 1      after TPD_G;
         end if;
      end if;
      
      -- frame error counter
      if rising_edge(byteClk) then
         if byteClkRst = '1' or cntResetSync = '1' then
            frameErrCnt <= (others=>'0')  after TPD_G;
         elsif frameErrCntEn = '1' then
            frameErrCnt <= frameErrCnt + 1 after TPD_G;
         end if;
      end if;
      
      -- code error counter
      if rising_edge(byteClk) then
         if byteClkRst = '1' or cntResetSync = '1' then
            codeErrCnt <= (others=>'0')   after TPD_G;
         elsif codeErrCntEn = '1' then
            codeErrCnt <= codeErrCnt + 1  after TPD_G;
         end if;
      end if;
      
      -- timeout error counter
      if rising_edge(byteClk) then
         if byteClkRst = '1' or cntResetSync = '1' then
            timeoutErrCnt <= (others=>'0')   after TPD_G;
         elsif timeoutErrCntEn = '1' then
            timeoutErrCnt <= timeoutErrCnt + 1 after TPD_G;
         end if;
      end if;
      
      -- frame error flag register
      if rising_edge(byteClk) then
         if (frameReqSync = '1' and state = IDLE_S) or byteClkRst = '1' then
            frameErr <= '0'               after TPD_G;
         elsif timeoutErrCntEn = '1' or frameErrCntEn = '1' then
            frameErr <= '1'               after TPD_G;
         end if;
      end if;
      
      
   end process;
   
   -- apply ASIC mask
   frameReqMask <= frameReq and asicMask(to_integer(unsigned(ASIC_NUMBER_G)));
   
   cntFrameDone   <= std_logic_vector(frameCnt);
   cntFrameError  <= std_logic_vector(frameErrCnt);
   cntCodeError   <= std_logic_vector(codeErrCnt);
   cntToutError   <= std_logic_vector(timeoutErrCnt);
   

   fsm_cmb_p: process (state, frameReqSync, timeoutReqSync, sFifoAxisSlave, headerData, sAxisMaster, wordCnt, forceFrameRead) 
   variable sFifoAxisMasterVar : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   begin
      next_state <= state;
      sFifoAxisMasterVar := AXI_STREAM_MASTER_INIT_C;
      wordCntEn <= '0';
      wordCntRst <= '1';
      frameAck <= '0';
      headerAck <= '0';
      frameCntEn <= '0';
      frameErrCntEn <= '0';
      codeErrCntEn <= '0';
      timeoutErrCntEn <= '0';
      
      case state is
      
         when IDLE_S =>
            frameAck <= '1';
            if frameReqSync = '1' then
               next_state <= HEADER_S;
            end if;
         
         when HEADER_S =>
            wordCntRst <= '0';
            
            sFifoAxisMasterVar.tData(31 downto 0) := headerData;
            sFifoAxisMasterVar.tValid := '1';
            
            if sFifoAxisSlave.tReady = '1' then
               wordCntEn <= '1';
            end if;
            if wordCnt = 0 then
               ssiSetUserSof(SLAVE_AXI_CONFIG_C, sFifoAxisMasterVar, '1');
            elsif wordCnt >= HEADER_WORDS_C - 1 then
               next_state <= WAIT_DATA_S;
            end if;
         
         when WAIT_DATA_S =>
            headerAck <= '1';
            if sAxisMaster.tData(15 downto 0) = SOF_C and sAxisMaster.tUser(1 downto 0) = "10" and sAxisMaster.tValid = '1' then
               next_state <= DATA_IN_S;
            elsif timeoutReqSync = '1' then
               timeoutErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
         
         when DATA_IN_S =>
            
            if sAxisMaster.tValid = '1' then
               wordCntEn <= '1';
            end if;
            wordCntRst <= '0';
            
            -- tUser(3 downto 2) is codeError
            -- tUser(5 downto 4) is dispError
            sFifoAxisMasterVar.tData(31 downto 16) := "000000" & sAxisMaster.tUser(5) & sAxisMaster.tUser(3) & "000000" & sAxisMaster.tUser(4) & sAxisMaster.tUser(2);
            sFifoAxisMasterVar.tData(15 downto  0) := sAxisMaster.tData(15 downto 0);
            sFifoAxisMasterVar.tValid := sAxisMaster.tValid;
            
            -- count potentially not critical errors and continue capturing the data (DATA_IN_S)
            if (sAxisMaster.tUser(3 downto 2) /= "00" or sAxisMaster.tUser(5 downto 4) /= "00") and sAxisMaster.tValid = '1' then
               codeErrCntEn <= '1';
            end if;
            
            -- cannot stop the ASIC readout when the slave is not ready
            if sFifoAxisSlave.tReady = '0' then
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
            
            -- number of bytes is checked to prevent missing EOF code
            if wordCnt > FRAME_WORDS_G then
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
            
            -- K byte that is not EOF
            if sAxisMaster.tUser(1 downto 0) /= "00" and sAxisMaster.tData(15 downto 0) /= EOF_C and sAxisMaster.tValid = '1' and forceFrameRead = '0' then
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
            
            -- if forced read skip checking the EOF
            if wordCnt = FRAME_WORDS_G and forceFrameRead = '1' then 
               sFifoAxisMasterVar.tValid := '0';
               frameCntEn <= '1';
               wordCntRst <= '1';
               next_state <= DONE_S;
            end if;
            
            -- EOF
            if sAxisMaster.tUser(1 downto 0) = "10" and sAxisMaster.tData(15 downto 0) = EOF_C and sAxisMaster.tValid = '1' and forceFrameRead = '0' then
               sFifoAxisMasterVar.tValid := '0';
               wordCntEn <= '0';
               next_state <= EOF_S;
            end if;
         
         when EOF_S => 
            -- number of bytes is checked to ensure no missing bytes
            if wordCnt = FRAME_WORDS_G then
               frameCntEn <= '1';
               next_state <= DONE_S;
            else
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
         
         when DONE_S => 
            
            sFifoAxisMasterVar.tData(31 downto 0) := x"00000000";   -- 4 x zero bytes footer
            sFifoAxisMasterVar.tValid := '1';
            ssiSetUserEofe(SLAVE_AXI_CONFIG_C, sFifoAxisMasterVar, '0'); --EOF
            sFifoAxisMasterVar.tLast := '1';
            
            if sFifoAxisSlave.tReady = '1' then
               next_state <= IDLE_S;
            end if;
         
         when ERROR_S => 
            
            sFifoAxisMasterVar.tData(31 downto 0) := x"00000000";
            sFifoAxisMasterVar.tValid := '1';
            sFifoAxisMasterVar.tLast := '1';
            ssiSetUserEofe(SLAVE_AXI_CONFIG_C, sFifoAxisMasterVar, '1'); --EOFE
            
            if sFifoAxisSlave.tReady = '1' then
               next_state <= IDLE_S;
            end if;
            
         when others =>
            next_state <= ERROR_S;
      
      end case;
      
      sFifoAxisMaster <= sFifoAxisMasterVar;
      
   end process;
   
   -- header data mux
   
   headerData <=
      ZEROWORD_C & x"00" & "00" & LANE_C & "00" & VC_C   when wordCnt = 0  else
      cntAcquisition(31 downto 0)                        when wordCnt = 1  else
      cntSequence(31 downto 0)                           when wordCnt = 2  else
      channelID(31 downto 0)                             when wordCnt = 14 else     -- 15th dword (ID)
      ZEROWORD_C & ZEROWORD_C;
   
   -- channel id
   channelID <= x"000000" & cntReadout & ASIC_NUMBER_G;
   
   
end rtl;
