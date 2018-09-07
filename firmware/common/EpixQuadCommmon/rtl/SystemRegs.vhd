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
      -- User reset output
      usrRst            : out sl;
      -- AXI lite slave port for register access
      axilClk           : in  sl;
      axilRst           : in  sl;
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
      asicGr            : out   sl
   );
end SystemRegs;


-- Define architecture
architecture RTL of SystemRegs is
   
   constant LATCH_TEMP_DEF_C  : sl        := ite(USE_TEMP_FAULT_G, '1', '0');
   constant DEBOUNCE_PERIOD_C : real      := ite(SIM_SPEEDUP_G, 5.0E-6, 500.0E-3);
   constant ASIC_GR_INDEX_C   : natural   := ite(SIM_SPEEDUP_G, 5, 25);

   type RegType is record
      asicAnaEnReg      : sl;
      asicDigEnReg      : sl;
      asicAnaEn         : sl;
      asicDigEn         : slv(1 downto 0);
      asicDigEnShift    : slv(15 downto 0);
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
      asicGrCnt         : slv(25 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      asicAnaEnReg      => '0',
      asicDigEnReg      => '0',
      asicAnaEn         => '0',
      asicDigEn         => "00",
      asicDigEnShift    => x"0000",
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
      asicGrCnt         => (others=>'0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal idValues   : Slv64Array(3 downto 0);
   signal idValids   : slv(3 downto 0);
   
   signal tempAlert  : sl;

begin

   U_Debouncer : entity work.Debouncer
      generic map(
         TPD_G             => TPD_G,
         INPUT_POLARITY_G  => '0',                 -- active LOW
         OUTPUT_POLARITY_G => '1',                 -- active HIGH
         CLK_FREQ_G        => 100.0E+6,            -- units of Hz
         DEBOUNCE_PERIOD_G => DEBOUNCE_PERIOD_C,   -- units of seconds
         SYNCHRONIZE_G     => true)                -- Run input through 2 FFs before filtering
      port map(
         clk => axilClk,
         i   => tempAlertL,
         o   => tempAlert
      );

   --------------------------------------------------
   -- AXI Lite register logic
   --------------------------------------------------

   comb : process (axilRst, ddrVttPok, r, sAxilReadMaster, sAxilWriteMaster,
                   tempAlert, idValids, idValues) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;

      -- reset strobes
      v.syncAll := '0';

      -- sync inputs
      v.ddrVttPok := ddrVttPok;

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
      if r.asicAnaEnReg = '1' and r.dcdcEn(1 downto 0) = "11" then
         v.asicAnaEn := '1';
      else
         v.asicAnaEn := '0';
      end if;
      if r.asicDigEnReg = '1' and r.dcdcEn(3) = '1' then
         v.asicDigEn(0) := '1';
      else
         v.asicDigEn(0) := '0';
      end if;
      
      -- ASIC Global Reset Counter
      if r.asicDigEn(0) = '0' then
         v.asicGrCnt := (others=>'0');
      elsif r.asicGrCnt(ASIC_GR_INDEX_C) = '0' then
         v.asicGrCnt := r.asicGrCnt + 1;
      end if;

      -- Determine the AXI-Lite transaction
      v.sAxilReadSlave.rdata := (others => '0');
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
      
      for i in 3 downto 0 loop
         axiSlaveRegisterR(regCon, x"030"+toSlv(i*8, 12), 0, ite(idValids(i) = '1',idValues(i)(31 downto  0), x"00000000")); --ASIC carrier ID low
         axiSlaveRegisterR(regCon, x"034"+toSlv(i*8, 12), 0, ite(idValids(i) = '1',idValues(i)(63 downto 32), x"00000000")); --ASIC carrier ID high
      end loop;

      -- DCDC sync registers
      axiSlaveRegister(regCon, x"100", 0, v.syncAll);
      for i in 10 downto 0 loop
         axiSlaveRegister(regCon, x"200"+toSlv(i*4, 12), 0, v.syncHalfClk(i));
         axiSlaveRegister(regCon, x"300"+toSlv(i*4, 12), 0, v.syncPhase(i));
      end loop;

      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);

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
      
      -- ID chip reset
      -- ASIC carrier ID chip is on ASIC's DVDD
      v.asicDigEn(1) := r.asicDigEn(0);
      if r.asicDigEn(0) = '1' and r.asicDigEn(1) = '0' then
         v.asicDigEnShift(0)  := '1';
      else
         v.asicDigEnShift     := r.asicDigEnShift(14 downto 0) & '0';
      end if;
      if r.asicDigEnShift /= 0 then
         v.idRst := '1';
      else
         v.idRst := '0';
      end if;

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave <= r.sAxilWriteSlave;
      sAxilReadSlave <= r.sAxilReadSlave;
      
      usrRst      <= r.usrRst;
      dcdcEn      <= r.dcdcEn;
      dcdcSync    <= r.syncOut;
      ddrVttEn    <= r.ddrVttEn;
      asicAnaEn   <= r.asicAnaEn;
      asicDigEn   <= r.asicDigEn(0);
      asicGr      <= r.asicGrCnt(ASIC_GR_INDEX_C);

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -----------------------------------------------
   -- ASIC carrier serial IDs
   ----------------------------------------------- 
   G_DS2411 : for i in 0 to 3 generate
      U_DS2411 : entity work.DS2411Core
      generic map (
         TPD_G        => TPD_G,
         CLK_PERIOD_G => CLK_PERIOD_G
      )
      port map (
         clk       => axilClk,
         rst       => r.idRst,
         fdSerSdio => asicDmSn(i),
         fdValue   => idValues(i),
         fdValid   => idValids(i)
      );
   end generate;

end RTL;

