-------------------------------------------------------------------------------
-- File       : EpixQuadMonitoring.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-01-22
-- Last update: 2016-07-11
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.I2cPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

entity EpixQuadMonitoring is
   generic (
      TPD_G             : time      := 1 ns;
      I2C_SCL_FREQ_G    : real      := 100.0E+3;   -- units of Hz
      I2C_MIN_PULSE_G   : real      := 100.0E-9;   -- units of seconds
      AXI_CLK_FREQ_G    : real      := 156.25E+6;  -- units of Hz
      SIM_SPEEDUP_G     : boolean   := false
   );  
   port (
      -- Clocks and Resets
      sysClk            : in    sl;
      sysRst            : in    sl;
      -- Trigger inputs
      acqStart          : in    sl;
      -- monitor ADC bus
      envSck            : out   sl;
      envCnv            : out   sl;
      envDin            : out   sl;
      envSdo            : in    sl;
      -- humidity I2C bus (2 devices)
      humScl            : inout sl;
      humSda            : inout sl;
      -- AXI-Lite Register Interface
      axilReadMaster    : in    AxiLiteReadMasterType;
      axilReadSlave     : out   AxiLiteReadSlaveType;
      axilWriteMaster   : in    AxiLiteWriteMasterType;
      axilWriteSlave    : out   AxiLiteWriteSlaveType;
      -- Monitor data for the image stream
      monData           : out   Slv16Array(15 downto 0);
      -- Monitor Data Interface
      monitorTxMaster   : out  AxiStreamMasterType;
      monitorTxSlave    : in   AxiStreamSlaveType;
      monitorEn         : in   sl);
end entity EpixQuadMonitoring;

architecture rtl of EpixQuadMonitoring is
   
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := ite(SIM_SPEEDUP_G,  7, (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1);
   constant FILTER_C         : natural := ite(SIM_SPEEDUP_G, 11, natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1);
   
   constant I2C_HUM_CONFIG_C : I2cAxiLiteDevArray(1 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("1000100", 48, 16, '0', '1')),
      1 => (MakeI2cAxiLiteDevType("1001100", 8, 8, '0'))
   );  
   
   -- worst case scenarion measurement time is 15 ms (66.67 Hz)
   constant SHT31_MEAS_TIME_C : natural := ite(SIM_SPEEDUP_G, 100,(getTimeRatio(AXI_CLK_FREQ_G, 66.67)) - 1);
   
   -- number of registers to read from NCT218
   constant NCT218_REGS_NUM_C : natural := 3;
   -- register addresses to read from NCT218
   constant NCT218_REGS_C     : Slv8Array(NCT218_REGS_NUM_C-1 downto 0) := (
      0 => x"00", -- local temperature register
      1 => x"10", -- external temperature low byte
      2 => x"01"  -- external temperature high byte
   );
   
   -- minimum clock period at 1.8VIO is 50 ns
   constant AD7949_SPI_SCLK_C : real := 1.0E+6;
   -- maximum sampling (cycle) frequency is 250kHz
   constant AD7949_CYC_CLK_C  : real := 250.0E+3;
   constant AD7949_CYC_PER_C  : natural := getTimeRatio(AXI_CLK_FREQ_G, AD7949_CYC_CLK_C)-1;
   
   type StateType is (
      WAIT_REQ_S, 
      ADDR_S, 
      WRITE_S, 
      READ_TXN_S, 
      READ_S, 
      BUS_ACK_S, 
      REG_ACK_S
   );
   
   type HumStateType is (
      IDLE_S, 
      HSTART_S, 
      HBUS_WAIT1_S, 
      HMEAS_WAIT_S, 
      HMEAS_READ_S, 
      HBUS_WAIT2_S, 
      TSTART_S,
      TBUS_WAIT1_S,
      TBUS_READ_S,
      TBUS_WAIT2_S
   );
   
   type SpiStateType is (
      IDLE_S, 
      BUS_EN_S,
      BUS_WAIT_S,
      WAIT_TCYC_S
   );
   
   type RegType is record
      state             : StateType;
      byteCount         : slv(2 downto 0);
      i2cMasterIn       : I2cMasterInType;
      -- I2cRegMasterOutType
      regAck            : sl;
      regFail           : sl;
      regFailCode       : slv(7 downto 0);
      regRdData         : slv(47 downto 0);
      -- I2cRegMasterInType
      i2cAddr           : slv(9 downto 0);
      tenbit            : sl;
      regAddr           : slv(31 downto 0);
      regWrData         : slv(31 downto 0);
      regOp             : sl;
      regAddrSkip       : sl;
      regAddrSize       : slv(1 downto 0);
      regDataSize       : slv(2 downto 0);
      regReq            : sl;
      busReq            : sl;
      endianness        : sl;
      repeatStart       : sl;
      --
      trigger           : sl;
      monitorEnReg      : sl;
      trigPrescaler     : slv(15 downto 0);
      prescalerCnt      : slv(15 downto 0);
      humState          : HumStateType;
      shtError          : slv(15 downto 0);
      shtHumReg         : slv(15 downto 0);
      shtTempReg        : slv(15 downto 0);
      waitCnt           : slv(31 downto 0);
      nctRegCnt         : integer range 0 to NCT218_REGS_NUM_C-1;
      nctError          : slv(15 downto 0);
      nctRegs           : Slv8Array(NCT218_REGS_NUM_C-1 downto 0);
      spiRdEn           : sl;
      spiWrEn           : sl;
      spiWrData         : slv(13 downto 0);
      spiWrdCnt         : slv(3 downto 0);
      spiCycCnt         : integer range 0 to AD7949_CYC_PER_C;
      spiState          : SpiStateType;
      adDataReg         : Slv16Array(7 downto 0);
      emptyDataReg      : Slv32Array(31 downto 0);
      emptyCount        : Slv32Array(1 downto 0);
      --
      txMaster          : AxiStreamMasterType;
      sAxilWriteSlave   : AxiLiteWriteSlaveType;
      sAxilReadSlave    : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state             => WAIT_REQ_S,
      byteCount         => (others => '0'),
      i2cMasterIn       => (
         enable         => '0',
         prescale       => (others => '0'),
         filter         => (others => '0'),
         txnReq         => '0',
         stop           => '0',
         op             => '0',
         busReq         => '0',
         addr           => (others => '0'),
         tenbit         => '0',
         wrValid        => '0',
         wrData         => (others => '0'),
         rdAck          => '0'),
      -- I2cRegMasterOutType
      regAck            => '0',
      regFail           => '0',
      regFailCode       => (others => '0'),
      regRdData         => (others => '0'),
      -- I2cRegMasterInType
      i2cAddr           => (others => '0'),
      tenbit            => '0',
      regAddr           => (others => '0'),
      regWrData         => (others => '0'),
      regOp             => '0',               -- 1 for write, 0 for read
      regAddrSkip       => '0',
      regAddrSize       => (others => '0'),
      regDataSize       => (others => '0'),
      regReq            => '0',
      busReq            => '0',
      endianness        => '0',
      repeatStart       => '0',
      --
      trigger           => '0',
      monitorEnReg      => '1',
      trigPrescaler     => (others=>'0'),
      prescalerCnt      => (others=>'0'),
      humState          => IDLE_S,
      shtError          => (others=>'0'),
      shtHumReg         => (others=>'0'),
      shtTempReg        => (others=>'0'),
      waitCnt           => (others=>'0'),
      nctRegCnt         => 0,
      nctError          => (others=>'0'),
      nctRegs           => (others=>(others=>'0')),
      spiRdEn           => '0',
      spiWrEn           => '0',
      spiWrData         => (others=>'0'),
      spiWrdCnt         => (others=>'0'),
      spiCycCnt         => 0,
      spiState          => IDLE_S,
      adDataReg         => (others=>(others=>'0')),
      emptyDataReg      => (others=>(others=>'0')),
      emptyCount        => (others=>(others=>'0')),
      --
      txMaster          => AXI_STREAM_MASTER_INIT_C,
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   signal i2cMasterIn   : I2cMasterInType;
   signal i2cMasterOut  : I2cMasterOutType;
   
   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;
   
   signal spiRdEn       : sl;
   signal spiRdData     : slv(13 downto 0);

   function getIndex (
      endianness : sl;
      byteCount  : slv;
      totalBytes : slv)
      return integer is
   begin
      if (endianness = '0') then
         -- little endian
         return conv_integer(byteCount)*8;
      else
         -- big endian
         return (conv_integer(totalBytes)-conv_integer(byteCount))*8;
      end if;
   end function getIndex;

begin
   
   --------------------------------------------------
   -- Basic I2c Master
   --------------------------------------------------
   
   i2cMaster_1 : entity work.I2cMaster
      generic map (
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => FILTER_C,
         DYNAMIC_FILTER_G     => 0)
      port map (
         clk          => sysClk,
         srst         => sysRst,
         arst         => '0',
         i2cMasterIn  => i2cMasterIn,
         i2cMasterOut => i2cMasterOut,
         i2ci         => i2ci,
         i2co         => i2co);
   
   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => humScl,                  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output  

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => humSda,                  -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output  
   
   --------------------------------------------------
   -- Basic SPI Master
   --------------------------------------------------
   
   U_SpiMaster : entity work.SpiMaster
   generic map (
      TPD_G             => TPD_G,
      NUM_CHIPS_G       => 1,
      DATA_SIZE_G       => 14,
      CPHA_G            => '0',
      CPOL_G            => '0',
      CLK_PERIOD_G      => (1.0/AXI_CLK_FREQ_G),
      SPI_SCLK_PERIOD_G => (1.0/AD7949_SPI_SCLK_C)
   )
   port map (
      --Global Signals
      clk         => sysClk,
      sRst        => sysRst,
      -- Parallel interface
      chipSel     => "0",
      wrEn        => r.spiWrEn,
      wrData      => r.spiWrData,
      rdEn        => spiRdEn,
      rdData      => spiRdData,
      --SPI interface
      spiCsL(0)   => envCnv,
      spiSclk     => envSck,
      spiSdi      => envDin,
      spiSdo      => envSdo
   );
   
   --------------------------------------------------
   -- Combinational logic
   --------------------------------------------------

   comb : process (sysRst, r, axilReadMaster, axilWriteMaster,
      i2cMasterOut, acqStart, monitorEn, monitorTxSlave, spiRdData, spiRdEn) is
      variable v            : RegType;
      variable addrIndexVar : integer;
      variable dataIndexVar : integer;
      variable regCon       : AxiLiteEndPointType;
   begin
      v := r;
      
      -- reset strobes
      v.trigger   := '0';
      
      -- prescale the trigger as set
      if acqStart = '1' and r.monitorEnReg = '1' then
         if r.prescalerCnt < r.trigPrescaler then
            v.prescalerCnt := r.prescalerCnt + 1;
         else
            v.prescalerCnt := (others=>'0');
            v.trigger      := '1';
         end if;
      end if;
      
      
      ------------------------------------------------------------------------------------------------
      -- Register access
      ------------------------------------------------------------------------------------------------
      
      -- Determine the AXI-Lite transaction
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.monitorEnReg);
      axiSlaveRegisterR(regCon, x"004", 0, monitorEn);
      axiSlaveRegister (regCon, x"008", 0, v.trigPrescaler);
      axiSlaveRegisterR(regCon, x"00C", 0, r.shtError);
      axiSlaveRegisterR(regCon, x"010", 0, r.shtHumReg);
      axiSlaveRegisterR(regCon, x"014", 0, r.shtTempReg);
      axiSlaveRegisterR(regCon, x"018", 0, r.nctError);
      for i in NCT218_REGS_NUM_C - 1 downto 0 loop
         axiSlaveRegisterR(regCon, x"01C"+toSlv(i*4,12), 0, r.nctRegs(i));
      end loop;
      for i in 7 downto 0 loop
         axiSlaveRegisterR(regCon, x"100"+toSlv(i*4,12), 0, r.adDataReg(i));
      end loop;
      for i in 31 downto 0 loop
         axiSlaveRegister (regCon, x"200"+toSlv(i*4,12), 0, v.emptyDataReg(i));
      end loop;
      for i in 1 downto 0 loop
         axiSlaveRegister (regCon, x"300"+toSlv(i*4,12), 0, v.emptyCount(i));
         if r.emptyCount(i) > 0 then
            v.emptyCount(i) := r.emptyCount(i) - 1;
         end if;
      end loop;
      

      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);
      
      
      ------------------------------------------------------------------------------------------------
      -- I2C bus readout state machine
      -- modified I2cRegMaster from surf that allows transactions over 4 bytes
      ------------------------------------------------------------------------------------------------
      
      addrIndexVar := getIndex(r.endianness, r.byteCount, r.regAddrSize);
      dataIndexVar := getIndex(r.endianness, r.byteCount, r.regDataSize);

      v.regAck  := '0';
      v.regFail := '0';

      v.i2cMasterIn.rdAck := '0';

      case r.state is
         when WAIT_REQ_S =>
            v.byteCount := (others => '0');
            if (r.regReq = '1') then
               v.i2cMasterIn.txnReq := '1';
               v.i2cMasterIn.op     := '1';
               -- Use a repeated start for reads when directed to do so
               -- This is done by setting stop to 0 for the regAddr write txn
               -- Then the following read txn will be issued with repeated start
               v.i2cMasterIn.stop   := ite(r.regOp = '0' and r.repeatStart = '1', '0', '1');
               v.i2cMasterIn.busReq := r.busReq;
               v.state              := ADDR_S;
               if r.busReq = '1' then
                  v.state := BUS_ACK_S;
               elsif (r.regAddrSkip = '1') then
                  if (r.regOp = '1') then
                     v.state := WRITE_S;
                  else
                     v.i2cMasterIn.op := '0';
                     v.state := READ_S;
                  end if;                  
               end if;
            end if;
            
         when ADDR_S =>
            -- When a new register access request is seen,
            -- Write the register address out on the bus first
            -- One byte at a time, order determined by endianness input
            v.i2cMasterIn.wrData  := r.regAddr(addrIndexVar+7 downto addrIndexVar);
            v.i2cMasterIn.wrValid := '1';
            -- Must drop txnReq as last byte is sent if reading
            v.i2cMasterIn.txnReq  := not toSl(r.byteCount = r.regAddrSize and r.regOp = '0');

            if (i2cMasterOut.wrAck = '1') then
               v.byteCount           := r.byteCount + 1;
               v.i2cMasterIn.wrValid := '0';
               if (r.byteCount = r.regAddrSize) then
                  -- Done sending addr
                  v.byteCount := (others => '0');
                  if (r.regOp = '1') then
                     v.state := WRITE_S;
                  else
                     v.state := READ_TXN_S;
                  end if;
               end if;
            end if;

         when WRITE_S =>
            -- Txn started in WAIT_REQ_S still active
            -- Put wrData on the bus one byte at a time
            v.i2cMasterIn.wrData  := r.regWrData(dataIndexVar+7 downto dataIndexVar);
            v.i2cMasterIn.wrValid := '1';
            v.i2cMasterIn.txnReq  := not toSl(r.byteCount = r.regDataSize);
            v.i2cMasterIn.stop    := '1';  -- Send stop when done writing all bytes
            if (i2cMasterOut.wrAck = '1') then
               v.byteCount           := r.byteCount + 1;
               v.i2cMasterIn.wrValid := '0';
               if (r.byteCount = r.regDataSize) then  -- could use rxnReq = 0
                  v.state := REG_ACK_S;
               end if;
            end if;
            

         when READ_TXN_S =>
            -- Start new txn to read data bytes
            v.i2cMasterIn.txnReq := '1';
            v.i2cMasterIn.op     := '0';
            v.i2cMasterIn.stop   := '1';  -- i2c stop after all bytes are read
            v.state              := READ_S;

         when READ_S =>
            -- Drop txnReq on last byte
            v.i2cMasterIn.txnReq := not toSl(r.byteCount = r.regDataSize);
            -- Read data bytes as they arrive
            if (i2cMasterOut.rdValid = '1' and r.i2cMasterIn.rdAck = '0') then
               v.byteCount                                     := r.byteCount + 1;
               v.regRdData(dataIndexVar+7 downto dataIndexVar) := i2cMasterOut.rdData;
               v.i2cMasterIn.rdAck                             := '1';
               if (r.byteCount = r.regDataSize) then
                  -- Done
                  v.state := REG_ACK_S;
               end if;
            end if;

         when BUS_ACK_S => 
            if i2cMasterOut.busAck = '1' then
               v.i2cMasterIn.txnReq := '0';
               v.state              := REG_ACK_S;
            end if;
            
         when REG_ACK_S =>
            -- Req done. Ack the req.
            -- Might have failed so hold regFail (would be set to 0 otherwise).
            v.regAck  := '1';
            v.regFail := r.regFail;
            if (r.regReq = '0') then
--          v.regAck := '0'; Might want this back. 
               v.state := WAIT_REQ_S;
            end if;

      end case;

      -- Always check for errors an cancel the txn if they happen
      if (i2cMasterOut.txnError = '1' and i2cMasterOut.rdValid = '1') then
         v.regFail     := '1';
         v.regFailCode := i2cMasterOut.rdData;
         v.i2cMasterIn.txnReq := '0';
         v.i2cMasterIn.rdAck  := '1';
         v.state              := REG_ACK_S;
      end if;
      
      ------------------------------------------------------------------------------------------------
      -- State machine to conduct measurements and make readout of the devices on the humidity I2C bus
      ------------------------------------------------------------------------------------------------
      
      case r.humState is
         
         when IDLE_S =>
            v.nctRegCnt := 0;
            if r.trigger = '1' then
               v.humState := HSTART_S;
            end if;
         
         -- conduct measurement and readout of SHT31-DIS-B
         -- send single shot command
         when HSTART_S =>
            -- start humidity and temperature measurement
            v.i2cAddr      := I2C_HUM_CONFIG_C(0).i2cAddress;
            v.tenbit       := I2C_HUM_CONFIG_C(0).i2cTenbit;
            v.endianness   := I2C_HUM_CONFIG_C(0).endianness;
            -- no address (just command in data)
            v.regAddr      := (others=>'0');
            v.regAddrSize  := toSlv(wordCount(1, 8) - 1, 2);
            v.regAddrSkip  := '1';
            -- single shot command 
            -- clock stretching disabled 0x24
            -- Medium repeatability 0x0B
            v.regDataSize  := toSlv(wordCount(16, 8) - 1, 3);
            v.regWrData(15 downto 0) := x"0B24";
            v.repeatStart  := '0';
            v.regOp        := '1';  -- Write
            v.regReq       := '1';
            -- wait unitl complete
            if r.regAck = '0' then
               v.humState     := HBUS_WAIT1_S;
            end if;
         
         -- wait for I2C transaction complete
         when HBUS_WAIT1_S =>
            if (r.regAck = '1' and r.regReq = '1') then
               v.regReq    := '0';
               if r.regFail = '0' then
                  v.humState  := HMEAS_WAIT_S;
               else
                  -- SHT31 command failed 
                  -- goto next device on the bus
                  v.humState  := TSTART_S;
                  if r.shtError < x"FFFF" then
                     v.shtError  := r.shtError + 1;
                  end if;
               end if;
            end if;
         
         -- wait for the internal measurement complete
         when HMEAS_WAIT_S =>
            if r.waitCnt < SHT31_MEAS_TIME_C then
               v.waitCnt   := r.waitCnt + 1;
            else
               v.waitCnt   := (others=>'0');
               v.humState  := HMEAS_READ_S;
            end if;
         
         -- read humidity and temperature sensor
         when HMEAS_READ_S =>
            -- start humidity and temperature measurement
            v.i2cAddr      := I2C_HUM_CONFIG_C(0).i2cAddress;
            v.tenbit       := I2C_HUM_CONFIG_C(0).i2cTenbit;
            v.endianness   := I2C_HUM_CONFIG_C(0).endianness;
            -- skip register address
            v.regAddr      := (others=>'0');
            v.regAddrSize  := toSlv(wordCount(1, 8) - 1, 2);
            v.regAddrSkip  := '1';
            -- request 6 bytes
            v.regDataSize  := toSlv(wordCount(48, 8) - 1, 3);
            v.regWrData    := (others=>'0');
            v.repeatStart  := '0';
            v.regOp        := '0';  -- Read
            v.regReq       := '1';
            -- wait unitl complete
            if r.regAck = '0' then
               v.humState     := HBUS_WAIT2_S;
            end if;
         
         -- wait for I2C transaction complete
         when HBUS_WAIT2_S =>
            if (r.regAck = '1' and r.regReq = '1') then
               v.regReq    := '0';
               if r.regFail = '0' then
                  -- save measurements
                  -- skip CRC
                  v.shtTempReg   := r.regRdData(7 downto 0)   & r.regRdData(15 downto 8);
                  v.shtHumReg    := r.regRdData(31 downto 24) & r.regRdData(39 downto 32);
               else
                  -- SHT31 command failed 
                  if r.shtError < x"FFFF" then
                     v.shtError  := r.shtError + 1;
                  end if;
               end if;
               -- go to next device on the bus
               v.humState  := TSTART_S;
            end if;
         
         -- read out NCT218 FPGA junction temperature sensor
         when TSTART_S =>
            -- send NTC218 pionter value
            v.i2cAddr      := I2C_HUM_CONFIG_C(1).i2cAddress;
            v.tenbit       := I2C_HUM_CONFIG_C(1).i2cTenbit;
            v.endianness   := I2C_HUM_CONFIG_C(1).endianness;
            -- no address (just pointer value in data)
            v.regAddr      := (others=>'0');
            v.regAddrSize  := toSlv(wordCount(1, 8) - 1, 2);
            v.regAddrSkip  := '1';
            -- single shot command 
            -- clock stretching disabled 0x24
            -- Medium repeatability 0x0B
            v.regDataSize  := toSlv(wordCount(8, 8) - 1, 3);
            v.regWrData(7 downto 0) := NCT218_REGS_C(r.nctRegCnt);
            v.repeatStart  := '0';
            v.regOp        := '1';  -- Write
            v.regReq       := '1';
            -- wait unitl complete
            if r.regAck = '0' then
               v.humState     := TBUS_WAIT1_S;
            end if;
         
         when TBUS_WAIT1_S =>
            if (r.regAck = '1' and r.regReq = '1') then
               v.regReq    := '0';
               if r.regFail = '0' then
                  v.humState  := TBUS_READ_S;
               else
                  -- NCT command failed 
                  -- goto IDLE_S
                  v.humState  := IDLE_S;
                  if r.nctError < x"FFFF" then
                     v.nctError  := r.nctError + 1;
                  end if;
               end if;
            end if;
            
         when TBUS_READ_S =>
            -- start humidity and temperature measurement
            v.i2cAddr      := I2C_HUM_CONFIG_C(1).i2cAddress;
            v.tenbit       := I2C_HUM_CONFIG_C(1).i2cTenbit;
            v.endianness   := I2C_HUM_CONFIG_C(1).endianness;
            -- skip register address
            v.regAddr      := (others=>'0');
            v.regAddrSize  := toSlv(wordCount(1, 8) - 1, 2);
            v.regAddrSkip  := '1';
            -- request 6 bytes
            v.regDataSize  := toSlv(wordCount(8, 8) - 1, 3);
            v.regWrData    := (others=>'0');
            v.repeatStart  := '0';
            v.regOp        := '0';  -- Read
            v.regReq       := '1';
            -- wait unitl complete
            if r.regAck = '0' then
               v.humState     := TBUS_WAIT2_S;
            end if;
            
         when TBUS_WAIT2_S =>
            if (r.regAck = '1' and r.regReq = '1') then
               v.regReq    := '0';
               if r.regFail = '0' then
                  -- save current register
                  v.nctRegs(r.nctRegCnt) := r.regRdData(7 downto 0);
                  if r.nctRegCnt < NCT218_REGS_NUM_C-1 then
                     -- read next register
                     v.nctRegCnt := r.nctRegCnt + 1;
                     v.humState  := TSTART_S;
                  else
                     -- all registers done
                     v.nctRegCnt := 0;
                     v.humState  := IDLE_S;
                  end if;
               else
                  -- NCT command failed 
                  if r.nctError < x"FFFF" then
                     v.nctError  := r.nctError + 1;
                  end if;
                  -- go to IDLE
                  v.humState  := IDLE_S;
               end if;
            end if;
            
      end case;
      
      ------------------------------------------------------------------------------------------------
      -- AD7949 readout state machine
      ------------------------------------------------------------------------------------------------
      
      v.spiWrEn := '0';
      v.spiRdEn := spiRdEn;
      
      case r.spiState is
         
         -- wait for trigger
         when IDLE_S =>
            if r.trigger = '1' then
               v.spiState := BUS_EN_S;
            end if;
         
         -- write config and read the measurement
         when BUS_EN_S =>
            v.spiWrData := "1111" & r.spiWrdCnt(2 downto 0) & "0000001"; 
            v.spiWrEn   := '1';
            v.spiState := BUS_WAIT_S;
         
         when BUS_WAIT_S =>
            if spiRdEn = '1' and r.spiRdEn = '0' then
               -- skip first 2 samples (ADC pipeline)
               if r.spiWrdCnt >= 2 then
                  v.adDataReg(conv_integer(r.spiWrdCnt)-2) := "00" & spiRdData;
               end if;
               v.spiState := WAIT_TCYC_S;
            end if;
         
         -- wait Tcyc for next measurement
         when WAIT_TCYC_S =>
            if r.spiCycCnt >= AD7949_CYC_PER_C then
               v.spiCycCnt := 0;
               if r.spiWrdCnt >= 9 then
                  v.spiWrdCnt := (others=>'0');
                  v.spiState  := IDLE_S;
               else
                  v.spiWrdCnt := r.spiWrdCnt + 1;
                  v.spiState  := BUS_EN_S;
               end if;
            else
               v.spiCycCnt := r.spiCycCnt + 1;
            end if;
            
      end case;
      
      ------------------------------------------------------------------------------------------------
      -- Synchronous Reset
      ------------------------------------------------------------------------------------------------
      
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;
      
      ------------------------------------------------------------------------------------------------
      -- Signal assignment
      ------------------------------------------------------------------------------------------------
      
      rin <= v;

      axilWriteSlave          <= r.sAxilWriteSlave;
      axilReadSlave           <= r.sAxilReadSlave;
      
      -- Internal signals
      i2cMasterIn.enable      <= '1';
      i2cMasterIn.prescale    <= toSlv(PRESCALE_C, 16);
      i2cMasterIn.filter      <= (others => '0');  -- Not using dynamic filtering
      i2cMasterIn.addr        <= r.i2cAddr;
      i2cMasterIn.tenbit      <= r.tenbit;
      i2cMasterIn.txnReq      <= r.i2cMasterIn.txnReq;
      i2cMasterIn.stop        <= r.i2cMasterIn.stop;
      i2cMasterIn.op          <= r.i2cMasterIn.op;
      i2cMasterIn.wrValid     <= r.i2cMasterIn.wrValid;
      i2cMasterIn.wrData      <= r.i2cMasterIn.wrData;
      i2cMasterIn.rdAck       <= r.i2cMasterIn.rdAck;
      i2cMasterIn.busReq      <= r.i2cMasterIn.busReq;
      
      monitorTxMaster         <= r.txMaster;
      
      monData( 0)             <= r.shtHumReg;
      monData( 1)             <= r.shtTempReg;
      monData( 2)             <= x"00" & r.nctRegs(0);
      monData( 3)             <= r.nctRegs(2) & r.nctRegs(1);
      monData(11 downto  4)   <= r.adDataReg;
      monData(15 downto 12)   <= (others=>(others=>'0'));

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
