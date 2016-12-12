-------------------------------------------------------------------------------
-- Title      : ReadoutControl
-------------------------------------------------------------------------------
-- File       : ReadoutControl.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-22
-- Last update: 2016-12-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Filters incomming ADC data from multiple channels and builds
-- event frames.
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'EPIX Development Firmware', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.AcquisitionControlPkg.all;
use work.CoulterPkg.all;

entity ReadoutControl is

   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input stream
      adcStreamClk : in sl;
      adcStreamRst : in sl;
      adcStreams   : in AxiStreamMasterArray(11 downto 0);

      distClk     : in sl;
      distRst     : in sl;
      distTrigger : in sl;

      clk            : in  sl;
      rst            : in  sl;
      acqStatus      : in  AcquisitionStatusType;
      dataAxisMaster : out AxiStreamMasterType;
      dataAxisSlave  : in  AxiStreamSlaveType;
      dataAxisCtrl   : in  AxiStreamCtrlType);

end entity ReadoutControl;

architecture rtl of ReadoutControl is

   constant ADC_CHANNELS_C : integer := 12;

   type StateType is (WAIT_TRIGGER_S, DATA_S, TAIL_S);

   type RegType is record
      state          : StateType;
      acqCount       : slv(15 downto 0);
      slotCounts     : slv9Array(ADC_CHANNELS_C-1 downto 0);
      muxAxisSlave   : AxiStreamSlaveType;
      dataAxisMaster : AxiStreamMasterType;

   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => WAIT_TRIGGER_S,
      acqCount       => (others => '0'),
      slotCounts     => (others => (others => '0')),
      muxAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      dataAxisMaster => axiStreamMasterInit(COULTER_AXIS_CFG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal channelDone         : slv(ADC_CHANNELS_C-1 downto 0);
   signal filteredAxisMasters : AxiStreamMasterArray(11 downto 0);
   signal filteredAxisSlaves  : AxiStreamSlaveArray(11 downto 0);
   signal muxAxisMaster       : AxiStreamMasterType;
   signal triggerSync         : sl;

begin

   U_SynchronizerFifo_1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => false,
         BRAM_EN_G    => false,
         DATA_WIDTH_G => 1,
         ADDR_WIDTH_G => 4)
      port map (
         rst    => rst,                 -- [in]
         wr_clk => distClk,             -- [in]
         wr_en  => distTrigger,         -- [in]
         din(0) => '0',                 -- [in]
         rd_clk => clk,                 -- [in]
         rd_en  => '1',                 -- [in]
         valid  => triggerSync,         -- [out]
         dout   => open);               -- [out]

   -------------------------------------------------------------------------------------------------
   -- Place an adc stream filter on each stream to grab only the samples that we want
   -- based on acqStatus
   -------------------------------------------------------------------------------------------------
   AdcStreamFilterGen : for i in adcStreams'range generate
      U_AdcStreamFilter_1 : entity work.AdcStreamFilter
         generic map (
            TPD_G               => TPD_G,
            FILTERED_AXIS_CFG_G => COULTER_AXIS_CFG_C)
         port map (
            adcStreamClk       => adcStreamClk,            -- [in]
            adcStreamRst       => adcStreamRst,            -- [in]
            adcStream          => adcStreams(i),           -- [in]
            acqStatus          => acqStatus,               -- [in]                        
            clk                => clk,                     -- [in]
            rst                => rst,                     -- [in]
            filteredAxisMaster => filteredAxisMasters(i),  -- [out]
            filteredAxisSlave  => filteredAxisSlaves(i));  -- [in]
   end generate;

   U_AxiStreamMux_1 : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => ADC_CHANNELS_C,
         MODE_G        => "INDEXED",
         PIPE_STAGES_G => 1,
         ILEAVE_EN_G   => false)
      port map (
         axisClk      => clk,                  -- [in]
         axisRst      => rst,                  -- [in]
         sAxisMasters => filteredAxisMasters,  -- [in]
         sAxisSlaves  => filteredAxisSlaves,   -- [out]
         disableSel   => channelDone,          -- [in]
         mAxisMaster  => muxAxisMaster,        -- [out]
         mAxisSlave   => r.muxAxisSlave);      -- [in]

   GEN_CHANNEL_DONE : for i in 0 to ADC_CHANNELS_C-1 generate
      channelDone(i) <= r.slotCounts(i)(8);
   end generate;


   comb : process (channelDone, dataAxisCtrl, muxAxisMaster, r, rst, triggerSync) is
      variable v : RegType;
   begin
      v := r;

      v.dataAxisMaster      := axiStreamMasterInit(COULTER_AXIS_CFG_C);
      v.muxAxisSlave.tReady := '0';

      case (r.state) is
         when WAIT_TRIGGER_S =>
            -- Trigger starts an acquisition, in which there are 256 (acqCfg.scCount) slots
            v.slotCounts := (others => (others => '0'));
            if (triggerSync = '1') then
               if (dataAxisCtrl.pause = '0') then
                  v.dataAxisMaster.tValid             := '1';
                  ssiSetUserSof(COULTER_AXIS_CFG_C, v.dataAxisMaster, '1');
                  v.dataAxisMaster.tData(15 downto 0) := r.acqCount;
                  v.muxAxisSlave.tReady               := '1';
                  v.state                             := DATA_S;
               else
               -- Send special overflow error frame
               end if;
            end if;

         when DATA_S =>
            v.muxAxisSlave.tReady := '1';
            if (muxAxisMaster.tValid = '1') then
               v.dataAxisMaster.tValid             := '1';
               v.dataAxisMaster.tData(6 downto 0)  := muxAxisMaster.tDest(6 downto 0);
               v.dataAxisMaster.tData(7)           := muxAxisMaster.tLast;
               v.dataAxisMaster.tData(15 downto 8) := r.slotCounts(conv_integer(muxAxisMaster.tDest))(7 downto 0);

               -- Pack 14 bit adc samples into a wide word
               -- vivado is going to shit the bed with this
               for i in 0 to 7 loop
                  for j in 0 to 13 loop
                     v.dataAxisMaster.tData(16+(i*14)+j) := muxAxisMaster.tData((i*16)+j);
                  end loop;
--                   v.dataAxisMaster.tData(16+13+(i*14) downto 16+(i*14)) :=
--                      muxAxisMaster.tData((i*16)+13 downto i*16);
               end loop;

               v.slotCounts(conv_integer(muxAxisMaster.tDest)) :=
                  r.slotCounts(conv_integer(muxAxisMaster.tDest)) + muxAxisMaster.tLast;

            end if;

            if (uAnd(channelDone) = '1') then
               v.state := TAIL_S;
            end if;

         when TAIL_S =>
            v.acqCount              := r.acqCount + 1;
            v.dataAxisMaster.tValid := '1';
            v.dataAxisMaster.tData  := (others => '0');
            v.dataAxisMaster.tLast  := '1';
            v.state                 := WAIT_TRIGGER_S;
      end case;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin            <= v;
      dataAxisMaster <= r.dataAxisMaster;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
