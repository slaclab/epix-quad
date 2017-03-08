-------------------------------------------------------------------------------
-- Title      : AdcStreamFilter
-------------------------------------------------------------------------------
-- File       : AdcStreamFilter.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-22
-- Last update: 2017-03-08
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
use work.Ad9249Pkg.all;

use work.AcquisitionControlPkg.all;

entity AdcStreamFilter is

   generic (
      TPD_G               : time                := 1 ns;
      FILTERED_AXIS_CFG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Input stream
      adcStreamClk : in sl;
      adcStreamRst : in sl;
      adcStream    : in AxiStreamMasterType;
      acqStatus    : in AcquisitionStatusType;

      -- Main clock and reset
      clk                : in  sl;
      rst                : in  sl;
      -- Filtered (and buffered) output stream
      filteredAxisMaster : out AxiStreamMasterType;
      filteredAxisSlave  : in  AxiStreamSlaveType);

end entity AdcStreamFilter;

architecture rtl of AdcStreamFilter is

   type RegType is record
      capture      : sl;
      filteredAxis : AxiStreamMasterType;
      count        : slv(7 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      capture      => '1',
      filteredAxis => AXI_STREAM_MASTER_INIT_C,
      count        => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal adcWindowSync : sl;

begin

   U_Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => adcStreamClk,         -- [in]
         rst     => adcStreamRst,         -- [in]
         dataIn  => acqStatus.adcWindow,  -- [in]
         dataOut => adcWindowSync);       -- [out]

   comb : process (acqStatus, adcStream, adcStreamRst, adcWindowSync, r) is
      variable v : RegType;
   begin
      v := r;

      v.filteredAxis.tValid := '0';
      v.filteredAxis.tData  := adcStream.tData;
      v.filteredAxis.tLast  := toSl(r.count = acqStatus.cfgMckCount-1);

      if (adcWindowSync = '0') then
         v.capture := '1';
      end if;

      -- Filter every other sample when acqStatus.adcWindow = '1'
      if (adcWindowSync = '1' and adcStream.tvalid = '1') then
         v.filteredAxis.tValid := r.capture;
         v.capture             := not r.capture;

         if (r.capture = '1') then
            v.count := r.count + 1;
            if (r.count = acqStatus.cfgMckCount-1) then
               v.count := (others => '0');
            end if;
         end if;
      end if;

      if (adcStreamRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

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
