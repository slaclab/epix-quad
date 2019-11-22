-------------------------------------------------------------------------------
-- File       : SystemRegs.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-06-09
-- Last update: 2018-03-13
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

entity SystemRegs is
   generic (
      TPD_G             : time            := 1 ns;
      CLK_PERIOD_G      : real            := 10.0e-9;
      USE_DCDC_SYNC_G   : boolean         := false;
      USE_TEMP_FAULT_G  : boolean         := true;
      SIM_SPEEDUP_G     : boolean         := false);
   port (
      -- System Clock
      sysClk            : in  sl;
      sysRst            : in  sl;
      -- User reset output
      usrRst            : out sl;
      -- ADC ISERDESE reset
      adcClkRst         : out slv(9 downto 0);
      -- ADC Startup Signals
      adcReqStart       : out sl;
      adcReqTest        : out sl;
      -- AXI lite slave port for register access
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      -- Power Supply Cntrl Ports
      asicAnaEn         : out sl;
      asicDigEn         : out sl;
      dcdcSync          : out slv(10 downto 0);
      dcdcEn            : out slv(3 downto 0);
      ddrVttEn          : out sl;
      ddrVttPok         : in  sl;
      -- FPGA temperature alert
      tempAlertL        : in  sl;
      -- ASIC Carrier IDs
      asicDmSn          : inout slv(3 downto 0);
      -- ASIC Global Reset
      asicGr            : out sl;
      -- trigger inputs
      trigPgp           : in  sl := '0';
      trigTtl           : in  sl := '0';
      trigCmd           : in  sl := '0';
      -- trigger output
      acqStart          : out sl;
      -- ASIC mask output
      asicMask          : out slv(15 downto 0)
   );
end SystemRegs;


-- Define architecture
architecture RTL of SystemRegs is
   
   constant LATCH_TEMP_DEF_C  : sl                 := ite(USE_TEMP_FAULT_G, '1', '0');
   constant DEBOUNCE_PERIOD_C : real               := ite(SIM_SPEEDUP_G, 5.0E-6, 500.0E-3);
   constant ASIC_GR_INDEX_C   : natural            := ite(SIM_SPEEDUP_G, 5, 25);
   constant ASIC_MAS_INIT_C   : slv(15 downto 0)   := ite(SIM_SPEEDUP_G, x"FFFF", x"0000");

   type RegType is record
      acqStart          : sl;
      asicAnaEnReg      : sl;
      asicDigEnReg      : sl;
      asicAnaEn         : sl;
      asicDigEn         : sl;
      idRst             : sl;
      tempFault         : sl;
      latchTempFault    : sl;
      dcdcEnReg         : slv(3 downto 0);
      dcdcEn            : slv(3 downto 0);
      ddrVttEn          : sl;
      ddrVttPok         : sl;
      sAxilWriteSlave   : AxiLiteWriteSlaveType;
      sAxilReadSlave    : AxiLiteReadSlaveType;
      syncAll           : sl;
      sync              : slv(10 downto 0);
      syncClkCnt        : Slv32Array(10 downto 0);
      syncPhaseCnt      : Slv32Array(10 downto 0);
      syncHalfClk       : Slv32Array(10 downto 0);
      syncPhase         : Slv32Array(10 downto 0);
      syncOut           : slv(10 downto 0);
      usrRstShift       : slv(7 downto 0);
      usrRst            : sl;
      adcClkRst         : slv(9 downto 0);
      adcReqStart       : sl;
      adcReqTest        : sl;
      adcTestDone       : sl;
      adcTestFailed     : sl;
      adcChanFailed     : Slv32Array(9 downto 0);
      asicGrCnt         : slv(25 downto 0);
      trigEn            : sl;
      trigSrcSel        : slv(1 downto 0);
      autoTrigEn        : sl;
      autoTrig          : sl;
      autoTrigReg       : slv(31 downto 0);
      autoTrigPer       : slv(31 downto 0);
      autoTrigCnt       : slv(31 downto 0);
      trigPerRst        : sl;
      trigPerRdy        : slv(1 downto 0);
      trigPerCnt        : slv(31 downto 0);
      trigPer           : slv(31 downto 0);
      trigPerMin        : slv(31 downto 0);
      trigPerMax        : slv(31 downto 0);
      asicMaskReg       : slv(31 downto 0);
      asicMask          : slv(15 downto 0);
      idValues          : Slv64Array(3 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      acqStart          => '0',
      asicAnaEnReg      => '0',
      asicDigEnReg      => '0',
      asicAnaEn         => '0',
      asicDigEn         => '0',
      idRst             => '0',
      tempFault         => '0',
      latchTempFault    => LATCH_TEMP_DEF_C,
      dcdcEnReg         => (others => '0'),
      dcdcEn            => (others => '0'),
      ddrVttEn          => '1',
      ddrVttPok         => '0',
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      syncAll           => '0',
      sync              => (others => '0'),
      syncClkCnt        => (others => (others => '0')),
      syncPhaseCnt      => (others => (others => '0')),
      syncHalfClk       => (others => (others => '0')),
      syncPhase         => (others => (others => '0')),
      syncOut           => (others => '0'),
      usrRstShift       => (others => '0'),
      usrRst            => '0',
      adcClkRst         => (others=>'0'),
      adcReqStart       => '0',
      adcReqTest        => '0',
      adcTestDone       => '0',
      adcTestFailed     => '0',
      adcChanFailed     => (others => (others => '0')),
      asicGrCnt         => (others=>'0'),
      trigEn            => '0',
      trigSrcSel        => (others=>'0'),
      autoTrigEn        => '0',
      autoTrig          => '0',
      autoTrigReg       => (others=>'0'),
      autoTrigPer       => (others=>'0'),
      autoTrigCnt       => (others=>'0'),
      trigPerRst        => '0',
      trigPerRdy        => (others=>'0'),
      trigPerCnt        => (others=>'0'),
      trigPer           => (others=>'0'),
      trigPerMin        => (others=>'1'),
      trigPerMax        => (others=>'0'),
      asicMaskReg       => (others=>'0'),
      asicMask          => ASIC_MAS_INIT_C,
      idValues          => (others => (others => '0'))
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal idValues   : Slv64Array(3 downto 0);
   signal idValids   : slv(3 downto 0);
   
   signal tempAlert  : sl;
   
   signal extTrig    : slv(2 downto 0);
   
   signal idRstSync  : sl;

begin
   
   --------------------------------------------------
   -- TempAlert Filter
   --------------------------------------------------
   U_Debouncer : entity work.Debouncer
      generic map(
         TPD_G             => TPD_G,
         INPUT_POLARITY_G  => '0',                 -- active LOW
         OUTPUT_POLARITY_G => '1',                 -- active HIGH
         CLK_FREQ_G        => 100.0E+6,            -- units of Hz
         DEBOUNCE_PERIOD_G => DEBOUNCE_PERIOD_C,   -- units of seconds
         SYNCHRONIZE_G     => true)                -- Run input through 2 FFs before filtering
      port map(
         clk => sysClk,
         i   => tempAlertL,
         o   => tempAlert
      );
   
   
   --------------------------------------------------
   -- External Trigger Synchronizers
   --------------------------------------------------
   U_TrigPgpEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => trigPgp,
         risingEdge => extTrig(0)
      );
   
   U_TrigTtlEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => trigTtl,
         risingEdge => extTrig(1)
      );
   
   U_TrigCmdEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => trigCmd,
         risingEdge => extTrig(2)
      );

   --------------------------------------------------
   -- AXI Lite register logic
   --------------------------------------------------

   comb : process (sysRst, ddrVttPok, r, sAxilReadMaster, sAxilWriteMaster,
                   tempAlert, idValids, idValues, extTrig) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;

      -- reset strobes
      v.syncAll      := '0';
      v.trigPerRst   := '0';
      v.idRst        := '0';
      v.asicMaskReg  := (others=>'0');
      v.adcClkRst    := (others=>'0');

      -- sync inputs
      v.ddrVttPok := ddrVttPok;
      
      for i in 3 downto 0 loop
         if idValids(i) = '1' then
            v.idValues(i) := idValues(i);
         end if;
      end loop;

      -- Generate the tempFault
      if r.latchTempFault = '0' then
         v.tempFault := '0';
      elsif tempAlert = '1' then
         v.tempFault := '1';
      end if;
      
      -- enable DCDCs if tempFault inactive
      if r.tempFault = '0' then
         v.dcdcEn := r.dcdcEnReg;
      else
         v.dcdcEn := "0000";
      end if;
      
      -- enable ASIC LDOs only after its DCDC is already turned on
      -- digital has to be enabled first or same time with analog (enforced)
      if r.asicDigEnReg = '1' and r.dcdcEn(3) = '1' then
         v.asicDigEn := '1';
      else
         v.asicDigEn := '0';
      end if;
      -- do not allow to turn on analog when digital is off
      if r.asicAnaEnReg = '1' and r.dcdcEn(1 downto 0) = "11" and r.asicDigEn = '1' then
         v.asicAnaEn := '1';
      else
         v.asicAnaEn := '0';
      end if;
      
      -- ASIC Global Reset Counter
      if r.asicDigEn = '0' then
         v.asicGrCnt := (others=>'0');
      elsif r.asicGrCnt(ASIC_GR_INDEX_C) = '0' then
         v.asicGrCnt := r.asicGrCnt + 1;
      end if;
      
      -- Auto Trigger Counter and Pulse
      v.autoTrig := '0';
      if r.autoTrigReg > 0 then
         v.autoTrigPer := r.autoTrigReg - 1;
      else
         v.autoTrigPer := (others=>'0');
      end if;
      if r.autoTrigEn = '0' then
         v.autoTrigCnt  := (others=>'0');
      elsif r.autoTrigCnt < r.autoTrigPer then
         v.autoTrigCnt  := r.autoTrigCnt + 1;
      elsif r.autoTrigCnt /= 0 then
         v.autoTrig     := '1';
         v.autoTrigCnt  := (others=>'0');
      end if;
      
      -- trigger source select
      if r.trigEn = '1' then
         if r.trigSrcSel = 0 then
            v.acqStart := extTrig(0);
         elsif r.trigSrcSel = 1 then
            v.acqStart := extTrig(1);
         elsif r.trigSrcSel = 2 then
            v.acqStart := extTrig(2);
         elsif r.trigSrcSel = 3 then
            v.acqStart := r.autoTrig;
         else
            v.acqStart := '0';
         end if;
      else
         v.acqStart := '0';
      end if;
      
      -- trigger rate monitoring
      if r.trigPerRst = '1' then
         v.trigPerMin := (others=>'1');
         v.trigPerMax := (others=>'0');
         v.trigPer    := (others=>'0');
         v.trigPerRdy := (others=>'0');
         v.trigPerCnt := (others=>'0');
      else
         -- after min 2 triggers latch counter, min and max
         if r.acqStart = '1' and r.trigPerRdy = 2 then
            v.trigPer    := r.trigPerCnt+1;
            if r.trigPerMax < r.trigPerCnt+1 then
               v.trigPerMax := r.trigPerCnt+1;
            end if;
            if r.trigPerMin > r.trigPerCnt+1 then
               v.trigPerMin := r.trigPerCnt+1;
            end if;
         elsif r.acqStart = '1' and r.trigPerRdy < 2 then
            v.trigPerRdy := r.trigPerRdy + 1;
         end if;
         -- count in between triggers
         if r.acqStart = '1' then
            v.trigPerCnt := (others=>'0');
         elsif r.trigPerCnt /= x"FFFFFFFF" then
            v.trigPerCnt := r.trigPerCnt + 1;
         end if;
      end if;

      -- Determine the AXI-Lite transaction
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.usrRstShift(0));
      axiSlaveRegister (regCon, x"004", 0, v.dcdcEnReg);
      axiSlaveRegister (regCon, x"008", 0, v.asicAnaEnReg);
      axiSlaveRegister (regCon, x"00C", 0, v.asicDigEnReg);
      axiSlaveRegister (regCon, x"010", 0, v.ddrVttEn);
      axiSlaveRegisterR(regCon, x"014", 0, r.ddrVttPok);

      axiSlaveRegisterR(regCon, x"018", 0, tempAlert);
      axiSlaveRegisterR(regCon, x"01C", 0, r.tempFault);
      axiSlaveRegister (regCon, x"020", 0, v.latchTempFault);
      
      axiSlaveRegister (regCon, x"024", 0, v.idRst);
      axiSlaveRegister (regCon, x"028", 0, v.asicMaskReg);
      axiSlaveRegisterR(regCon, x"028", 0, r.asicMask);
      
      for i in 3 downto 0 loop
         axiSlaveRegisterR(regCon, x"030"+toSlv(i*8, 12), 0, r.idValues(i)(31 downto  0)); --ASIC carrier ID low
         axiSlaveRegisterR(regCon, x"034"+toSlv(i*8, 12), 0, r.idValues(i)(63 downto 32)); --ASIC carrier ID high
      end loop;

      -- DCDC sync registers
      axiSlaveRegister(regCon, x"100", 0, v.syncAll);
      for i in 10 downto 0 loop
         axiSlaveRegister(regCon, x"200"+toSlv(i*4, 12), 0, v.syncHalfClk(i));
         axiSlaveRegister(regCon, x"300"+toSlv(i*4, 12), 0, v.syncPhase(i));
      end loop;
      
      axiSlaveRegister (regCon, x"400", 0, v.trigEn);
      axiSlaveRegister (regCon, x"404", 0, v.trigSrcSel);
      axiSlaveRegister (regCon, x"408", 0, v.autoTrigEn);
      axiSlaveRegister (regCon, x"40C", 0, v.autoTrigReg);
      axiSlaveRegister (regCon, x"410", 0, v.trigPerRst);
      axiSlaveRegisterR(regCon, x"414", 0, r.trigPer);
      axiSlaveRegisterR(regCon, x"418", 0, r.trigPerMin);
      axiSlaveRegisterR(regCon, x"41C", 0, r.trigPerMax);
      
      axiSlaveRegister (regCon, x"500", 0, v.adcClkRst);
      axiSlaveRegister (regCon, x"504", 0, v.adcReqStart);
      axiSlaveRegister (regCon, x"508", 0, v.adcReqTest);
      axiSlaveRegister (regCon, x"50C", 0, v.adcTestDone);
      axiSlaveRegister (regCon, x"510", 0, v.adcTestFailed);
      for i in 9 downto 0 loop
         axiSlaveRegister(regCon, x"514"+toSlv(i*4, 12), 0, v.adcChanFailed(i));
      end loop;
      

      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);
      
      -- ASIC mask with a key to only allow MB to write
      if r.asicMaskReg(31 downto 16) = x"AAAA" then
         v.asicMask := r.asicMaskReg(15 downto 0);
      end if;
      
      -- DCDC sync logic
      for i in 10 downto 0 loop
         if USE_DCDC_SYNC_G = true then
            -- phase counters
            if r.syncAll = '1' then
               v.syncPhaseCnt(i) := (others => '0');
               v.sync(i)         := '1';
            elsif r.syncPhaseCnt(i) < r.syncPhase(i) then
               v.syncPhaseCnt(i) := r.syncPhaseCnt(i) + 1;
            else
               v.sync(i) := '0';
            end if;
            -- clock counters
            if r.sync(i) = '1' then
               v.syncClkCnt(i) := (others => '0');
               v.syncOut(i)    := '0';
            elsif r.syncClkCnt(i) = r.syncHalfClk(i) then
               v.syncClkCnt(i) := (others => '0');
               v.syncOut(i)    := not r.syncOut(i);
            else
               v.syncClkCnt(i) := r.syncClkCnt(i) + 1;
            end if;
            -- disable sync if resister is zero
            if r.syncHalfClk(i) = 0 then
               v.syncOut(i) := '0';
            end if;
         else
            -- remove sync functionality if not required
            v.syncPhaseCnt(i) := (others => '0');
            v.syncClkCnt(i)   := (others => '0');
            v.sync(i)         := '0';
            v.syncOut(i)      := '0';
         end if;
      end loop;

      -- software reset logic
      v.usrRstShift := v.usrRstShift(6 downto 0) & '0';
      if r.usrRstShift /= 0 then
         v.usrRst := '1';
      else
         v.usrRst := '0';
      end if;

      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave <= r.sAxilWriteSlave;
      sAxilReadSlave <= r.sAxilReadSlave;
      
      usrRst      <= r.usrRst;
      adcClkRst   <= r.adcClkRst;
      adcReqStart <= r.adcReqStart;
      adcReqTest  <= r.adcReqTest;
      dcdcEn      <= r.dcdcEn;
      dcdcSync    <= r.syncOut;
      ddrVttEn    <= r.ddrVttEn;
      asicAnaEn   <= r.asicAnaEn;
      asicDigEn   <= r.asicDigEn;
      asicGr      <= r.asicGrCnt(ASIC_GR_INDEX_C);
      acqStart    <= r.acqStart;
      asicMask    <= r.asicMask;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -----------------------------------------------
   -- ASIC carrier serial IDs
   ----------------------------------------------- 
   U_IdRstSync: entity work.Synchronizer
   port map (
      clk     => sysClk,
      rst     => sysRst,
      dataIn  => r.idRst,
      dataOut => idRstSync
   );
   
   G_DS2411 : for i in 0 to 3 generate
      U_DS2411 : entity work.DS2411Core
      generic map (
         TPD_G        => TPD_G,
         CLK_PERIOD_G => CLK_PERIOD_G,
         SMPL_TIME_G  => 19.1E-6
      )
      port map (
         clk       => sysClk,
         rst       => idRstSync,
         fdSerSdio => asicDmSn(i),
         fdValue   => idValues(i),
         fdValid   => idValids(i)
      );
   end generate;

end RTL;

