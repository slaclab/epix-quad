-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RegControlCpix.vhd
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
-- Description: Cpix register controller
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.CpixPkg.all;

library unisim;
use unisim.vcomponents.all;

entity RegControlCpix is
   generic (
      TPD_G          : time := 1 ns
   );
   port (
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : in  sl;  
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs (axiClk domain)
      cpixStatus     : in  CpixStatusType;
      cpixConfig     : out CpixConfigType
   );
end RegControlCpix;

architecture rtl of RegControlCpix is
   
   type RegType is record
      cpixRegOut     : CpixConfigType;
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      cpixRegOut     => CPIX_CONFIG_INIT_C,
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, r) is
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
      
      -- Reset data
      v.axiReadSlave.rdata       := (others => '0');
      
      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Map out standard registers
      axiSlaveRegisterW(x"000000" & "00",  0, v.cpixRegOut.cpixRunToAcq );
      axiSlaveRegisterW(x"000001" & "00",  0, v.cpixRegOut.cpixR0ToAcq  );
      axiSlaveRegisterW(x"000002" & "00",  0, v.cpixRegOut.cpixAcqWidth );
      axiSlaveRegisterW(x"000003" & "00",  0, v.cpixRegOut.cpixAcqToCnt );
      axiSlaveRegisterW(x"000004" & "00",  0, v.cpixRegOut.cpixSyncWidth);
      axiSlaveRegisterW(x"000005" & "00",  0, v.cpixRegOut.cpixSROWidth );
      axiSlaveRegisterW(x"000006" & "00",  0, v.cpixRegOut.cpixNRuns    );
      axiSlaveRegisterW(x"000007" & "00",  0, v.cpixRegOut.cpixCntAnotB );
      axiSlaveRegisterW(x"000008" & "00",  0, v.cpixRegOut.syncMode );
      axiSlaveRegisterW(x"000009" & "00",  0, v.cpixRegOut.cpixAsicPinControl );
      axiSlaveRegisterW(x"00000A" & "00",  0, v.cpixRegOut.cpixAsicPins );
      
      axiSlaveRegisterW(x"000100" & "00",  0, v.cpixRegOut.cpixErrorRst );
      axiSlaveRegisterW(x"000101" & "00",  0, v.cpixRegOut.forceFrameRead );
      
      axiSlaveRegisterR(x"000200" & "00",  0, cpixStatus.cpixAsicInSync(0));
      axiSlaveRegisterR(x"000201" & "00",  0, cpixStatus.cpixFrameErr(0));
      axiSlaveRegisterR(x"000202" & "00",  0, cpixStatus.cpixCodeErr(0));
      axiSlaveRegisterR(x"000203" & "00",  0, cpixStatus.cpixTimeoutErr(0));
      axiSlaveRegisterW(x"000204" & "00",  0, v.cpixRegOut.doutResync(0));
      axiSlaveRegisterW(x"000205" & "00",  0, v.cpixRegOut.doutDelay(0));
      axiSlaveRegisterR(x"000206" & "00",  0, cpixStatus.cpixFramesGood(0));
      
      axiSlaveRegisterR(x"000300" & "00",  0, cpixStatus.cpixAsicInSync(1));
      axiSlaveRegisterR(x"000301" & "00",  0, cpixStatus.cpixFrameErr(1));
      axiSlaveRegisterR(x"000302" & "00",  0, cpixStatus.cpixCodeErr(1));
      axiSlaveRegisterR(x"000303" & "00",  0, cpixStatus.cpixTimeoutErr(1));
      axiSlaveRegisterW(x"000304" & "00",  0, v.cpixRegOut.doutResync(1));
      axiSlaveRegisterW(x"000305" & "00",  0, v.cpixRegOut.doutDelay(1));
      axiSlaveRegisterR(x"000306" & "00",  0, cpixStatus.cpixFramesGood(1));
      
      -- keep addresses x"000400" and x"000500" for future ASICs
      
      axiSlaveDefault(AXI_RESP_OK_C);
      
      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      --------------------------
      -- Outputs 
      --------------------------
      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      cpixConfig     <= r.cpixRegOut;
      
   end process comb;
   
   

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
