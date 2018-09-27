-------------------------------------------------------------------------------
-- File       : RdoutCoreBram.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-07
-- Last update: 2017-07-14
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity RdoutCoreBram is
   generic (
      TPD_G             : time            := 1 ns;
      BANK_COLS_G       : natural         := 48;
      BANK_ROWS_G       : natural         := 178;
      LINE_REVERSE_G    : slv(3 downto 0) := "1010"
   );
   port (
      -- ADC interface
      sysClk               : in  sl;
      sysRst               : in  sl;
      -- AXI-Lite Interface for local registers 
      sAxilReadMaster      : in  AxiLiteReadMasterType;
      sAxilReadSlave       : out AxiLiteReadSlaveType;
      sAxilWriteMaster     : in  AxiLiteWriteMasterType;
      sAxilWriteSlave      : out AxiLiteWriteSlaveType;
      -- Opcode to insert into frame
      opCode               : in  slv(7 downto 0);
      -- Run control
      acqBusy              : in  sl;
      acqCount             : in  slv(31 downto 0);
      acqSmplEn            : in  sl;
      readDone             : out sl;
      -- ADC stream input
      adcStream            : in  AxiStreamMasterArray(63 downto 0);
      tpsStream            : in  AxiStreamMasterArray(15 downto 0);
      -- Test stream input
      testStream           : in  AxiStreamMasterArray(63 downto 0);
      -- ASIC digital data signals to/from deserializer
      asicDout             : in  slv(15 downto 0);
      asicDoutTest         : in  slv(15 downto 0);
      asicRoClk            : in  sl;
      roClkTail            : out slv(7 downto 0);
      -- Frame stream output (axisClk domain)
      axisClk              : in  sl;
      axisRst              : in  sl;
      axisMaster           : out AxiStreamMasterType;
      axisSlave            : in  AxiStreamSlaveType
   );
end RdoutCoreBram;

architecture rtl of RdoutCoreBram is
   
   -- ASIC settings
   constant BANK_COLS_C    : natural := BANK_COLS_G/2 - 1;
   constant BANK_ROWS_C    : natural := BANK_ROWS_G - 1;
   constant COLS_BITS_C    : natural := log2(BANK_COLS_G/2);   -- div by 2 for 32 bit packed 2 pixels
   constant ROWS_BITS_C    : natural := log2(BANK_ROWS_G);
   
   -- Buffer settings
   constant BUFF_BITS_C    : integer range 1 to 5 := 3;
   constant BUFF_MAX_C     : slv(2**BUFF_BITS_C-1 downto 0) := (others=>'1');
   constant TIMEOUT_C      : integer := 10000;  -- 100us
   
   -- Stream settings
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(4);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   constant LANE_C         : slv( 1 downto 0) := "00";
   constant VC_C           : slv( 1 downto 0) := "00";
   constant QUAD_C         : slv( 1 downto 0) := "00";
   
   -- Custom data types
   type LineValidArray is array (natural range <>) of slv(2**BUFF_BITS_C-1 downto 0);
   
   type WrStateType is (
      IDLE_S,
      BUFFER_S,
      WRITE_S
   );
   
   type RdStateType is (
      IDLE_S,
      HDR_S,
      WAIT_LINE_S,
      MOVE_LINE_S,
      FOOTER_S,
      TPS_DATA_S
   );
   
   type RegType is record
      rdoutEn              : sl;
      rdoutEnReg           : sl;
      testData             : sl;
      adcDataBuf           : Slv14Array(63 downto 0);
      seqCount             : slv(31 downto 0);
      seqCountReset        : sl;
      adcPipelineDly       : slv(7 downto 0);
      adcPipelineDlyReg    : slv(7 downto 0);
      acqSmplEn            : slv(255 downto 0);
      readPend             : sl;
      error                : sl;
      wordCnt              : integer range 0 to 7;
      timeCnt              : integer range 0 to TIMEOUT_C;
      sRowCount            : integer range 0 to 3;             -- 4 lines
      bankCount            : integer range 0 to 15;            -- 16 banks per line
      colCount             : integer range 0 to BANK_COLS_C;   -- generic column count
      rowCount             : slv(ROWS_BITS_C-1 downto 0);      -- generic row count
      lineBufErr           : Slv32Array(3 downto 0);
      lineBufValid         : LineValidArray(3 downto 0);
      memWrEn              : sl;
      lineWrAddr           : slv(COLS_BITS_C-1 downto 0);
      lineWrBuff           : slv(BUFF_BITS_C-1 downto 0);
      lineRdAddr           : slv(COLS_BITS_C-1 downto 0);
      memWrAddr            : slv(BUFF_BITS_C+COLS_BITS_C-1 downto 0);
      doutRd               : slv(63 downto 0);
      wrState              : WrStateType;
      rdState              : RdStateType;
      txMaster             : AxiStreamMasterType;
      sAxilWriteSlave      : AxiLiteWriteSlaveType;
      sAxilReadSlave       : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdoutEn              => '0',
      rdoutEnReg           => '0',
      testData             => '0',
      adcDataBuf           => (others=>(others=>'0')),
      seqCount             => (others=>'0'),
      seqCountReset        => '0',
      adcPipelineDly       => (others=>'0'),
      adcPipelineDlyReg    => (others=>'0'),
      acqSmplEn            => (others=>'0'),
      readPend             => '0',
      error                => '0',
      wordCnt              => 0,
      timeCnt              => 0,
      sRowCount            => 0,
      bankCount            => 0,
      colCount             => 0,
      rowCount             => (others=>'0'),
      lineBufErr           => (others=>(others=>'0')),
      lineBufValid         => (others=>(others=>'0')),
      memWrEn              => '0',
      lineWrAddr           => (others=>'0'),
      lineWrBuff           => (others=>'0'),
      lineRdAddr           => (others=>'0'),
      memWrAddr            => (others=>'0'),
      doutRd               => (others=>'0'),
      wrState              => IDLE_S,
      rdState              => IDLE_S,
      txMaster             => AXI_STREAM_MASTER_INIT_C,
      sAxilWriteSlave      => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave       => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r                : RegType := REG_INIT_C;
   signal rin              : RegType;
   
   signal acqBusyEdge     : std_logic             := '0';
   signal txSlave          : AxiStreamSlaveType;
   
   signal memWrEn          : sl;
   signal memWrAddr        : slv(BUFF_BITS_C+COLS_BITS_C-1 downto 0);
   signal memRdAddr        : slv(BUFF_BITS_C+COLS_BITS_C-1 downto 0);
   signal memRdData        : Slv32VectorArray(3 downto 0, 15 downto 0);
   signal memWrData        : Slv32Array(63 downto 0);
   
   signal muxStrMap        : AxiStreamMasterArray(63 downto 0);
   signal muxStream        : AxiStreamMasterArray(63 downto 0);
   
   signal iRoClkTail       : Slv8Array(3 downto 0);
   signal doutOut          : Slv2Array(63 downto 0);
   signal doutValid        : slv(63 downto 0);
   
   signal muxAsicDout      : slv(15 downto 0);
   
begin
   --r.rowCount(BUFF_BITS_C-1 downto 0)
   assert ROWS_BITS_C >= BUFF_BITS_C
      report "ROWS_BITS_C must be >= BUFF_BITS_C"
      severity failure;
   
   assert BANK_COLS_G mod 2 = 0
      report "BANK_COLS_G must be even number"
      severity failure;
   
   muxStream   <= adcStream when r.testData = '0' else testStream;
   muxAsicDout <= asicDout  when r.testData = '0' else asicDoutTest;
   
   --------------------------------------------------
   -- Map ADC/Test channels
   --------------------------------------------------
   
   -- sRow 0 (bottom, bottom)
   -- ASIC 9, ASIC 10 (left)
   muxStrMap( 0) <= muxStream(40);
   muxStrMap( 1) <= muxStream(41);
   muxStrMap( 2) <= muxStream(42);
   muxStrMap( 3) <= muxStream(43);
   muxStrMap( 4) <= muxStream(44);
   muxStrMap( 5) <= muxStream(45);
   muxStrMap( 6) <= muxStream(46);
   muxStrMap( 7) <= muxStream(47);
   
   -- sRow 0 (bottom, bottom)
   -- ASIC 13, ASIC 14 (right)
   muxStrMap( 8) <= muxStream(56);
   muxStrMap( 9) <= muxStream(57);
   muxStrMap(10) <= muxStream(58);
   muxStrMap(11) <= muxStream(59);
   muxStrMap(12) <= muxStream(60);
   muxStrMap(13) <= muxStream(61);
   muxStrMap(14) <= muxStream(62);
   muxStrMap(15) <= muxStream(63);
   
   -- sRow 1 (bottom, up)
   -- ASIC 8, ASIC 11  (left)
   muxStrMap(16) <= muxStream(32);
   muxStrMap(17) <= muxStream(33);
   muxStrMap(18) <= muxStream(34);
   muxStrMap(19) <= muxStream(35);
   muxStrMap(20) <= muxStream(36);
   muxStrMap(21) <= muxStream(37);
   muxStrMap(22) <= muxStream(38);
   muxStrMap(23) <= muxStream(39);
   
   -- sRow 1 (bottom, up)
   -- ASIC 12, ASIC 15  (right)
   muxStrMap(24) <= muxStream(48);
   muxStrMap(25) <= muxStream(49);
   muxStrMap(26) <= muxStream(50);
   muxStrMap(27) <= muxStream(51);
   muxStrMap(28) <= muxStream(52);
   muxStrMap(29) <= muxStream(53);
   muxStrMap(30) <= muxStream(54);
   muxStrMap(31) <= muxStream(55);
   
   -- sRow 2 (bottom, bottom)
   -- ASIC 1, ASIC 2 (left)
   muxStrMap(32) <= muxStream( 8);
   muxStrMap(33) <= muxStream( 9);
   muxStrMap(34) <= muxStream(10);
   muxStrMap(35) <= muxStream(11);
   muxStrMap(36) <= muxStream(12);
   muxStrMap(37) <= muxStream(13);
   muxStrMap(38) <= muxStream(14);
   muxStrMap(39) <= muxStream(15);
   
   -- sRow 2 (bottom, bottom)
   -- ASIC 5, ASIC 6 (right)
   muxStrMap(40) <= muxStream(24);
   muxStrMap(41) <= muxStream(25);
   muxStrMap(42) <= muxStream(26);
   muxStrMap(43) <= muxStream(27);
   muxStrMap(44) <= muxStream(28);
   muxStrMap(45) <= muxStream(29);
   muxStrMap(46) <= muxStream(30);
   muxStrMap(47) <= muxStream(31);
   
   -- sRow 3 (bottom, up)
   -- ASIC 0, ASIC 3  (left)
   muxStrMap(48) <= muxStream(0);
   muxStrMap(49) <= muxStream(1);
   muxStrMap(50) <= muxStream(2);
   muxStrMap(51) <= muxStream(3);
   muxStrMap(52) <= muxStream(4);
   muxStrMap(53) <= muxStream(5);
   muxStrMap(54) <= muxStream(6);
   muxStrMap(55) <= muxStream(7);
   
   -- sRow 3 (bottom, up)
   -- ASIC 4, ASIC 7  (right)
   muxStrMap(56) <= muxStream(16);
   muxStrMap(57) <= muxStream(17);
   muxStrMap(58) <= muxStream(18);
   muxStrMap(59) <= muxStream(19);
   muxStrMap(60) <= muxStream(20);
   muxStrMap(61) <= muxStream(21);
   muxStrMap(62) <= muxStream(22);
   muxStrMap(63) <= muxStream(23);
   
   --------------------------------------------------
   -- Data storage and readout FSMs
   --------------------------------------------------
   
   U_ReadStartEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => acqBusy,
         risingEdge => acqBusyEdge
      );
   
   comb : process (sysRst, sAxilReadMaster, sAxilWriteMaster, txSlave, r,
      acqBusyEdge, acqBusy, acqCount, acqSmplEn, memRdData, opCode, muxStrMap, tpsStream,
      doutValid, doutOut) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
      variable sRowCountVar : integer;
   begin
      v := r;
      
      -- settings that chan change when no readout is pending
      if r.readPend = '0' and acqBusyEdge = '0' then
         v.rdoutEn         := r.rdoutEnReg;
         v.adcPipelineDly  := r.adcPipelineDlyReg;
      end if;
      
      -- count readouts
      if r.seqCountReset = '1' then
         v.seqCount := (others=>'0');
      elsif acqBusyEdge = '1' and r.rdoutEn = '1' then
         v.seqCount := r.seqCount + 1;
      end if;
      
      --------------------------------------------------
      -- AXI Lite register logic
      --------------------------------------------------
      
      -- Determine the AXI-Lite transaction
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.rdoutEnReg        );
      axiSlaveRegisterR(regCon, x"004", 0, r.seqCount          );
      axiSlaveRegister (regCon, x"008", 0, v.seqCountReset     );
      axiSlaveRegister (regCon, x"00C", 0, v.adcPipelineDlyReg );
      axiSlaveRegisterR(regCon, x"010", 0, r.lineBufErr(0)     );
      axiSlaveRegisterR(regCon, x"014", 0, r.lineBufErr(1)     );
      axiSlaveRegisterR(regCon, x"018", 0, r.lineBufErr(2)     );
      axiSlaveRegisterR(regCon, x"01C", 0, r.lineBufErr(3)     );
      axiSlaveRegister (regCon, x"020", 0, v.testData          );
      
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);
      
      --------------------------------------------------
      -- Line buffers write FSM (64 bank channels)
      -- one ADC pipeline delay to allow common DPRAM write control
      --------------------------------------------------
      
      v.memWrEn   := '0';
      
      case r.wrState is
         
         -- write samples to RAM when readout is pending
         when IDLE_S =>
            if r.readPend = '1' then
               v.wrState := BUFFER_S;
            end if;
            v.lineWrAddr   := (others=>'0');
            v.lineWrBuff   := (others=>'0');
            v.lineBufValid := (others=>(others=>'0'));
         
         -- buffer first sample for 32 bit write
         when BUFFER_S =>
            -- drive the buffer logic on delayed strobe
            if r.acqSmplEn(conv_integer(r.adcPipelineDly)) = '1' then
               -- buffer incoming samples for 32 bit data packing
               for i in 63 downto 0 loop
                  v.adcDataBuf(i) := muxStrMap(i).tData(13 downto 0);
               end loop;
               v.wrState := WRITE_S;
            end if;
            if r.readPend = '0' then
               v.wrState := IDLE_S;
            end if;
            
         -- write to memory
         when WRITE_S =>
            v.memWrAddr := r.lineWrBuff & r.lineWrAddr;
            -- drive the buffer logic on delayed strobe
            if r.acqSmplEn(conv_integer(r.adcPipelineDly)) = '1' then
               if r.lineWrAddr = BANK_COLS_C then
                  -- move to next buffer
                  v.lineWrAddr := (others=>'0');
                  v.lineWrBuff := r.lineWrBuff + 1;
                  -- set valid flag (all finish simultaneously)
                  for i in 3 downto 0 loop
                     v.lineBufValid(i)(conv_integer(r.lineWrBuff)) := '1';
                  end loop;
               else
                  -- every 2 sample strobes move buffer write pointer
                  v.lineWrAddr := r.lineWrAddr + 1;
               end if;
               v.memWrEn   := '1';
               v.wrState   := BUFFER_S;
            end if;
            if r.readPend = '0' then
               v.wrState   := IDLE_S;
            end if;
            
         when others =>
            v.wrState := IDLE_S;
            
      end case;
      
      -- shift the sample strobe
      if r.readPend = '1' then
         v.acqSmplEn := r.acqSmplEn(254 downto 0) & acqSmplEn;
      else
         v.acqSmplEn := (others=>'0');
      end if;
      
      -- check for buffer overflow
      for i in 3 downto 0 loop
         if r.acqSmplEn(conv_integer(r.adcPipelineDly)) = '1' and r.lineBufValid(i) = BUFF_MAX_C then
            v.lineBufErr(i) := r.lineBufErr(i) + 1;
            v.error := '1';
         end if;
      end loop;
      
      -- clear error counters when readout is disabled
      if r.rdoutEn = '0' then
         v.lineBufErr   := (others=>(others=>'0'));
      end if;
      
      --------------------------------------------------
      -- FSM to assemble and stream 4 lines (16 banks per line)
      --------------------------------------------------
      
      -- temporary
      for i in 63 downto 0 loop
         if doutValid(i) = '1' then
            v.doutRd(i) := '1';
         else
            v.doutRd(i) := '0';
         end if;
      end loop;
      
      -- Reset strobing Signals
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
         v.txMaster.tStrb  := (others => '1');
      end if;
      
      case r.rdState is
         
         -- wait for trigger
         when IDLE_S =>
            if LINE_REVERSE_G(r.sRowCount) = '0' then
               v.lineRdAddr := (others=>'0');
            else
               v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
            end if;
            v.sRowCount    := 0;
            v.bankCount    := 0;
            v.colCount     := 0;
            v.rowCount     := (others=>'0');
            v.readPend     := '0';
            v.error        := '0';
            if acqBusyEdge = '1' and r.rdoutEn = '1' then
               v.readPend  := '1';
               v.rdState   := HDR_S;
            end if;
      
         when HDR_S =>
            if v.txMaster.tValid = '0' then
               v.txMaster.tValid := '1';
               if r.wordCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, v.txMaster, '1');
                  v.txMaster.tData(31 downto 0) := x"000000" & "00" & LANE_C & "00" & VC_C;
               elsif r.wordCnt = 1 then
                  v.txMaster.tData(31 downto 0) := x"0" & "00" & QUAD_C & opCode & acqCount(15 downto 0);
               elsif r.wordCnt = 2 then
                  v.txMaster.tData(31 downto 0) := r.seqCount;
               else
                  v.txMaster.tData(31 downto 0) := x"00000000";
               end if;
               if (r.wordCnt = 7) then
                  v.wordCnt   := 0;
                  v.timeCnt   := 0;
                  v.rdState   := WAIT_LINE_S;
               else
                  v.wordCnt   := r.wordCnt + 1;
               end if;
            end if;
            
         when WAIT_LINE_S =>
            if v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) = '1' then
               if LINE_REVERSE_G(r.sRowCount) = '0' then
                  v.lineRdAddr := r.lineRdAddr + 1;
               else
                  v.lineRdAddr := r.lineRdAddr - 1;
               end if;
               v.rdState   := MOVE_LINE_S;
            elsif r.timeCnt = TIMEOUT_C then
               v.error     := '1';
               v.rdState   := FOOTER_S;
            else
               v.timeCnt   := r.timeCnt + 1;
            end if;
            
         when MOVE_LINE_S =>
            if v.txMaster.tValid = '0' then
               
               v.txMaster.tValid := '1';
               v.txMaster.tData(31 downto 0) := memRdData(r.sRowCount, r.bankCount);  -- super row 0-3, bank 0-15 = 64 memory channels
               
               if r.colCount < BANK_COLS_C then    -- next column in bank
                  v.colCount := r.colCount + 1;
               elsif r.bankCount < 15 then         -- next bank (out of 16)
                  v.colCount  := 0;
                  v.bankCount := r.bankCount + 1;
               elsif r.sRowCount < 3 then          -- next super row (out of 4)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.sRowCount    := r.sRowCount + 1;
                  v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
               elsif r.rowCount < BANK_ROWS_C then -- next row (go to wait for line state)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.sRowCount    := 0;
                  v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  v.rowCount     := r.rowCount + 1;
                  v.timeCnt      := 0;
                  v.rdState      := WAIT_LINE_S;
               else                                -- image done (go to footer state)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.sRowCount    := 0;
                  v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  v.rowCount     := (others=>'0');
                  v.rdState      := FOOTER_S;
               end if;
               
               -- move the read address 1 cycle ahead of the pixel counters
               if r.colCount = BANK_COLS_C and r.bankCount = 15 and r.sRowCount = 3 then
                  if LINE_REVERSE_G(0) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
               elsif r.colCount = BANK_COLS_C-1 and r.bankCount = 15 then
                  sRowCountVar := conv_integer(toSlv(v.sRowCount+1,2));
                  if LINE_REVERSE_G(sRowCountVar) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
               elsif r.colCount = BANK_COLS_C-1 then
                  if LINE_REVERSE_G(v.sRowCount) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
               else
                  if LINE_REVERSE_G(v.sRowCount) = '0' then
                     v.lineRdAddr := r.lineRdAddr + 1;
                  else
                     v.lineRdAddr := r.lineRdAddr - 1;
                  end if;
               end if;
               
            end if;
         
         when FOOTER_S =>
            -- reserved footer space similar to small epix data frame
            -- length of 1 super row
            if v.txMaster.tValid = '0' then
               
               v.txMaster.tValid := '1';
               v.txMaster.tData(31 downto 0) := x"00000000";
               
               if r.colCount < BANK_COLS_C then    -- next column in bank
                  v.colCount := r.colCount + 1;
               elsif r.bankCount < 15 then         -- next bank
                  v.colCount  := 0;
                  v.bankCount := r.bankCount + 1;
               else
                  v.colCount  := 0;
                  v.bankCount := 0;
                  v.rdState   := TPS_DATA_S;
               end if;
               
            end if;
         
         when TPS_DATA_S =>
            if v.txMaster.tValid = '0' then
               v.txMaster.tValid := '1';
               if r.wordCnt = 0 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(1).tData(13 downto 0) & "00" & tpsStream(0).tData(13 downto 0);
               elsif r.wordCnt = 1 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(3).tData(13 downto 0) & "00" & tpsStream(2).tData(13 downto 0);
               elsif r.wordCnt = 2 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(5).tData(13 downto 0) & "00" & tpsStream(4).tData(13 downto 0);
               elsif r.wordCnt = 3 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(7).tData(13 downto 0) & "00" & tpsStream(6).tData(13 downto 0);
               elsif r.wordCnt = 4 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(9).tData(13 downto 0) & "00" & tpsStream(8).tData(13 downto 0);
               elsif r.wordCnt = 5 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(11).tData(13 downto 0) & "00" & tpsStream(10).tData(13 downto 0);
               elsif r.wordCnt = 6 then
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(13).tData(13 downto 0) & "00" & tpsStream(12).tData(13 downto 0);
               else
                  v.txMaster.tData(31 downto 0) := "00" & tpsStream(15).tData(13 downto 0) & "00" & tpsStream(14).tData(13 downto 0);
               end if;
               
               if (r.wordCnt = 7) then
                  v.wordCnt   := 0;
                  v.readPend  := '0';
                  v.txMaster.tLast  := '1';
                  ssiSetUserEofe(SLAVE_AXI_CONFIG_C, v.txMaster, r.error);
                  v.rdState   := IDLE_S;
               else
                  v.wordCnt   := r.wordCnt + 1;
               end if;
               
            end if;
         
         when others =>
            v.rdState := IDLE_S;
            
      end case;
      
         
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;
      
      memWrEn     <= v.memWrEn;
      memWrAddr   <= r.memWrAddr;
      memRdAddr   <= r.rowCount(BUFF_BITS_C-1 downto 0) & r.lineRdAddr;
      
      readDone <= not r.readPend;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   ----------------------------------------------------------------------
   -- Line DPRAM buffers (64 bank channels)
   ----------------------------------------------------------------------
   G_sRowBuf : for i in 3 downto 0 generate
      G_BankBuf : for j in 15 downto 0 generate
         
         -- stage two 16 bit words for write into 32 bit memory
         -- swap words if line readout is reversed
         memWrData(i*16+j) <= 
            "00" & muxStrMap(i*16+j).tData(13 downto 0) &
            "00" & r.adcDataBuf(i*16+j) when LINE_REVERSE_G(i) = '0' else
            "00" & r.adcDataBuf(i*16+j) &
            "00" & muxStrMap(i*16+j).tData(13 downto 0);
         
         U_BankBufRam: entity work.DualPortRam
         generic map (
            TPD_G          => TPD_G,
            DATA_WIDTH_G   => 32,
            ADDR_WIDTH_G   => BUFF_BITS_C+COLS_BITS_C
         )
         port map (
            -- Port A     
            clka    => sysClk,
            wea     => memWrEn,
            rsta    => sysRst,
            addra   => memWrAddr,
            dina    => memWrData(i*16+j),
            -- Port B
            clkb    => sysClk,
            rstb    => sysRst,
            addrb   => memRdAddr,
            doutb   => memRdData(i, j)
         );
         
      end generate G_BankBuf;
   end generate G_sRowBuf;
   
   ---------------------------------------------------------------
   -- Digital output deserializer 
   --------------------- ------------------------------------------
   G_DOUT_EPIX10KA : for i in 3 downto 0 generate
      
      U_DoutAsic : entity work.DoutDeserializer
      generic map (
         TPD_G             => TPD_G,
         BANK_COLS_G       => BANK_COLS_G
      )
      port map ( 
         clk               => sysClk,
         rst               => sysRst,
         acqBusy           => acqBusy,
         roClkTail         => iRoClkTail(i),
         asicDout          => muxAsicDout(3+i*4 downto 0+i*4),
         asicRoClk         => asicRoClk,
         doutOut           => doutOut(15+i*16 downto 0+i*16),
         doutRd            => r.doutRd(15+i*16 downto 0+i*16),
         doutValid         => doutValid(15+i*16 downto 0+i*16),
         sAxilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
         sAxilWriteSlave   => open,
         sAxilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
         sAxilReadSlave    => open
      );
   
   end generate;
   
   roClkTail <= iRoClkTail(0);
   
   ----------------------------------------------------------------------
   -- Streaming out FIFO
   ----------------------------------------------------------------------
   
   U_AxisOut : entity work.AxiStreamFifoV2
   generic map (
      -- General Configurations
      TPD_G               => TPD_G,
      PIPE_STAGES_G       => 1,
      SLAVE_READY_EN_G    => true,
      VALID_THOLD_G       => 1,     -- =0 = only when frame ready
      -- FIFO configurations
      GEN_SYNC_FIFO_G     => false,
      CASCADE_SIZE_G      => 1,
      FIFO_ADDR_WIDTH_G   => 10,
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C
   )
   port map (
      -- Slave Port
      sAxisClk    => sysClk,
      sAxisRst    => sysRst,
      sAxisMaster => r.txMaster,
      sAxisSlave  => txSlave,
      -- Master Port
      mAxisClk    => axisClk,
      mAxisRst    => axisRst,
      mAxisMaster => axisMaster,
      mAxisSlave  => axisSlave
   );
   
end rtl;