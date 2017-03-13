-------------------------------------------------------------------------------
-- Title      : Coulter Acquisition Control
-------------------------------------------------------------------------------
-- File       : AcquisitionControl.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-31
-- Last update: 2017-03-13
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

-- Surf packages
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

-- Coulter packages
use work.AcquisitionControlPkg.all;

entity AcquisitionControl is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (

      -- AXI-Lite Interface for configuration
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- 250 Mhz reference clock
      distClk : in sl;
      distRst : in sl;

      -- Incoming command
      trigger : sl;

      -- ASIC Outputs
      elineRst      : out sl;
      elineSc       : out sl;
      elineMck      : out sl;
      elineOverflow : in  slv(1 downto 0);

      -- ADC 
      adcClk    : out sl;
      adcClkRst : out sl;

      -- Status
      acqStatus : out AcquisitionStatusType);

end AcquisitionControl;


-- Define architecture
architecture rtl of AcquisitionControl is

   type StateType is (WAIT_TRIGGER_S, WAIT_SC_FALL_S, COUNT_MCK_S);

   -- Configuration registers
   type CfgRegType is record
      scDelay        : slv(15 downto 0);  -- delay between trigger and SC rise
      scPosWidth     : slv(15 downto 0);  -- sc high time (baseline sampling)
      scNegWidth     : slv(15 downto 0);  -- sc low time (Tslot=scPos+scNeg)
      scCount        : slv(15 downto 0);  -- Number of slots in acquisition
      mckDelay       : slv(15 downto 0);  -- delay between sc fall and mck start (signal sampling)
      mckPosWidth    : slv(15 downto 0);  -- mck high time
      mckNegWidth    : slv(15 downto 0);  -- mck low time
      mckCount       : slv(7 downto 0);   -- Number of MCK pulses per slot (should be 16)
      adcClkPosWidth : slv(15 downto 0);  -- Adc clock high time
      adcClkNegWidth : slv(15 downto 0);  -- Adc clock low time      
      adcClkDelay    : slv(15 downto 0);  -- Delay time between trigger and new rising edge of ADC clk
      adcWindowDelay : slv(9 downto 0);   -- Delay between mck start and adc sample capture
      mckDisable     : sl;              -- Disable mck (is this necessary?)
      clkDisable     : sl;              -- Master clock disable (sc, mck, adcClk)
      invertMck      : sl;
   end record CfgRegType;

   constant CFG_REG_INIT_C : CfgRegType := (
      scDelay        => X"6200",        -- ~200 us for adcs to relock to shifted clock
      scPosWidth     => X"1000",        --X"0640", --toSlv(50*16*2, 16),
      scNegWidth     => X"1000",        --X"0640", --toSlv(50*16*2, 16),
      scCount        => toSlv(256, 16),
      mckDelay       => X"0080",        --toSlv(50*8, 16),
      mckPosWidth    => X"000B",        --toSlv(19, 16),  -- ~10 MHz
      mckNegWidth    => X"000B",        --toSlv(19, 16),
      mckCount       => toSlv(16, 8),   -- 16 pixels per slot, this should never change
      adcClkPosWidth => X"0005",        --toSlv(9, 16),   -- ~20 Mhz ADC clock
      adcClkNegWidth => X"0005",        --toSlv(9, 16),
      adcClkDelay    => toSlv(0, 16),
      adcWindowDelay => toSlv(282, 10),
      mckDisable     => '0',
      clkDisable     => '0',
      invertMck      => '0');

   type RegType is record
      -- AXIL output buses
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      -- AXIL config registers
      cfg            : CfgRegType;
      -- Local registers
      state          : StateType;
      scRst          : sl;
      scCounter      : slv(15 downto 0);
      mckRst         : sl;
      mckCounter     : slv(7 downto 0);
      adcClkRst      : sl;
      acqStatus      : AcquisitionStatusType;
      elineRst       : sl;
      scPreFallCount : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      cfg            => CFG_REG_INIT_C,
      state          => WAIT_TRIGGER_S,
      scRst          => '1',
      scCounter      => (others => '0'),
      mckRst         => '1',
      mckCounter     => (others => '0'),
      adcClkRst      => '0',
      acqStatus      => ACQUISITION_STATUS_INIT_C,
      elineRst       => '0',
      scPreFallCount => (others => '0'));

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

   signal scPreRise  : sl;
   signal scPreFall  : sl;
   signal mckPreRise : sl;
   signal mckPreFall : sl;

begin

   -- Synchronize the Axi lite bus to distClk
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
         mAxiClk         => distClk,             -- [in]
         mAxiClkRst      => distRst,             -- [in]
         mAxiReadMaster  => locAxilReadMaster,   -- [out]
         mAxiReadSlave   => r.axilReadSlave,     -- [in]
         mAxiWriteMaster => locAxilWriteMaster,  -- [out]
         mAxiWriteSlave  => r.axilWriteSlave);   -- [in]

   -- Synchronize trigger to distClk
   U_SynchronizerEdge_1 : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => distClk,        -- [in]
         rst         => distRst,        -- [in]
         dataIn      => trigger,        -- [in]
         dataOut     => open,           -- [out]
         risingEdge  => triggerRise,    -- [out]
         fallingEdge => open);          -- [out]

   U_ClockDivider_SC : entity work.ClockDivider
      generic map (
         TPD_G => TPD_G)
      port map (
         clk        => distClk,           -- [in]
         rst        => r.scRst,           -- [in]
         highCount  => r.cfg.scPosWidth,  -- [in]
         lowCount   => r.cfg.scNegWidth,  -- [in]
         delayCount => r.cfg.scDelay,     -- [in]
         divClk     => iSc,               -- [out]
         preRise    => scPreRise,         -- [out]
         preFall    => scPreFall);        -- [out]


   U_ClockDivider_MCK : entity work.ClockDivider
      generic map (
         TPD_G => TPD_G)
      port map (
         clk        => distClk,            -- [in]
         rst        => r.mckRst,           -- [in]
         highCount  => r.cfg.mckPosWidth,  -- [in]
         lowCount   => r.cfg.mckNegWidth,  -- [in]
         delayCount => r.cfg.mckDelay,     -- [in]
         divClk     => iMck,               -- [out]
         preRise    => mckPreRise,         --[out]
         preFall    => mckPreFall);        --[out]

   U_ClockDivider_ADCCLK : entity work.ClockDivider
      generic map (
         TPD_G => TPD_G)
      port map (
         clk        => distClk,               -- [in]
         rst        => r.adcClkRst,           -- [in]
         highCount  => r.cfg.adcClkPosWidth,  -- [in]
         lowCount   => r.cfg.adcClkNegWidth,  -- [in]
         delayCount => r.cfg.adcClkDelay,     -- [in]
         divClk     => iAdcClk);              -- [out]

   U_SlvDelay_AdcWindow : entity work.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         REG_OUTPUT_G => true,
         DELAY_G      => 1024,
         WIDTH_G      => 1)
      port map (
         clk     => distClk,                -- [in]
         delay   => r.cfg.adcWindowDelay,   -- [in]
         din(0)  => r.acqStatus.adcWindow,  -- [in]
         dout(0) => acqStatus.adcWindow);   -- [out]

   U_SlvDelay_AdcLast : entity work.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         REG_OUTPUT_G => true,
         DELAY_G      => 1024,
         WIDTH_G      => 1)
      port map (
         clk     => distClk,               -- [in]
         delay   => r.cfg.adcWindowDelay,  -- [in]
         din(0)  => r.acqStatus.adcLast,   -- [in]
         dout(0) => acqStatus.adcLast);    -- [out]

   acqStatus.adcWindowStart <= '0';
   acqStatus.adcWindowEnd   <= '0';
   acqStatus.mckPulse       <= '0';
   acqStatus.trigger        <= r.acqStatus.trigger;
   acqStatus.scFall         <= scPreFall;
   acqStatus.cfgMckCount    <= r.cfg.mckCount;
   acqStatus.cfgScCount     <= r.cfg.scCount;

   -------------------------------------------------------------------------------------------------
   -- Main logic
   -------------------------------------------------------------------------------------------------
   comb : process (distRst, elineOverflow, iAdcClk, iMck, iSc, locAxilReadMaster,
                   locAxilWriteMaster, mckPreFall, mckPreRise, r, scPreFall, triggerRise) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v           := r;
      v.adcClkRst := '0';

      if (scPreFall = '1') then
         v.scPreFallCount := r.scPreFallCount + 1;
      end if;

      -- Declare configuration registers
      axiSlaveWaitTxn(axilEp, locAxilWriteMaster, locAxilReadMaster, v.axilWriteSlave, v.axilReadSlave);
      axiSlaveRegister(axilEp, X"00", 0, v.cfg.scDelay);
      axiSlaveRegister(axilEp, X"04", 0, v.cfg.scPosWidth);
      axiSlaveRegister(axilEp, X"08", 0, v.cfg.scNegWidth);
      axiSlaveRegister(axilEp, X"0C", 0, v.cfg.scCount);
      axiSlaveRegister(axilEp, X"10", 0, v.cfg.mckDelay);
      axiSlaveRegister(axilEp, X"14", 0, v.cfg.mckPosWidth);
      axiSlaveRegister(axilEp, X"18", 0, v.cfg.mckNegWidth);
      axiSlaveRegister(axilEp, X"1C", 0, v.cfg.mckCount);
      axiSlaveRegister(axilEp, X"20", 0, v.cfg.adcClkPosWidth);
      axiSlaveRegister(axilEp, X"20", 31, v.adcClkRst, '1');
      axiSlaveRegister(axilEp, X"24", 0, v.cfg.adcClkNegWidth);
      axiSlaveRegister(axilEp, X"24", 31, v.adcClkRst, '1');
      axiSlaveRegister(axilEp, X"28", 0, v.cfg.adcClkDelay);
      axiSlaveRegister(axilEp, X"2C", 0, v.cfg.adcWindowDelay);
      axiSlaveRegister(axilEp, X"30", 0, v.cfg.mckDisable);
      axiSlaveRegister(axilEp, X"34", 0, v.cfg.clkDisable);
      axiSlaveRegister(axilEp, X"38", 0, v.elineRst);
      axiSlaveRegisterR(axilEp, X"3C", 0, r.scPreFallCount);
      axiSlaveRegisterR(axilEp, X"40", 0, elineOverflow);
      axiSlaveRegister(axilEp, X"44", 0, v.cfg.invertMck);
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      -- Default Register values
      v.acqStatus.trigger        := triggerRise;
      v.acqStatus.mckPulse       := mckPreRise;
      v.acqStatus.adcWindowStart := '0';
      v.acqStatus.adcWindowEnd   := '0';

      case (r.state) is
         when WAIT_TRIGGER_S =>
            -- Hold SC and MCK in reset between triggers
            v.scRst      := '1';
            v.mckRst     := '1';
            v.scCounter  := (others => '0');
            v.mckCounter := (others => '0');
            if (triggerRise = '1') then
               -- Pulse the adcClk reset to realign it upon trigger
               v.adcClkRst := '1';
               v.state     := WAIT_SC_FALL_S;
            end if;

         when WAIT_SC_FALL_S =>
            -- Release SC reset and wait for a falling edge of SC.
            v.scRst      := '0';
            v.mckCounter := (others => '0');
            if (scPreFall = '1') then
               -- Release MCK rst when SC goes low
               -- Increment  SC fall counter
               v.mckRst    := '0';
               v.scCounter := r.scCounter + 1;
               v.state     := COUNT_MCK_S;
            end if;

         when COUNT_MCK_S =>
            -- Set adcWindow high on first rising edge (will remain high)
            if (mckPreRise = '1') then
               v.acqStatus.adcWindow := '1';

               if (r.mckCounter = X"0000") then
                  v.acqStatus.adcWindowStart := '1';
               end if;

               -- Set adcLast before last on last mck
               if (r.mckCounter = r.cfg.mckCount-1) then
                  v.acqStatus.adcLast := '1';
               end if;
            end if;

            -- Increment counter with each mck falling edge
            if (mckPreFall = '1') then
               v.mckCounter := r.mckCounter + 1;
            end if;

            -- Hold mck in reset again once all edges have been sent
            if (r.mckCounter = r.cfg.mckCount) then
               -- Done with mck
               v.mckRst                 := '1';
               v.acqStatus.adcWindow    := '0';
               v.acqStatus.adcWindowEnd := '1';
               v.acqStatus.adcLast      := '0';
               if (r.scCounter = r.cfg.scCount) then
                  -- Done with acquisition
                  v.state := WAIT_TRIGGER_S;
               else
                  -- Wait for next SC fall
                  v.state := WAIT_SC_FALL_S;
               end if;
            end if;

      end case;

      -- Clock disable registers override state machine
      if (r.cfg.mckDisable = '1') then
         v.mckRst := '1';
      end if;

      if (r.cfg.clkDisable = '1') then
         v.scRst     := '1';
         v.mckRst    := '1';
         v.adcClkRst := '1';
      end if;

      -- Synchronous reset
      if (distRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      -- Outputs
      elineSc   <= iSc;
      if r.cfg.invertMck = '0' then
         elineMck  <= iMck;
      else
         elineMck <= not iMck;
      end if;
      adcClk    <= iAdcClk;
      adcClkRst <= r.adcClkRst;
      elineRst  <= r.elineRst;

   end process comb;

   seq : process (distClk) is
   begin
      if (rising_edge(distClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;

