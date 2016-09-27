-------------------------------------------------------------------------------
-- Title      : Testbench for design "AcquisitionControl"
-------------------------------------------------------------------------------
-- File       : AcquisitionControlTb.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-21
-- Last update: 2016-09-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

----------------------------------------------------------------------------------------------------

entity AcquisitionControlTb is

end entity AcquisitionControlTb;

----------------------------------------------------------------------------------------------------

architecture tb of AcquisitionControlTb is

   -- component generics
   constant TPD_G            : time            := 1 ns;
   constant AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;

   -- component ports
   signal axilClk         : sl;                                                      -- [in]
   signal axilRst         : sl;                                                      -- [in]
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;   -- [in]
   signal axilReadSlave   : AxiLiteReadSlaveType;                                    -- [out]
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;  -- [in]
   signal axilWriteSlave  : AxiLiteWriteSlaveType;                                   -- [out]
   signal clk250          : sl;                                                      -- [in]
   signal rst250          : sl;                                                      -- [in]
   signal trigger         : sl;
   signal elineRst        : sl;                                                      -- [out]
   signal elineSc         : sl;                                                      -- [out]
   signal elineMck        : sl;                                                      -- [out]
   signal adcValid        : sl;                                                      -- [out]
   signal adcDone         : sl;                                                      -- [out]
   signal adcClk          : sl;                                                      -- [out]
   signal adcClkRst       : sl;                                                      -- [out]

begin

   -- component instantiation
   U_AcquisitionControl: entity work.AcquisitionControl
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         axilReadMaster  => axilReadMaster,   -- [in]
         axilReadSlave   => axilReadSlave,    -- [out]
         axilWriteMaster => axilWriteMaster,  -- [in]
         axilWriteSlave  => axilWriteSlave,   -- [out]
         clk250          => clk250,           -- [in]
         rst250          => rst250,           -- [in]
         trigger         => trigger,
         elineRst        => elineRst,         -- [out]
         elineSc         => elineSc,          -- [out]
         elineMck        => elineMck,         -- [out]
         adcValid        => adcValid,         -- [out]
         adcDone         => adcDone,          -- [out]
         adcClk          => adcClk,           -- [out]
         adcClkRst       => adcClkRst);       -- [out]

   
   U_ClkRst_AXIL : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => axilClk,
         rst  => axilRst);
   
   U_ClkRst_250 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk250,
         rst  => rst250);

   U_ClkRst_trig : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 10 us,
         RST_HOLD_TIME_G   => 50 ns,
         SYNC_RESET_G      => true)
      port map (
         rst  => trigger);
   
   
end architecture tb;

----------------------------------------------------------------------------------------------------
