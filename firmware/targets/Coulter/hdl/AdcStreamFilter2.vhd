-------------------------------------------------------------------------------
-- Title      : AdcStreamFilter2
-------------------------------------------------------------------------------
-- File       : AdcStreamFilter2.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-22
-- Last update: 2017-03-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Filters samples out of an ADC stream based on direction from
-- an AcquisitionControl block.
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
use work.AxiLitePkg.all;
use work.Ad9249Pkg.all;

use work.AcquisitionControlPkg.all;

entity AdcStreamFilter2 is

   generic (
      TPD_G               : time                := 1 ns;
      FILTERED_AXIS_CFG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      distClk : in sl;

      -- Input stream
      adcStreamClk : in sl;
      adcStreamRst : in sl;
      adcStream    : in AxiStreamMasterType;
      acqStatus    : in AcquisitionStatusType;

      -- Axi bus synced to ADC stream clock
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;


      -- Main clock and reset
      clk                : in  sl;
      rst                : in  sl;
      -- Filtered (and buffered) output stream  
      filteredAxisMaster : out AxiStreamMasterType;
      filteredAxisSlave  : in  AxiStreamSlaveType);

end entity AdcStreamFilter2;

architecture rtl of AdcStreamFilter2 is

   type StateType is (WAIT_SC_FALL_S, WAIT_NON_ZERO_S, ADC_CAPTURE_S);

   type RegType is record
      state          : StateType;
      count          : slv(31 downto 0);
      scFallCount    : slv(31 downto 0);
      mckCount       : slv(7 downto 0);
      capture        : sl;
      filteredAxis   : AxiStreamMasterType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => WAIT_SC_FALL_S,
      count          => (others => '0'),
      scFallCount    => (others => '0'),
      mckCount       => (others => '0'),
      capture        => '1',
      filteredAxis   => AXI_STREAM_MASTER_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal cfgMckCount : slv(7 downto 0);
   signal scFall      : sl;


begin

   U_SynchronizerVector_1 : entity work.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 2,
         WIDTH_G  => 8)
      port map (
         clk     => adcStreamClk,           -- [in]
         rst     => adcStreamRst,           -- [in]
         dataIn  => acqStatus.cfgMckCount,  -- [in]
         dataOut => cfgMckCount);           -- [out]

   U_SynchronizerFifo_1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => false,
         DATA_WIDTH_G => 1,
         ADDR_WIDTH_G => 4)
      port map (
         rst    => '0',                 -- [in]
         wr_clk => distClk,             -- [in]
         wr_en  => acqStatus.scFall,    -- [in]
         din(0) => acqStatus.scFall,    -- [in]
         rd_clk => adcStreamClk,        -- [in]
         rd_en  => '1',                 -- [in]
         valid  => scFall,              -- [out]
         dout   => open);               -- [out]


   comb : process (adcStream, adcStreamRst, axilReadMaster, axilWriteMaster, cfgMckCount, r, scFall) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable state  : slv(2 downto 0);
   begin
      v := r;

      if (scFall = '1') then
         v.scFallCount := r.scFallCount + 1;
      end if;

      v.filteredAxis.tValid := '0';
      v.filteredAxis.tData  := adcStream.tData;
      v.filteredAxis.tLast  := '0';

      case r.state is
         when WAIT_SC_FALL_S =>
            state                 := "001";
            v.mckCount            := (others => '0');
            v.count(31 downto 24) := X"55";
            if (scFall = '1') then
               v.count := (others => '0');
               v.state := WAIT_NON_ZERO_S;
            end if;

         when WAIT_NON_ZERO_S =>
            state                 := "010";
            v.mckCount            := (others => '0');
            v.count               := r.count + 1;
            v.count(31 downto 24) := X"AA";

            if (adcStream.tValid = '1' and adcStream.tData(15 downto 0) /= X"2000") then
               v.state   := ADC_CAPTURE_S;
               v.capture := '1';
            end if;

         when ADC_CAPTURE_S =>
            state := "100";
            if (adcStream.tValid = '1') then
               v.filteredAxis.tValid := r.capture;
               v.capture             := not r.capture;

               if (r.capture = '1') then
                  v.mckCount := r.mckCount + 1;
               end if;

               if (r.mckCount = cfgMckCount-1 and r.capture = '1') then
                  v.filteredAxis.tLast := '1';
                  v.state              := WAIT_SC_FALL_S;
               end if;
            end if;

      end case;

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
      axiSlaveRegisterR(axilEp, X"00", 0, r.count);
      axiSlaveRegisterR(axilEp, X"04", 0, state);
      axiSlaveRegisterR(axilEp, X"08", 0, r.scFallCount);
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);


      if (adcStreamRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

   end process comb;

   seq : process (adcStreamClk) is
   begin
      if (rising_edge(adcStreamClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_AxiStreamFifoV2_1 : entity work.AxiStreamFifoV2
      generic map (
         TPD_G                  => TPD_G,
         INT_PIPE_STAGES_G      => 0,
         PIPE_STAGES_G          => 1,
         SLAVE_READY_EN_G       => true,
         VALID_THOLD_G          => 0,
         BRAM_EN_G              => false,
         XIL_DEVICE_G           => "7Series",
         USE_BUILT_IN_G         => false,
         GEN_SYNC_FIFO_G        => false,
         FIFO_ADDR_WIDTH_G      => 5,
         INT_WIDTH_SELECT_G     => "WIDE",
         LAST_FIFO_ADDR_WIDTH_G => 0,
         SLAVE_AXI_CONFIG_G     => AD9249_AXIS_CFG_G,
         MASTER_AXI_CONFIG_G    => FILTERED_AXIS_CFG_G)
      port map (
         sAxisClk    => adcStreamClk,        -- [in]
         sAxisRst    => adcStreamRst,        -- [in]
         sAxisMaster => r.filteredAxis,      -- [in]
         sAxisSlave  => open,                -- [out]
         sAxisCtrl   => open,                -- [out]
         mAxisClk    => clk,                 -- [in]
         mAxisRst    => rst,                 -- [in]
         mAxisMaster => filteredAxisMaster,  -- [out]
         mAxisSlave  => filteredAxisSlave);  -- [in]

end architecture rtl;
