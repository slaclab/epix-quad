-------------------------------------------------------------------------------
-- File       : RegControl.vhd
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

use work.EpixPkgGen2.all;

library unisim;
use unisim.vcomponents.all;

entity RegControl is
   generic (
      TPD_G            : time            := 1 ns;
      FPGA_BASE_CLOCK_G    : slv(31 downto 0);
      BUILD_INFO_G  : BuildInfoType;
      EN_DEVICE_DNA_G  : boolean         := true;
      HARD_RESET_G     : boolean         := true;
      EN_MICROBLAZE_G  : boolean         := true;
      CLK_PERIOD_G     : real            := 10.0e-9;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_OK_C);
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
      epixStatus     : in  EpixStatusType;
      epixConfig     : out EpixConfigType;
      -- Guard ring DAC interfaces
      dacSclk        : out sl;
      dacDin         : out sl;
      dacCsb         : out sl;
      dacClrb        : out sl;
      -- 1-wire board ID interfaces
      serialIdIo     : inout slv(1 downto 0)
   );
end RegControl;

architecture rtl of RegControl is

   constant BUILD_INFO_C       : BuildInfoRetType    := toBuildInfo(BUILD_INFO_G);
   
   type RegType is record
      usrRst         : sl;
      epixRegOut     : EpixConfigType;
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      reqStartupD1   : sl;
      idValues       : Slv64Array(2 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      usrRst         => '0',
      epixRegOut     => EPIX_CONFIG_INIT_C,
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      reqStartupD1   => '0',
      idValues       => (others=>(others=>'0'))
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiReset : sl;
   
   signal idValues : Slv64Array(2 downto 0);
   signal idValids : slv(2 downto 0);
   
   signal adcCardStartUp     : sl;
   signal adcCardStartUpEdge : sl;
   
   signal chipIdRst          : sl;
   
begin

   axiReset <= (sysRst or r.usrRst) when(HARD_RESET_G) else sysRst;
   axiRst   <= axiReset;

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiReset, axiWriteMaster, r, ePixStatus, idValids, idValues) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
      
   begin
      -- Latch the current value
      v := r;

      -- Reset strobe signals
      v.epixRegOut.acqCountReset := '0';
      v.epixRegOut.seqCountReset := '0';
      
      -- Check for hard reset
      if (HARD_RESET_G = false) then
         v.usrRst := '0';
         if (r.usrRst = '1') then
            -- Reset the register
            v := REG_INIT_C;
         end if;      
      end if;      
      
      -- allow non 50% ducty cycle for ASIC readout clock
      if r.epixRegOut.asicRoClkT(0) = '0' then
         v.epixRegOut.asicRoClkHalfT(31 downto 16) := '0' & r.epixRegOut.asicRoClkT(15 downto 1);
         v.epixRegOut.asicRoClkHalfT(15 downto 0)  := '0' & r.epixRegOut.asicRoClkT(15 downto 1);
      else
         v.epixRegOut.asicRoClkHalfT(31 downto 16) := '0' & r.epixRegOut.asicRoClkT(15 downto 1) + 1;
         v.epixRegOut.asicRoClkHalfT(15 downto 0)  := '0' & r.epixRegOut.asicRoClkT(15 downto 1);
      end if;
      
      -- register IDs to help with timing closure
      for i in 2 downto 0 loop
         if idValids(i) = '1' then
            v.idValues(i) := idValues(i);
         else
            v.idValues(i) := (others=>'0');
         end if;
      end loop;
      
      -- sum all time delays leading to the ACQ pulse and expose in a read only register
      v.epixRegOut.asicPreAcqTime := r.epixRegOut.acqToAsicR0Delay + r.epixRegOut.asicR0Width + r.epixRegOut.asicR0ToAsicAcq;
      
      -- reset Ack and Fail when calibration requested (Req rising edge)
      v.reqStartupD1 := r.epixRegOut.requestStartupCal;
      if r.epixRegOut.requestStartupCal = '1' and r.reqStartupD1 = '0' then
         v.epixRegOut.startupAck := '0';
         v.epixRegOut.startupFail := '0';
      end if;
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);
      
      -- Special reset for write to address 00
      if regCon.axiStatus.writeEnable = '1' and axiWriteMaster.awaddr = 0 then
         v.usrRst := '1';
      end if;

      -- Map out standard registers    
      axiSlaveRegisterR(regCon, x"000" & "00",  0, BUILD_INFO_C.fwVersion); -- Need a reset strobe
      axiSlaveRegister (regCon, x"001" & "00",  0, v.epixRegOut.runTriggerEnable);
      axiSlaveRegister (regCon, x"002" & "00",  0, v.epixRegOut.runTriggerDelay);
      axiSlaveRegister (regCon, x"003" & "00",  0, v.epixRegOut.daqTriggerEnable);
      axiSlaveRegister (regCon, x"004" & "00",  0, v.epixRegOut.daqTriggerDelay);
      axiSlaveRegisterR(regCon, x"005" & "00",  0, epixStatus.acqCount);
      axiSlaveRegister (regCon, x"006" & "00",  0, v.epixRegOut.acqCountReset);
      axiSlaveRegister (regCon, x"007" & "00",  0, v.epixRegOut.vguardDacSetting);
      axiSlaveRegister (regCon, x"008" & "00",  0, v.epixRegOut.powerEnable);
      axiSlaveRegisterR(regCon, x"00A" & "00",  0, epixStatus.iDelayCtrlRdy);
      axiSlaveRegisterR(regCon, x"00B" & "00",  0, epixStatus.seqCount);
      axiSlaveRegister (regCon, x"00C" & "00",  0, v.epixRegOut.seqCountReset);
      axiSlaveRegister (regCon, x"00D" & "00",  0, v.epixRegOut.asicMask);
      axiSlaveRegisterR(regCon, x"010" & "00",  0, FPGA_BASE_CLOCK_G);
      axiSlaveRegister (regCon, x"011" & "00",  0, v.epixRegOut.autoRunEn);
      axiSlaveRegister (regCon, x"012" & "00",  0, v.epixRegOut.autoTrigPeriod);
      axiSlaveRegister (regCon, x"013" & "00",  0, v.epixRegOut.autoDaqEn);
      axiSlaveRegister (regCon, x"020" & "00",  0, v.epixRegOut.acqToAsicR0Delay);
      axiSlaveRegister (regCon, x"021" & "00",  0, v.epixRegOut.asicR0ToAsicAcq);
      axiSlaveRegister (regCon, x"022" & "00",  0, v.epixRegOut.asicAcqWidth);
      axiSlaveRegister (regCon, x"023" & "00",  0, v.epixRegOut.asicAcqLToPPmatL);
      axiSlaveRegister (regCon, x"024" & "00",  0, v.epixRegOut.asicRoClkT);
      axiSlaveRegister (regCon, x"026" & "00",  0, v.epixRegOut.adcClkHalfT);
      axiSlaveRegister (regCon, x"027" & "00",  0, v.epixRegOut.totalPixelsToRead);
      axiSlaveRegister (regCon, x"029" & "00",  0, v.epixRegOut.asicPins);
      axiSlaveRegister (regCon, x"02A" & "00",  0, v.epixRegOut.manualPinControl);
      axiSlaveRegister (regCon, x"02A" & "00",  8, v.epixRegOut.testPattern);
      axiSlaveRegister (regCon, x"02B" & "00",  0, v.epixRegOut.asicR0Width);
      axiSlaveRegisterR(regCon, x"030" & "00",  0, r.idValues(0)(31 downto  0)); --Digital card ID low
      axiSlaveRegisterR(regCon, x"031" & "00",  0, r.idValues(0)(63 downto 32)); --Digital card ID high
      axiSlaveRegisterR(regCon, x"032" & "00",  0, r.idValues(1)(31 downto  0)); --Analog card ID low
      axiSlaveRegisterR(regCon, x"033" & "00",  0, r.idValues(1)(63 downto 32)); --Analog card ID high
      
      axiSlaveRegisterR(regCon, x"039" & "00",  0, r.epixRegOut.asicPreAcqTime);
      axiSlaveRegister (regCon, x"03A" & "00",  0, v.epixRegOut.asicPPmatToReadout);
      axiSlaveRegisterR(regCon, x"03B" & "00",  0, r.idValues(2)(31 downto  0)); --Carrier card ID low
      axiSlaveRegisterR(regCon, x"03C" & "00",  0, r.idValues(2)(63 downto 32)); --Carrier card ID high
      axiSlaveRegister (regCon, x"03D" & "00",  0, v.epixRegOut.pgpTrigEn);
      axiSlaveRegister (regCon, x"080" & "00",  0, v.epixRegOut.requestStartupCal);
      axiSlaveRegister (regCon, x"080" & "00",  1, v.epixRegOut.startupAck);          -- set by Microblaze
      axiSlaveRegister (regCon, x"080" & "00",  2, v.epixRegOut.startupFail);         -- set by Microblaze
      
      axiSlaveRegister (regCon, x"090" & "00",  0, v.epixRegOut.pipelineDelayA0);
      axiSlaveRegister (regCon, x"091" & "00",  0, v.epixRegOut.pipelineDelayA1);
      axiSlaveRegister (regCon, x"092" & "00",  0, v.epixRegOut.pipelineDelayA2);
      axiSlaveRegister (regCon, x"093" & "00",  0, v.epixRegOut.pipelineDelayA3);
      
      axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);

      -- Check if no microblaze attached
      if (EN_MICROBLAZE_G = false) then
         v.epixRegOut.requestStartupCal := '0';
         v.epixRegOut.startupAck        := '1';
         v.epixRegOut.startupFail       := '0';
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
      epixConfig     <= r.epixRegOut;
      
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
   -- Serial IDs: FPGA Device DNA + DS2411's
   -----------------------------------------------  
   GEN_DEVICE_DNA : if (EN_DEVICE_DNA_G = true) generate
      G_DEVICE_DNA : entity surf.DeviceDna
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => axiClk,
            rst      => axiReset,
            dnaValue(127 downto 64) => open,
            dnaValue( 63 downto  0) => idValues(0),
            dnaValid => idValids(0));
   end generate GEN_DEVICE_DNA;
   
   BYP_DEVICE_DNA : if (EN_DEVICE_DNA_G = false) generate
      idValids(0) <= '1';
      idValues(0) <= (others=>'0');
   end generate BYP_DEVICE_DNA;   
      
   G_DS2411 : for i in 0 to 1 generate
      U_DS2411_N : entity surf.DS2411Core
      generic map (
         TPD_G        => TPD_G,
         CLK_PERIOD_G => CLK_PERIOD_G,
         SMPL_TIME_G  => 19.1E-6
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
   adcCardStartUp <= r.epixRegOut.startupAck or r.epixRegOut.startupFail;
   U_adcCardStartUpRisingEdge : entity surf.SynchronizerEdge
   generic map (
      TPD_G       => TPD_G)
   port map (
      clk         => axiClk,
      dataIn      => adcCardStartUp,
      risingEdge  => adcCardStartUpEdge
   );
   
end rtl;
