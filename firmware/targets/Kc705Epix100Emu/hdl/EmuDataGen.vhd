-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EmuDataGen.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-01-25
-- Last update: 2017-01-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'Example Project Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Example Project Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity EmuDataGen is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- Trigger Interface
      opCodeEn : in  sl;
      opCode   : in  slv(7 downto 0);
      -- Streaming Interface
      txMaster : out AxiStreamMasterType;
      txSlave  : in  AxiStreamSlaveType);
end EmuDataGen;

architecture rtl of EmuDataGen is

   constant MAX_CNT_C    : natural             := 272650;  -- (1090604/4)-1
   constant AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);

   -- Hard coded words in the data stream for now
   constant LANE_C     : slv(1 downto 0)  := "00";
   constant VC_C       : slv(1 downto 0)  := "00";
   constant QUAD_C     : slv(1 downto 0)  := "00";
   constant ZEROWORD_C : slv(31 downto 0) := x"00000000";

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      opCnt    : slv(31 downto 0);
      opCode   : slv(7 downto 0);
      cnt      : natural range 0 to (MAX_CNT_C+1);
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      opCnt    => (others => '0'),
      opCode   => x"00",
      cnt      => 0,
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (opCode, opCodeEn, r, rst, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for trigger
            if (opCodeEn = '1') then
               -- Save the OP-code value
               v.opCode := opCode;
               -- Next state
               v.state  := MOVE_S;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if ready to move data
            if (v.txMaster.tValid = '0') then
               -- Write the data 
               v.txMaster.tValid             := '1';
               -- Reset the data bus
               v.txMaster.tData(31 downto 0) := ZEROWORD_C;
               -- Increment the counter
               v.cnt                         := r.cnt + 1;
               -- Check for first word
               if (r.cnt = 0) then
                  -- Set the SOF bit
                  ssiSetUserSof(AXI_CONFIG_G, v.txMaster, '1');
                  -- Insert the lane pointer
                  v.txMaster.tData(31 downto 0) := x"000000" & "00" & LANE_C & "00" & VC_C;
               -- Check for second word
               elsif (r.cnt = 1) then
                  -- Insert the op-code & counter
                  v.txMaster.tData(31 downto 0) := x"0" & "00" & QUAD_C & r.opCode & r.opCnt(15 downto 0);
               -- Check for thridd word
               elsif (r.cnt = 2) then
                  -- Insert the counter
                  v.txMaster.tData(31 downto 0) := r.opCnt(31 downto 0);
               -- Check for last word
               elsif (r.cnt = MAX_CNT_C) then
                  -- Reset the counter
                  v.cnt            := 0;
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Increment the counter
                  v.opCnt          := r.opCnt + 1;
                  -- Next state
                  v.state          := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs              
      txMaster <= r.txMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
