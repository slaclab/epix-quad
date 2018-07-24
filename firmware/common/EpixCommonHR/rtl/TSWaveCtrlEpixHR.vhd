-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TSWaveCtrlEpixHR.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 07/20/2018
-- Last update: 2018-07-24
-- Platform   : Vivado 2017.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Change log:
-- [DD] 07/20/2018 - Created
-------------------------------------------------------------------------------
-- Description: Test Structure External clock waveform register controller
-------------------------------------------------------------------------------
-- This file is part of 'EpixHR Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EpixHR Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.EpixHRPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TSWaveCtrlEpixHR is
   generic (
      TPD_G             : time            := 1 ns;     
      CLK_PERIOD_G      : real            := 10.0e-9
   );
   port (
      -- Global Signals
      axiClk         : in  sl;
      sysCLK         : in  sl;
      dSysClk        : in  sl;          -- delayed sys clock
      axiRst         : in  sl;
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- ASICs acquisition signals
      asicSDCLk      : out sl;
      asicSDRst      : out sl;
      asicSHClk      : out sl
   );
end TSWaveCtrlEpixHR;

architecture rtl of TSWaveCtrlEpixHR is
   
   type AsicAcqType is record
      SDRst           : sl;
      SDRstPolarity   : sl;
      SDRstDelay      : slv(31 downto 0);
      SDRstWidth      : slv(31 downto 0);
      SHClk           : sl;
      SHClkPolarity   : sl;
      SHClkDelay      : slv(31 downto 0);
      SHClkWidth      : slv(31 downto 0);
   end record AsicAcqType;
   
   constant ASICACQ_TYPE_INIT_C : AsicAcqType := (
      SDRst           => '0',
      SDRstPolarity   => '0',
      SDRstDelay      => x"00000020",
      SDRstWidth      => x"00000001",
      SHClk           => '0',
      SHClkPolarity   => '1',
      SHClkDelay      => x"00000020",
      SHClkWidth      => x"00000020"
   );
   
   type RegType is record
      usrRst            : sl;
      enWaveforms       : sl;
      adcClk            : sl;
      adcCnt            : slv(31 downto 0);
      adcClkHalfT       : slv(31 downto 0);
      asicAcqReg        : AsicAcqType;
      asicAcqTimeCnt    : slv(31 downto 0);
      axiReadSlave      : AxiLiteReadSlaveType;
      axiWriteSlave     : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      usrRst            => '0',
      enWaveforms       => '1',
      adcClk            => '1',
      adcCnt            => (others=>'0'),
      adcClkHalfT       => x"00000001",
      asicAcqReg        => ASICACQ_TYPE_INIT_C,
      asicAcqTimeCnt    => (others=>'0'),
      axiReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal axiReset : sl;

   attribute keep : string;                              -- for chipscope
   attribute keep of r : signal is "true";               -- for chipscope

      
begin

   axiReset <= axiRst or r.usrRst;

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiReset, axiWriteMaster, r) is
      variable v           : RegType;
      variable regCon      : AxiLiteEndPointType;
      
   begin
      -- Latch the current value
      v := r;
      
      -- Reset data and strobes
      v.axiReadSlave.rdata       := (others => '0');
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);
      
      -- Map out standard registers
      axiSlaveRegister(regCon,  x"000000",  0, v.usrRst);
      axiSlaveRegister(regCon,  x"000004",  0, v.enWaveforms);
      axiSlaveRegister(regCon,  x"000010",  0, v.adcClkHalfT);
      axiSlaveRegister(regCon,  x"000020",  0, v.asicAcqReg.SDRstPolarity);
      axiSlaveRegister(regCon,  x"000024",  0, v.asicAcqReg.SDRstDelay);
      axiSlaveRegister(regCon,  x"000028",  0, v.asicAcqReg.SDRstWidth);
      axiSlaveRegister(regCon,  x"000030",  0, v.asicAcqReg.SHClkPolarity);
      axiSlaveRegister(regCon,  x"000034",  0, v.asicAcqReg.SHClkDelay);
      axiSlaveRegister(regCon,  x"000038",  0, v.asicAcqReg.SHClkWidth); 
      
      
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
      
      -- programmable ASIC acquisition waveform
      -- SHClk waveforms defines the period of the events
      if ((r.asicAcqReg.SHClkWidth + r.asicAcqReg.SHClkDelay) < r.asicAcqTimeCnt) or (r.enWaveforms = '0') then
         v.asicAcqTimeCnt        := (others=>'0');
         v.asicAcqReg.SDRst      := r.asicAcqReg.SDRstPolarity;
         v.asicAcqReg.SHClk      := r.asicAcqReg.SHClkPolarity;
      else
         -- always count
         v.asicAcqTimeCnt := r.asicAcqTimeCnt + 1;
         
         -- single pulse. zero value corresponds to infinite delay/width
         if r.asicAcqReg.SDRstDelay /= 0 and r.asicAcqReg.SDRstDelay <= r.asicAcqTimeCnt then
            v.asicAcqReg.SDRst := not r.asicAcqReg.SDRstPolarity;
            if r.asicAcqReg.SDRstWidth /= 0 and (r.asicAcqReg.SDRstWidth + r.asicAcqReg.SDRstDelay) <= r.asicAcqTimeCnt then
               v.asicAcqReg.SDRst := r.asicAcqReg.SDRstPolarity;
            end if;
         end if;
         
         -- single pulse. zero value corresponds to infinite delay/width
         if r.asicAcqReg.SHClkDelay /= 0 and r.asicAcqReg.SHClkDelay <= r.asicAcqTimeCnt then
            v.asicAcqReg.SHClk := not r.asicAcqReg.SHClkPolarity;
            if r.asicAcqReg.SHClkWidth /= 0 and (r.asicAcqReg.SHClkWidth + r.asicAcqReg.SHClkDelay) <= r.asicAcqTimeCnt then
               v.asicAcqReg.SHClk := r.asicAcqReg.SHClkPolarity;
            end if;
         end if;
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
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   latch : process (SysClk) is
   begin
      if rising_edge(SysClk) then
        asicSDRst      <= r.asicAcqReg.SDRst;
        asicSHClk      <= r.asicAcqReg.SHClk;
      end if;
   end process latch;

   delyedLatch : process (dSysClk) is
   begin
      if rising_edge(dSysClk) then
         asicSDClk <= r.adcClk after TPD_G;
      end if;
   end process delyedLatch;
   
end rtl;
