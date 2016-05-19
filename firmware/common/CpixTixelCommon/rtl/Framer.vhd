-------------------------------------------------------------------------------
-- Title      : Frame grabber module
-------------------------------------------------------------------------------
-- File       : Framer.vhd
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

entity Framer is
   generic (
      TPD_G                : time                  := 1 ns;
      FRAME_BYTES_G        : natural               := 4608;
      ASIC_NUMBER_G        : slv(3 downto 0)       := "0000"
   );
   port (
      -- global signals
      byteClk        : in  sl;
      byteClkRst     : in  sl;
      sysClk         : in  sl;
      sysRst         : in  sl;
      
      -- decoded data signals (byteClk)
      inSync         : in  sl;
      dataOut        : in  slv(7 downto 0);
      dataKOut       : in  sl;
      codeErr        : in  sl;
      dispErr        : in  sl;
      
      -- control/status signals (byteClk)
      forceFrameRead : in  sl;
      cntAcquisition : in  slv(31 downto 0);
      cntSequence    : in  slv(31 downto 0);
      cntAReadout    : in  sl;
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
      epixConfig     : in  EpixConfigType;
      
      -- AXI Stream Master Port (sysClk)
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType
   );
end Framer;

architecture rtl of Framer is

   constant SOF_C                : slv(7 downto 0)       := x"F7";
   constant EOF_C                : slv(7 downto 0)       := x"FD";
   constant D102_C               : slv(7 downto 0)       := x"4A";
   constant HEADER_BYTES_C       : natural               := 60;
   constant LANE_C               : slv( 1 downto 0)      := "00";
   constant VC_C                 : slv( 1 downto 0)      := "00";
   constant ZEROBYTE_C           : slv( 7 downto 0)      := x"00";
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType   := ssiAxiStreamConfig(1, TKEEP_COMP_C);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType   := ssiAxiStreamConfig(4, TKEEP_COMP_C);
   
   signal sAxisMaster      : AxiStreamMasterType;
   signal sAxisSlave       : AxiStreamSlaveType;
   
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
   
   signal headerData       : slv(7 downto 0);
   signal channelID        : slv(31 downto 0);
   
   signal lutAddr          : slv(15 downto 0);
   signal lutData          : slv(15 downto 0);
   
   TYPE STATE_TYPE IS (IDLE_S, HEADER_S, WAIT_DATA_S, SOF_S, DATA_IN_S, EOF_S, ERROR_S, DONE_S);
   signal state, next_state : STATE_TYPE; 
   signal byteCnt    : unsigned(31 downto 0); 
   signal byteCntEn  : sl; 
   signal byteCntRst : sl;  
   
   signal inSyncD1   : sl;
   signal inSyncD2   : sl;
   signal inSyncD3   : sl;
   signal dataOutD1  : slv(7 downto 0);
   signal dataOutD2  : slv(7 downto 0);
   signal dataOutD3  : slv(7 downto 0);
   signal dataKOutD1 : sl;
   signal dataKOutD2 : sl;
   signal dataKOutD3 : sl;
   signal codeErrD1  : sl;
   signal codeErrD2  : sl;
   signal codeErrD3  : sl;
   signal dispErrD1  : sl;
   signal dispErrD2  : sl;
   signal dispErrD3  : sl;
   signal lutByteCnt : sl;
   
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
      sAxisMaster => sAxisMaster,
      sAxisSlave  => sAxisSlave,
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
      
      -- 3 stage pipeline
      if rising_edge(byteClk) then
         if byteClkRst = '1' then
            inSyncD1 <= '0'               after TPD_G;
            inSyncD2 <= '0'               after TPD_G;
            inSyncD3 <= '0'               after TPD_G;
            dataKOutD1 <= '0'             after TPD_G;
            dataKOutD2 <= '0'             after TPD_G;
            dataKOutD3 <= '0'             after TPD_G;
            codeErrD1 <= '0'              after TPD_G;
            codeErrD2 <= '0'              after TPD_G;
            codeErrD3 <= '0'              after TPD_G;
            dispErrD1 <= '0'              after TPD_G;
            dispErrD2 <= '0'              after TPD_G;
            dispErrD3 <= '0'              after TPD_G;
            dataOutD1 <= (others=>'0')    after TPD_G;
            dataOutD2 <= (others=>'0')    after TPD_G;
            dataOutD3 <= (others=>'0')    after TPD_G;
         else
            inSyncD1 <= inSync            after TPD_G;
            inSyncD2 <= inSyncD1          after TPD_G;
            inSyncD3 <= inSyncD2          after TPD_G;
            dataKOutD1 <= dataKOut        after TPD_G;
            dataKOutD2 <= dataKOutD1      after TPD_G;
            dataKOutD3 <= dataKOutD2      after TPD_G;
            codeErrD1 <= codeErr          after TPD_G;
            codeErrD2 <= codeErrD1        after TPD_G;
            codeErrD3 <= codeErrD2        after TPD_G;
            dispErrD1 <= dispErr          after TPD_G;
            dispErrD2 <= dispErrD1        after TPD_G;
            dispErrD3 <= dispErrD2        after TPD_G;
            dataOutD1 <= dataOut          after TPD_G;
            dataOutD2 <= dataOutD1        after TPD_G;
            dataOutD3 <= dataOutD2        after TPD_G;
         end if;
      end if;
      
      -- byte counter
      if rising_edge(byteClk) then
         if byteCntRst = '1' then
            byteCnt <= (others=>'0')      after TPD_G;
         elsif byteCntEn = '1' then
            byteCnt <= byteCnt + 1        after TPD_G;
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
   frameReqMask <= frameReq and epixConfig.asicMask(to_integer(unsigned(ASIC_NUMBER_G)));
   
   cntFrameDone   <= std_logic_vector(frameCnt);
   cntFrameError  <= std_logic_vector(frameErrCnt);
   cntCodeError   <= std_logic_vector(codeErrCnt);
   cntToutError   <= std_logic_vector(timeoutErrCnt);
   

   fsm_cmb_p: process (state, frameReqSync, timeoutReqSync, sAxisSlave, headerData, inSyncD3, codeErrD3, dispErrD3, dataKOutD3, dataOutD3, byteCnt, lutData, forceFrameRead) 
   variable sAxisMasterVar : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   begin
      next_state <= state;
      sAxisMasterVar := AXI_STREAM_MASTER_INIT_C;
      byteCntEn <= '0';
      byteCntRst <= '1';
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
            byteCntRst <= '0';
            
            sAxisMasterVar.tData(7 downto 0) := headerData;
            sAxisMasterVar.tValid := '1';
            
            if sAxisSlave.tReady = '1' then
               byteCntEn <= '1';
            end if;
            if byteCnt = 0 then
               ssiSetUserSof(SLAVE_AXI_CONFIG_C, sAxisMasterVar, '1');
            elsif byteCnt >= HEADER_BYTES_C - 1 then
               next_state <= WAIT_DATA_S;
            end if;
         
         when WAIT_DATA_S =>
            headerAck <= '1';
            if inSyncD3 = '1' and dataKOutD3 = '1' and dataOutD3 = SOF_C then
               next_state <= SOF_S;
            elsif timeoutReqSync = '1' then
               timeoutErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
      
         when SOF_S =>
            if forceFrameRead = '1' then
               next_state <= DATA_IN_S;
            elsif inSyncD3 = '1' and dataKOutD3 = '0' and dataOutD3 = D102_C then
               next_state <= DATA_IN_S;
            else
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
         
         when DATA_IN_S =>
            byteCntEn <= '1';
            byteCntRst <= '0';
            
            if byteCnt(0) = '0' then
               sAxisMasterVar.tData(7 downto 0) := lutData(7 downto 0);
            else
               sAxisMasterVar.tData(7 downto 0) := lutData(15 downto 8);
            end if;
            --sAxisMasterVar.tData(7 downto 0) := dataOutD3;
            sAxisMasterVar.tValid := '1';
            
            -- count potentially not critical errors and continue capturing the data (DATA_IN_S)
            if inSyncD3 = '0' or codeErrD3 = '1' or dispErrD3 = '1' then
               codeErrCntEn <= '1';
            end if;
            
            -- cannot stop the ASIC readout when the slave is not ready
            if sAxisSlave.tReady = '0' then
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
            
            -- number of bytes is checked to prevent missing EOF code
            if byteCnt > FRAME_BYTES_G then
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
            
            -- K byte that is not EOF
            if dataKOutD3 = '1' and dataOutD3 /= EOF_C and forceFrameRead = '0' then
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
            
            -- if forced read skip checking the EOF
            if byteCnt = FRAME_BYTES_G and forceFrameRead = '1' then 
               sAxisMasterVar.tValid := '0';
               frameCntEn <= '1';
               byteCntRst <= '1';
               next_state <= DONE_S;
            end if;
            
            -- EOF
            if dataKOutD3 = '1' and dataOutD3 = EOF_C and forceFrameRead = '0' then
               sAxisMasterVar.tValid := '0';
               byteCntEn <= '0';
               next_state <= EOF_S;
            end if;
         
         when EOF_S => 
            -- number of bytes is checked to ensure no missing bytes
            if byteCnt = FRAME_BYTES_G then
               frameCntEn <= '1';
               next_state <= DONE_S;
            else
               frameErrCntEn <= '1';
               next_state <= ERROR_S;
            end if;
         
         when DONE_S => 
            byteCntRst <= '0';
            
            sAxisMasterVar.tData(7 downto 0) := x"00";   -- 4 x zero bytes footer
            sAxisMasterVar.tValid := '1';
            
            if sAxisSlave.tReady = '1' then
               byteCntEn <= '1';
            end if;
            
            if byteCnt >= 3 then
               sAxisMasterVar.tLast := '1';
               ssiSetUserEofe(SLAVE_AXI_CONFIG_C, sAxisMasterVar, '0'); --EOF
               next_state <= IDLE_S;
            end if;
         
         when ERROR_S => 
            byteCntRst <= '0';
            
            sAxisMasterVar.tData(7 downto 0) := x"00";
            sAxisMasterVar.tValid := '1';
            sAxisMasterVar.tLast := '1';
            ssiSetUserEofe(SLAVE_AXI_CONFIG_C, sAxisMasterVar, '1'); --EOFE
            
            if sAxisSlave.tReady = '1' then
               next_state <= IDLE_S;
            end if;
            
         when others =>
            next_state <= ERROR_S;
      
      end case;
      
      sAxisMaster <= sAxisMasterVar;
      
   end process;
   
   -- header data mux
   headerData <=
      ZEROBYTE_C                    when byteCnt = 3  else
      ZEROBYTE_C                    when byteCnt = 2  else
      ZEROBYTE_C                    when byteCnt = 1  else
      "00" & LANE_C & "00" & VC_C   when byteCnt = 0  else
      cntAcquisition(31 downto 24)  when byteCnt = 7  else
      cntAcquisition(23 downto 16)  when byteCnt = 6  else
      cntAcquisition(15 downto  8)  when byteCnt = 5  else
      cntAcquisition(7  downto  0)  when byteCnt = 4  else
      cntSequence(31 downto 24)     when byteCnt = 11 else
      cntSequence(23 downto 16)     when byteCnt = 10 else
      cntSequence(15 downto  8)     when byteCnt = 9  else
      cntSequence(7  downto  0)     when byteCnt = 8  else
      channelID(31 downto 24)       when byteCnt = 59 else     -- 15th dword (ID)
      channelID(23 downto 16)       when byteCnt = 58 else     -- 15th dword (ID)
      channelID(15 downto  8)       when byteCnt = 57 else     -- 15th dword (ID)
      channelID(7  downto  0)       when byteCnt = 56 else     -- 15th dword (ID)
      ZEROBYTE_C;
   
   -- channel id
   channelID <= x"000000" & "000" & cntAReadout & ASIC_NUMBER_G;
   
   -- CPIX LUT instance
   U_CpixLUT : entity work.CpixLUT
   port map ( 
      sysClk   => byteClk,
      address  => lutAddr(14 downto 0),
      dataOut  => lutData(14 downto 0),
      enable   => '1'
   );
   lutData(15) <= '0';
   
   -- LUT address register
   lut_p: process ( byteClk ) 
   begin
      if rising_edge(byteClk) then
         if byteClkRst = '1' then
            lutAddr <= (others=>'0')            after TPD_G;
         -- update LUT address every second byte
         elsif lutByteCnt = '0' then
            lutAddr <= dataOut & dataOutD1      after TPD_G; 
         end if;
      end if;
      
      -- bit used to store 2 address bytes in right order
      if rising_edge(byteClk) then
         if inSync = '1' and dataOut = SOF_C and dataKOut = '1' then
            lutByteCnt <= '0'                   after TPD_G;
         else
            lutByteCnt <= not lutByteCnt        after TPD_G; 
         end if;
      end if;
   end process;
   
end rtl;
