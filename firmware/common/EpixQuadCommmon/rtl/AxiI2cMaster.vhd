-------------------------------------------------------------------------------
-- File       : AxiI2cMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-23
-- Last update: 2018-08-27
-------------------------------------------------------------------------------
-- Description: Maps a number of I2C devices on an I2C bus onto an AXI Bus.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.I2cPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiI2cMaster is

   generic (
      TPD_G             : time   := 1 ns;
      I2C_SCL_FREQ_G    : real   := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G   : real   := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G    : real   := 156.25E+6    -- units of Hz
   );
   port (
      axiClk            : in sl;
      axiRst            : in sl;
      axiReadMaster     : in  AxiLiteReadMasterType;
      axiReadSlave      : out AxiLiteReadSlaveType;
      axiWriteMaster    : in  AxiLiteWriteMasterType;
      axiWriteSlave     : out AxiLiteWriteSlaveType;
      -- I2C Ports
      scl               : inout sl;
      sda               : inout sl
   );

end entity AxiI2cMaster;

architecture rtl of AxiI2cMaster is
   
   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   type RegType is record
      axiReadSlave   : AxiLiteReadSlaveType;
      axiWriteSlave  : AxiLiteWriteSlaveType;
      i2cRegMasterIn : I2cRegMasterInType;
      regRdData      : slv(31 downto 0);
      regFail        : sl;
      regFailCode    : slv(7 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      i2cRegMasterIn => I2C_REG_MASTER_IN_INIT_C,
      regRdData      => (others=>'0'),
      regFail        => '0',
      regFailCode    => (others=>'0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal i2cRegMasterIn  : I2cRegMasterInType;
   signal i2cRegMasterOut : I2cRegMasterOutType;
   
   signal i2ci : i2c_in_type;
   signal i2co : i2c_out_type;

begin

   -------------------------------------------------------------------------------------------------
   -- Main Comb Process
   -------------------------------------------------------------------------------------------------
   comb : process (axiReadMaster, axiRst, axiWriteMaster, i2cRegMasterOut, r) is
      variable v         : RegType;
      variable regCon    : AxiLiteEndPointType;
   begin
      v := r;
      
      -- clear request flag and store data if read op
      if (i2cRegMasterOut.regAck = '1' and r.i2cRegMasterIn.regReq = '1') then
         v.i2cRegMasterIn.regReq := '0';
         if (r.i2cRegMasterIn.regOp = '0') then
            v.regRdData := i2cRegMasterOut.regRdData;
         end if;
         if (i2cRegMasterOut.regFail = '1') then
            v.regFailCode := i2cRegMasterOut.regFailCode;
            v.regFail     := i2cRegMasterOut.regFail;
         else
            v.regFailCode := (others=>'0');
            v.regFail     := '0';
         end if;
      end if;
      
      ------------------------------------------------------------------------------------------------
      -- Register access
      ------------------------------------------------------------------------------------------------
      
      -- Determine the AXI-Lite transaction
      v.axiReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.i2cRegMasterIn.i2cAddr);
      axiSlaveRegister (regCon, x"004", 0, v.i2cRegMasterIn.tenbit);
      axiSlaveRegister (regCon, x"008", 0, v.i2cRegMasterIn.regAddr);
      axiSlaveRegister (regCon, x"00C", 0, v.i2cRegMasterIn.regWrData);
      axiSlaveRegister (regCon, x"010", 0, v.i2cRegMasterIn.regAddrSize);
      axiSlaveRegister (regCon, x"014", 0, v.i2cRegMasterIn.regAddrSkip);
      axiSlaveRegister (regCon, x"018", 0, v.i2cRegMasterIn.regDataSize);
      axiSlaveRegister (regCon, x"01C", 0, v.i2cRegMasterIn.endianness);
      axiSlaveRegister (regCon, x"020", 0, v.i2cRegMasterIn.repeatStart);
      axiSlaveRegister (regCon, x"024", 0, v.i2cRegMasterIn.regOp);
      axiSlaveRegister (regCon, x"028", 0, v.i2cRegMasterIn.regReq);
      axiSlaveRegisterR(regCon, x"02C", 0, r.regRdData);
      axiSlaveRegisterR(regCon, x"030", 0, r.regFail);
      axiSlaveRegisterR(regCon, x"034", 0, r.regFailCode);
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_RESP_DECERR_C);
      

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v               := REG_INIT_C;
      end if;

      rin <= v;

      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      i2cRegMasterIn <= r.i2cRegMasterIn;

   end process comb;

   -------------------------------------------------------------------------------------------------
   -- Sequential Process
   -------------------------------------------------------------------------------------------------
   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   -------------------------------------------------------------------------------------------------
   -- I2cRegMaster
   -------------------------------------------------------------------------------------------------
   
   I2cRegMaster_Inst : entity work.I2cRegMaster
      generic map(
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => FILTER_C,
         PRESCALE_G           => PRESCALE_C)
      port map (
         -- I2C Port Interface
         i2ci   => i2ci,
         i2co   => i2co,
         -- I2C Register Interface
         regIn  => i2cRegMasterIn,
         regOut => i2cRegMasterOut,
         -- Clock and Reset
         clk    => axiClk,
         srst   => axiRst);

   IOBUF_SCL : IOBUF
      port map (
         O  => i2ci.scl,                -- Buffer output
         IO => scl,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.scl,                -- Buffer input
         T  => i2co.scloen);            -- 3-state enable input, high=input, low=output  

   IOBUF_SDA : IOBUF
      port map (
         O  => i2ci.sda,                -- Buffer output
         IO => sda,                     -- Buffer inout port (connect directly to top-level port)
         I  => i2co.sda,                -- Buffer input
         T  => i2co.sdaoen);            -- 3-state enable input, high=input, low=output  

end architecture rtl;

