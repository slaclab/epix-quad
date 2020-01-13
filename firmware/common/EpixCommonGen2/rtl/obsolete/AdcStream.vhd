-------------------------------------------------------------------------------
-- File       : AdcStream.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Dumps ADC data to streaming link.
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
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AdcStream is
   generic (
      TPD_G                      : time := 1 ns;
      -- AXI Stream Configurations
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType        := ssiAxiStreamConfig(4, TKEEP_COMP_C)
   );
   port (
      -- Master Port (mAxisClk)
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType;
      -- Trigger Signal (locClk domain)
      locClk       : in  sl;
      locRst       : in  sl;
      trig         : in  sl;
      packetLength : in  slv(31 downto 0) := X"FFFFFFFF";
      readoutCh    : in  slv( 4 downto 0) := (others => '0');
      -- Data in
      adcValid     : in  slv(19 downto 0);
      adcData      : in  Slv16Array(19 downto 0)
   );
end AdcStream;

architecture rtl of AdcStream is
   
   type StateType is (
      IDLE_S,
      LENGTH_S,
      DATA_S);  

   type RegType is record
      busy         : sl;
      packetLength : slv(31 downto 0);
      dataCnt      : slv(31 downto 0);
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      '1',
      (others => '0'),
      (others => '0'),
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txCtrl : AxiStreamCtrlType;
   
   attribute dont_touch : string;
   attribute dont_touch of r : signal is "true";
   
begin

   comb : process (r, trig, adcValid, adcData, packetLength, readoutCh) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.txMaster);
      v.txMaster.tData := (others => '0');


      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the busy flag
            v.busy := '0';
            -- Check for a trigger
            if trig = '1' then
               -- Set the busy flag
               v.busy           := '1';
               -- Check the packet length request value
               if packetLength = 0 then
                  -- Force minimum packet length of 2 (+1)
                  v.packetLength := toSlv(2, 32);
               elsif packetLength = 1 then
                  -- Force minimum packet length of 2 (+1)
                  v.packetLength := toSlv(2, 32);
               else
                  -- Latch the packet length
                  v.packetLength := packetLength;
               end if;
               -- Next State
               v.state := LENGTH_S;
            end if;
         ----------------------------------------------------------------------
         when LENGTH_S =>
            -- Check if the FIFO is ready
            if txCtrl.pause = '0' then
               -- Set the SOF bit
               ssiSetUserSof(MASTER_AXI_STREAM_CONFIG_G, v.txMaster, '1');
               -- Send the upper packetLength value
               v.txMaster.tvalid             := '1';
               v.txMaster.tData(31 downto 0) := r.packetLength;
               -- Increment the counter
               v.dataCnt                     := r.dataCnt + 1;
               -- Next State
               v.state                       := DATA_S;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if the FIFO is ready
            if txCtrl.pause = '0' and adcValid(conv_integer(readoutCh)) = '1' then
               -- Send the ADC data word
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := x"0000" & adcData(conv_integer(readoutCh));
               -- Increment the counter
               v.dataCnt                     := r.dataCnt + 1;
               -- Check the counter
               if r.dataCnt = r.packetLength then
                  -- Reset the counter
                  v.dataCnt        := (others => '0');
                  -- Set the EOF bit                
                  v.txMaster.tLast := '1';
                  -- Reset the busy flag
                  v.busy           := '0';
                  -- Next State
                  v.state          := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (locRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      -- busy <= r.busy;
      mAxisMaster <= r.txMaster;
      
   end process comb;

   seq : process (locClk) is
   begin
      if rising_edge(locClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
