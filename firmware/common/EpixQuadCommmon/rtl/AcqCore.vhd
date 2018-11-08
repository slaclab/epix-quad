-------------------------------------------------------------------------------
-- File       : AcqCore.vhd
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

entity AcqCore is
   generic (
      TPD_G             : time         := 1 ns;
      BANK_COLS_G       : natural      := 48;
      BANK_ROWS_G       : natural      := 178
   );
   port (
      -- System Clock (100 MHz)
      sysClk            : in  sl;
      sysRst            : in  sl;
      -- AXI lite slave port for register access
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      -- Run control
      acqStart          : in    sl;
      acqBusy           : out   sl;
      acqCount          : out   slv(31 downto 0);
      acqSmplEn         : out   sl;
      readDone          : in    sl;
      roClkTail         : in    slv(7 downto 0);
      -- ASIC Control Ports
      asicAcq           : out   sl;
      asicR0            : out   sl;
      asicSync          : out   sl;
      asicPpmat         : out   sl;
      asicRoClk         : out   sl;
      -- ADC Clock Output
      adcClk            : out   sl
   );
end AcqCore;


-- Define architecture
architecture RTL of AcqCore is
   
   type AcqStateType is (
      IDLE_S,
      WAIT_R0_S,
      PULSE_R0_S,
      WAIT_ACQ_S,
      ACQ_S,
      WAIT_PPMAT_S,
      WAIT_POST_PPMAT_S,
      SYNC_TO_ADC_S,
      WAIT_ADC_S,
      NEXT_CELL_S,
      WAIT_DOUT_S,
      NEXT_DOUT_S,
      WAIT_FOR_READOUT_S,
      SYNC_S
   );
   
   type RegType is record
      acqCount             : slv(31 downto 0);
      acqCountReset        : sl;
      acqToAsicR0Delay     : slv(31 downto 0);
      asicR0Width          : slv(31 downto 0);
      asicR0ToAsicAcq      : slv(31 downto 0);
      asicAcqWidth         : slv(31 downto 0);
      asicAcqLToPPmatL     : slv(31 downto 0);
      asicRoClkHalfTReg    : slv(31 downto 0);
      asicRoClkHalfT       : slv(31 downto 0);
      asicPreAcqTime       : slv(31 downto 0);
      asicPpmatToReadout   : slv(31 downto 0);
      asicPinForce         : slv(4 downto 0);
      asicPinValue         : slv(4 downto 0);
      asicAcq              : sl;
      asicR0               : sl;
      asicSync             : sl;
      asicPpmat            : sl;
      asicRoClk            : sl;
      acqSmplEn            : sl;
      roClkCnt             : slv(31 downto 0);
      acqBusy              : sl;
      adcClk               : sl;
      stateCnt             : slv(31 downto 0);
      acqState             : AcqStateType;
      sAxilWriteSlave      : AxiLiteWriteSlaveType;
      sAxilReadSlave       : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      acqCount             => (others=>'0'),
      acqCountReset        => '0',
      acqToAsicR0Delay     => (others=>'0'),
      asicR0Width          => toSlv(100, 32),
      asicR0ToAsicAcq      => toSlv(100, 32),
      asicAcqWidth         => toSlv(100, 32),
      asicAcqLToPPmatL     => (others=>'0'),
      asicRoClkHalfTReg    => (others=>'0'),
      asicRoClkHalfT       => (others=>'0'),
      asicPreAcqTime       => (others=>'0'),
      asicPpmatToReadout   => (others=>'0'),
      asicPinForce         => (others=>'0'),
      asicPinValue         => (others=>'0'),
      asicAcq              => '0',
      asicR0               => '0',
      asicSync             => '0',
      asicPpmat            => '0',
      asicRoClk            => '0',
      acqSmplEn            => '0',
      roClkCnt             => (others=>'0'),
      acqBusy              => '0',
      adcClk               => '0',
      stateCnt             => (others=>'0'),
      acqState             => IDLE_S,
      sAxilWriteSlave      => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave       => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal acqStartEdge       : std_logic             := '0';
   
   constant ROCLK_COUNT_C : natural := 4 * BANK_COLS_G * BANK_ROWS_G;   -- roClk is divided by 4, (data is read out from 64 banks simultaneously)
   
begin
   
   U_ReadStartEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => acqStart,
         risingEdge => acqStartEdge
      );

   comb : process (sysRst, r, sAxilReadMaster, sAxilWriteMaster,
      acqStartEdge, readDone, roClkTail) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;
      
      v.asicRoClkHalfTReg := (others=>'0');
      
      -- ADC clock frequency is fixed to 50 MHz
      v.adcClk := not r.adcClk;
      
      -- clear strobe
      v.acqCountReset := '0';
      
      -- count acquisitions
      if r.acqCountReset = '1' then
         v.acqCount := (others=>'0');
      elsif acqStartEdge = '1' and r.acqBusy = '0' then
         v.acqCount := r.acqCount + 1;
      end if;
      
      --------------------------------------------------
      -- AXI Lite register logic
      --------------------------------------------------
      
      -- Determine the AXI-Lite transaction
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegisterR(regCon, x"000", 0, r.acqCount          );
      axiSlaveRegister (regCon, x"004", 0, v.acqCountReset     );
      axiSlaveRegister (regCon, x"008", 0, v.acqToAsicR0Delay  );
      axiSlaveRegister (regCon, x"00C", 0, v.asicR0Width       );
      axiSlaveRegister (regCon, x"010", 0, v.asicR0ToAsicAcq   );
      axiSlaveRegister (regCon, x"014", 0, v.asicAcqWidth      );
      axiSlaveRegister (regCon, x"018", 0, v.asicAcqLToPPmatL  );
      axiSlaveRegister (regCon, x"01C", 0, v.asicPpmatToReadout);
      axiSlaveRegister (regCon, x"020", 0, v.asicRoClkHalfTReg );
      axiSlaveRegisterR(regCon, x"020", 0, r.asicRoClkHalfT    );
      axiSlaveRegisterR(regCon, x"024", 0, toSlv(ROCLK_COUNT_C, 32));
      axiSlaveRegisterR(regCon, x"028", 0, r.asicPreAcqTime    );
      axiSlaveRegister (regCon, x"02C", 0, v.asicPinForce      );
      axiSlaveRegister (regCon, x"030", 0, v.asicPinValue      );
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXI_RESP_DECERR_C);
      
      -- ASIC RdoutClk period is preset by the Microblaze and should be changed only be an expert
      if r.asicRoClkHalfTReg(31 downto 16) = x"AAAA" then
         v.asicRoClkHalfT := x"0000" & r.asicRoClkHalfTReg(15 downto 0);
      end if;
      
      --------------------------------------------------
      -- Acquisition FSM
      -- Based on small EPIX camera implementation by Kurtis
      --------------------------------------------------
      
      v.stateCnt  := r.stateCnt + 1;
      v.acqBusy   := '1';
      v.asicAcq   := '0';
      v.asicR0    := '1';
      v.asicSync  := '0';
      v.asicPpmat := '0';
      v.asicRoClk := '0';
      v.acqSmplEn := '0';
      
      -- sum all delay leading to ACQ pulse
      v.asicPreAcqTime := r.acqToAsicR0Delay + r.asicR0Width + r.asicR0ToAsicAcq;
      
      case r.acqState is
         
         -- wait for trigger
         when IDLE_S =>
            v.stateCnt  := (others=>'0');
            v.roClkCnt  := (others=>'0');
            v.acqBusy   := '0';
            -- R0 must be low in IDLE for the matrix configuration to work
            v.asicR0    := '0';
            if acqStartEdge = '1' then
               v.acqState := WAIT_R0_S;
            end if;
         
         -- delay before R0
         when WAIT_R0_S =>
            v.asicR0 := '0';
            v.asicPpmat := '1';
            if r.stateCnt >= r.acqToAsicR0Delay then
               v.stateCnt := (others=>'0');
               v.acqState := PULSE_R0_S;
            end if;
         
         -- R0 pulse (low)
         when PULSE_R0_S =>
            v.asicR0 := '0';
            v.asicPpmat := '1';
            if r.stateCnt >= r.asicR0Width then
               v.stateCnt := (others=>'0');
               v.acqState := WAIT_ACQ_S;
            end if;
         
         -- delay before ACQ pulse
         when WAIT_ACQ_S =>
            v.asicPpmat := '1';
            if r.stateCnt >= r.asicR0ToAsicAcq then
               v.stateCnt := (others=>'0');
               v.acqState := ACQ_S;
            end if;
         
         -- ACQ pulse (high)
         when ACQ_S =>
            v.asicAcq := '1';
            v.asicPpmat := '1';
            if r.stateCnt >= r.asicAcqWidth then
               v.stateCnt := (others=>'0');
               v.acqState := WAIT_PPMAT_S;
            end if;
         
         -- removed DROP_ACQ_S state as it was an empty transition
         
         -- Delay before PPMAT drop (matrix power off)
         when WAIT_PPMAT_S =>
            v.asicPpmat := '1';
            if r.stateCnt >= r.asicAcqLToPPmatL then
               v.stateCnt := (others=>'0');
               v.acqState := WAIT_POST_PPMAT_S;
            end if;
         
         -- delay before start of readout
         when WAIT_POST_PPMAT_S =>
            if r.stateCnt >= r.asicPPmatToReadout then
               v.stateCnt := (others=>'0');
               v.acqState := SYNC_TO_ADC_S;
            end if;
         
         -- synchronize with adcClk
         when SYNC_TO_ADC_S =>
            if r.adcClk = '1' then
               v.stateCnt := (others=>'0');
               v.acqState := NEXT_CELL_S;
            end if;
         
         -- asicRoClk low
         when WAIT_ADC_S =>
            if r.stateCnt >= r.asicRoClkHalfT-1 or r.asicRoClkHalfT = 0 then
               v.stateCnt  := (others=>'0');
               v.roClkCnt  := r.roClkCnt + 1;
               if r.roClkCnt < ROCLK_COUNT_C-1 then
                  v.acqState  := NEXT_CELL_S;
               else
                  v.roClkCnt := (others=>'0');
                  -- roClkTail is equal to roClk delay needed to output
                  -- remaining digital output bits
                  if roClkTail = 0 then
                     v.acqState := WAIT_FOR_READOUT_S;
                  else
                     v.acqState := NEXT_DOUT_S;
                  end if;
               end if;
            end if;
         
         -- asicRoClk high
         when NEXT_CELL_S =>
            v.asicRoClk := '1';
            if r.stateCnt >= r.asicRoClkHalfT-1 or r.asicRoClkHalfT = 0 then
               v.stateCnt := (others=>'0');
               v.acqState := WAIT_ADC_S;
            end if;
            if r.roClkCnt(1 downto 0) = "11" and r.stateCnt = 0 then
               v.acqSmplEn := '1';
            end if;
         
         -- asicRoClk low
         when WAIT_DOUT_S =>
            if r.stateCnt >= r.asicRoClkHalfT-1 or r.asicRoClkHalfT = 0 then
               v.stateCnt  := (others=>'0');
               if r.roClkCnt < roClkTail then
                  v.roClkCnt := r.roClkCnt + 1;
                  v.acqState := NEXT_DOUT_S;
               else
                  v.acqState := WAIT_FOR_READOUT_S;
               end if;
            end if;
         
         -- asicRoClk high
         when NEXT_DOUT_S =>
            v.asicRoClk := '1';
            if r.stateCnt >= r.asicRoClkHalfT-1 or r.asicRoClkHalfT = 0 then
               v.stateCnt := (others=>'0');
               v.acqState := WAIT_DOUT_S;
            end if;
         
         -- wait unit all ASIC data is read out (handshake)
         when WAIT_FOR_READOUT_S =>
            if readDone = '1' then
               v.stateCnt := (others=>'0');
               v.acqState := SYNC_S;
            end if;
         
         -- SACI_RESET_S state renamed to SYNC_S
         -- for simplicity the big EPIX will use sync pulse
         -- instead of a SACI prep command for synchronization
         when SYNC_S =>
            v.asicSync  := '1';
            -- arbitrary sync pulse width (1us)
            if r.stateCnt >= 100 then
               v.stateCnt := (others=>'0');
               v.acqState := IDLE_S;
            end if;
         
         -- removed DONE_S state as it was an empty transition
            
         when others =>
            v.acqState := IDLE_S;
            
      end case;
         
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;
      acqBusy           <= r.acqBusy;
      adcClk            <= r.adcClk;
      acqCount          <= r.acqCount;
      acqSmplEn         <= r.acqSmplEn;

   end process comb;
   
   asicAcq     <= r.asicAcq   when r.asicPinForce(0) = '0' else r.asicPinValue(0);
   asicR0      <= r.asicR0    when r.asicPinForce(1) = '0' else r.asicPinValue(1);
   asicPpmat   <= r.asicPpmat when r.asicPinForce(2) = '0' else r.asicPinValue(2);
   asicSync    <= r.asicSync  when r.asicPinForce(3) = '0' else r.asicPinValue(3);
   asicRoClk   <= r.asicRoClk when r.asicPinForce(4) = '0' else r.asicPinValue(4);

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end RTL;

