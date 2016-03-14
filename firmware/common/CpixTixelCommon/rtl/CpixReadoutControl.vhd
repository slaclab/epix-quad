-------------------------------------------------------------------------------
-- Title      : cPix detector readout control
-------------------------------------------------------------------------------
-- File       : CpixReadoutControl.vhd
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EpixPkgGen2.all;


library unisim;
use unisim.vcomponents.all;

entity CpixReadoutControl is
   generic (
      TPD_G                      : time      := 1 ns;
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4)
   );
   port (
      -- global signals
      sysClk         : in  sl;
      sysClkRst      : in  sl;
      byteClk        : in  sl;
      byteClkRst     : in  sl;
      
      -- trigger inputs
      acqStart       : in  sl;
      dataSend       : in  sl;
      
      -- handshake signals
      readDone       : out sl;
      acqBusy        : in  sl;
      
      -- decoded data signals
      inSync         : in  slv(1 downto 0);
      dataOut        : in  Slv8Array(1 downto 0);
      dataKOut       : in  slv(1 downto 0);
      codeErr        : in  slv(1 downto 0);
      dispErr        : in  slv(1 downto 0);
      
      -- config/status signals
      epixConfig     : in  epixConfigType;
      acqCount       : in  slv(31 downto 0);
      seqCount       : out slv(31 downto 0);
      envData        : in  Slv32Array(8 downto 0);
      frameErr       : out Slv32Array(1 downto 0);
      frameErrRst    : in  sl;
      
      -- stream out signals
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType
   );
end CpixReadoutControl;

architecture rtl of CpixReadoutControl is

   constant DAQ_TIMEOUT_C     : unsigned(31 downto 0) := to_unsigned(50000,32); --500 us at 100 MHz
   constant ASIC_TIMEOUT_C    : unsigned(31 downto 0) := to_unsigned(50000,32); --500 us at 100 MHz
   constant HEADER_SIZE_C     : natural   := 14;
   -- Hard coded words in the data stream for now
   constant BYTE_C            : slv( 2 downto 0) := "000";
   constant SHORT_C           : slv( 2 downto 0) := "001";
   constant LONG_C            : slv( 2 downto 0) := "010";
   constant LANE_C            : slv( 1 downto 0) := "00";
   constant VC_C              : slv( 1 downto 0) := "00";
   constant ZEROWORD_C        : slv(31 downto 0) := x"00000000";
   
   TYPE STATE_TYPE IS (IDLE, ARMED, WAIT_ASIC, HEADER, SEL_ASIC, SEND_ID, RD_FIFO, FOOTER);
   SIGNAL state, next_state   : STATE_TYPE; 
   
   
   signal timeCnt                : unsigned(31 downto 0);
   signal timeLoad               : unsigned(31 downto 0);
   signal timeCntRst             : std_logic;
   
   signal asicCnt                : natural;
   signal asicCntRst             : std_logic;
   signal asicCntEn              : std_logic;
   
   signal headerData             : std_logic_vector(31 downto 0);
   signal channelID              : std_logic_vector(31 downto 0);
   
   signal dwordCnt               : natural;
   signal dwordCntRst            : std_logic;
   signal dwordCntEn             : std_logic;
   
   signal seqCnt                 : unsigned(31 downto 0);
   signal seqCntEn               : std_logic;
   signal dataSendSys            : std_logic;
   signal acqStartSys            : std_logic;
   signal frameRstByte           : std_logic;
   signal frameBytes             : std_logic_vector(31 downto 0);
   signal frameDone              : std_logic_vector(1 downto 0);
   signal frameError             : std_logic_vector(1 downto 0);
   signal codeError              : std_logic_vector(1 downto 0);
   signal frameRdEn              : std_logic_vector(1 downto 0);
   signal frameValidRaw          : std_logic_vector(1 downto 0);
   signal frameValid             : std_logic_vector(1 downto 0);
   signal frameEmpty             : std_logic_vector(1 downto 0);
   signal frameDataRaw           : Slv32Array(1 downto 0);
   signal frameData              : Slv32Array(1 downto 0);
   signal frameRst               : std_logic;
   type Unsigned32Array is array (natural range <>) of unsigned(31 downto 0);
   signal frameErrCnt            : Unsigned32Array(1 downto 0);
   
   attribute keep : string;
   attribute keep of state : signal is "true";
   
begin

   -- Edge detection for signals that interface with other blocks
   U_DataSendSys : entity work.SynchronizerEdge
   port map (
      clk        => sysClk,
      rst        => sysClkRst,
      dataIn     => dataSend,
      risingEdge => dataSendSys
   );
   U_AcqStartSys : entity work.SynchronizerEdge
   port map (
      clk        => sysClk,
      rst        => sysClkRst,
      dataIn     => acqStart,
      risingEdge => acqStartSys
   );
   U_FrameRstByte : entity work.SynchronizerEdge
   port map (
      clk        => byteClk,
      rst        => byteClkRst,
      dataIn     => frameRst,
      risingEdge => frameRstByte
   );

   -----------------------------------------------
   -- Frame grabbers instantiation
   -----------------------------------------------
   
   G_AsicFrame : for i in 0 to 1 generate
      U_FrameGrabber : entity work.FrameGrabber
      port map (
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         inSync         => inSync(i),
         dataOut        => dataOut(i),
         dataKOut       => dataKOut(i),
         codeErr        => codeErr(i),
         dispErr        => dispErr(i),
         frameRst       => frameRstByte,
         frameBytes     => frameBytes,
         frameDone      => frameDone(i),
         frameError     => frameError(i),
         codeError      => codeError(i),
         rd_clk         => sysClk,
         rd_en          => frameRdEn(i),
         dout           => frameDataRaw(i),
         valid          => frameValid(i),
         empty          => frameEmpty(i)
      );
      
      -- High 15 bit Look-Up Table
      U_CpixLUTHi : entity work.CpixLUT
      port map ( 
         sysClk   => sysClk,
         address  => frameDataRaw(i)(30 downto 16),
         dataOut  => frameData(i)(30 downto 16),
         enable   => '1'
      );
      
      -- Low 15 bit Look-Up Table
      U_CpixLUTLo : entity work.CpixLUT
      port map ( 
         sysClk   => sysClk,
         address  => frameDataRaw(i)(14 downto 0),
         dataOut  => frameData(i)(14 downto 0),
         enable   => '1'
      );
      
      -- Unused data bits
      frameData(i)(31) <= '0';
      frameData(i)(15) <= '0';
      
      -- status counters
      fsm_seq_p: process ( sysClk ) 
      begin
         
         -- frame error counters
         if rising_edge(sysClk) then
            if sysClkRst = '1' or frameErrRst = '1' then
               frameErrCnt(i) <= (others => '0')    after TPD_G;
            elsif frameError(i) = '1' then
               frameErrCnt(i) <= frameErrCnt(i) + 1 after TPD_G;
            end if;
         end if;
      
      end process;
      
      frameErr(i) <= std_logic_vector(frameErrCnt(i));
      
   end generate G_AsicFrame;
   
   -- one pixel is 2 bytes
   frameBytes <= epixConfig.totalPixelsToRead(30 downto 0) & '0';
   
   
   -----------------------------------------------
   -- Readout FSM
   -----------------------------------------------
   
   fsm_seq_p: process ( sysClk ) 
   begin
      -- FSM state register
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            state <= IDLE                 after TPD_G;
         else
            state <= next_state           after TPD_G;
         end if;
      end if;
      
      -- daq trigger timeout counter
      if rising_edge(sysClk) then
         if sysClkRst = '1' or timeCntRst = '1' then
            timeCnt <= timeLoad           after TPD_G;
         elsif timeCnt /= 0 then
            timeCnt <= timeCnt - 1        after TPD_G;
         end if;
      end if;
      
      -- word counter
      if rising_edge(sysClk) then
         if sysClkRst = '1' or dwordCntRst = '1' then
            dwordCnt <= 0                 after TPD_G;
         elsif dwordCntEn = '1' then
            dwordCnt <= dwordCnt + 1      after TPD_G;         
         end if;
      end if;
      
      -- ASIC counter
      if rising_edge(sysClk) then
         if sysClkRst = '1' or asicCntRst = '1' then
            asicCnt <= 0                  after TPD_G;
         elsif asicCntEn = '1' then
            asicCnt <= asicCnt + 1        after TPD_G;
         end if;
      end if;
      
      -- sequence/frame counter
      if rising_edge(sysClk) then
         if sysClkRst = '1' or epixConfig.seqCountReset = '1' then
            seqCnt <= (others => '0')   after TPD_G;
         elsif seqCntEn = '1' then
            seqCnt <= seqCnt + 1      after TPD_G;
         end if;
      end if;
      
      -- delayed frame valid indicating when the LUT data is available
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            frameValidRaw(0) <= '0'    after TPD_G;
            frameValidRaw(1) <= '0'    after TPD_G;
         else
            frameValidRaw(0) <= frameValid(0)   after TPD_G;
            frameValidRaw(1) <= frameValid(1)   after TPD_G;
         end if;
      end if;
      
   end process;
   

   fsm_cmb_p: process ( 
      state, acqStartSys, dataSendSys, dwordCnt, timeCnt, asicCnt, mAxisSlave,
      headerData, epixConfig, frameDone, frameData, frameValid, frameValidRaw,  channelID) 
      variable mAxisMasterVar : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   begin
      next_state <= state;
      dwordCntRst <= '1';
      asicCntEn <= '0';
      asicCntRst <= '0';
      seqCntEn <= '0';
      timeCntRst <= '1';
      timeLoad <= (others=>'0');
      mAxisMasterVar := AXI_STREAM_MASTER_INIT_C;
      frameRdEn <= (others=>'0');
      frameRst <= '0';
      
      case state is
      
         when IDLE =>
            frameRst <= '1';
            if acqStartSys = '1' then
               timeLoad <= DAQ_TIMEOUT_C;
               next_state <= ARMED;
            end if;
      
         when ARMED =>
            timeCntRst <= '0';
            if dataSendSys = '1' then
               seqCntEn <= '1';
               timeLoad <= ASIC_TIMEOUT_C;
               next_state <= WAIT_ASIC;
            elsif timeCnt = 0 then
               next_state <= IDLE;
            end if;
         
         when WAIT_ASIC => 
            timeCntRst <= '0';
            if epixConfig.asicMask(1 downto 0) = "00" or timeCnt = 0 then
               next_state <= IDLE;
            elsif frameDone = epixConfig.asicMask(1 downto 0) then
               next_state <= HEADER;
            end if;
         
         when HEADER =>
            mAxisMasterVar.tData(31 downto 0) := headerData;
            mAxisMasterVar.tValid := '1';
            dwordCntRst <= '0';
            if mAxisSlave.tReady = '1' then
               dwordCntEn <= '1';
            else
               dwordCntEn <= '0';
            end if;
            if dwordCnt = 0 then
               ssiSetUserSof(MASTER_AXI_STREAM_CONFIG_G, mAxisMasterVar, '1');
            elsif dwordCnt = HEADER_SIZE_C - 1 then
               asicCntRst <= '1';
               next_state <= SEL_ASIC;
            end if;
         
         when SEL_ASIC =>
            if epixConfig.asicMask(asicCnt) = '1' and asicCnt < 2 then
               next_state <= SEND_ID;
            elsif asicCnt < 2 then
               asicCntEn <= '1';
            else
               next_state <= FOOTER;
            end if;
         
         when SEND_ID => 
            mAxisMasterVar.tData(31 downto 0) := channelID;
            mAxisMasterVar.tValid := '1';
            if mAxisSlave.tReady = '1' then
               next_state <= RD_FIFO;
            end if;
         
         when RD_FIFO => 
            mAxisMasterVar.tData(31 downto 0) := frameData(asicCnt);
            
            if frameValidRaw(asicCnt) = '1' then
               mAxisMasterVar.tValid := '1';
            else
               mAxisMasterVar.tValid := '0';
               asicCntEn <= '1';
               next_state <= SEL_ASIC;
            end if;
            
            if mAxisSlave.tReady = '1' and frameValid(asicCnt) = '1' then
               frameRdEn(asicCnt) <= '1';
            else
               frameRdEn(asicCnt) <= '0';
            end if;

         
         when FOOTER =>
            ssiSetUserEofe(MASTER_AXI_STREAM_CONFIG_G, mAxisMasterVar, '0');
            mAxisMasterVar.tData(31 downto 0) := ZEROWORD_C;
            mAxisMasterVar.tValid := '1';
            mAxisMasterVar.tLast := '1';
            if mAxisSlave.tReady = '1' then
               next_state <= IDLE;
            end if;
            
         when others =>
            next_state <= IDLE;
      
      end case;
      
      mAxisMaster <= mAxisMasterVar;
      
   end process;
   
   seqCount <= std_logic_vector(seqCnt);
   
   channelID <= std_logic_vector(to_unsigned(asicCnt, 32));
   
   headerData <= 
      x"000000" & "00" & LANE_C & "00" & VC_C      when dwordCnt = 0 else
      std_logic_vector(acqCount)                   when dwordCnt = 1 else
      std_logic_vector(seqCnt)                     when dwordCnt = 2 else
      ZEROWORD_C                                   when dwordCnt = 3 else
      ZEROWORD_C                                   when dwordCnt = 4 else
      ZEROWORD_C                                   when dwordCnt = 5 else
      ZEROWORD_C                                   when dwordCnt = 6 else
      ZEROWORD_C                                   when dwordCnt = 7 else
      ZEROWORD_C                                   when dwordCnt = 8 else
      ZEROWORD_C                                   when dwordCnt = 9 else
      ZEROWORD_C                                   when dwordCnt = 10 else
      ZEROWORD_C                                   when dwordCnt = 11 else
      ZEROWORD_C                                   when dwordCnt = 12 else
      ZEROWORD_C                                   when dwordCnt = 13 else
      ZEROWORD_C;
   
   
end rtl;
