-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RegControlM.vhd
-- Author     : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 04/26/2016
-- Last update: 04/26/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Change log:
-- [MK] 04/26/2016 - Created
-------------------------------------------------------------------------------
-- Description: EpixMArray32 register controller
-------------------------------------------------------------------------------
-- This file is part of 'Epix Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Epix Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity RegControlM is
   generic (
      TPD_G             : time               := 1 ns;
      EN_DEVICE_DNA_G   : boolean            := true;
      CLK_PERIOD_G      : real            := 10.0e-9;
      BUILD_INFO_G      : BuildInfoType
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
      -- Register Inputs/Outputs (axiClk domain)
      powerEn        : out slv(2 downto 0);
      dbgSel1        : out slv(4 downto 0);
      dbgSel2        : out slv(4 downto 0);
      -- 1-wire board ID interfaces
      serialIdIo     : inout slv(1 downto 0);
      -- fast ADC clock
      adcClk         : out sl;
      -- ASICs acquisition signals
      acqStart       : in  sl;   -- trigger in
      asicGlblRst    : out sl;   -- to ASIC
      asicR1         : out sl;   -- to ASIC
      asicR2         : out sl;   -- to ASIC
      asicR3         : out sl;   -- to ASIC
      asicClk        : out sl;   -- to ASIC
      asicStart      : out sl;   -- to readout
      asicSample     : out sl;   -- to readout (with pipeline delay setting)
      asicReady      : in  sl;   -- from readout
      -- debug trigger out
      trigOut        : out sl
   );
end RegControlM;

architecture rtl of RegControlM is
   
   type AsicAcqType is record
      asicStart         : sl;
      asicGlblRst       : sl;
      asicGlblRstDly    : slv(7 downto 0);
      asicR1            : sl;
      asicR2            : sl;
      asicR3            : sl;
      asicR1Tr1         : slv(31 downto 0);
      asicR2Tr1         : slv(31 downto 0);
      asicR3Tr1         : slv(31 downto 0);
      asicR1Tr2         : slv(31 downto 0);
      asicR2Tr2         : slv(31 downto 0);
      asicR3Tr2         : slv(31 downto 0);
      asicR1Test        : sl;                -- register setting
      asicClk           : sl;
      asicClkMaskEn     : sl;
      asicClkMaskCnt    : slv(10 downto 0);
      asicClkDly        : slv(31 downto 0);  -- register setting
      asicClkPerHalf    : slv(15 downto 0);  -- register setting
      asicClkPerCnt     : slv(15 downto 0);
      asicClkCnt        : integer;
      asicSample        : slv(255 downto 0);
      asicSampleDly     : slv(7 downto 0);   -- register setting
      trigOut           : sl;
      trigOutDly        : slv(31 downto 0);
      trigOutLen        : slv(31 downto 0);
      asicR3ForceLow    : sl;
   end record AsicAcqType;
   
   constant ASICACQ_TYPE_INIT_C : AsicAcqType := (
      asicStart         => '0',
      asicGlblRst       => '0',
      asicGlblRstDly    => (others=>'0'),
      asicR1            => '1',
      asicR2            => '1',
      asicR3            => '1',
      asicR1Tr1         => toSlv(0, 32),     -- T = value * 10ns
      asicR2Tr1         => toSlv(100, 32),   -- T = value * 10ns
      asicR3Tr1         => toSlv(0, 32),     -- T = value * 10ns
      asicR1Tr2         => toSlv(600, 32),   -- T = value * 10ns
      asicR2Tr2         => toSlv(450, 32),   -- T = value * 10ns
      asicR3Tr2         => toSlv(500, 32),   -- T = value * 10ns
      asicR1Test        => '0',
      asicClk           => '0',
      asicClkMaskEn     => '0',
      asicClkMaskCnt    => (others=>'0'),
      asicClkDly        => toSlv(1000, 32),  -- T = value * 10ns
      asicClkPerHalf    => toSlv(100, 16),   -- T = value * 10ns
      asicClkPerCnt     => (others=>'0'),
      asicClkCnt        => 0,
      asicSample        => (others=>'0'),
      asicSampleDly     => toSlv(112, 8),    -- 112 is sampling in the middle of low asicClk (verified in asicR1Test mode)
      trigOut           => '0',
      trigOutDly        => (others=>'0'),
      trigOutLen        => (others=>'0'),
      asicR3ForceLow    => '0'
   );
   
   type StateType is (IDLE_S, WAIT_ADC_S);
   
   type RegType is record
      usrRst            : sl;
      asicAcqReg        : AsicAcqType;
      asicAcqTimeCnt    : slv(31 downto 0);
      acqState          : StateType;
      adcClk            : sl;
      adcCnt            : slv(31 downto 0);
      adcClkHalfT       : slv(31 downto 0);
      pwrEnableReq      : slv(2 downto 0);
      dbgSel1           : slv(4 downto 0);
      dbgSel2           : slv(4 downto 0);
      requestStartupCal : sl;
      startupAck        : sl;
      startupFail       : sl;
      axiReadSlave      : AxiLiteReadSlaveType;
      axiWriteSlave     : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      usrRst            => '0',
      asicAcqReg        => ASICACQ_TYPE_INIT_C,
      asicAcqTimeCnt    => (others=>'1'),
      acqState          => IDLE_S,
      adcClk            => '0',
      adcCnt            => (others=>'0'),
      adcClkHalfT       => x"00000001",
      pwrEnableReq      => (others=>'0'),
      dbgSel1           => (others=>'0'),
      dbgSel2           => (others=>'0'),
      requestStartupCal => '0',
      startupAck        => '0',
      startupFail       => '0',
      axiReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal idValues : Slv64Array(2 downto 0);
   signal idValids : slv(2 downto 0);
   
   signal adcCardStartUp     : sl;
   signal adcCardStartUpEdge : sl;
   
   signal chipIdRst          : sl;
   
   signal axiReset : sl;
   
   constant BUILD_INFO_C       : BuildInfoRetType    := toBuildInfo(BUILD_INFO_G);
   
begin

   axiReset <= sysRst or r.usrRst;
   axiRst   <= axiReset;

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiReset, axiWriteMaster, r, idValids, idValues, acqStart, asicReady) is
      variable v           : RegType;
      variable regCon      : AxiLiteEndPointType;
      
   begin
      -- Latch the current value
      v := r;
      
      -- Reset data and strobes
      v.axiReadSlave.rdata       := (others => '0');
      v.asicAcqReg.asicSample    := r.asicAcqReg.asicSample(254 downto 0) & '0';
      v.asicAcqReg.asicStart     := '0';
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);
      
      -- Map out standard registers
      axiSlaveRegister (regCon, x"000000",  0, v.usrRst );
      axiSlaveRegisterR(regCon, x"000000",  0, BUILD_INFO_C.fwVersion );
      axiSlaveRegisterR(regCon, x"000004",  0, ite(idValids(0) = '1',idValues(0)(31 downto  0), x"00000000")); --Digital card ID low
      axiSlaveRegisterR(regCon, x"000008",  0, ite(idValids(0) = '1',idValues(0)(63 downto 32), x"00000000")); --Digital card ID high
      axiSlaveRegisterR(regCon, x"00000C",  0, ite(idValids(1) = '1',idValues(1)(31 downto  0), x"00000000")); --Analog card ID low
      axiSlaveRegisterR(regCon, x"000010",  0, ite(idValids(1) = '1',idValues(1)(63 downto 32), x"00000000")); --Analog card ID high
      axiSlaveRegisterR(regCon, x"000014",  0, ite(idValids(2) = '1',idValues(2)(31 downto  0), x"00000000")); --Carrier card ID low
      axiSlaveRegisterR(regCon, x"000018",  0, ite(idValids(2) = '1',idValues(2)(63 downto 32), x"00000000")); --Carrier card ID high
      
      axiSlaveRegister(regCon,  x"000100",  0, v.asicAcqReg.asicR1Tr1);
      axiSlaveRegister(regCon,  x"000104",  0, v.asicAcqReg.asicR2Tr1);
      axiSlaveRegister(regCon,  x"000108",  0, v.asicAcqReg.asicR3Tr1);
      axiSlaveRegister(regCon,  x"00010C",  0, v.asicAcqReg.asicR1Tr2);
      axiSlaveRegister(regCon,  x"000110",  0, v.asicAcqReg.asicR2Tr2);
      axiSlaveRegister(regCon,  x"000114",  0, v.asicAcqReg.asicR3Tr2);
      axiSlaveRegister(regCon,  x"000118",  0, v.asicAcqReg.asicR1Test);
      axiSlaveRegister(regCon,  x"00011C",  0, v.asicAcqReg.asicClkDly);
      axiSlaveRegister(regCon,  x"000120",  0, v.asicAcqReg.asicClkPerHalf);
      axiSlaveRegister(regCon,  x"000124",  0, v.asicAcqReg.asicSampleDly);
      axiSlaveRegister(regCon,  x"000128",  0, v.asicAcqReg.trigOutDly);
      axiSlaveRegister(regCon,  x"00012C",  0, v.asicAcqReg.trigOutLen);
      axiSlaveRegister(regCon,  x"000130",  0, v.asicAcqReg.asicClkMaskEn);
      axiSlaveRegister(regCon,  x"000134",  0, v.asicAcqReg.asicClkMaskCnt);
      axiSlaveRegister(regCon,  x"000138",  0, v.asicAcqReg.asicR3ForceLow);
      
      axiSlaveRegister(regCon,  x"000200",  0, v.pwrEnableReq);
      axiSlaveRegister(regCon,  x"000204",  0, v.dbgSel1);
      axiSlaveRegister(regCon,  x"000208",  0, v.dbgSel2);
      
      axiSlaveRegister(regCon,  x"000300",  0, v.adcClkHalfT);
      axiSlaveRegister(regCon,  x"000304",  0, v.requestStartupCal);
      axiSlaveRegister(regCon,  x"000304",  1, v.startupAck);          -- set by Microblaze
      axiSlaveRegister(regCon,  x"000304",  2, v.startupFail);         -- set by Microblaze     
      
      -- Special reset for write to address 00
      --if regCon.axiStatus.writeEnable = '1' and axiWriteMaster.awaddr = 0 then
      --   v.usrRst := '1';
      --end if;
      
      axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_RESP_OK_C);
      
      -- ADC clock counter
      if r.adcCnt >= r.adcClkHalfT - 1 then
         v.adcClk := not r.adcClk;
         v.adcCnt := (others => '0');
      else
         v.adcCnt := r.adcCnt + 1;
      end if;
      
      -- FSM to synchronize acqStart to the ADC clock
      case (r.acqState) is
         
         when IDLE_S =>
            if acqStart = '1' and asicReady = '1' and r.asicAcqReg.asicGlblRst = '1' then
               v.acqState := WAIT_ADC_S;
            end if;
         
         when WAIT_ADC_S =>
            if r.adcCnt = 0 and r.adcClk = '0' then
               v.acqState := IDLE_S;
               v.asicAcqReg.asicStart := '1';
            end if;
         
         when others => null;
         
      end case;
      
      -- programmable ASIC acquisition waveform
      if r.asicAcqReg.asicGlblRst = '0' then
         v.asicAcqTimeCnt           := (others=>'1');
      elsif acqStart = '1' and asicReady = '1' then
         v.asicAcqTimeCnt           := (others=>'0');
         if r.asicAcqReg.asicR1Test = '0' then
            v.asicAcqReg.asicR1     := '1';
         else
            v.asicAcqReg.asicR1     := '0';
         end if;
         v.asicAcqReg.asicR2        := '1';
         if r.asicAcqReg.asicR3ForceLow = '0' then
            v.asicAcqReg.asicR3        := '1';
         else
            v.asicAcqReg.asicR3        := '0';
         end if;
         v.asicAcqReg.trigOut       := '0';
         v.asicAcqReg.asicClk       := '0';
         v.asicAcqReg.asicClkPerCnt := (others=>'0');
         v.asicAcqReg.asicClkCnt    := 0;
      elsif r.acqState = IDLE_S then
      
         if r.asicAcqTimeCnt /= x"FFFFFFFF" then
            v.asicAcqTimeCnt := r.asicAcqTimeCnt + 1;
         end if;
         
         -- asicR1 waveform (2 transitions) only when not in R1 test mode
         if r.asicAcqReg.asicR1Test = '0' then
            if r.asicAcqReg.asicR1Tr1 <= r.asicAcqTimeCnt then
               v.asicAcqReg.asicR1 := '0';
            end if;
            if r.asicAcqReg.asicR1Tr1 + r.asicAcqReg.asicR1Tr2 <= r.asicAcqTimeCnt then
               v.asicAcqReg.asicR1 := '1';
            end if;
         end if;
         
         -- asicR2 waveform (2 transitions)
         if r.asicAcqReg.asicR2Tr1 <= r.asicAcqTimeCnt then
            v.asicAcqReg.asicR2 := '0';
         end if;
         if r.asicAcqReg.asicR2Tr1 + r.asicAcqReg.asicR2Tr2 <= r.asicAcqTimeCnt then
            v.asicAcqReg.asicR2 := '1';
         end if;
         
         -- asicR3 waveform (2 transitions)
         if r.asicAcqReg.asicR3Tr1 <= r.asicAcqTimeCnt then
            v.asicAcqReg.asicR3 := '0';
         end if;
         if r.asicAcqReg.asicR3Tr1 + r.asicAcqReg.asicR3Tr2 <= r.asicAcqTimeCnt then
            v.asicAcqReg.asicR3 := '1';
         end if; 
         -- force R3 low (test mode)
         if r.asicAcqReg.asicR3ForceLow = '1' then
            v.asicAcqReg.asicR3 := '0';
         end if;
         
         -- asicClk generator 
         -- starts after delay as set in the register
         if r.asicAcqReg.asicClkDly <= r.asicAcqTimeCnt then
            if r.asicAcqReg.asicClkCnt < 2048 then
               -- rising edge transition
               if r.asicAcqReg.asicClkPerCnt = (r.asicAcqReg.asicClkPerHalf - 1) and r.asicAcqReg.asicClk = '0' then
                  v.asicAcqReg.asicClk      := '1';
                  -- R1 test mode (for ADC latency measurement)
                  if r.asicAcqReg.asicR1Test = '1' then
                     v.asicAcqReg.asicR1 := '0';
                  end if;
               end if;
               -- falling edge transition
               if r.asicAcqReg.asicClkPerCnt = (r.asicAcqReg.asicClkPerHalf - 1) and r.asicAcqReg.asicClk = '1' then
                  v.asicAcqReg.asicClk      := '0';
                  v.asicAcqReg.asicClkCnt   := r.asicAcqReg.asicClkCnt + 1;
                  -- sample at or after falling edge of asicClk
                  v.asicAcqReg.asicSample(0) := '1';
                  -- R1 test mode (for ADC latency measurement)
                  if r.asicAcqReg.asicR1Test = '1' and r.asicAcqReg.asicClkCnt = 0 then
                     v.asicAcqReg.asicR1 := '1';
                  end if;
               end if;
            end if;
            -- asicClk half period counter
            if r.asicAcqReg.asicClkPerCnt < (r.asicAcqReg.asicClkPerHalf - 1) then
               v.asicAcqReg.asicClkPerCnt := r.asicAcqReg.asicClkPerCnt + 1;
            else
               v.asicAcqReg.asicClkPerCnt := (others=>'0');
            end if;
            
         end if;
         
         -- output trigger generator
         if r.asicAcqReg.trigOutDly <= r.asicAcqTimeCnt then
            v.asicAcqReg.trigOut := '1';
         end if;
         if r.asicAcqReg.trigOutDly + r.asicAcqReg.trigOutLen <= r.asicAcqTimeCnt then
            v.asicAcqReg.trigOut := '0';
         end if;
         if r.asicAcqReg.trigOutLen = 0 then
            v.asicAcqReg.trigOut := '0';
         end if;
         
      end if;
      
      -- ASIC global reset
      if r.pwrEnableReq(1 downto 0) /= "11" then
         v.asicAcqReg.asicGlblRstDly   := (others=>'0');
         v.asicAcqReg.asicGlblRst      := '0';
      elsif r.asicAcqReg.asicGlblRstDly /= x"FF" then
         v.asicAcqReg.asicGlblRstDly   := r.asicAcqReg.asicGlblRstDly + 1;
         v.asicAcqReg.asicGlblRst      := '0';
      else
         v.asicAcqReg.asicGlblRst      := '1';
      end if;
      
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
      adcClk         <= r.adcClk;
      powerEn        <= r.pwrEnableReq;
      dbgSel1        <= r.dbgSel1;
      dbgSel2        <= r.dbgSel2;
      
      asicGlblRst    <= r.asicAcqReg.asicGlblRst;
      asicR1         <= r.asicAcqReg.asicR1;
      asicR2         <= r.asicAcqReg.asicR2;
      asicR3         <= r.asicAcqReg.asicR3;
      -- stop reading out at a given (set) pixel
      -- ASIC debug test
      -- remove feature when done testing
      if r.asicAcqReg.asicClkCnt >= r.asicAcqReg.asicClkMaskCnt and r.asicAcqReg.asicClkMaskEn = '1' then
         asicClk     <= '0';
      else
         asicClk     <= r.asicAcqReg.asicClk;
      end if;
      asicStart      <= r.asicAcqReg.asicStart;
      asicSample     <= r.asicAcqReg.asicSample(conv_integer(r.asicAcqReg.asicSampleDly));
      trigOut        <= r.asicAcqReg.trigOut;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   
   -----------------------------------------------
   -- Serial IDs: FPGA Device DNA + DS2411's
   -----------------------------------------------  
   GEN_DEVICE_DNA : if (EN_DEVICE_DNA_G = true) generate
      G_DEVICE_DNA : entity work.DeviceDna
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => axiClk,
            rst      => axiReset,
            dnaValue(127 downto 64) => open,
            dnaValue( 63 downto  0) => idValues(0),
            dnaValid => idValids(0)
         );
   end generate GEN_DEVICE_DNA;
   
   BYP_DEVICE_DNA : if (EN_DEVICE_DNA_G = false) generate
      idValids(0) <= '1';
      idValues(0) <= (others=>'0');
   end generate BYP_DEVICE_DNA;   
      
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
         fdValue   => idValues(i+1),
         fdValid   => idValids(i+1)
      );
   end generate;
   
   chipIdRst <= axiReset or adcCardStartUpEdge;

   -- Special reset to the DS2411 to re-read in the event of a start up request event
   -- Start up (picoblaze) is disabling the ASIC digital monitors to ensure proper carrier ID readout
   adcCardStartUp <= r.startupAck or r.startupFail;
   U_adcCardStartUpRisingEdge : entity work.SynchronizerEdge
   generic map (
      TPD_G       => TPD_G)
   port map (
      clk         => axiClk,
      dataIn      => adcCardStartUp,
      risingEdge  => adcCardStartUpEdge
   );
   
end rtl;
