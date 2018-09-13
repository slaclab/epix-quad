-------------------------------------------------------------------------------
-- File       : RdoutCore.vhd
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
use work.AxiPkg.all;
use work.SsiPkg.all;

entity RdoutCore is
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
      -- AXI DDR Buffer Interface (sysClk domain)
      axiWriteMasters      : out AxiWriteMasterArray(3 downto 0);
      axiWriteSlaves       : in  AxiWriteSlaveArray(3 downto 0);
      axiReadMaster        : out AxiReadMasterType;
      axiReadSlave         : in  AxiReadSlaveType;
      buffersRdy           : in  sl;
      -- Run control
      acqStart             : in  sl;
      acqBusy              : in  sl;
      acqCount             : in  slv(31 downto 0);
      acqSample            : in  sl;
      readDone             : out sl;
      -- ADC stream input
      adcStream            : in  AxiStreamMasterArray(63 downto 0);
      -- Frame stream output (axisClk domain)
      axisClk              : in  sl;
      axisRst              : in  sl;
      axisMaster           : out AxiStreamMasterType;
      axisSlave            : in  AxiStreamSlaveType
   );
end RdoutCore;

architecture rtl of RdoutCore is
   
   -- ASIC settings
   
   constant BANK_COLS_C          : natural := BANK_COLS_G - 1;
   constant BANK_ROWS_C          : natural := BANK_ROWS_G - 1;
   constant BANK_NUM_C           : natural := 15;
   
   -- Buffer settings
   
   constant LINE_BYTES_C   : natural := BANK_COLS_G*2;                  -- number of bytes of one row in a bank (2 bytes per pixel)
   constant LINE_ADDR_C    : natural := log2(BANK_COLS_G);              -- memory address to fit full line
   constant LINE_BUFF_C    : natural := 1;                              -- memory address to fit multiple line buffers (2**LINE_BUFF_C buffers)
   
   constant DDR_SIZE_C     : natural := LINE_BYTES_C * BANK_ROWS_G * (BANK_NUM_C+1);   -- number of bytes of 1 out of 4 image buffers
   constant DDR_ADDR_C     : natural := log2(DDR_SIZE_C);               -- memory address to fit 1 out of 4 image buffers
   constant DDR_BUFF_C     : natural := 3;                              -- memory address to fit multiple 1 out of 4 image buffers (2**DDR_BUFF_C buffers)
   
   -- AXI settings
   
   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 30,
      DATA_BYTES_C => 16,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8
   );
   
   constant AXI_BURST_C : slv(1 downto 0)    := "01";
   constant AXI_CACHE_C : slv(3 downto 0)    := "1111";
   constant AWLEN_C     : slv(7 downto 0)    := getAxiLen(AXI_CONFIG_C, LINE_BYTES_C);
   
   -- Stream settings
   
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(4);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   -- Custom data types
   
   type LineValidArray is array (natural range <>) of slv(2**LINE_BUFF_C-1 downto 0);
   type LineAddrArray  is array (natural range <>) of slv(LINE_ADDR_C-1 downto 0);
   type LineBuffArray  is array (natural range <>) of slv(LINE_BUFF_C-1 downto 0);
   type LineFullArray  is array (natural range <>) of slv(LINE_ADDR_C+LINE_BUFF_C-1 downto 0);
   type DdrAddrArray   is array (natural range <>) of slv(DDR_ADDR_C-1 downto 0);
   type DdrBuffArray   is array (natural range <>) of slv(DDR_BUFF_C-1 downto 0);
   
   type BankIntArray   is array (natural range <>) of integer range 0 to BANK_NUM_C;
   type ColIntArray    is array (natural range <>) of integer range 0 to BANK_COLS_C;
   type RowIntArray    is array (natural range <>) of integer range 0 to BANK_ROWS_C;
   
   type RdStateType is (
      IDLE_S
   );
   
   type WrStateType is (
      IDLE_S,
      ADDR_S,
      MOVE_S
   );
   
   type WrStateArray is array (natural range<>) of WrStateType;
   
   type RegType is record
      rdoutEn              : sl;
      rdoutEnReg           : sl;
      seqCount             : slv(31 downto 0);
      seqCountReset        : sl;
      adcPipelineDly       : slv(6 downto 0);
      acqSample            : slv(127 downto 0);
      readPend             : slv(3 downto 0);
      bankCount            : BankIntArray(3 downto 0);
      rowCount             : RowIntArray(3 downto 0);
      colCount             : ColIntArray(3 downto 0);
      lineBufErr           : Slv32Array(3 downto 0);
      ddrWrNum             : DdrBuffArray(3 downto 0);
      ddrWrAddr            : DdrAddrArray(3 downto 0);
      lineBufValid         : LineValidArray(3 downto 0);
      lineWrAddr           : slv(LINE_ADDR_C-1 downto 0);
      lineWrBuff           : slv(LINE_BUFF_C-1 downto 0);
      lineRdAddr           : LineAddrArray(3 downto 0);
      lineRdBuff           : LineBuffArray(3 downto 0);
      wrState              : WrStateArray(3 downto 0);
      rdState              : RdStateType;
      txMaster             : AxiStreamMasterType;
      rMaster              : AxiReadMasterType;
      wMaster              : AxiWriteMasterArray(3 downto 0);
      sAxilWriteSlave      : AxiLiteWriteSlaveType;
      sAxilReadSlave       : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdoutEn              => '0',
      rdoutEnReg           => '0',
      seqCount             => (others=>'0'),
      seqCountReset        => '0',
      adcPipelineDly       => (others=>'0'),
      acqSample            => (others=>'0'),
      readPend             => (others=>'0'),
      bankCount            => (others=>0),
      rowCount             => (others=>0),
      colCount             => (others=>0),
      lineBufErr           => (others=>(others=>'0')),
      ddrWrNum             => (others=>(others=>'0')),
      ddrWrAddr            => (others=>(others=>'0')),
      lineBufValid         => (others=>(others=>'0')),
      lineWrAddr           => (others=>'0'),
      lineWrBuff           => (others=>'0'),
      lineRdAddr           => (others=>(others=>'0')),
      lineRdBuff           => (others=>(others=>'0')),
      wrState              => (others=>IDLE_S),
      rdState              => IDLE_S,
      txMaster             => AXI_STREAM_MASTER_INIT_C,
      rMaster              => axiReadMasterInit(AXI_CONFIG_C, AXI_BURST_C, AXI_CACHE_C),
      wMaster              => (others=>axiWriteMasterInit(AXI_CONFIG_C, '1', AXI_BURST_C, AXI_CACHE_C)),
      sAxilWriteSlave      => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave       => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal acqStartEdge     : std_logic             := '0';
   signal txSlave          : AxiStreamSlaveType;
   
   signal memWrEn          : sl;
   signal memWrAddr        : slv(LINE_BUFF_C+LINE_ADDR_C-1 downto 0);
   signal memRdAddr        : LineFullArray(63 downto 0);
   signal memRdData        : Slv14Array(63 downto 0);
   
begin
   
   assert LINE_BYTES_C <= 4096 
      report "Line size over 4kB is not supported" 
      severity failure;
   
   assert LINE_BYTES_C mod AXI_CONFIG_C.DATA_BYTES_C = 0 
      report "Line size must be " & integer'image(AXI_CONFIG_C.DATA_BYTES_C) & " bytes aligned" 
      severity failure;
      
   assert (DDR_ADDR_C + DDR_BUFF_C + 2) < AXI_CONFIG_C.ADDR_WIDTH_C
      report "Buffer size " & integer'image(2**(DDR_ADDR_C + DDR_BUFF_C + 2)) & " is larger than available " & integer'image(2**AXI_CONFIG_C.ADDR_WIDTH_C) & "bytes"
      severity failure;
   
   --------------------------------------------------
   -- Data storage and readout FSMs
   --------------------------------------------------
   
   U_ReadStartEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => acqStart,
         risingEdge => acqStartEdge
      );
   
   comb : process (sysRst, axiReadSlave, axiWriteSlaves, sAxilReadMaster, sAxilWriteMaster, txSlave, r,
      buffersRdy, acqStartEdge, acqBusy, acqCount, acqSample, memRdData) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;
      
      if r.readPend = "0000" and acqStartEdge = '0' then
         v.rdoutEn := r.rdoutEnReg;
      end if;
      
      -- count readouts
      if r.seqCountReset = '1' then
         v.seqCount := (others=>'0');
      elsif acqStartEdge = '1' and r.rdoutEn = '1' and buffersRdy = '1' then
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
      axiSlaveRegisterR(regCon, x"020", 0, buffersRdy          );
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);
      
      --------------------------------------------------
      -- Line buffers (64 bank channels)
      -- one pipeline delay to allow common DPRAM write control
      --------------------------------------------------
      
      if r.rdoutEn = '1' and buffersRdy = '1' then
         
         -- shift the sample strobe
         v.acqSample := r.acqSample(126 downto 0) & acqSample;
         
         -- line write pointer
         if r.acqSample(conv_integer(r.adcPipelineDly)) = '1' then
            if r.lineWrAddr = BANK_COLS_C then
               -- move to next line buffer
               v.lineWrAddr := (others=>'0');
               v.lineWrBuff := r.lineWrBuff + 1;
               v.lineBufValid(3)(conv_integer(r.lineWrBuff)) := '1';
               v.lineBufValid(2)(conv_integer(r.lineWrBuff)) := '1';
               v.lineBufValid(1)(conv_integer(r.lineWrBuff)) := '1';
               v.lineBufValid(0)(conv_integer(r.lineWrBuff)) := '1';
            else
               -- move line write pointer
               v.lineWrAddr := r.lineWrAddr + 1;
            end if;
         end if;
         
         -- check for line buffer overflow
         -- all 4 line FSMs should finish before writing again
         for i in 3 downto 0 loop
            if r.lineBufValid(i)(conv_integer(r.lineWrBuff)) = '1' and r.acqSample(conv_integer(r.adcPipelineDly)) = '1' then
               v.lineBufErr(i) := r.lineBufErr(i) + 1;
            end if;
         end loop;
         
      else
         v.lineWrAddr   := (others=>'0');
         v.lineWrBuff   := (others=>'0');
         v.lineBufValid := (others=>(others=>'0'));
      end if;
      
      --------------------------------------------------
      -- Write FSMs (4 line channels)
      -- 16 banks per line
      --------------------------------------------------
      
      for i in 3 downto 0 loop
         
         -- Reset strobing Signals
         if (axiWriteSlaves(i).awready = '1') then
            v.wMaster(i).awvalid := '0';
         end if;
         if (axiWriteSlaves(i).wready = '1') then
            v.wMaster(i).wvalid := '0';
            v.wMaster(i).wlast  := '0';
         end if;
      
      
         case r.wrState(i) is
            
            
            -- wait for trigger
            when IDLE_S =>
               if LINE_REVERSE_G(i) = '0' then
                  v.lineRdAddr(i) := (others=>'0');
               else
                  v.lineRdAddr(i) := toSlv(BANK_COLS_C,LINE_ADDR_C);
               end if;
               v.ddrWrAddr(i)    := (others=>'0');
               v.lineRdBuff(i)   := (others=>'0');
               v.bankCount(i)    := 0;
               v.rowCount(i)     := 0;
               v.colCount(i)     := 0;
               v.readPend(i)     := '0';
               if acqStartEdge = '1' and r.rdoutEn = '1' and buffersRdy = '1' then
                  v.readPend(i)  := '1';
                  v.wrState(i)   := ADDR_S;
               end if;
         
            when ADDR_S =>
            
               -- Check if ready to make memory request
               if (v.wMaster(i).awvalid = '0') then
                  -- Wait for the whole line stored in DPRAM bufffer
                  if r.lineBufValid(i)(conv_integer(r.lineRdBuff(i))) = '1' then
                     -- Set the memory address
                     v.wMaster(i).awaddr := resize((toSlv(i,2) & r.ddrWrNum(i) & r.ddrWrAddr(i)), v.wMaster(i).awaddr'length);
                     -- Set the burst length
                     v.wMaster(i).awlen := AWLEN_C;
                     -- Set the flag
                     v.wMaster(i).awvalid := '1';
                     -- Next state
                     v.wrState(i) := MOVE_S;
                     -- save pixel data and move write address
                     v.wMaster(i).wdata(15 downto 0) := "00" & memRdData(r.bankCount(i)+i*16);
                     v.ddrWrAddr(i) := r.ddrWrAddr(i) + 2;
                     -- get next pixel
                     if LINE_REVERSE_G(i) = '0' then
                        v.lineRdAddr(i) := r.lineRdAddr(i) + 1;
                     else
                        v.lineRdAddr(i) := r.lineRdAddr(i) - 1;
                     end if;
                  end if;
               end if;
            
            when MOVE_S =>
               -- Check if ready to move data
               if (v.wMaster(i).wvalid = '0') then
                  -- Address increment by 2 bytes ("00" & 14 bit pixels)
                  v.ddrWrAddr(i) := r.ddrWrAddr(i) + 2;
                  -- get next pixel
                  if LINE_REVERSE_G(i) = '0' then
                     v.lineRdAddr(i) := r.lineRdAddr(i) + 1;
                  else
                     v.lineRdAddr(i) := r.lineRdAddr(i) - 1;
                  end if;
                  -- Register data bytes
                  -- Move the data every 8 samples (128 bit AXI bus)
                  if r.ddrWrAddr(i)(3 downto 0) = "0000" then
                     v.wMaster(i).wdata(15 downto 0) := "00" & memRdData(r.bankCount(i)+i*16);
                  elsif r.ddrWrAddr(i)(3 downto 0) = "0010" then
                     v.wMaster(i).wdata(31 downto 16) := "00" & memRdData(r.bankCount(i)+i*16);
                  elsif r.ddrWrAddr(i)(3 downto 0) = "0100" then
                     v.wMaster(i).wdata(47 downto 32) := "00" & memRdData(r.bankCount(i)+i*16);
                  elsif r.ddrWrAddr(i)(3 downto 0) = "0110" then
                     v.wMaster(i).wdata(63 downto 48) := "00" & memRdData(r.bankCount(i)+i*16);
                  elsif r.ddrWrAddr(i)(3 downto 0) = "1000" then
                     v.wMaster(i).wdata(79 downto 64) := "00" & memRdData(r.bankCount(i)+i*16);
                  elsif r.ddrWrAddr(i)(3 downto 0) = "1010" then
                     v.wMaster(i).wdata(95 downto 80) := "00" & memRdData(r.bankCount(i)+i*16);
                  elsif r.ddrWrAddr(i)(3 downto 0) = "1100" then
                     v.wMaster(i).wdata(111 downto 96) := "00" & memRdData(r.bankCount(i)+i*16);
                  else --"1110"
                     v.wMaster(i).wdata(127 downto 112) := "00" & memRdData(r.bankCount(i)+i*16); 
                     v.wMaster(i).wvalid := '1';
                  end if;
                  
                  v.wMaster(i).wstrb(15 downto 0) := x"FFFF";
                  
                  -- Check for last AXI transfer (line size burst)
                  if r.colCount(i) >= BANK_COLS_C and r.bankCount(i) >= BANK_NUM_C then
                     v.bankCount(i) := 0;
                     -- Set the last flag
                     v.wMaster(i).wlast := '1';
                     -- check if all rows done
                     if r.rowCount(i) >= BANK_ROWS_C then
                        -- image done
                        v.wrState(i)    := IDLE_S;
                        -- move to next image buffer
                        v.ddrWrNum(i)   := r.ddrWrNum(i) + 1;
                     else
                        -- next row
                        v.lineBufValid(i)(conv_integer(r.lineRdBuff(i))) := '0';
                        v.lineRdBuff(i) := r.lineRdBuff(i) + 1;
                        v.rowCount(i)   := r.rowCount(i) + 1;
                        if LINE_REVERSE_G(i) = '0' then
                           v.lineRdAddr(i) := (others=>'0');
                        else
                           v.lineRdAddr(i) := toSlv(BANK_COLS_C,LINE_ADDR_C);
                        end if;
                        v.wrState(i)    := ADDR_S;
                     end if;
                  -- check if the last column in a bank
                  elsif r.colCount(i) >= BANK_COLS_C then
                     v.bankCount(i) := r.bankCount(i) + 1;
                     v.colCount(i)  := 0;
                  -- increment column counter
                  else
                     v.colCount(i)  := r.colCount(i) + 1;
                  end if;
               end if;
               
            when others =>
               v.wrState(i) := IDLE_S;
               
         end case;
         
         for k in 15 downto 0 loop
            memRdAddr(k+i*16) <= r.lineRdBuff(i) & r.lineRdAddr(i);
         end loop;
      
      end loop;
         
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
      axiReadMaster     <= r.rMaster;
      axiWriteMasters   <= r.wMaster;
      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;
      
      memWrEn           <= r.acqSample(conv_integer(r.adcPipelineDly));
      memWrAddr         <= r.lineWrBuff & r.lineWrAddr;
      
      readDone <= not (r.readPend(3) or r.readPend(2) or r.readPend(1) or r.readPend(0));

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
   G_BankBuf : for i in 63 downto 0 generate
      U_BankBufRam: entity work.DualPortRam
      generic map (
         TPD_G          => TPD_G,
         DATA_WIDTH_G   => 14,
         ADDR_WIDTH_G   => LINE_BUFF_C+LINE_ADDR_C
      )
      port map (
         -- Port A     
         clka    => sysClk,
         wea     => memWrEn,
         rsta    => sysRst,
         addra   => memWrAddr,
         dina    => adcStream(i).tData(13 downto 0),
         -- Port B
         clkb    => sysClk,
         rstb    => sysRst,
         addrb   => memRdAddr(i),
         doutb   => memRdData(i)
      );
   end generate G_BankBuf;
   
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
