-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RegExtControl.vhd
-- Author     : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created    : 07/21/2016
-- Last update: 07/21/2016
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 07/21/2016: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

use work.EpixPkgGen2.all;

library unisim;
use unisim.vcomponents.all;

entity RegExtControl is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_OK_C);
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
      epixConfigExt  : out EpixConfigExtType
   );
end RegExtControl;

architecture rtl of RegExtControl is
   
   type RegType is record
      epixRegOut     : EpixConfigExtType;
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      epixRegOut     => EPIX_CONFIG_EXT_INIT_C,
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
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
      
   begin
      -- Latch the current value
      v := r;   
      
      -- Reset data
      v.axiReadSlave.rdata       := (others => '0');
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      -- Map out standard registers    
      axiSlaveRegister (regCon, x"000" & "00",  0, v.epixRegOut.ghostCorr);
      
      axiSlaveRegister (regCon, x"200" & "00",  0, v.epixRegOut.dbgReg);
      
      axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);
      
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
      epixConfigExt  <= r.epixRegOut;
      
   end process comb;
   
   

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
