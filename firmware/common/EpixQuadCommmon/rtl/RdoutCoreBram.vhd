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
   
   
   type StateType is (
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
      adcDataDly           : Slv14Array(63 downto 0);
      seqCount             : slv(31 downto 0);
      seqCountReset        : sl;
      adcPipelineDly       : slv(6 downto 0);
      acqSmplEn            : slv(127 downto 0);
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
      rdState              : StateType;
      txMaster             : AxiStreamMasterType;
      sAxilWriteSlave      : AxiLiteWriteSlaveType;
      sAxilReadSlave       : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdoutEn              => '0',
      rdoutEnReg           => '0',
      adcDataDly           => (others=>(others=>'0')),
      seqCount             => (others=>'0'),
      seqCountReset        => '0',
      adcPipelineDly       => (others=>'0'),
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
   
begin
   --r.rowCount(BUFF_BITS_C-1 downto 0)
   assert ROWS_BITS_C >= BUFF_BITS_C
      report "ROWS_BITS_C must be >= BUFF_BITS_C"
      severity failure;
   
   assert BANK_COLS_G mod 2 = 0
      report "BANK_COLS_G must be even number"
      severity failure;
   
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
      acqBusyEdge, acqBusy, acqCount, acqSmplEn, memRdData, opCode, adcStream, tpsStream) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;
      
      if r.readPend = '0' and acqBusyEdge = '0' then
         v.rdoutEn := r.rdoutEnReg;
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
      axiSlaveRegister (regCon, x"00C", 0, v.adcPipelineDly    );
      axiSlaveRegisterR(regCon, x"010", 0, r.lineBufErr(0)     );
      axiSlaveRegisterR(regCon, x"014", 0, r.lineBufErr(1)     );
      axiSlaveRegisterR(regCon, x"018", 0, r.lineBufErr(2)     );
      axiSlaveRegisterR(regCon, x"01C", 0, r.lineBufErr(3)     );
      
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);
      
      --------------------------------------------------
      -- Line buffers (64 bank channels)
      -- one pipeline delay to allow common DPRAM write control
      --------------------------------------------------
      
      if r.readPend = '1' then
         
         -- shift the sample strobe
         v.acqSmplEn := r.acqSmplEn(126 downto 0) & acqSmplEn;
         
         -- drive the buffer logic on delayed strobe
         if r.acqSmplEn(conv_integer(r.adcPipelineDly)) = '1' then
            
            -- buffer incoming samples for 32 bit data packing
            for i in 63 downto 0 loop
               v.adcDataDly(i) := adcStream(i).tData(13 downto 0);
            end loop;
            
            if r.lineWrAddr = BANK_COLS_C and r.memWrEn = '1' then
               -- move to next buffer
               v.lineWrAddr := (others=>'0');
               v.lineWrBuff := r.lineWrBuff + 1;
               -- set valid flag (all finish simultaneously)
               for i in 3 downto 0 loop
                  v.lineBufValid(i)(conv_integer(r.lineWrBuff)) := '1';
               end loop;
            elsif r.memWrEn = '1' then
               -- every 2 sample strobes move buffer write pointer
               v.lineWrAddr := r.lineWrAddr + 1;
            end if;
            
            -- increase write address every 2 sample strobes
            v.memWrEn := not r.memWrEn;
            
            -- check for buffer overflow
            for i in 3 downto 0 loop
               if r.lineBufValid(i) = BUFF_MAX_C then
                  v.lineBufErr(i) := r.lineBufErr(i) + 1;
                  v.error := '1';
               end if;
            end loop;
            
         end if;
         
      else
         v.memWrEn := '0';
         v.acqSmplEn    := (others=>'0');
         v.lineWrAddr   := (others=>'0');
         v.lineWrBuff   := (others=>'0');
         v.lineBufValid := (others=>(others=>'0'));
      end if;
      
      --------------------------------------------------
      -- FSM to assemble and stream 4 lines (16 banks per line)
      --------------------------------------------------
      
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
                  if LINE_REVERSE_G(r.sRowCount) = '0' then
                     v.lineRdAddr := r.lineRdAddr + 1;
                  else
                     v.lineRdAddr := r.lineRdAddr - 1;
                  end if;
               elsif r.bankCount < 15 then         -- next bank (out of 16)
                  v.colCount  := 0;
                  v.bankCount := r.bankCount + 1;
                  if LINE_REVERSE_G(r.sRowCount) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
               elsif v.sRowCount < 3 then          -- next super row (out of 4)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.sRowCount    := r.sRowCount + 1;
                  v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  if LINE_REVERSE_G(r.sRowCount) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
               elsif r.rowCount < BANK_ROWS_C then -- next row (go to wait for line state)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.sRowCount    := 0;
                  v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  v.rowCount     := r.rowCount + 1;
                  if LINE_REVERSE_G(r.sRowCount) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
                  v.timeCnt      := 0;
                  v.rdState      := WAIT_LINE_S;
               else                                -- image done (go to footer state)
                  v.colCount     := 0;
                  v.bankCount    := 0;
                  v.sRowCount    := 0;
                  v.lineBufValid(r.sRowCount)(conv_integer(r.rowCount(BUFF_BITS_C-1 downto 0))) := '0'; -- invalidate the buffer
                  v.rowCount     := (others=>'0');
                  if LINE_REVERSE_G(r.sRowCount) = '0' then
                     v.lineRdAddr := (others=>'0');
                  else
                     v.lineRdAddr := toSlv(BANK_COLS_C, COLS_BITS_C);
                  end if;
                  v.rdState      := FOOTER_S;
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
      
      if r.memWrEn = '1' then
         memWrEn <= r.acqSmplEn(conv_integer(r.adcPipelineDly));
      else
         memWrEn <= '0';
      end if;
      memWrAddr         <= r.lineWrBuff & r.lineWrAddr;
      memRdAddr         <= r.rowCount(BUFF_BITS_C-1 downto 0) & r.lineRdAddr;
      
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
         
         memWrData(i*j) <= 
            "00" & adcStream(i*j).tData(13 downto 0) &
            "00" & r.adcDataDly(i*j);
         
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
            dina    => memWrData(i*j),
            -- Port B
            clkb    => sysClk,
            rstb    => sysRst,
            addrb   => memRdAddr,
            doutb   => memRdData(i, j)
         );
         
      end generate G_BankBuf;
   end generate G_sRowBuf;
   
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
