-------------------------------------------------------------------------------
-- Title      : AdcStreamFilter
-------------------------------------------------------------------------------
-- File       : AdcStreamFilter.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-22
-- Last update: 2016-09-22
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

entity AdcStreamFilter is

   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input stream
      adcStreamClk : in sl;
      adcStreamRst : in sl;
      adcStream    : in AxiStreamMasterType;

      -- Acquisition timing signals
      acqStatus : in AcquisitionStatusType;

      -- Filtered (and buffered) output stream
      filteredStreamClk    : in  sl;
      filteredStreamRst    : in  sl;
      filteredStreamMaster : out AxiStreamMasterType;
      filteredStreamSlave  : in  AxiStreamSlaveType);

end entity AdcStreamFilter;

architecture rtl of AdcStreamFilter is

begin

   comb : process (acqStatus, adcStream, adcStreamRst, r) is
      variable v : RegType;
   begin
      v := r;

      v.filteredStream.tValid := '0';
      v.filteredStream.tData  := adcStream.tData;
      v.filteredStream.tLast  := acqStatus.adcLast;

      -- Filter every other sample when acqStatus.adcWindow = '1'
      if (acqStatus.adcWindow = '1' and adcStream.tvalid = '1') then
         v.filteredStream.tValid := r.capture;
         v.capture               := not r.capture;
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
         VALID_THOLD_G          => 1,
         BRAM_EN_G              => false,
         XIL_DEVICE_G           => "7Series",
         USE_BUILT_IN_G         => false,
         GEN_SYNC_FIFO_G        => false,
         FIFO_ADDR_WIDTH_G      => 5,
         INT_WIDTH_SELECT_G     => "WIDE"
         LAST_FIFO_ADDR_WIDTH_G => 0,
         SLAVE_AXI_CONFIG_G     => AD9249_AXIS_CFG_G,
         MASTER_AXI_CONFIG_G    => AD9249_AXIS_CFG_G)
      port map (
         sAxisClk    => adcStreamClk,          -- [in]
         sAxisRst    => adcStreamRst,          -- [in]
         sAxisMaster => r.filteredStream,      -- [in]
         sAxisSlave  => open,                  -- [out]
         sAxisCtrl   => open,                  -- [out]
         mAxisClk    => filteredStreamClk,     -- [in]
         mAxisRst    => filteredStreamRst,     -- [in]
         mAxisMaster => filteredStreamMaster,  -- [out]
         mAxisSlave  => filteredStreamSlave);  -- [in]

end architecture rtl;
