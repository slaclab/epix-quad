-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RegControlGen2.vhd
-- Author     : Kurtis Nishimura  <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-02-09
-- Last update: 2014-02-09
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Change log:
-- [MK] 01/14/2016 - Removed iSaciClk slow clock. SaciMaster replaced by SaciMasterSync.
-- [MK] 01/14/2016 - Fixed prepare for readout command. It was sent only to ASIC 0.
-- [MK] 01/28/2016 - Fixed SACI state machine
-- [MK] 01/28/2016 - Fixed carrier ID readout
-- [MK] 02/23/2016 - Increased SACI clock frequency to 10MHz. Improved SACI FSM to better handle 
--                   simultaneous prepare for readout commands and SACI register accesses.
-------------------------------------------------------------------------------
-- Description: Adaptation of Gen1 ePix register controller to Gen2 dig. card.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SaciMasterPkg.all;

use work.EpixPkgGen2.all;
use work.ScopeTypes.all;
use work.Version.all;

library unisim;
use unisim.vcomponents.all;

entity RegControlGen2 is
   generic (
      TPD_G                : time                  := 1 ns;
      NUM_ASICS_G          : natural range 1 to 8  := 4;
      CLK_PERIOD_G         : real := 10.0e-9
   );
   port (
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : out sl;
      sysRst         : in  sl;   
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Monitoring enable command incoming stream
      monEnAxisMaster : in AxiStreamMasterType;
      -- Register Inputs/Outputs (axiClk domain)
      epixStatus     : in  EpixStatusType;
      epixConfig     : out EpixConfigType;
      scopeConfig    : out ScopeConfigType;
      -- SACI prep-for-readout command request
      saciReadoutReq : in  sl;
      saciReadoutAck : out sl;
      -- SACI interfaces to ASIC(s)
      saciClk        : out sl;
      saciSelL       : out slv(NUM_ASICS_G-1 downto 0);
      saciCmd        : out sl;
      saciRsp        : in  slv(NUM_ASICS_G-1 downto 0);
      -- Guard ring DAC interfaces
      dacSclk        : out sl;
      dacDin         : out sl;
      dacCsb         : out sl;
      dacClrb        : out sl;
      -- 1-wire board ID interfaces
      serialIdIo     : inout slv(1 downto 0)
   );
end RegControlGen2;

architecture rtl of RegControlGen2 is

   type SaciState is (SACI_IDLE_S, SACI_REG_S, SACI_PAUSE_S, SACI_CMD_S, 
                      SACI_PIXEL_ROW_S, SACI_PIXEL_ROW_PAUSE_S, 
                      SACI_PIXEL_COL_S, SACI_PIXEL_COL_PAUSE_S,
                      SACI_PIXEL_DATA_S, SACI_PIXEL_NEXT_S, SACI_PIXEL_DONE_S);

   type MultiPixelWriteType is record
      asic       : slv(1 downto 0);
      row        : slv(9 downto 0);
      col        : slv(9 downto 0);
      data       : Slv16Array(3 downto 0);
      bankFlag   : slv(3 downto 0);
      calRowFlag : sl;
      calBotFlag : sl;
      req        : sl;
   end record;
   constant MULTI_PIXEL_WRITE_INIT_C : MultiPixelWriteType := (
      asic       => (others => '0'),
      row        => (others => '0'),
      col        => (others => '0'),
      data       => (others => (others => '0')),
      bankFlag   => (others => '0'),
      calRowFlag => '0',
      calBotFlag => '0',
      req        => '0'
   );
   
   type RegType is record
      usrRst         : sl;
      saciTimeout    : sl;
      saciReadoutAck : sl;
      saciChipCnt    : slv(1 downto 0);
      saciTimeoutCnt : slv(15 downto 0);
      saciAxiRsp     : slv(1 downto 0);
      globalMultiPix : MultiPixelWriteType;
      localMultiPix  : MultiPixelWriteType;
      saciRegIn      : SaciMasterInType;
      saciSelIn      : SaciMasterInType;
      saciState      : SaciState;
      epixRegOut     : EpixConfigType;
      scopeRegOut    : ScopeConfigType;
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      reqStartupD1   : sl;
      dummyRegs      : Slv32Array(4 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      usrRst         => '0',
      saciTimeout    => '0',
      saciReadoutAck => '0',
      saciChipCnt    => (others => '0'),
      saciTimeoutCnt => (others => '0'),
      saciAxiRsp     => AXI_RESP_OK_C,
      globalMultiPix => MULTI_PIXEL_WRITE_INIT_C,
      localMultiPix  => MULTI_PIXEL_WRITE_INIT_C,
      saciRegIn      => SACI_MASTER_IN_INIT_C,
      saciSelIn      => SACI_MASTER_IN_INIT_C,
      saciState      => SACI_IDLE_S,
      epixRegOut     => EPIX_CONFIG_INIT_C,
      scopeRegOut    => SCOPE_CONFIG_INIT_C,
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      reqStartupD1   => '0',
      dummyRegs      => (others=>(others=>'0'))
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiReset : sl;
   
   signal idValues : Slv64Array(2 downto 0);
   signal idValids : slv(2 downto 0);
   
   signal iSaciSelL       : slv(NUM_ASICS_G-1 downto 0);
   signal iSaciRsp        : sl;
   signal saciRst         : sl;
   
   signal iSaciSelOut : SaciMasterOutType;
   
   signal adcCardStartUp     : sl;
   signal adcCardStartUpEdge : sl;
   
   signal chipIdRst          : sl;
   
begin

   axiReset <= sysRst or r.usrRst;
   axiRst   <= axiReset;

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiReset, axiWriteMaster, r, saciReadoutReq, iSaciSelOut,
                   ePixStatus, idValids, idValues, monEnAxisMaster) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;

      -- Wrapper procedures to make calls cleaner.
      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
      begin
         axiSlaveRegister(axiReadMaster, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
      begin
         axiSlaveRegister(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
      begin
         axiSlaveRegister(axiReadMaster, v.axiReadSlave, axiStatus, addr, offset, reg);
      end procedure;

      procedure axiSlaveDefault (
         axiResp : in slv(1 downto 0)) is
      begin
         axiSlaveDefault(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus, axiResp);
      end procedure;
      
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.epixRegOut.acqCountReset := '0';
      v.epixRegOut.seqCountReset := '0';
      v.scopeRegOut.arm          := '0';
      v.scopeRegOut.trig         := '0';
      v.saciReadoutAck           := '0';
      
      -- dedicated axi stream channel to set or clear monitorEnable register
      if monEnAxisMaster.tValid = '1' and monEnAxisMaster.tLast = '1' then
         v.epixRegOut.monitorEnable := monEnAxisMaster.tData(0);
      end if;
      
      
      -- sum all time delays leading to the ACQ pulse and expose in a read only register
      v.epixRegOut.asicPreAcqTime := r.epixRegOut.acqToAsicR0Delay + r.epixRegOut.asicR0Width + r.epixRegOut.asicR0ToAsicAcq;
      
      -- reset Ack and Fail when calibration requested (Req rising edge)
      v.reqStartupD1 := r.epixRegOut.requestStartupCal;
      if r.epixRegOut.requestStartupCal = '1' and r.reqStartupD1 = '0' then
         v.epixRegOut.startupAck := '0';
         v.epixRegOut.startupFail := '0';
      end if;
      
      -- add a feature to disable the pseudoscope when the DAC trigger is disabled
      v.scopeRegOut.triggerEnable:= r.epixRegOut.daqTriggerEnable;
      
      -- Reset data
      v.axiReadSlave.rdata       := (others => '0');
      
      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Map out standard registers
      axiSlaveRegisterR(x"000000" & "00",  0, FPGA_VERSION_C); -- Need a reset strobe
      axiSlaveRegisterW(x"000001" & "00",  0, v.epixRegOut.runTriggerEnable);
      axiSlaveRegisterW(x"000002" & "00",  0, v.epixRegOut.runTriggerDelay);
      axiSlaveRegisterW(x"000003" & "00",  0, v.epixRegOut.daqTriggerEnable);
      axiSlaveRegisterW(x"000004" & "00",  0, v.epixRegOut.daqTriggerDelay);
      axiSlaveRegisterR(x"000005" & "00",  0, epixStatus.acqCount);
      axiSlaveRegisterW(x"000006" & "00",  0, v.epixRegOut.acqCountReset);
      axiSlaveRegisterW(x"000007" & "00",  0, v.epixRegOut.vguardDacSetting);
      axiSlaveRegisterW(x"000008" & "00",  0, v.epixRegOut.powerEnable);
      axiSlaveRegisterR(x"00000A" & "00",  0, epixStatus.iDelayCtrlRdy);
      axiSlaveRegisterR(x"00000B" & "00",  0, epixStatus.seqCount);
      axiSlaveRegisterW(x"00000C" & "00",  0, v.epixRegOut.seqCountReset);
      axiSlaveRegisterW(x"00000D" & "00",  0, v.epixRegOut.asicMask);
      axiSlaveRegisterR(x"000010" & "00",  0, FPGA_BASE_CLOCK_C);
      axiSlaveRegisterW(x"000011" & "00",  0, v.epixRegOut.autoRunEn);
      axiSlaveRegisterW(x"000012" & "00",  0, v.epixRegOut.autoTrigPeriod);
      axiSlaveRegisterW(x"000013" & "00",  0, v.epixRegOut.autoDaqEn);
      axiSlaveRegisterW(x"00001F" & "00",  0, v.epixRegOut.doutPipelineDelay);
      axiSlaveRegisterW(x"000020" & "00",  0, v.epixRegOut.acqToAsicR0Delay);
      axiSlaveRegisterW(x"000021" & "00",  0, v.epixRegOut.asicR0ToAsicAcq);
      axiSlaveRegisterW(x"000022" & "00",  0, v.epixRegOut.asicAcqWidth);
      axiSlaveRegisterW(x"000023" & "00",  0, v.epixRegOut.asicAcqLToPPmatL);
      axiSlaveRegisterW(x"000024" & "00",  0, v.epixRegOut.asicRoClkHalfT);
      axiSlaveRegisterW(x"000025" & "00",  0, v.epixRegOut.adcReadsPerPixel);
      axiSlaveRegisterW(x"000026" & "00",  0, v.epixRegOut.adcClkHalfT);
      axiSlaveRegisterW(x"000027" & "00",  0, v.epixRegOut.totalPixelsToRead);
      axiSlaveRegisterW(x"000029" & "00",  0, v.epixRegOut.asicPins);
      axiSlaveRegisterW(x"00002A" & "00",  0, v.epixRegOut.manualPinControl);
      axiSlaveRegisterW(x"00002A" & "00",  6, v.dummyRegs(0)(0));
      axiSlaveRegisterW(x"00002A" & "00",  7, v.epixRegOut.adcStreamMode);
      axiSlaveRegisterW(x"00002A" & "00",  8, v.epixRegOut.testPattern);
      axiSlaveRegisterW(x"00002A" & "00", 11, v.epixRegOut.asicR0Mode);
      axiSlaveRegisterW(x"00002B" & "00",  0, v.epixRegOut.asicR0Width);
      axiSlaveRegisterW(x"00002C" & "00",  0, v.dummyRegs(1));
      axiSlaveRegisterW(x"00002D" & "00",  0, v.dummyRegs(2));
      axiSlaveRegisterW(x"00002E" & "00",  0, v.dummyRegs(3));
      axiSlaveRegisterW(x"00002F" & "00",  0, v.dummyRegs(4));
      axiSlaveRegisterR(x"000030" & "00",  0, ite(idValids(0) = '1',idValues(0)(31 downto  0), x"00000000")); --Digital card ID low
      axiSlaveRegisterR(x"000031" & "00",  0, ite(idValids(0) = '1',idValues(0)(63 downto 32), x"00000000")); --Digital card ID high
      axiSlaveRegisterR(x"000032" & "00",  0, ite(idValids(1) = '1',idValues(1)(31 downto  0), x"00000000")); --Analog card ID low
      axiSlaveRegisterR(x"000033" & "00",  0, ite(idValids(1) = '1',idValues(1)(63 downto 32), x"00000000")); --Analog card ID high
      
      axiSlaveRegisterR(x"000039" & "00",  0, r.epixRegOut.asicPreAcqTime);
      axiSlaveRegisterW(x"00003A" & "00",  0, v.epixRegOut.asicPPmatToReadout);
      axiSlaveRegisterR(x"00003B" & "00",  0, ite(idValids(2) = '1',idValues(2)(31 downto  0), x"00000000")); --Carrier card ID low
      axiSlaveRegisterR(x"00003C" & "00",  0, ite(idValids(2) = '1',idValues(2)(63 downto 32), x"00000000")); --Carrier card ID high
      axiSlaveRegisterW(x"00003D" & "00",  0, v.epixRegOut.pgpTrigEn);
      axiSlaveRegisterW(x"00003E" & "00",  0, v.epixRegOut.monitorEnable);
      axiSlaveRegisterW(x"000040" & "00",  0, v.epixRegOut.tpsDelay);
      axiSlaveRegisterW(x"000040" & "00", 16, v.epixRegOut.tpsEdge);
      axiSlaveRegisterW(x"000050" & "00",  0, v.scopeRegOut.arm);
      axiSlaveRegisterW(x"000051" & "00",  0, v.scopeRegOut.trig);
      axiSlaveRegisterW(x"000052" & "00",  0, v.scopeRegOut.scopeEnable);
      axiSlaveRegisterW(x"000052" & "00",  1, v.scopeRegOut.triggerEdge);
      axiSlaveRegisterW(x"000052" & "00",  2, v.scopeRegOut.triggerChannel);
      axiSlaveRegisterW(x"000052" & "00",  6, v.scopeRegOut.triggerMode);
      axiSlaveRegisterW(x"000052" & "00", 16, v.scopeRegOut.triggerAdcThresh);
      axiSlaveRegisterW(x"000053" & "00",  0, v.scopeRegOut.triggerHoldoff);
      axiSlaveRegisterW(x"000053" & "00", 13, v.scopeRegOut.triggerOffset);
      axiSlaveRegisterW(x"000054" & "00",  0, v.scopeRegOut.traceLength);
      axiSlaveRegisterW(x"000054" & "00", 13, v.scopeRegOut.skipSamples);
      axiSlaveRegisterW(x"000055" & "00",  0, v.scopeRegOut.inputChannelA);
      axiSlaveRegisterW(x"000055" & "00",  5, v.scopeRegOut.inputChannelB);
      axiSlaveRegisterW(x"000056" & "00",  0, v.scopeRegOut.triggerDelay);
      axiSlaveRegisterW(x"000080" & "00",  0, v.epixRegOut.requestStartupCal);
      axiSlaveRegisterW(x"000080" & "00",  1, v.epixRegOut.startupAck);          -- set by Microblaze
      axiSlaveRegisterW(x"000080" & "00",  2, v.epixRegOut.startupFail);         -- set by Microblaze
      axiSlaveRegisterW(x"000081" & "00",  0, v.epixRegOut.requestConfDump);
      
      axiSlaveRegisterW(x"000090" & "00",  0, v.epixRegOut.pipelineDelayA0);
      axiSlaveRegisterW(x"000091" & "00",  0, v.epixRegOut.pipelineDelayA1);
      axiSlaveRegisterW(x"000092" & "00",  0, v.epixRegOut.pipelineDelayA2);
      axiSlaveRegisterW(x"000093" & "00",  0, v.epixRegOut.pipelineDelayA3);
      
      -- gen 2 slow ADC data transformed to real numbers
      axiSlaveRegisterR(x"000140" & "00",  0, epixStatus.envData(0));
      axiSlaveRegisterR(x"000141" & "00",  0, epixStatus.envData(1));
      axiSlaveRegisterR(x"000142" & "00",  0, epixStatus.envData(2));
      axiSlaveRegisterR(x"000143" & "00",  0, epixStatus.envData(3));
      axiSlaveRegisterR(x"000144" & "00",  0, epixStatus.envData(4));
      axiSlaveRegisterR(x"000145" & "00",  0, epixStatus.envData(5));
      axiSlaveRegisterR(x"000146" & "00",  0, epixStatus.envData(6));
      axiSlaveRegisterR(x"000147" & "00",  0, epixStatus.envData(7));
      axiSlaveRegisterR(x"000148" & "00",  0, epixStatus.envData(8));

      -- Pseudo-SACI space, 0x080000
      -- These are commands used to do multi-SACI commands (e.g., configure multiple pixels)
      -- Note that these are EPIX100A-sized.  It must be extended to other ePix devices if desired.
      -- 2014.12.18 - Adding support for EpixS size
      -- 0x080000 - Row in global space
      -- 0x080001 - Col in global space
      -- 0x080002 - Left most pixel in global space
      -- 0x080003 - Next pixel to the right
      -- 0x080004 - Next pixel to the right
      -- 0x080005 - Right most pixel in global space, initiate SACI transactions
      axiSlaveRegisterW(x"080000" & "00",  0, v.globalMultiPix.row);
      axiSlaveRegisterW(x"080000" & "00", 16, v.globalMultiPix.calRowFlag);
      axiSlaveRegisterW(x"080000" & "00", 17, v.globalMultiPix.calBotFlag);
      axiSlaveRegisterW(x"080001" & "00",  0, v.globalMultiPix.col);
      axiSlaveRegisterW(x"080002" & "00",  0, v.globalMultiPix.data(0));
      axiSlaveRegisterW(x"080003" & "00",  0, v.globalMultiPix.data(1));
      axiSlaveRegisterW(x"080004" & "00",  0, v.globalMultiPix.data(2));
      --                x"080005" handled below so we can withold ack
      
      -- These are external devices that require waiting 
      -- on another interface to give a response.
      -- 0x080000 - 0x0FFFFF - Pseudo SACI Space
      -- 0x800000 - 0xFFFFFF - SACI Space
      if (axiStatus.writeEnable = '1') then
         -- Special reset for write to address 00
         if (axiWriteMaster.awaddr = 0) then
            v.usrRst := '1';
         -- Pseudo SACI Commands (multi-pixel write)
         elsif (axiWriteMaster.awaddr(25 downto 0) = x"080005" & "00") then
            v.globalMultiPix.data(3) := axiWriteMaster.wdata(15 downto 0);
            v.globalMultiPix.req     := '1';
         -- SACI Commands
         elsif (axiWriteMaster.awaddr(25) = '1') then
            v.saciRegIn.req    := '1';
            v.saciRegIn.op     := '1';
            v.saciRegIn.chip   := axiWriteMaster.awaddr(23 downto 22);
            v.saciRegIn.cmd    := axiWriteMaster.awaddr(20 downto 14);
            v.saciRegIn.addr   := axiWriteMaster.awaddr(13 downto 2);
            v.saciRegIn.wrData := axiWriteMaster.wdata;
         else
            axiSlaveDefault(AXI_RESP_OK_C);
         end if;
      end if;
      
      if (axiStatus.readEnable = '1') then
         -- Pseudo SACI Commands (multi-pixel write only... just return success)
         if (axiReadMaster.araddr(25 downto 0) = x"080005" & "00") then
            axiSlaveDefault(AXI_RESP_OK_C);
         -- SACI Commands
         elsif (axiReadMaster.araddr(25) = '1') then
            v.saciRegIn.req    := '1';
            v.saciRegIn.op     := '0';
            v.saciRegIn.chip   := axiReadMaster.araddr(23 downto 22);
            v.saciRegIn.cmd    := axiReadMaster.araddr(20 downto 14);
            v.saciRegIn.addr   := axiReadMaster.araddr(13 downto 2);
            v.saciRegIn.wrData := (others => '0');         
         else
            axiSlaveDefault(AXI_RESP_OK_C);
         end if;
      end if;
      

      -- SACI mediation
      -- By default let the SACI counter count
      if r.saciTimeout /= '1' then
         v.saciTimeoutCnt := r.saciTimeoutCnt + 1;
      end if;
      
      v.saciTimeout := r.saciTimeoutCnt(15);
      
      -- State machine for SACI mediation
      case(r.saciState) is
         when SACI_IDLE_S =>
            -- Default state for SACI Master
            v.saciSelIn := SACI_MASTER_IN_INIT_C;
            -- In idle state, continually reset SACI timeout
            v.saciTimeoutCnt := (others => '0');
            
            -- make sure that all previous requests are done before processing the next incoming
            if iSaciSelOut.fail = '0' and r.saciTimeout = '0' and iSaciSelOut.ack = '0' then
            
               -- If we see a register request, process it
               if (r.saciRegIn.req = '1') then
                  v.saciSelIn := r.saciRegIn;
                  v.saciState := SACI_REG_S;
                  
               -- If we see a multi-pixel write request, handle it
               elsif (r.globalMultiPix.req = '1') then
                  globalToLocalPixel(FPGA_VERSION_C(31 downto 24),
                                     r.globalMultiPix.row,
                                     r.globalMultiPix.col,
                                     r.globalMultiPix.calRowFlag,
                                     r.globalMultiPix.calBotFlag,
                                     r.globalMultiPix.data,
                                     v.localMultiPix.asic,
                                     v.localMultiPix.row,
                                     v.localMultiPix.col,
                                     v.localMultiPix.data);
                  v.localMultiPix.bankFlag := "1110";
                  -- If the ASIC is not active, immediately drop the req and return
                  if (r.epixRegOut.asicMask(conv_integer(v.localMultiPix.asic)) = '0') then
                     v.saciAxiRsp := AXI_RESP_OK_C;
                     v.saciState  := SACI_PIXEL_DONE_S;
                  else
                     v.saciState := SACI_PIXEL_ROW_S;
                  end if;
                  
               -- Otherwise watch for prepare for readout requests
               elsif (saciReadoutReq = '1') then
                  v.saciChipCnt      := (others => '0');
                  v.saciSelIn.req    := '0';
                  v.saciSelIn.op     := '0';
                  v.saciSelIn.chip   := (others => '0');
                  v.saciSelIn.cmd    := (others => '0');
                  v.saciSelIn.addr   := (others => '0');
                  v.saciSelIn.wrData := (others => '0');
                  v.saciState := SACI_PAUSE_S;
               end if;
               
            end if;
            
            
            
         -- Standard SACI register request
         when SACI_REG_S =>
            if (iSaciSelOut.fail = '1' or r.saciTimeout = '1') then
               v.saciSelIn.req := '0';
               v.saciRegIn.req := '0';
               v.saciAxiRsp    := AXI_RESP_SLVERR_C;
            elsif (iSaciSelOut.ack = '1') then
               v.saciSelIn.req := '0';
               v.saciRegIn.req := '0';
               v.saciAxiRsp    := AXI_RESP_OK_C;
            end if;
            
            if (r.saciSelIn.req = '0' and iSaciSelOut.ack = '0') then
               v.saciState     := SACI_IDLE_S;
               v.saciSelIn.req := '0';
               v.saciRegIn.req := '0';
               if (r.saciRegIn.op = '1') then
                  axiSlaveWriteResponse(v.axiWriteSlave,r.saciAxiRsp);
               else
                  v.axiReadSlave.rdata := iSaciSelOut.rdData;
                  axiSlaveReadResponse(v.axiReadSlave,r.saciAxiRsp);
               end if;
            end if;
            
            
         -------- Automated SACI prepare for readout ----------
         when SACI_PAUSE_S =>
            v.saciTimeoutCnt := (others => '0');
            v.saciSelIn.chip := r.saciChipCnt;
            if (r.epixRegOut.asicMask(conv_integer(r.saciChipCnt)) = '0') then
               if (r.saciChipCnt = 3) then
                  v.saciReadoutAck := '1';
                  v.saciState := SACI_IDLE_S;
               else
                  v.saciChipCnt := r.saciChipCnt + 1;
               end if;
            elsif iSaciSelOut.fail = '0' and r.saciTimeout = '0' and iSaciSelOut.ack = '0' then
               v.saciState := SACI_CMD_S;
            end if;
         when SACI_CMD_S =>
            v.saciSelIn.req := '1';
            if iSaciSelOut.fail = '1' or r.saciTimeout = '1' or iSaciSelOut.ack = '1' then
               v.saciSelIn.req := '0';
               if (r.saciChipCnt = 3) then
                  v.saciReadoutAck := '1';
                  v.saciState := SACI_IDLE_S;
               else
                  v.saciChipCnt   := r.saciChipCnt + 1;
                  v.saciState := SACI_PAUSE_S;
               end if;
            end if;
         --------- Multi pixel write -----------
         -- Write row (CMD = 6, RW = 1, ADDR = 17, DATA = ROW)
         when SACI_PIXEL_ROW_S  =>
            v.saciSelIn.req    := '1';
            v.saciSelIn.op     := '1';
            v.saciSelIn.chip   := r.localMultiPix.asic;
            v.saciSelIn.cmd    := "000" & x"6";
            v.saciSelIn.addr   := x"011";
            v.saciSelIn.wrData := x"0000" & x"0" & "000" & r.localMultiPix.row(8 downto 0);
            if (iSaciSelOut.ack = '1') then
               v.saciState := SACI_PIXEL_ROW_PAUSE_S;
            elsif (r.saciTimeout = '1' or iSaciSelOut.fail = '1') then
               v.saciAxiRsp := AXI_RESP_SLVERR_C;
               v.saciState  := SACI_PIXEL_DONE_S;
            end if;
         when SACI_PIXEL_ROW_PAUSE_S =>
            v.saciTimeoutCnt := (others => '0');
            v.saciSelIn.req  := '0';
            if (iSaciSelOut.ack = '0') then
               v.saciState := SACI_PIXEL_COL_S;
            end if;
         -- Write col (CMD = 6, RW = 1, ADDR = 19, DATA = Bank + Col
         when SACI_PIXEL_COL_S => 
            v.saciSelIn.req    := '1';
            v.saciSelIn.op     := '1';
            v.saciSelIn.chip   := r.localMultiPix.asic;
            v.saciSelIn.cmd    := "000" & x"6";
            v.saciSelIn.addr   := x"013";
            v.saciSelIn.wrData := x"0000" & x"0" & "0" & r.localMultiPix.bankFlag & r.localMultiPix.col(6 downto 0);
            if (iSaciSelOut.ack = '1') then
               v.saciState := SACI_PIXEL_COL_PAUSE_S;
            elsif (r.saciTimeout = '1' or iSaciSelOut.fail = '1') then
               v.saciAxiRsp := AXI_RESP_SLVERR_C;
               v.saciState  := SACI_PIXEL_DONE_S;
            end if;
         when SACI_PIXEL_COL_PAUSE_S =>
            v.saciTimeoutCnt := (others => '0');
            v.saciSelIn.req  := '0';
            if (iSaciSelOut.ack = '0') then
               v.saciState := SACI_PIXEL_DATA_S;
            end if;
         -- Write data (CMD = 5, RW = 1, ADDR = X, DATA = MT)
         when SACI_PIXEL_DATA_S =>
            v.saciSelIn.req    := '1';
            v.saciSelIn.op     := '1';
            v.saciSelIn.chip   := r.localMultiPix.asic;
            v.saciSelIn.cmd    := "000" & x"5";
            v.saciSelIn.addr   := x"000";
            v.saciSelIn.wrData := x"0000" & r.localMultiPix.data(0);
            if (iSaciSelOut.ack = '1') then
               v.saciState := SACI_PIXEL_NEXT_S;
            elsif (r.saciTimeout = '1' or iSaciSelOut.fail = '1') then
               v.saciAxiRsp    := AXI_RESP_SLVERR_C;
               v.saciState     := SACI_PIXEL_DONE_S;
            end if;
         when SACI_PIXEL_NEXT_S => 
            v.saciTimeoutCnt := (others => '0');
            v.saciSelIn.req  := '0';
            if (iSaciSelOut.ack = '0') then
               -- Done if this was the last bank
               if r.localMultiPix.bankFlag = "0111" then
                  v.saciAxiRsp := AXI_RESP_OK_C;
                  v.saciState  := SACI_PIXEL_DONE_S;
               -- Otherwise, rotate the bank counter and pixel data
               else
                  v.localMultiPix.bankFlag(3 downto 1) := r.localMultiPix.bankFlag(2 downto 0);
                  v.localMultiPix.bankFlag(0)          := r.localMultiPix.bankFlag(3);
                  v.localMultiPix.data(2 downto 0)     := r.localMultiPix.data(3 downto 1);
                  v.saciState                          := SACI_PIXEL_COL_S;
               end if;
            end if;
         when SACI_PIXEL_DONE_S =>
            v.globalMultiPix.req := '0';
            v.saciSelIn.req      := '0';
            if (iSaciSelOut.ack = '0') then
               axiSlaveWriteResponse(v.axiWriteSlave,r.saciAxiRsp);
               v.saciState := SACI_IDLE_S;
            end if;
         when others =>
            v.saciState := SACI_IDLE_S;
      end case;
         
      -- Synchronous Reset
      if axiReset = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      --------------------------
      -- Outputs 
      --------------------------
      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      epixConfig     <= r.epixRegOut;
      scopeConfig    <= r.scopeRegOut;
      saciReadoutAck <= r.saciReadoutAck;
      
   end process comb;
   
   

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -----------------------------------------------
   -- DAC Controller
   -----------------------------------------------
   U_DacCntrl : entity work.DacCntrl 
      generic map (
         TPD_G => TPD_G
      )
      port map ( 
         sysClk          => axiClk,
         sysClkRst       => axiReset,
         dacData         => r.epixRegOut.vguardDacSetting,
         dacDin          => dacDin,
         dacSclk         => dacSclk,
         dacCsL          => dacCsb,
         dacClrL         => dacClrb
      );

   -----------------------------------------------
   -- SACI Master
   -----------------------------------------------
   process ( axiClk ) begin
      if rising_edge(axiClk) then
         if iSaciSelL(0) = '0' then
            iSaciRsp <= saciRsp(0);
         elsif iSaciSelL(1) = '0' then
            iSaciRsp <= saciRsp(1);
         elsif iSaciSelL(2) = '0' then
            iSaciRsp <= saciRsp(2);
         elsif iSaciSelL(3) = '0' then
            iSaciRsp <= saciRsp(3);
         else
            iSaciRsp <= '0';
         end if;
      end if;
   end process;
   
   -- Actual SACI Master
   U_Saci : entity work.SaciMasterSync 
   port map (
       clk           => axiClk,
       rst           => saciRst,
       saciClk       => saciClk,
       saciSelL      => iSaciSelL,
       saciCmd       => saciCmd,
       saciRsp       => iSaciRsp,
       saciHalfClk   => x"0A",      -- saciClk fixed @ ~4.5MHz
       saciMasterIn  => r.saciSelIn,
       saciMasterOut => iSaciSelOut
   );
   saciSelL <= iSaciSelL;
   saciRst <= axiReset or r.saciTimeout;
      
   -----------------------------------------------
   -- Serial IDs: FPGA Device DNA + DS2411's
   -----------------------------------------------      
   G_DEVICE_DNA : entity work.DeviceDna
      generic map (
         TPD_G => TPD_G
      )
      port map (
         clk      => axiClk,
         rst      => axiReset,
         dnaValue => idValues(0),
         dnaValid => idValids(0)
      );
      
   G_DS2411 : for i in 0 to 1 generate
      U_DS2411_N : entity work.DS2411Core
         generic map (
            TPD_G        => TPD_G,
            CLK_PERIOD_G => CLK_PERIOD_G
         )
         port map (
            clk       => axiClk,
            rst       => chipIdRst,
            fdSerSdio => serialIdIo(i),
            fdSerial  => idValues(i+1),
            fdValid   => idValids(i+1)
         );
   end generate;
   
   chipIdRst <= axiReset or adcCardStartUpEdge;

   -- Special reset to the DS2411 to re-read in the event of a start up request event
   -- Start up (picoblaze) is disabling the ASIC digital monitors to ensure proper carrier ID readout
   adcCardStartUp <= r.epixRegOut.startupAck or r.epixRegOut.startupFail;
   U_adcCardStartUpRisingEdge : entity work.SynchronizerEdge
      generic map (
         TPD_G       => TPD_G)
      port map (
         clk         => axiClk,
         dataIn      => adcCardStartUp,
         risingEdge  => adcCardStartUpEdge);
   
end rtl;
