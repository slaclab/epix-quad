-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RegControlTixel.vhd
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
-- Description: Tixel register controller
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TixelPkg.all;

library unisim;
use unisim.vcomponents.all;

entity RegControlTixel is
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
      tixelStatus     : in  TixelStatusType;
      tixelConfig     : out TixelConfigType
   );
end RegControlTixel;

architecture rtl of RegControlTixel is
   
   type RegType is record
      tixelRegOut     : TixelConfigType;
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      tixelRegOut     => TIXEL_CONFIG_INIT_C,
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
      axiSlaveRegisterW(x"000000" & "00",  0, v.tixelRegOut.tixelRunToR0 );
      axiSlaveRegisterW(x"000001" & "00",  0, v.tixelRegOut.tixelR0ToStart  );
      axiSlaveRegisterW(x"000002" & "00",  0, v.tixelRegOut.tixelStartToTpulse );
      axiSlaveRegisterW(x"000003" & "00",  0, v.tixelRegOut.tixelTpulseToAcq );
      axiSlaveRegisterW(x"000004" & "00",  0, v.tixelRegOut.tixelSyncMode );
      axiSlaveRegisterW(x"000005" & "00",  0, v.tixelRegOut.tixelReadouts );
      
      axiSlaveRegisterW(x"000009" & "00",  0, v.tixelRegOut.tixelAsicPinControl );
      axiSlaveRegisterW(x"00000A" & "00",  0, v.tixelRegOut.tixelAsicPins );
      
      axiSlaveRegisterW(x"000100" & "00",  0, v.tixelRegOut.tixelErrorRst );
      axiSlaveRegisterW(x"000101" & "00",  0, v.tixelRegOut.forceFrameRead );
      
      axiSlaveRegisterR(x"000200" & "00",  0, tixelStatus.tixelAsicInSync(0));
      axiSlaveRegisterR(x"000201" & "00",  0, tixelStatus.tixelFrameErr(0));
      axiSlaveRegisterR(x"000202" & "00",  0, tixelStatus.tixelCodeErr(0));
      axiSlaveRegisterR(x"000203" & "00",  0, tixelStatus.tixelTimeoutErr(0));
      axiSlaveRegisterW(x"000204" & "00",  0, v.tixelRegOut.doutResync(0));
      axiSlaveRegisterW(x"000205" & "00",  0, v.tixelRegOut.doutDelay(0));
      axiSlaveRegisterR(x"000206" & "00",  0, tixelStatus.tixelFramesGood(0));
      
      axiSlaveRegisterR(x"000300" & "00",  0, tixelStatus.tixelAsicInSync(1));
      axiSlaveRegisterR(x"000301" & "00",  0, tixelStatus.tixelFrameErr(1));
      axiSlaveRegisterR(x"000302" & "00",  0, tixelStatus.tixelCodeErr(1));
      axiSlaveRegisterR(x"000303" & "00",  0, tixelStatus.tixelTimeoutErr(1));
      axiSlaveRegisterW(x"000304" & "00",  0, v.tixelRegOut.doutResync(1));
      axiSlaveRegisterW(x"000305" & "00",  0, v.tixelRegOut.doutDelay(1));
      axiSlaveRegisterR(x"000306" & "00",  0, tixelStatus.tixelFramesGood(1));
      
      axiSlaveRegisterW(x"000400" & "00",  0, v.tixelRegOut.tixelDebug);
      
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
      tixelConfig     <= r.tixelRegOut;
      
   end process comb;
   
   

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
