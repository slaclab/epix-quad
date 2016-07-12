-------------------------------------------------------------------------------
-- Title      : Coulter Acquisition Control
-------------------------------------------------------------------------------
-- File       : AcquisitionControl.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-31
-- Last update: 2016-06-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Controls ASIC clocking for the ELINE100 ASIC.
-------------------------------------------------------------------------------
-- This file is part of Coulter. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of Coulter, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity AcquisitionControl is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (

      -- AXI-Lite Interface for configuration
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- 250 Mhz reference clock
      clk250 : in sl;
      rst250 : in sl;

      -- Incoming command
      trigger : sl;

      -- ASIC Outputs
      elineRst : out sl;
      elineSc  : out sl;
      elineMck : out sl;

      bla : out slv(31 downto 0);

      -- ADC 
      adcValid   : out sl;
      adcValid20 : out sl;
      adcValid0  : out sl;
      adcDone    : out sl;
      adcClk     : out sl;
      adcClkRst  : out sl);

end AcquisitionControl;


-- Define architecture
architecture rtl of AcquisitionControl is

   type StateType is (WAIT_TRIGGER_S, WAIT_SC_FALL_S, COUNT_MCK_S);

   type RegType is record
      -- AXIL output buses
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

      -- AXIL config registers
      scDelay        : slv(15 downto 0);  -- delay between trigger and SC rise
      scPosWidth     : slv(15 downto 0);  -- sc high time
      scNegWidth     : slv(15 downto 0);  -- sc low time
      scCount        : slv(11 downto 0);  -- Number of slots in acquisition
      mckDelay       : slv(15 downto 0);  -- delay between sc fall and mck start
      mckPosWidth    : slv(15 downto 0);  -- mck high time
      mckNegWidth    : slv(15 downto 0);  -- mck low time
      mckCount       : slv(7 downto 0);   -- Number of MCK pulses per slot
      adcClkPosWidth : slv(15 downto 0);  -- Adc clock high time
      adcClkNegWidth : slv(15 downto 0);  -- Adc clock high time      
      adcClkDelay    : slv(15 downto 0);  -- Delay time between trigger and new rising edge of ADC clk
      adcValidDelay  : slv(9 downto 0);   -- Delay between mck start and adc sample capture
      mckDisable     : sl;              -- Disable mck (is this necessary?)
      clkDisable     : sl;              -- Master clock disable (sc, mck, adcClk)

      -- Local registers
      state          : StateType;
      scRst          : sl;
      scLast         : sl;
      scFallCounter  : slv(11 downto 0);
      mckRst         : sl;
      mckLast        : sl;
      mckFallCounter : slv(7 downto 0);
      adcClkRst      : sl;
      adcValid       : sl;
      adcValidStb    : sl;
      adcDone        : sl;
      bla            : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      scDelay        => (others => '0'),
      scPosWidth     => (others => '0'),
      scNegWidth     => (others => '0'),
      scCount        => (others => '0'),
      mckDelay       => (others => '0'),
      mckPosWidth    => (others => '0'),
      mckNegWidth    => (others => '0'),
      mckCount       => (others => '0'),
      adcClkPosWidth => (others => '0'),
      adcClkNegWidth => (others => '0'),
      adcClkDelay    => (others => '0'),
      adcValidDelay  => (others => '0'),
      mckDisable     => '0',
      clkDisable     => '0',
      state          => WAIT_TRIGGER_S,
      scRst          => '0',
      scLast         => '0',
      scFallCounter  => (others => '0'),
      mckRst         => '0',
      mckLast        => '0',
      mckFallCounter => (others => '0'),
      adcClkRst      => '0',
      adcValid       => '0',
      adcValidStb    => '0',
      adcDone        => '0',
      bla            => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal locAxilReadMaster  : AxiLiteReadMasterTYpe;
   signal locAxilReadSlave   : AxiLiteReadSlaveType;
   signal locAxilWriteMaster : AxiLiteWriteMasterTYpe;
   signal locAxilWriteSlave  : AxiLiteWriteSlaveType;

   signal triggerRise : sl;
   signal iSc         : sl;
   signal iMck        : sl;
   signal iAdcClk     : sl;
   signal iAdcValid   : sl;

begin

   -- Synchronize the Axi lite bus to 250 Mhz clock
   U_AxiLiteAsync_1 : entity work.AxiLiteAsync
      generic map (
         TPD_G => TPD_G)
      port map (
         sAxiClk         => axilClk,             -- [in]
         sAxiClkRst      => axilRst,             -- [in]
         sAxiReadMaster  => axilReadMaster,      -- [in]
         sAxiReadSlave   => axilReadSlave,       -- [out]
         sAxiWriteMaster => axilWriteMaster,     -- [in]
         sAxiWriteSlave  => axilWriteSlave,      -- [out]
         mAxiClk         => clk250,              -- [in]
         mAxiClkRst      => rst250,              -- [in]
         mAxiReadMaster  => locAxilReadMaster,   -- [out]
         mAxiReadSlave   => r.axilReadSlave,     -- [in]
         mAxiWriteMaster => locAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => r.axilWriteSlave);   -- [in]

   -- Synchronize trigger to clk250
   U_SynchronizerEdge_1 : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => clk250,         -- [in]
         rst         => rst250,         -- [in]
         dataIn      => trigger,        -- [in]
         dataOut     => open,           -- [out]
         risingEdge  => triggerRise,    -- [out]
         fallingEdge => open);          -- [out]

   U_ClockDivider_SC : entity work.ClockDivider
      generic map (
         TPD_G => TPD_G)
      port map (
         clk        => clk250,          -- [in]
         rst        => r.scRst,         -- [in]
         highCount  => r.scPosWidth,    -- [in]
         lowCount   => r.scNegWidth,    -- [in]
         delayCount => r.scDelay,       -- [in]
         divClk     => iSc);            -- [out]


   U_ClockDivider_MCK : entity work.ClockDivider
      generic map (
         TPD_G => TPD_G)
      port map (
         clk        => clk250,          -- [in]
         rst        => r.mckRst,        -- [in]
         highCount  => r.mckPosWidth,   -- [in]
         lowCount   => r.mckNegWidth,   -- [in]
         delayCount => r.mckDelay,      -- [in]
         divClk     => iMck);           -- [out]

   U_ClockDivider_ADCCLK : entity work.ClockDivider
      generic map (
         TPD_G => TPD_G)
      port map (
         clk        => clk250,            -- [in]
         rst        => r.adcClkRst,       -- [in]
         highCount  => r.adcClkPosWidth,  -- [in]
         lowCount   => r.adcClkNegWidth,  -- [in]
         delayCount => r.adcClkDelay,     -- [in]
         divClk     => iAdcClk);          -- [out]

--    U_FifoDelay_AdcValid : entity work.FifoDelay
--       generic map (
--          TPD_G             => TPD_G,
--          DATA_WIDTH_G      => 1,
--          BRAM_EN_G         => false,
--          FIFO_ADDR_WIDTH_G => 4)
--       port map (
--          clk     => clk250,             -- [in]
--          rst     => rst250,             -- [in]
--          din(0)  => r.adcValid,         -- [in]
--          wrEn    => r.adcValidToggle,   -- [in]
--          delay   => r.adcValidDelay,    -- [in]
--          dout(0) => iAdcValid,          -- [out]
--          valid   => open);              -- [out]

   U_SlvDelay_1 : entity work.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         REG_OUTPUT_G => true,
         DELAY_G      => 1024,
         WIDTH_G      => 1)
      port map (
         clk     => clk250,             -- [in]
         delay   => r.adcValidDelay,    -- [in]
         din(0)  => r.adcValid,         -- [in]
         dout(0) => iAdcValid);         -- [out]

   U_SlvDelay_20 : entity work.SlvDelay
      generic map (
         TPD_G    => TPD_G,
         SRL_EN_G => false,
         DELAY_G  => 20,
         WIDTH_G  => 1)
      port map (
         clk     => clk250,             -- [in]
--         delay   => r.adcValidDelay,    -- [in]
         din(0)  => r.adcValid,         -- [in]
         dout(0) => adcValid20);        -- [out]

   U_SlvDelay_0 : entity work.SlvDelay
      generic map (
         TPD_G    => TPD_G,
         SRL_EN_G => true,
         DELAY_G  => 0,
         WIDTH_G  => 1)
      port map (
         clk     => clk250,             -- [in]
--         delay   => r.adcValidDelay,    -- [in]
         din(0)  => r.adcValid,         -- [in]
         dout(0) => adcValid0);         -- [out]

   comb : process (iAdcClk, iAdcValid, iMck, iSc, locAxilReadMaster, locAxilWriteMaster, r, rst250,
                   triggerRise) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      v.bla := X"4";

      -- Declare configuration registers
      axiSlaveWaitTxn(axilEp, locAxilWriteMaster, locAxilReadMaster, v.axilWriteSlave, v.axilReadSlave);
      axiSlaveRegister(axilEp, X"00", 0, v.scDelay);
      axiSlaveRegister(axilEp, X"04", 0, v.scPosWidth);
      axiSlaveRegister(axilEp, X"08", 0, v.scNegWidth);
      axiSlaveRegister(axilEp, X"0C", 0, v.scCount);
      axiSlaveRegister(axilEp, X"10", 0, v.mckDelay);
      axiSlaveRegister(axilEp, X"14", 0, v.mckPosWidth);
      axiSlaveRegister(axilEp, X"18", 0, v.mckNegWidth);
      axiSlaveRegister(axilEp, X"1C", 0, v.mckCount);
      axiSlaveRegister(axilEp, X"20", 0, v.adcClkPosWidth);
      axiSlaveRegister(axilEp, X"24", 0, v.adcClkNegWidth);
      axiSlaveRegister(axilEp, X"28", 0, v.adcClkDelay);
      axiSlaveRegister(axilEp, X"2C", 0, v.adcValidDelay);
      axiSlaveRegister(axilEp, X"30", 0, v.mckDisable);
      axiSlaveRegister(axilEp, X"34", 0, v.clkDisable);
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      v.adcDone     := '0';
      v.adcClkRst   := '0';
      v.scLast      := iSc;
      v.mckLast     := iMck;
      v.adcValidStb := '0';

      case (r.state) is
         when WAIT_TRIGGER_S =>
            -- Hold SC and MCK in reset between triggers
            v.adcDone := '1';
            v.scRst   := '1';
            v.mckRst  := '1';
            if (triggerRise = '1') then
               -- Pulse the adcClk reset to realign it upon trigger
               v.adcClkRst := '1';
               v.state     := WAIT_SC_FALL_S;
            end if;

         when WAIT_SC_FALL_S =>
            -- Release SC reset and wait for a falling edge of SC.
            v.scRst := '0';

            if (iSc = '0' and r.scLast = '1') then
               -- Release MCK rst when SC goes low
               -- Increment  SC fall counter
               v.mckRst        := '0';
               v.scFallCounter := r.scFallCounter + 1;
               v.adcValid      := '1';
               v.adcValidStb   := '1';
               v.state         := COUNT_MCK_S;
            end if;

         when COUNT_MCK_S =>
            -- Increment counter with each mck falling edge
            if (iMck = '0' and r.mckLast = '1') then
               v.mckFallCounter := r.mckFallCounter + 1;
            end if;

            -- Hold mck in reset again once all edges have been sent
            if (r.mckFallCounter = r.mckCount) then
               -- Done with mck
               v.mckRst      := '1';
               v.adcValid    := '0';
               v.adcValidStb := '1';
               if (r.scFallCounter = r.scCount) then
                  -- Done with acquisition
                  v.state := WAIT_TRIGGER_S;
               else
                  -- Wait for next SC fall
                  v.state := WAIT_SC_FALL_S;
               end if;
            end if;

      end case;

      -- Clock disable registers override state machine
      if (r.mckDisable = '1') then
         v.mckRst := '1';
      end if;

      if (r.clkDisable = '1') then
         v.scRst     := '1';
         v.mckRst    := '1';
         v.adcClkRst := '1';
      end if;

      -- Synchronous reset
      if (rst250 = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Outputs
      elineSc   <= iSc;
      elineMck  <= iMck;
      adcClk    <= iAdcClk;
      adcClkRst <= r.adcClkRst;
      adcValid  <= iAdcValid;
      adcDone   <= r.adcDone;
      bla       <= r.bla;

   end process comb;

   seq : process (clk250) is
   begin
      if (rising_edge(clk250)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

