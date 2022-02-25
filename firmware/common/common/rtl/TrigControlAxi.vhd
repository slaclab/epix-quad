-------------------------------------------------------------------------------
-- File       : TrigControlAxi.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity TrigControlAxi is
   generic (
      TPD_G              : time             := 1 ns;
      AXIL_ERR_RESP_G    : slv(1 downto 0)  := AXI_RESP_DECERR_C
   );
   port (
      -- global clk
      sysClk        : in  sl;
      sysRst        : in  sl;
      -- Outputs
      acqStart      : out sl;
      dataSend      : out sl;
      -- External trigger inputs
      runTrigger    : in  sl;
      daqTrigger    : in  sl;
      -- Software trigger
      swRun         : in   sl;
      -- Fiber optic trigger
      pgpOpCode     : in   slv(7 downto 0);
      pgpOpCodeEn   : in   sl;
      -- Fiducial code output
      opCodeOut     : out slv(7 downto 0);
      -- AXI lite slave port for register access
      axilClk           : in  sl;
      axilRst           : in  sl;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType
   );

end TrigControlAxi;

architecture rtl of TrigControlAxi is


   type TriggerType is record
      runTriggerEnable  : sl;
      daqTriggerEnable  : sl;
      pgpTrigEn         : sl;
      autoRunEn         : sl;
      autoDaqEn         : sl;
      acqCountReset     : sl;
      runTriggerDelay   : slv(31 downto 0);
      daqTriggerDelay   : slv(31 downto 0);
      autoTrigPeriod    : slv(31 downto 0);
      runTrigPrescale   : slv(31 downto 0);
      daqTrigPrescale   : slv(31 downto 0);
   end record TriggerType;

   constant TRIGGER_INIT_C : TriggerType := (
      runTriggerEnable  => '0',
      daqTriggerEnable  => '0',
      pgpTrigEn         => '0',
      autoRunEn         => '0',
      autoDaqEn         => '0',
      acqCountReset     => '0',
      runTriggerDelay   => (others=>'0'),
      daqTriggerDelay   => (others=>'0'),
      autoTrigPeriod    => (others=>'0'),
      runTrigPrescale   => (others=>'0'),
      daqTrigPrescale   => (others=>'0')
   );

   type RegType is record
      trig              : TriggerType;
      sAxilWriteSlave   : AxiLiteWriteSlaveType;
      sAxilReadSlave    : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      trig              => TRIGGER_INIT_C,
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal coreSidebandRun : sl;
   signal coreSidebandDaq : sl;
   signal combinedRunTrig : sl;
   signal combinedDaqTrig : sl;

   signal runTriggerEdge  : std_logic;
   signal daqTriggerEdge  : std_logic;
   signal runTriggerCnt   : std_logic_vector(31 downto 0);
   signal daqTriggerCnt   : std_logic_vector(31 downto 0);
   signal daqTriggerPreCnt   : std_logic_vector(31 downto 0);
   signal runTriggerPreCnt   : std_logic_vector(31 downto 0);
   signal runTriggerOut   : std_logic;
   signal daqTriggerOut   : std_logic;
   signal daqTriggerPreOut   : std_logic;
   signal runTriggerPreOut   : std_logic;
   signal countEnable     : std_logic;
   signal acqCount        : std_logic_vector(31 downto 0);
   signal acqCountSync    : std_logic_vector(31 downto 0);
   signal swRead          : std_logic;
   signal iRunTrigOut     : std_logic;
   signal iDaqTrigOut     : std_logic;
   signal hwRunTrig     : std_logic;
   signal hwDaqTrig     : std_logic;
   signal autoRunEn     : std_logic;
   signal autoDaqEn     : std_logic;


   signal trigSync : TriggerType;

begin

   -----------------------------------
   -- SW Triggers:
   --   Run trigger is opCode x00
   --   DAQ trigger trails by 1 clock
   -----------------------------------
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            swRead <= '0' after TPD_G;
         else
            swRead <= swRun after TPD_G;
         end if;
      end if;
   end process;

   -----------------------------------------
   -- PGP Sideband Triggers:
   --   Any op code is a trigger, actual op
   --   code is the fiducial.
   -----------------------------------------
   -- Map op code to output port
   -- Have sideband DAQ lag 1 cycle behind sideband run
   coreSidebandRun <= pgpOpCodeEn;
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            opCodeOut <= (others => '0') after TPD_G;
         elsif coreSidebandRun = '1' then
            opCodeOut <= pgpOpCode after TPD_G;
         end if;
         coreSidebandDaq <= coreSidebandRun;
      end if;
   end process;

   --------------------------------------------------
   -- Combine with TTL triggers and look for edges --
   --------------------------------------------------
   combinedRunTrig <= (coreSidebandRun and r.trig.pgpTrigEn) or (runTrigger and not r.trig.pgpTrigEn);
   combinedDaqTrig <= (coreSidebandDaq and r.trig.pgpTrigEn) or (daqTrigger and not r.trig.pgpTrigEn);

   --------------------------------
   -- Run Input
   --------------------------------
   -- Edge Detect
   U_RunEdge : entity surf.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => combinedRunTrig,
         risingEdge => runTriggerEdge
      );

   -- Delay
   process ( sysClk, sysRst ) begin
      if ( sysRst = '1' ) then
         runTriggerCnt  <= (others=>'0') after TPD_G;
         runTriggerOut  <= '0'           after TPD_G;
      elsif rising_edge(sysClk) then

         -- Run trigger is disabled
         if trigSync.runTriggerEnable = '0' then
            runTriggerCnt  <= (others=>'0') after TPD_G;
            runTriggerOut  <= '0'           after TPD_G;

         -- Edge detected
         elsif runTriggerEdge = '1' then
            runTriggerCnt <= trigSync.runTriggerDelay after TPD_G;

            -- Trigger immediatly if delay is set to zero
            if trigSync.runTriggerDelay = 0 then
               runTriggerOut <= '1' after TPD_G;
            else
               runTriggerOut <= '0' after TPD_G;
            end if;

         -- Stop at zero
         elsif runTriggerCnt = 0 then
            runTriggerOut <= '0' after TPD_G;

         -- About to reach zero
         elsif runTriggerCnt = 1 then
            runTriggerOut <= '1'           after TPD_G;
            runTriggerCnt <= (others=>'0') after TPD_G;

         -- Counting down
         else
            runTriggerOut <= '0'               after TPD_G;
            runTriggerCnt <= runTriggerCnt - 1 after TPD_G;
         end if;
      end if;
   end process;

   --------------------------------
   -- DAQ trigger input
   --------------------------------

   -- Edge Detect
   U_AcqEdge : entity surf.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => combinedDaqTrig,
         risingEdge => daqTriggerEdge
      );

   -- Delay
   process ( sysClk, sysRst ) begin
      if ( sysRst = '1' ) then
         daqTriggerCnt  <= (others=>'0') after TPD_G;
         daqTriggerOut  <= '0'           after TPD_G;
      elsif rising_edge(sysClk) then

         -- DAQ trigger is disabled
         if trigSync.daqTriggerEnable = '0' then
            daqTriggerCnt  <= (others=>'0') after TPD_G;
            daqTriggerOut  <= '0'           after TPD_G;

         -- Edge detected
         elsif daqTriggerEdge = '1' then
            daqTriggerCnt <= trigSync.daqTriggerDelay after TPD_G;

            -- Trigger immediatly if delay is set to zero
            if trigSync.daqTriggerDelay = 0 then
               daqTriggerOut <= '1' after TPD_G;
            else
               daqTriggerOut <= '0' after TPD_G;
            end if;

         -- Stop at zero
         elsif daqTriggerCnt = 0 then
            daqTriggerOut <= '0' after TPD_G;

         -- About to reach zero
         elsif daqTriggerCnt = 1 then
            daqTriggerOut <= '1'           after TPD_G;
            daqTriggerCnt <= (others=>'0') after TPD_G;

         -- Counting down
         else
            daqTriggerOut <= '0'               after TPD_G;
            daqTriggerCnt <= daqTriggerCnt - 1 after TPD_G;
         end if;
      end if;
   end process;

   -- Run trigger optional prescaler
   process ( sysClk, sysRst ) begin
      if ( sysRst = '1' ) then
         runTriggerPreCnt  <= (others=>'0') after TPD_G;
         runTriggerPreOut  <= '0'           after TPD_G;
      elsif rising_edge(sysClk) then

         if runTriggerOut = '1' then

            if runTriggerPreCnt >= r.trig.runTrigPrescale then
               runTriggerPreCnt  <= (others=>'0') after TPD_G;
               runTriggerPreOut  <= '1'           after TPD_G;
            else
               runTriggerPreCnt  <= runTriggerPreCnt + 1 after TPD_G;
            end if;

         else
            runTriggerPreOut  <= '0'           after TPD_G;

         end if;
      end if;
   end process;

   -- Daq trigger optional prescaler
   process ( sysClk, sysRst ) begin
      if ( sysRst = '1' ) then
         daqTriggerPreCnt  <= (others=>'0') after TPD_G;
         daqTriggerPreOut  <= '0'           after TPD_G;
      elsif rising_edge(sysClk) then

         if daqTriggerOut = '1' then

            if daqTriggerPreCnt >= r.trig.daqTrigPrescale then
               daqTriggerPreCnt  <= (others=>'0') after TPD_G;
               daqTriggerPreOut  <= '1'           after TPD_G;
            else
               daqTriggerPreCnt  <= daqTriggerPreCnt + 1 after TPD_G;
            end if;

         else
            daqTriggerPreOut  <= '0'           after TPD_G;

         end if;
      end if;
   end process;


   --------------------------------
   -- External triggers
   --------------------------------
   hwRunTrig <= runTriggerPreOut;
   hwDaqTrig <= daqTriggerPreOut;

   --------------------------------
   -- Autotrigger block
   --------------------------------
   U_AutoTrig : entity work.AutoTrigger
   port map (
      -- Sync clock and reset
      sysClk        => sysClk,
      sysClkRst     => sysRst,
      -- Inputs
      runTrigIn     => hwRunTrig,
      daqTrigIn     => hwDaqTrig,
      -- Number of clock cycles between triggers
      trigPeriod    => trigSync.autoTrigPeriod,
      --Enable run and daq triggers
      runEn         => autoRunEn,
      daqEn         => autoDaqEn,
      -- Outputs
      runTrigOut    => iRunTrigOut,
      daqTrigOut    => iDaqTrigOut
   );

   autoRunEn <= '1' when trigSync.autoRunEn = '1' and trigSync.runTriggerEnable = '1' and trigSync.autoTrigPeriod /= 0 else '0';
   autoDaqEn <= '1' when trigSync.autoDaqEn = '1' and trigSync.daqTriggerEnable = '1' and trigSync.autoTrigPeriod /= 0 else '0';

   --------------------------------
   -- Acquisition Counter And Outputs
   --------------------------------
   acqStart   <= iRunTrigOut or swRun;
   dataSend   <= iDaqTrigOut or swRead;

   process ( sysClk, sysRst ) begin
      if ( sysRst = '1' ) then
         acqCount    <= (others=>'0') after TPD_G;
         countEnable <= '0'           after TPD_G;
      elsif rising_edge(sysClk) then
         countEnable <= iRunTrigOut or swRun after TPD_G;

         if trigSync.acqCountReset = '1' then
            acqCount <= (others=>'0') after TPD_G;
         elsif countEnable = '1' then
            acqCount <= acqCount + 1 after TPD_G;
         end if;
      end if;
   end process;

   --------------------------------------------------
   -- AXI Lite register logic
   --------------------------------------------------

   comb : process (axilRst, sAxilReadMaster, sAxilWriteMaster, r, acqCountSync) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
   begin
      v := r;

      v.trig.acqCountReset := '0';

      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegister (regCon, x"00", 0, v.trig.runTriggerEnable);
      axiSlaveRegister (regCon, x"04", 0, v.trig.runTriggerDelay);
      axiSlaveRegister (regCon, x"08", 0, v.trig.daqTriggerEnable);
      axiSlaveRegister (regCon, x"0C", 0, v.trig.daqTriggerDelay);
      axiSlaveRegister (regCon, x"10", 0, v.trig.autoRunEn);
      axiSlaveRegister (regCon, x"14", 0, v.trig.autoDaqEn);
      axiSlaveRegister (regCon, x"18", 0, v.trig.autoTrigPeriod);
      axiSlaveRegister (regCon, x"1C", 0, v.trig.pgpTrigEn);
      axiSlaveRegister (regCon, x"20", 0, v.trig.acqCountReset);
      axiSlaveRegisterR(regCon, x"24", 0, acqCountSync);
      axiSlaveRegister (regCon, x"30", 0, v.trig.runTrigPrescale);
      axiSlaveRegister (regCon, x"34", 0, v.trig.daqTrigPrescale);

      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
         acqCountSync <= acqCount after TPD_G;
      end if;
   end process seq;

   --sync registers to sysClk clock
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysRst = '1' then
            trigSync <= TRIGGER_INIT_C after TPD_G;
         else
            trigSync <= r.trig after TPD_G;
         end if;
      end if;
   end process;


end rtl;

