-------------------------------------------------------------------------------
-- File       : RdoutCoreBram.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'EPIX Development Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity RdoutCoreBram is
   generic (
      TPD_G             : time            := 1 ns;
      BANK_COLS_G       : natural         := 48;
      BANK_ROWS_G       : natural         := 178;
      LINE_REVERSE_G    : slv(3 downto 0) := "1010";
      AXISFIFO_G        : boolean         := true
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
      -- Monitor data for the image stream
      monData              : in  Slv16Array(37 downto 0);
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
   constant BANK_COLS_C    : natural := BANK_COLS_G/4 - 1;
   constant BANK_ROWS_C    : natural := BANK_ROWS_G - 1;
   constant COLS_BITS_C    : natural := log2(BANK_COLS_G/4);   -- div by 4 for 64 bit packed 4 pixels
   constant ROWS_BITS_C    : natural := log2(BANK_ROWS_G);

   -- Buffer settings
   constant BUFF_BITS_C    : integer range 1 to 5 := 2;
   constant BUFF_MAX_C     : slv(2**BUFF_BITS_C-1 downto 0) := (others=>'1');
   constant TIMEOUT_C      : integer := 500000;  -- 5ms

   -- Stream settings
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(8);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(8);

   constant LANE_C         : slv( 1 downto 0) := "00";
   constant VC_C           : slv( 1 downto 0) := "00";
   constant QUAD_C         : slv( 1 downto 0) := "00";

   type WrStateType is (
      IDLE_S,
      BUFFER_S,
      WRITE_S
   );

   type RdStateType is (
      IDLE_S,
      WAIT_LINE_S,
      MOVE_LINE_S
   );

   type StrStateType is (
      IDLE_S,
      HDR_S,
      DATA_S,
      FOOTER_S,
      TPS_DATA_S
   );

   type RegType is record
      rdoutEn              : sl;
      rdoutEnReg           : sl;
      testData             : sl;
      adcDataBuf0          : Slv14Array(63 downto 0);
      adcDataBuf1          : Slv14Array(63 downto 0);
      adcDataBuf2          : Slv14Array(63 downto 0);
      adcDataBufCnt        : integer range 0 to 2;
      seqCount             : slv(31 downto 0);
      seqCountReset        : sl;
      adcPipelineDly       : slv(7 downto 0);
      adcPipelineDlyReg    : slv(31 downto 0);
      acqSmplEn            : slv(255 downto 0);
      readPend             : sl;
      buffErr              : sl;
      timeErr              : sl;
      wordCnt              : integer range 0 to BANK_COLS_G/4*16;
      timeCnt              : integer range 0 to TIMEOUT_C;
      sRowCount            : integer range 0 to 4*BANK_ROWS_G-1; -- total number of rows
      bankCount            : integer range 0 to 15;              -- 16 banks per line
      colCount             : integer range 0 to BANK_COLS_C;     -- generic column count
      rowCount             : slv(ROWS_BITS_C-1 downto 0);        -- generic row count
      lineBufErr           : Slv32Array(3 downto 0);
      lineBufErrEn         : slv(3 downto 0);
      lineBufValid         : slv(2**BUFF_BITS_C-1 downto 0);
      memWrEn              : sl;
      lineWrAddr           : slv(COLS_BITS_C-1 downto 0);
      lineWrBuff           : slv(BUFF_BITS_C-1 downto 0);
      lineRdAddrF          : slv(COLS_BITS_C-1 downto 0);
      lineRdAddrR          : slv(COLS_BITS_C-1 downto 0);
      memWrAddr            : slv(BUFF_BITS_C+COLS_BITS_C-1 downto 0);
      doutRd               : Slv16Array(3 downto 0);
      fifoWrEn             : sl;
      fifoDin              : Slv64Array(3 downto 0);
      fifoRdEn             : slv(3 downto 0);
      wrState              : WrStateType;
      rdState              : RdStateType;
      strState             : StrStateType;
      txMaster             : AxiStreamMasterType;
      sAxilWriteSlave      : AxiLiteWriteSlaveType;
      sAxilReadSlave       : AxiLiteReadSlaveType;
      monData              : Slv16Array(37 downto 0);
      overSampleEn         : sl;
      overSampleSize       : slv(2 downto 0);
      overSampleSizePwr    : slv(6 downto 0);
      sAxisDropWord        : sl;
      sAxisDropWordCount   : slv(8 downto 0); 
      sAxisDropFrame       : sl;
      sAxisDropFrameCount  : slv(8 downto 0);
      mAxisDropWord        : sl;
      mAxisDropWordCount   : slv(8 downto 0);
      mAxisDropFrame       : sl;
      mAxisDropFrameCount  : slv(8 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdoutEn              => '0',
      rdoutEnReg           => '0',
      testData             => '0',
      adcDataBuf0          => (others=>(others=>'0')),
      adcDataBuf1          => (others=>(others=>'0')),
      adcDataBuf2          => (others=>(others=>'0')),
      adcDataBufCnt        => 0,
      seqCount             => (others=>'0'),
      seqCountReset        => '0',
      adcPipelineDly       => (others=>'0'),
      adcPipelineDlyReg    => (others=>'0'),
      acqSmplEn            => (others=>'0'),
      readPend             => '0',
      buffErr              => '0',
      timeErr              => '0',
      wordCnt              => 0,
      timeCnt              => 0,
      sRowCount            => 0,
      bankCount            => 0,
      colCount             => 0,
      rowCount             => (others=>'0'),
      lineBufErr           => (others=>(others=>'0')),
      lineBufErrEn         => (others=>'0'),
      lineBufValid         => (others=>'0'),
      memWrEn              => '0',
      lineWrAddr           => (others=>'0'),
      lineWrBuff           => (others=>'0'),
      lineRdAddrF          => (others=>'0'),
      lineRdAddrR          => (others=>'0'),
      memWrAddr            => (others=>'0'),
      doutRd               => (others=>(others=>'0')),
      fifoWrEn             => '0',
      fifoDin              => (others=>(others=>'0')),
      fifoRdEn             => (others=>'0'),
      wrState              => IDLE_S,
      rdState              => IDLE_S,
      strState             => IDLE_S,
      txMaster             => AXI_STREAM_MASTER_INIT_C,
      sAxilWriteSlave      => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave       => AXI_LITE_READ_SLAVE_INIT_C,
      monData              => (others=>(others=>'0')),
      overSampleEn         => '0',
      overSampleSize       => (others=>'0'),
      overSampleSizePwr    => (others=>'0'),
      sAxisDropWord        => '0',
      sAxisDropWordCount   => (others=>'0'),  
      sAxisDropFrame       => '0',
      sAxisDropFrameCount  => (others=>'0'),
      mAxisDropWord        => '0',
      mAxisDropWordCount   => (others=>'0'),
      mAxisDropFrame       => '0',
      mAxisDropFrameCount  => (others=>'0')
   );

   signal r                : RegType := REG_INIT_C;
   signal rin              : RegType;

   signal acqBusyEdge      : std_logic             := '0';
   signal txSlave          : AxiStreamSlaveType;

   signal memWrEn          : sl;
   signal memWrAddr        : slv(BUFF_BITS_C+COLS_BITS_C-1 downto 0);
   --signal memRdAddr        : slv(BUFF_BITS_C+COLS_BITS_C-1 downto 0);
   signal memRdAddr        : Slv16Array(63 downto 0);
   signal memRdData        : Slv64VectorArray(3 downto 0, 15 downto 0);
   signal memWrData        : Slv64Array(63 downto 0);

   signal adcStreamOvs     : AxiStreamMasterArray(63 downto 0);
   signal muxStrMap        : AxiStreamMasterArray(63 downto 0);
   signal muxStream        : AxiStreamMasterArray(63 downto 0);

   signal iRoClkTail       : Slv8Array(3 downto 0);
   signal doutOut          : Slv4VectorArray(3 downto 0, 15 downto 0);
   signal doutCount        : Slv8VectorArray(3 downto 0, 15 downto 0);
   signal doutValid        : Slv16Array(3 downto 0);

   signal muxAsicDout      : slv(15 downto 0);
   signal muxDoutMap       : slv(15 downto 0);

   signal doutRd           : Slv16Array(3 downto 0);

   signal fifoDout         : Slv64Array(3 downto 0);
   signal fifoAfull        : slv(3 downto 0);
   signal fifoRdy          : slv(3 downto 0);
   signal fifoValid        : slv(3 downto 0);
   signal fifoCascadeData  : Slv64Array(3 downto 0);
   signal fifrCascadeEn    : slv(3 downto 0);
   signal fifoCascadeValid : slv(3 downto 0);
   signal fifrCascadeAfull : slv(3 downto 0);

   signal fifoRdEn         : slv(3 downto 0);

   signal sAxisDropWord    : sl;
   signal sAxisDropFrame   : sl;
   signal mAxisDropWord    : sl;
   signal mAxisDropFrame   : sl;

begin
   --r.rowCount(BUFF_BITS_C-1 downto 0)
   assert ROWS_BITS_C >= BUFF_BITS_C
      report "ROWS_BITS_C must be >= BUFF_BITS_C"
      severity failure;

   assert BANK_COLS_G mod 4 = 0
      report "BANK_COLS_G must be multiple of 4"
      severity failure;

   muxStream   <=
      testStream     when r.testData = '1' else
      adcStreamOvs   when r.overSampleEn = '1' else
      adcStream;

   muxAsicDout <=
      asicDoutTest  when r.testData = '1' else
      asicDout;

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

   muxDoutMap( 0) <= muxAsicDout( 9);
   muxDoutMap( 1) <= muxAsicDout(10);

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

   muxDoutMap( 2) <= muxAsicDout(13);
   muxDoutMap( 3) <= muxAsicDout(14);

   -- sRow 1 (bottom, top)
   -- ASIC 8, ASIC 11  (left)
   muxStrMap(16) <= muxStream(32);
   muxStrMap(17) <= muxStream(33);
   muxStrMap(18) <= muxStream(34);
   muxStrMap(19) <= muxStream(35);
   muxStrMap(20) <= muxStream(36);
   muxStrMap(21) <= muxStream(37);
   muxStrMap(22) <= muxStream(38);
   muxStrMap(23) <= muxStream(39);

   muxDoutMap( 4) <= muxAsicDout( 8);
   muxDoutMap( 5) <= muxAsicDout(11);

   -- sRow 1 (bottom, top)
   -- ASIC 12, ASIC 15  (right)
   muxStrMap(24) <= muxStream(48);
   muxStrMap(25) <= muxStream(49);
   muxStrMap(26) <= muxStream(50);
   muxStrMap(27) <= muxStream(51);
   muxStrMap(28) <= muxStream(52);
   muxStrMap(29) <= muxStream(53);
   muxStrMap(30) <= muxStream(54);
   muxStrMap(31) <= muxStream(55);

   muxDoutMap( 6) <= muxAsicDout(12);
   muxDoutMap( 7) <= muxAsicDout(15);

   -- sRow 2 (top, bottom)
   -- ASIC 1, ASIC 2 (left)
   muxStrMap(32) <= muxStream( 8);
   muxStrMap(33) <= muxStream( 9);
   muxStrMap(34) <= muxStream(10);
   muxStrMap(35) <= muxStream(11);
   muxStrMap(36) <= muxStream(12);
   muxStrMap(37) <= muxStream(13);
   muxStrMap(38) <= muxStream(14);
   muxStrMap(39) <= muxStream(15);

   muxDoutMap( 8) <= muxAsicDout( 1);
   muxDoutMap( 9) <= muxAsicDout( 2);

   -- sRow 2 (top, bottom)
   -- ASIC 5, ASIC 6 (right)
   muxStrMap(40) <= muxStream(24);
   muxStrMap(41) <= muxStream(25);
   muxStrMap(42) <= muxStream(26);
   muxStrMap(43) <= muxStream(27);
   muxStrMap(44) <= muxStream(28);
   muxStrMap(45) <= muxStream(29);
   muxStrMap(46) <= muxStream(30);
   muxStrMap(47) <= muxStream(31);

   muxDoutMap(10) <= muxAsicDout( 5);
   muxDoutMap(11) <= muxAsicDout( 6);

   -- sRow 3 (top, top)
   -- ASIC 0, ASIC 3  (left)
   muxStrMap(48) <= muxStream(0);
   muxStrMap(49) <= muxStream(1);
   muxStrMap(50) <= muxStream(2);
   muxStrMap(51) <= muxStream(3);
   muxStrMap(52) <= muxStream(4);
   muxStrMap(53) <= muxStream(5);
   muxStrMap(54) <= muxStream(6);
   muxStrMap(55) <= muxStream(7);

   muxDoutMap(12) <= muxAsicDout( 0);
   muxDoutMap(13) <= muxAsicDout( 3);

   -- sRow 3 (top, top)
   -- ASIC 4, ASIC 7  (right)
   muxStrMap(56) <= muxStream(16);
   muxStrMap(57) <= muxStream(17);
   muxStrMap(58) <= muxStream(18);
   muxStrMap(59) <= muxStream(19);
   muxStrMap(60) <= muxStream(20);
   muxStrMap(61) <= muxStream(21);
   muxStrMap(62) <= muxStream(22);
   muxStrMap(63) <= muxStream(23);

   muxDoutMap(14) <= muxAsicDout( 4);
   muxDoutMap(15) <= muxAsicDout( 7);

   --------------------------------------------------
   -- Instantiate Moving Average cores for oversampling
   --------------------------------------------------
   G_OVERSAMPLE_AVG : for i in 63 downto 0 generate
      signal avgDataTmp       : Slv21Array(63 downto 0);
      signal avgDataTmpValid  : slv(63 downto 0);
      signal avgDataMux       : Slv14Array(63 downto 0);
   begin

      U_MovingAvg : entity surf.BoxcarIntegrator
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 14,
            ADDR_WIDTH_G => 7
         )
         port map (
            clk      => sysClk,
            rst      => sysRst,
            -- Configuration, intCount is 0 based, 0 = 1, 1 = 2, 1023 = 1024
            intCount => r.overSampleSizePwr,
            -- Inbound Interface
            ibValid  => adcStream(i).tValid,
            ibData   => adcStream(i).tData(13 downto 0),
            -- Outbound Interface
            obValid  => avgDataTmpValid(i),
            obData   => avgDataTmp(i)
         );

      avgDataMux(i) <=
         avgDataTmp(i)(20 downto 7) when r.overSampleSize = 7 else
         avgDataTmp(i)(19 downto 6) when r.overSampleSize = 6 else
         avgDataTmp(i)(18 downto 5) when r.overSampleSize = 5 else
         avgDataTmp(i)(17 downto 4) when r.overSampleSize = 4 else
         avgDataTmp(i)(16 downto 3) when r.overSampleSize = 3 else
         avgDataTmp(i)(15 downto 2) when r.overSampleSize = 2 else
         avgDataTmp(i)(14 downto 1) when r.overSampleSize = 1 else
         avgDataTmp(i)(13 downto 0);

      U_Reg : entity surf.RegisterVector
         generic map (
            TPD_G       => TPD_G,
            WIDTH_G     => 15
         )
         port map (
            clk         => sysClk,
            rst         => sysRst,
            sig_i(14)   => avgDataTmpValid(i),
            sig_i(13 downto 0) => avgDataMux(i),
            reg_o(14)   => adcStreamOvs(i).tValid,
            reg_o(13 downto 0) => adcStreamOvs(i).tData(13 downto 0)
         );

   end generate;

   --------------------------------------------------
   -- Data storage and readout FSMs
   --------------------------------------------------

   U_ReadStartEdge : entity surf.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => acqBusy,
         risingEdge => acqBusyEdge
      );

   comb : process (sysRst, sAxilReadMaster, sAxilWriteMaster, txSlave, r,
      acqBusyEdge, acqBusy, acqCount, acqSmplEn, memRdData, opCode, muxStrMap, tpsStream,
      doutValid, doutOut, doutCount, monData, fifoRdy, fifoValid, fifoDout, sAxisDropWord,
      sAxisDropFrame, mAxisDropWord, mAxisDropFrame) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
      variable doutValidVar : slv(3 downto 0);
      variable doutCountVar : slv(3 downto 0);
      variable sRowCountMod : integer range 0 to 3;
   begin
      v := r;

      v.adcPipelineDlyReg := (others=>'0');

      -- settings that chan change when no readout is pending
      if r.readPend = '0' and acqBusyEdge = '0' then
         v.rdoutEn         := r.rdoutEnReg;
      end if;

      -- count readouts
      if r.seqCountReset = '1' then
         v.seqCount := (others=>'0');
      elsif acqBusyEdge = '1' and r.rdoutEn = '1' then
         v.seqCount := r.seqCount + 1;
      end if;

      if sAxisDropWord = '1' then
        v.sAxisDropWordCount := r.sAxisDropWordCount + 1;
      end if;
      
      if sAxisDropFrame = '1' then
        v.sAxisDropFrameCount := r.sAxisDropFrameCount + 1;
      end if;

      if mAxisDropWord = '1' then
        v.mAxisDropWordCount := r.mAxisDropWordCount + 1;
      end if;
      
      if mAxisDropFrame = '1' then
        v.mAxisDropFrameCount := r.mAxisDropFrameCount + 1;
      end if;

      --------------------------------------------------
      -- AXI Lite register logic
      --------------------------------------------------

      -- Determine the AXI-Lite transaction
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.rdoutEnReg        );
      axiSlaveRegisterR(regCon, x"004", 0, r.seqCount          );
      axiSlaveRegister (regCon, x"008", 0, v.seqCountReset     );
      axiSlaveRegister (regCon, x"00C", 0, v.adcPipelineDlyReg );
      axiSlaveRegisterR(regCon, x"00C", 0, r.adcPipelineDly    );
      axiSlaveRegisterR(regCon, x"010", 0, r.lineBufErr(0)     );
      axiSlaveRegisterR(regCon, x"014", 0, r.lineBufErr(1)     );
      axiSlaveRegisterR(regCon, x"018", 0, r.lineBufErr(2)     );
      axiSlaveRegisterR(regCon, x"01C", 0, r.lineBufErr(3)     );
      axiSlaveRegister (regCon, x"020", 0, v.testData          );


      axiSlaveRegister (regCon, x"024", 0, v.overSampleEn      );
      axiSlaveRegister (regCon, x"028", 0, v.overSampleSize    );

      axiSlaveRegister (regCon, x"02C", 0, v.sAxisDropWordCount );
      axiSlaveRegister (regCon, x"030", 0, v.sAxisDropFrameCount);
      axiSlaveRegister (regCon, x"034", 0, v.mAxisDropWordCount );
      axiSlaveRegister (regCon, x"038", 0, v.mAxisDropFrameCount);

      if r.overSampleSize = 0 then
         v.overSampleSizePwr   := "0000000";
      elsif r.overSampleSize = 1 then
         v.overSampleSizePwr   := "0000001";
      elsif r.overSampleSize = 2 then
         v.overSampleSizePwr   := "0000011";
      elsif r.overSampleSize = 3 then
         v.overSampleSizePwr   := "0000111";
      elsif r.overSampleSize = 4 then
         v.overSampleSizePwr   := "0001111";
      elsif r.overSampleSize = 5 then
         v.overSampleSizePwr   := "0011111";
      elsif r.overSampleSize = 6 then
         v.overSampleSizePwr   := "0111111";
      else
         v.overSampleSizePwr   := "1111111";
      end if;


      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);

      -- ADC pipeline delay is preset by the Microblaze and should be changed only be an expert
      if r.adcPipelineDlyReg(31 downto 16) = x"AAAA" then
         v.adcPipelineDly := r.adcPipelineDlyReg(7 downto 0);
      end if;

      --------------------------------------------------
      -- Line buffers write FSM (64 bank channels)
      -- one ADC pipeline delay to allow common DPRAM write control
      --------------------------------------------------

      v.memWrEn   := '0';

      case r.wrState is

         -- write samples to RAM when readout is pending
         when IDLE_S =>
            if r.readPend = '1' then
               v.wrState      := BUFFER_S;
            end if;
            v.lineWrAddr      := (others=>'0');
            v.lineWrBuff      := (others=>'0');
            v.lineBufValid    := (others=>'0');
            v.adcDataBufCnt   := 0;

         -- buffer first sample for 32 bit write
         when BUFFER_S =>
            -- drive the buffer logic on delayed strobe
            if r.acqSmplEn(conv_integer(r.adcPipelineDly)) = '1' then
               -- buffer incoming samples for 32 bit data packing
               for i in 63 downto 0 loop
                  v.adcDataBuf0(i) := muxStrMap(i).tData(13 downto 0);
                  v.adcDataBuf1(i) := r.adcDataBuf0(i);
                  v.adcDataBuf2(i) := r.adcDataBuf1(i);
               end loop;
               if r.adcDataBufCnt < 2 then
                  v.adcDataBufCnt := r.adcDataBufCnt + 1;
               else
                  v.adcDataBufCnt := 0;
                  v.wrState       := WRITE_S;
               end if;
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
                  v.lineBufValid(conv_integer(r.lineWrBuff)) := '1';
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
         if r.acqSmplEn(conv_integer(r.adcPipelineDly)) = '1' and r.lineBufValid = BUFF_MAX_C then
            v.lineBufErrEn(i) := '1';
            v.buffErr         := '1';
         end if;
      end loop;

      -- clear error counters when readout is starting
      if r.rdoutEnReg = '1' and r.rdoutEn = '0' then
         v.lineBufErr   := (others=>(others=>'0'));
      end if;

      --------------------------------------------------
      -- FSM to assemble and stream 4 lines (16 banks per line)
      -- each line (super row) is written in parallel to 4 FIFOs
      --------------------------------------------------

      doutValidVar(0) := doutValid(0)(r.bankCount);
      doutValidVar(1) := doutValid(1)(r.bankCount);
      doutValidVar(2) := doutValid(2)(r.bankCount);
      doutValidVar(3) := doutValid(3)(r.bankCount);
      if doutCount(0, r.bankCount) >= BANK_COLS_C then
         doutCountVar(0) := '1';
      else
         doutCountVar(0) := '0';
      end if;
      if doutCount(1, r.bankCount) >= BANK_COLS_C then
         doutCountVar(1) := '1';
      else
         doutCountVar(1) := '0';
      end if;
      if doutCount(2, r.bankCount) >= BANK_COLS_C then
         doutCountVar(2) := '1';
      else
         doutCountVar(2) := '0';
      end if;
      if doutCount(3, r.bankCount) >= BANK_COLS_C then
         doutCountVar(3) := '1';
      else
         doutCountVar(3) := '0';
      end if;

      v.fifoWrEn := '0';
      v.doutRd := (others=>(others=>'0'));

      case r.rdState is

         -- wait for trigger
         when IDLE_S =>
            v.lineRdAddrF  := (others=>'0');
            v.lineRdAddrR  := toSlv(BANK_COLS_C, COLS_BITS_C);
            v.bankCount    := 0;
            v.colCount     := 0;
            v.rowCount     := (others=>'0');
            v.readPend     := '0';
            if acqBusyEdge = '1' and r.rdoutEn = '1' and r.buffErr = '0' and r.timeErr = '0' then
               v.readPend  := '1';
               v.rdState   := WAIT_LINE_S;
            end if;


         when WAIT_LINE_S =>
            if r.buffErr = '1' then
               v.timeCnt   := 0;
               v.rdState   := IDLE_S;
            elsif v.lineBufValid(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) = '1' and doutValidVar = "1111" and doutCountVar = "1111" then
               v.lineRdAddrF := r.lineRdAddrF + 1;
               v.lineRdAddrR := r.lineRdAddrR - 1;
               v.timeCnt   := 0;
               v.rdState   := MOVE_LINE_S;
            elsif r.timeCnt = TIMEOUT_C then
               v.timeErr   := '1';
               v.timeCnt   := 0;
               v.rdState   := IDLE_S;
            else
               v.timeCnt   := r.timeCnt + 1;
            end if;

         when MOVE_LINE_S =>
            if r.buffErr = '1' then
               v.rdState   := IDLE_S;
            elsif fifoRdy = "1111" then

               v.fifoWrEn := '1';

               for i in 3 downto 0 loop
                  v.fifoDin(i)(63 downto 0) := memRdData(i, r.bankCount);  -- super row 0-3, bank 0-15 = 64 memory channels
                  -- insert (overwrite) dout bits
                  v.fifoDin(i)(62) := doutOut(i, r.bankCount)(3);
                  v.fifoDin(i)(46) := doutOut(i, r.bankCount)(2);
                  v.fifoDin(i)(30) := doutOut(i, r.bankCount)(1);
                  v.fifoDin(i)(14) := doutOut(i, r.bankCount)(0);
                  v.doutRd(i)(r.bankCount) := '1';
               end loop;


               if r.colCount < BANK_COLS_C then    -- next column in bank
                  v.colCount := r.colCount + 1;
               elsif r.bankCount < 15 then         -- next bank (out of 16)
                  v.colCount  := 0;
                  v.bankCount := r.bankCount + 1;
               elsif r.rowCount < BANK_ROWS_C then -- next row (go to wait for line state)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.lineBufValid(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  v.rowCount     := r.rowCount + 1;
                  v.rdState      := WAIT_LINE_S;
               else                                -- image done (go to footer state)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.lineBufValid(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  v.rowCount     := (others=>'0');
                  v.rdState      := IDLE_S;
               end if;

               -- move the read address 1 cycle ahead of the pixel counters
               if r.colCount = BANK_COLS_C and r.bankCount = 15 then
                  v.lineRdAddrF  := (others=>'0');
                  v.lineRdAddrR  := toSlv(BANK_COLS_C, COLS_BITS_C);
               elsif r.colCount = BANK_COLS_C-1 then
                  v.lineRdAddrF  := (others=>'0');
                  v.lineRdAddrR  := toSlv(BANK_COLS_C, COLS_BITS_C);
               else
                  v.lineRdAddrF := r.lineRdAddrF + 1;
                  v.lineRdAddrR := r.lineRdAddrR - 1;
               end if;

            end if;

         when others =>
            v.rdState := IDLE_S;

      end case;


      --------------------------------------------------
      -- FSM to stream image data
      --------------------------------------------------

      -- Reset strobing Signals
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
         v.txMaster.tStrb  := (others => '1');
      end if;

      v.fifoRdEn := "0000";

      case r.strState is

         -- wait for trigger
         when IDLE_S =>
            v.sRowCount    := 0;
            v.wordCnt      := 0;
            v.buffErr      := '0';
            v.timeErr      := '0';
            v.lineBufErrEn := (others=>'0');
            v.monData      := monData;
            if r.readPend = '1' then
               v.strState   := HDR_S;
            end if;

         when HDR_S =>
            if v.txMaster.tValid = '0' then
               v.txMaster.tValid := '1';
               if r.wordCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, v.txMaster, '1');
                  v.txMaster.tData(31 downto  0) := x"000000" & "00" & LANE_C & "00" & VC_C;
                  v.txMaster.tData(63 downto 32) := x"0" & "00" & QUAD_C & opCode & acqCount(15 downto 0);
               elsif r.wordCnt = 1 then
                  v.txMaster.tData(31 downto  0) := r.seqCount;
                  v.txMaster.tData(63 downto 32) := x"00000000";
               else
                  v.txMaster.tData(31 downto  0) := x"00000000";
                  v.txMaster.tData(63 downto 32) := x"00000000";
               end if;
               if (r.wordCnt = 3) then
                  v.wordCnt   := 0;
                  v.strState   := DATA_S;
               else
                  v.wordCnt   := r.wordCnt + 1;
               end if;
            end if;

         when DATA_S =>

            -- get the last 2 bits of row counter to address a fifo
            -- data from each super row is split into 4 fifos
            -- de-interleaving is easy to implement, but it would cost a few ms of latency
            -- due to waiting for 3 FIFOs be filled with ASIC readout data
            -- deinterleaving would not work at 1kFPS without DDR buffering
            sRowCountMod := conv_integer(toSlv(r.sRowCount, 2));

            if r.buffErr = '1' or r.timeErr = '1' then
               v.strState   := FOOTER_S;
            elsif v.txMaster.tValid = '0' and fifoValid(sRowCountMod) = '1' then

               v.txMaster.tValid             := '1';
               v.txMaster.tData(63 downto 0) := fifoDout(sRowCountMod);
               v.fifoRdEn(sRowCountMod)      := '1';

               -- move data from one super row
               -- 16 banks * 12 (64 byte packed) columns
               if r.wordCnt < BANK_COLS_G/4*16 - 1 then
                  v.wordCnt := r.wordCnt + 1;
               -- move to the next super row
               elsif r.sRowCount < 4*BANK_ROWS_G-1 then
                  v.wordCnt   := 0;
                  v.sRowCount := r.sRowCount + 1;
               -- all rows completed (done)
               else
                  v.wordCnt   := 0;
                  v.sRowCount := 0;
                  v.strState  := FOOTER_S;
               end if;

            end if;

         when FOOTER_S =>
            -- reserved footer space similar to small epix data frame
            -- length of 1 super row
            if v.txMaster.tValid = '0' then

               v.txMaster.tValid := '1';

               if r.wordCnt = 0 then
                  v.txMaster.tData(31 downto  0) := r.monData( 1) & r.monData( 0);
                  v.txMaster.tData(63 downto 32) := r.monData( 3) & r.monData( 2);
               elsif r.wordCnt = 1 then
                  v.txMaster.tData(31 downto  0) := r.monData( 5) & r.monData( 4);
                  v.txMaster.tData(63 downto 32) := r.monData( 7) & r.monData( 6);
               elsif r.wordCnt = 2 then
                  v.txMaster.tData(31 downto  0) := r.monData( 9) & r.monData( 8);
                  v.txMaster.tData(63 downto 32) := r.monData(11) & r.monData(10);
               elsif r.wordCnt = 3 then
                  v.txMaster.tData(31 downto  0) := r.monData(13) & r.monData(12);
                  v.txMaster.tData(63 downto 32) := r.monData(15) & r.monData(14);
               elsif r.wordCnt = 4 then
                  v.txMaster.tData(31 downto  0) := r.monData(17) & r.monData(16);
                  v.txMaster.tData(63 downto 32) := r.monData(19) & r.monData(18);
               elsif r.wordCnt = 5 then
                  v.txMaster.tData(31 downto  0) := r.monData(21) & r.monData(20);
                  v.txMaster.tData(63 downto 32) := r.monData(23) & r.monData(22);
               elsif r.wordCnt = 6 then
                  v.txMaster.tData(31 downto  0) := r.monData(25) & r.monData(24);
                  v.txMaster.tData(63 downto 32) := r.monData(27) & r.monData(26);
               elsif r.wordCnt = 7 then
                  v.txMaster.tData(31 downto  0) := r.monData(29) & r.monData(28);
                  v.txMaster.tData(63 downto 32) := r.monData(31) & r.monData(30);
               elsif r.wordCnt = 8 then
                  v.txMaster.tData(31 downto  0) := r.monData(33) & r.monData(32);
                  v.txMaster.tData(63 downto 32) := r.monData(35) & r.monData(34);
               elsif r.wordCnt = 9 then
                  v.txMaster.tData(31 downto  0) := r.monData(37) & r.monData(36);
                  v.txMaster.tData(63 downto 32) := x"00000000";
               else
                  v.txMaster.tData(31 downto  0) := x"00000000";
                  v.txMaster.tData(63 downto 32) := x"00000000";
               end if;
               if (r.wordCnt < 10) then
                  v.wordCnt := r.wordCnt + 1;
               end if;

               -- transmit total of 1 super row (mostly zeroed reserved data)
               if r.wordCnt < BANK_COLS_G/4*16 - 1 then
                  v.wordCnt  := r.wordCnt + 1;
               else
                  v.wordCnt  := 0;
                  v.strState := TPS_DATA_S;
               end if;

            end if;

         when TPS_DATA_S =>
            if v.txMaster.tValid = '0' then
               v.txMaster.tValid := '1';
               if r.wordCnt = 0 then
                  v.txMaster.tData(31 downto  0) := "00" & tpsStream( 1).tData(13 downto 0) & "00" & tpsStream( 0).tData(13 downto 0);
                  v.txMaster.tData(63 downto 32) := "00" & tpsStream( 3).tData(13 downto 0) & "00" & tpsStream( 2).tData(13 downto 0);
               elsif r.wordCnt = 1 then
                  v.txMaster.tData(31 downto  0) := "00" & tpsStream( 5).tData(13 downto 0) & "00" & tpsStream( 4).tData(13 downto 0);
                  v.txMaster.tData(63 downto 32) := "00" & tpsStream( 7).tData(13 downto 0) & "00" & tpsStream( 6).tData(13 downto 0);
               elsif r.wordCnt = 2 then
                  v.txMaster.tData(31 downto  0) := "00" & tpsStream( 9).tData(13 downto 0) & "00" & tpsStream( 8).tData(13 downto 0);
                  v.txMaster.tData(63 downto 32) := "00" & tpsStream(11).tData(13 downto 0) & "00" & tpsStream(10).tData(13 downto 0);
               else
                  v.txMaster.tData(31 downto  0) := "00" & tpsStream(13).tData(13 downto 0) & "00" & tpsStream(12).tData(13 downto 0);
                  v.txMaster.tData(63 downto 32) := "00" & tpsStream(15).tData(13 downto 0) & "00" & tpsStream(14).tData(13 downto 0);
               end if;

               if (r.wordCnt = 3) then
                  v.wordCnt   := 0;
                  v.txMaster.tLast  := '1';
                  ssiSetUserEofe(SLAVE_AXI_CONFIG_C, v.txMaster, r.buffErr or r.timeErr);
                  for i in 3 downto 0 loop
                     if r.lineBufErrEn(i) = '1' then
                        v.lineBufErr(i) := r.lineBufErr(i) + 1;
                     end if;
                  end loop;
                  v.strState   := IDLE_S;
               else
                  v.wordCnt   := r.wordCnt + 1;
               end if;

            end if;

         when others =>
            v.strState := IDLE_S;

      end case;


      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;

      memWrEn     <= v.memWrEn;
      memWrAddr   <= r.memWrAddr;

      fifoRdEn    <= v.fifoRdEn;

      -- read strobe for the dout FIFOs
      -- swap ASIC banks in reversed super rows
      for i in 3 downto 0 loop
         if LINE_REVERSE_G(i) = '0' then
            doutRd(i) <= v.doutRd(i);
         else
            for j in 3 downto 0 loop
               for k in 3 downto 0 loop
                  doutRd(i)(j*4+k) <= v.doutRd(i)(j*4+(3-k));
               end loop;
            end loop;
         end if;
      end loop;

      readDone    <= not r.readPend;

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

         -- stage four 16 bit words for write into 64 bit memory
         -- swap words if line readout is reversed
         memWrData(i*16+j) <=

            "00" & muxStrMap(i*16+j).tData(13 downto 0) &
            "00" & r.adcDataBuf0(i*16+j) &
            "00" & r.adcDataBuf1(i*16+j) &
            "00" & r.adcDataBuf2(i*16+j) when LINE_REVERSE_G(i) = '0' else

            "00" & r.adcDataBuf2(i*16+j) &
            "00" & r.adcDataBuf1(i*16+j) &
            "00" & r.adcDataBuf0(i*16+j) &
            "00" & muxStrMap(i*16+j).tData(13 downto 0);

         memRdAddr(i*16+j)(BUFF_BITS_C+COLS_BITS_C-1 downto 0) <=
            r.rowCount(BUFF_BITS_C-1 downto 0) & r.lineRdAddrF when LINE_REVERSE_G(i) = '0' else
            r.rowCount(BUFF_BITS_C-1 downto 0) & r.lineRdAddrR;


         U_BankBufRam: entity surf.DualPortRam
         generic map (
            TPD_G          => TPD_G,
            DATA_WIDTH_G   => 64,
            ADDR_WIDTH_G   => BUFF_BITS_C+COLS_BITS_C,
            MEMORY_TYPE_G  => "distributed"
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
            addrb   => memRdAddr(i*16+j)(BUFF_BITS_C+COLS_BITS_C-1 downto 0),
            doutb   => memRdData(i, j)
         );

      end generate G_BankBuf;
   end generate G_sRowBuf;

   ---------------------------------------------------------------
   -- Digital output deserializer
   --------------------- ------------------------------------------
   G_DOUT_EPIX10KA : for i in 3 downto 0 generate
      signal iDoutOut   : Slv4Array(63 downto 0);
      signal iDoutCount : Slv8Array(63 downto 0);
      signal asicRoClkGated : sl;
   begin

      U_DoutAsic : entity work.DoutDeserializer
      generic map (
         TPD_G             => TPD_G,
         BANK_COLS_G       => BANK_COLS_G,
         RD_ORDER_INIT_G   => (others=>LINE_REVERSE_G(i)),
         FOUR_BIT_OUT_G    => true
      )
      port map (
         clk               => sysClk,
         rst               => sysRst,
         acqBusy           => acqBusy,
         roClkTail         => iRoClkTail(i),
         asicDout          => muxDoutMap(3+i*4 downto 0+i*4),
         asicRoClk         => asicRoClkGated,
         doutOut4          => iDoutOut(15+i*16 downto 0+i*16),
         doutRd            => doutRd(i),
         doutValid         => doutValid(i),
         doutCount         => iDoutCount(15+i*16 downto 0+i*16),
         sAxilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
         sAxilWriteSlave   => open,
         sAxilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
         sAxilReadSlave    => open
      );

      -- need gated clock to avoid out deserializing during
      -- the dummy readout (see AcqCore.vhd)
      asicRoClkGated <= asicRoClk and r.readPend;

      G_NORM : if LINE_REVERSE_G(i) = '0' generate
         G_VEC16 : for j in 15 downto 0 generate
            doutOut(i, j)     <= iDoutOut(j+i*16);
            doutCount(i, j)   <= iDoutCount(j+i*16);
         end generate;
      end generate;

      -- swap ASIC banks in reversed super rows
      G_REV  : if LINE_REVERSE_G(i) = '1' generate
         G_VEC1_4 : for j in 3 downto 0 generate
            G_VEC2_4 : for k in 3 downto 0 generate
               doutOut(i, j*4+k)   <= iDoutOut(j*4+(3-k)+i*16);
               doutCount(i, j*4+k) <= iDoutCount(j*4+(3-k)+i*16);
            end generate;
         end generate;
      end generate;

   end generate;

   roClkTail <= iRoClkTail(0);

   ----------------------------------------------------------------------
   -- Use plain FIFOs to store the whole image
   -- Spilt into 4 paths for faster data movement from line buffers by the rdState FS
   -- Each path corresponds to 1 out of 4 super rows
   ----------------------------------------------------------------------

   -- the cascade of 1 * 2^15 + 2^11 * 8 bytes                          = 278528 bytes
   -- the 0.25 frame size 48 cols * 178 rows * 64 banks * 2 bytes *0.25 = 273408 bytes
   -- the FIFO will fit whole image

   G_sRowFifo: for i in 3 downto 0 generate

      U_sRowFifo0 : entity surf.FifoCascade
         generic map (
            DATA_WIDTH_G      => 64,
            CASCADE_SIZE_G    => 1,
            ADDR_WIDTH_G      => 15,
            FWFT_EN_G         => true,
            GEN_SYNC_FIFO_G   => true
         )
         port map (
            rst               => sysRst,
            wr_clk            => sysClk,
            wr_en             => r.fifoWrEn,
            din               => r.fifoDin(i),
            almost_full       => fifoAfull(i),
            rd_clk            => sysClk,
            rd_en             => fifrCascadeEn(i),
            dout              => fifoCascadeData(i),
            valid             => fifoCascadeValid(i)
         );

      fifoRdy(i) <= not fifoAfull(i);

      U_sRowFifo1 : entity surf.FifoCascade
         generic map (
            DATA_WIDTH_G      => 64,
            CASCADE_SIZE_G    => 1,
            ADDR_WIDTH_G      => 11,
            FWFT_EN_G         => true,
            GEN_SYNC_FIFO_G   => true
         )
         port map (
            rst               => sysRst,
            wr_clk            => sysClk,
            wr_en             => fifrCascadeEn(i),
            din               => fifoCascadeData(i),
            almost_full       => fifrCascadeAfull(i),
            rd_clk            => sysClk,
            rd_en             => fifoRdEn(i),
            dout              => fifoDout(i),
            valid             => fifoValid(i)
         );

      fifrCascadeEn(i) <= not fifrCascadeAfull(i) and fifoCascadeValid(i);

   end generate G_sRowFifo;

   ----------------------------------------------------------------------
   -- Streaming out FIFO
   ----------------------------------------------------------------------

   G_AXISFIFO : if AXISFIFO_G = true generate
     begin
       U_AxisOut0 : entity surf.SsiFifo 
         generic map(
           -- General Configurations
           TPD_G                  => TPD_G,
           INT_PIPE_STAGES_G      => 1,
           PIPE_STAGES_G          => 1,
           SLAVE_READY_EN_G       => false,
           -- Valid threshold should always be 1 when using interleaved TDEST
           --       =1 = normal operation
           --       =0 = only when frame ready
           --       >1 = only when frame ready or # entries
           VALID_THOLD_G          => 1,
           VALID_BURST_MODE_G     => false,  -- only used in VALID_THOLD_G>1
           -- FIFO configurations
           GEN_SYNC_FIFO_G        => false,
           FIFO_ADDR_WIDTH_G      => 9,
           FIFO_FIXED_THRESH_G    => true,
           FIFO_PAUSE_THRESH_G    => 1,
           SYNTH_MODE_G           => "inferred",
           MEMORY_TYPE_G          => "block",
           -- Internal FIFO width select, "WIDE", "NARROW" or "CUSTOM"
           -- WIDE uses wider of slave / master. NARROW  uses narrower.
           -- CUSOTM uses passed FIFO_DATA_WIDTH_G
           INT_WIDTH_SELECT_G     => "WIDE",
           INT_DATA_WIDTH_G       => 16,
           -- If VALID_THOLD_G /=1, FIFO that stores on tLast transaction can be smaller.
           --       Set to 0 for same size as primary FIFO (default)
           --       Set >4 for custom size.
           --       Use at own risk. Overflow of tLast FIFO is not checked
           LAST_FIFO_ADDR_WIDTH_G => 0,
           -- Index = 0 is output, index = n is input
           CASCADE_PAUSE_SEL_G    => 0,
           CASCADE_SIZE_G         => 1,
           -- AXI Stream Port Configurations
           SLAVE_AXI_CONFIG_G     => SLAVE_AXI_CONFIG_C,
           MASTER_AXI_CONFIG_G    => MASTER_AXI_CONFIG_C)
       port map(
         -- Slave Interface (sAxisClk domain)
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Interface (mAxisClk domain)
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave,
         -- FIFO status and config
         sAxisDropWord   => sAxisDropWord,
         sAxisDropFrame  => sAxisDropFrame,
         mAxisDropWord   => mAxisDropWord,
         mAxisDropFrame  => mAxisDropFrame
         );
     end generate G_AXISFIFO;   
   
     G_NOT_AXISFIFO : if AXISFIFO_G = false generate
     begin
       axisMaster <= r.txMaster;
       txSlave    <= axisSlave;
     end generate G_NOT_AXISFIFO;

end rtl;
