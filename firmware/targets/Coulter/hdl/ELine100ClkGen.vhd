-------------------------------------------------------------------------------
-- Title      : ELine100 Clock Generator
-------------------------------------------------------------------------------
-- File       : ELine100ClkGen.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>,
--              Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2011-03-29
-- Last update: 2016-05-31
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Controls ASIC clocking for the ELINE100 ASIC.
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity ClockGen is 
   port ( 

      -- Master system clock, 250Mhz
      sysClk250     : in  sl;
      sysRst250     : in  sl;

      -- Incoming command
      cmdEn         : in  sl;
      cmdOpCode     : in  slv(7  downto 0);
      extTrig       : in  sl;
      enExtTrig     : in  sl;


      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;

      -- Configuration
      perMclkCount  : in  slv(7  downto 0);      
      ptDelay       : in  slv(7  downto 0);
      scDelay       : in  slv(7  downto 0);
      cckPosWidth   : in  slv(7  downto 0);
      cckNegWidth   : in  slv(7  downto 0);
      scPosWidth    : in  slv(15 downto 0);
      scNegWidth    : in  slv(15 downto 0);
      scCount       : in  slv(11 downto 0);
      mckPosWidth   : in  slv(7  downto 0);
      mckNegWidth   : in  slv(7  downto 0);
      mckDelay      : in  slv(15 downto 0);
      adcClkPer     : in  slv(7  downto 0);
      adcPhase      : in  slv(15 downto 0);
      adcDelay      : in  slv(15 downto 0);
      scStopCnt     : in  slv(11 downto 0);
      cckDisable    : in  sl;
      mckDisable    : in  sl;
      clkDisable    : in  sl;
      disToken      : in  sl;
      disSwitcher   : in  sl;
      regUpdate     : in  sl;

      -- Output Clocks
      asicRst       : out sl;
      adcValid      : out sl;
      adcDone       : out sl;
      adcClk        : out sl;
      asicSc        : out sl;
      asicMClk      : out sl;
      asicCClk      : out sl;

      -- Switcher
      parf          : out sl;
      pbrf          : out sl;
      palf          : out sl;
      pblf          : out sl;
      rsts          : out sl;
      tairf         : out sl;
      tbirf         : out sl;
      tailf         : out sl;
      tbilf         : out sl;
      scr           : out sl;
      scl           : out sl;
      air           : out sl;
      ail           : out sl;
      bir           : out sl;
      bil           : out sl
   );

   -- Keep from combinging chip selects
   attribute syn_preserve : boolean;
   attribute syn_preserve of asicSc:    signal is true;
   attribute syn_preserve of scr:       signal is true;
   attribute syn_preserve of scl:       signal is true;
   attribute syn_preserve of adcValid:  signal is true;
   attribute syn_preserve of adcClk:    signal is true;
   attribute syn_preserve of asicMClk:  signal is true;
   attribute syn_preserve of asicCClk:  signal is true;
   attribute syn_preserve of parf:      signal is true;
   attribute syn_preserve of pbrf:      signal is true;
   attribute syn_preserve of palf:      signal is true;
   attribute syn_preserve of pblf:      signal is true;
   attribute syn_preserve of rsts:      signal is true;
   attribute syn_preserve of tairf:     signal is true;
   attribute syn_preserve of tbirf:     signal is true;
   attribute syn_preserve of tailf:     signal is true;
   attribute syn_preserve of tbilf:     signal is true;
   attribute syn_preserve of air:       signal is true;
   attribute syn_preserve of ail:       signal is true;
   attribute syn_preserve of bir:       signal is true;
   attribute syn_preserve of bil:       signal is true;

end ClockGen;


-- Define architecture
architecture ClockGen of ClockGen is

   -- Local Signals
   signal intCmdReg      : sl;
   signal intCmdEn       : sl;
   signal tmpCmdEn1      : sl;
   signal tmpCmdEn2      : sl;
   signal tmpCmdEn3      : sl;
   signal intExtTrig     : sl;
   signal tmpExtTrig1    : sl;
   signal tmpExtTrig2    : sl;
   signal tmpExtTrig3    : sl;
   signal ptCount        : slv(7 downto 0);
   signal ptStrobe       : sl;
   signal ptDlyEnable    : sl;
   signal iptDelay       : slv(7  downto 0);
   signal iscDelay       : slv(7  downto 0);
   signal icckPosWidth   : slv(7  downto 0);
   signal icckNegWidth   : slv(7  downto 0);
   signal iscPosWidth    : slv(15 downto 0);
   signal iscNegWidth    : slv(15 downto 0);
   signal iscCount       : slv(11 downto 0);
   signal imckPosWidth   : slv(7  downto 0);
   signal imckNegWidth   : slv(7  downto 0);
   signal imckDelay      : slv(15 downto 0);
   signal iperMclkCount  : slv(7  downto 0);
   signal iasicSc        : sl;
   signal iasicMClk      : sl;
   signal iasicCClk      : sl;
   signal scEnable       : sl;
   signal scSwEnable     : sl;
   signal scAdcEnable    : sl;
   signal scStart        : sl;
   signal scDone         : sl;
   signal scDlyCount     : slv(7  downto 0);
   signal scDlyCountEn   : sl;
   signal scPerCount     : slv(15 downto 0);
   signal scTotCount     : slv(11 downto 0);
   signal cckPerCount    : slv(7  downto 0);
   signal mckPerCount    : slv(7  downto 0);
   signal mckDlyCount    : slv(15 downto 0);
   signal mckTotCount    : slv(4  downto 0);
   signal icckDisable    : sl;
   signal imckDisable    : sl;
   signal adcPerCount    : slv(7  downto 0);
   signal adcPhCount     : slv(15 downto 0);
   signal adcPhZero      : sl;
   signal adcPhZeroDly   : sl;
   signal iadcClk        : sl;
   signal adcDlyCount    : slv(15 downto 0);
   signal iadcValid      : sl;
   signal iadcClkPer     : slv(7  downto 0);
   signal iadcPhase      : slv(15 downto 0);
   signal iadcDelay      : slv(15 downto 0);
   signal adcTotCount    : slv(7  downto 0);
   signal iclkDisable    : sl;
   signal rstCount       : slv(15 downto 0);
   signal iswSc          : sl;
   signal iswScDly       : slv(23 downto 0);
   signal iswScOut       : sl;
   signal itif           : sl;
   signal iasicRst       : sl;
   signal iparf          : sl;
   signal idisToken      : sl;
   signal idisSwitcher   : sl;
   signal regUpdateDly1  : sl;
   signal regUpdateDly2  : sl;
   signal intRst250      : sl;
   signal stopSc         : sl;
   signal iscStopCnt     : slv(11 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Sample configuration values with fast clock
   process ( sysClk250, sysRst250 ) begin
      if sysRst250 = '1' then
         iptDelay       <= (others=>'0') after tpd;
         iscDelay       <= (others=>'0') after tpd;
         icckPosWidth   <= (others=>'0') after tpd;
         icckNegWidth   <= (others=>'0') after tpd;
         iscPosWidth    <= (others=>'0') after tpd;
         iscNegWidth    <= (others=>'0') after tpd;
         iscCount       <= (others=>'0') after tpd;
         imckPosWidth   <= (others=>'0') after tpd;
         imckNegWidth   <= (others=>'0') after tpd;
         imckDelay      <= (others=>'0') after tpd;
         icckDisable    <= '0'           after tpd;
         imckDisable    <= '0'           after tpd;
         iadcClkPer     <= (others=>'0') after tpd;
         iadcPhase      <= (others=>'0') after tpd;
         iadcDelay      <= (others=>'0') after tpd;
         iclkDisable    <= '0'           after tpd;
         idisToken      <= '0'           after tpd;
         idisSwitcher   <= '0'           after tpd;
         regUpdateDly1  <= '0'           after tpd;
         regUpdateDly2  <= '0'           after tpd;
         intRst250      <= '1'           after tpd;
         iperMclkCount  <= (others=>'0') after tpd;
         iscStopCnt     <= (others=>'0') after tpd;
      elsif rising_edge(sysClk250) then
         iptDelay       <= ptDelay       after tpd;
         iscDelay       <= scDelay       after tpd;
         icckPosWidth   <= cckPosWidth   after tpd;
         icckNegWidth   <= cckNegWidth   after tpd;
         iscPosWidth    <= scPosWidth    after tpd;
         iscNegWidth    <= scNegWidth    after tpd;
         iscCount       <= scCount       after tpd;
         imckPosWidth   <= mckPosWidth   after tpd;
         imckNegWidth   <= mckNegWidth   after tpd;
         imckDelay      <= mckDelay      after tpd;
         icckDisable    <= cckDisable    after tpd;
         imckDisable    <= mckDisable    after tpd;
         iadcClkPer     <= adcClkper     after tpd;
         iadcPhase      <= adcPhase      after tpd;
         iadcDelay      <= adcDelay      after tpd;
         iclkDisable    <= clkDisable    after tpd;
         idisToken      <= disToken      after tpd;
         idisSwitcher   <= disSwitcher   after tpd;
         regUpdateDly1  <= regUpdate     after tpd;
         regUpdateDly2  <= regUpdateDly1 after tpd;
         intRst250      <= regUpdateDly2 after tpd;
         iperMclkCount  <= perMclkCount  after tpd;
         iscStopCnt     <= scStopCnt     after tpd;
      end if;
   end process;

   -- Output Clocks
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         asicSc      <= '0' after tpd;
         scr         <= '0' after tpd;
         scl         <= '0' after tpd;
         adcClk      <= '0' after tpd;
         adcValid    <= '0' after tpd;
         asicMClk    <= '0' after tpd;
         asicCClk    <= '0' after tpd;
         parf        <= '0' after tpd;
         pbrf        <= '0' after tpd;
         palf        <= '0' after tpd;
         pblf        <= '0' after tpd;
         tairf       <= '0' after tpd;
         tbirf       <= '0' after tpd;
         tailf       <= '0' after tpd;
         tbilf       <= '0' after tpd;
         air         <= '0' after tpd;
         bir         <= '1' after tpd;
         ail         <= '1' after tpd; -- Single Pixel Test Version
         bil         <= '0' after tpd; -- Single Pixel Test Version
         --ail         <= '0' after tpd; -- Correct Version
         --bil         <= '1' after tpd; -- Correct Version
         rsts        <= '0' after tpd;
         asicRst     <= '0' after tpd;
      elsif rising_edge(sysClk250) then
         adcClk    <= iadcClk   after tpd;
         adcValid  <= iadcValid after tpd;

         if iclkDisable = '0' then
            asicSc    <= iasicSc                                              after tpd;
            asicMClk  <= iasicMClk and (not imckDisable)                      after tpd;
            asicCClk  <= iasicCClk and (not icckDisable)                      after tpd;
            scr       <= iswScOut  and (not idisSwitcher) and (not stopSc)    after tpd;
            scl       <= iswScOut  and (not idisSwitcher) and (not stopSc)    after tpd;
            tairf     <= itif      and (not idisToken) and (not idisSwitcher) after tpd;
            tbirf     <= itif      and (not idisToken) and (not idisSwitcher) after tpd;
            tailf     <= itif      and (not idisToken) and (not idisSwitcher) after tpd;
            tbilf     <= itif      and (not idisToken) and (not idisSwitcher) after tpd;
            air       <= iswScOut  and (not idisSwitcher)                     after tpd;
            bir       <= (not iswScOut) or idisSwitcher                       after tpd;
            ail       <= (not iswScOut) or idisSwitcher                       after tpd; -- Single Pixel Test Version
            bil       <= iswScOut  and (not idisSwitcher)                     after tpd; -- Single Pixel Test Version
            --bil       <= (not iswScOut) or idisSwitcher                       after tpd; -- Correct Version
            --ail       <= iswScOut  and (not idisSwitcher)                     after tpd; -- Correct Version
         else
            asicSc    <= '0' after tpd;
            asicMClk  <= '0' after tpd;
            asicCClk  <= '0' after tpd;
            scr       <= '0' after tpd;
            scl       <= '0' after tpd;
            tairf     <= '0' after tpd;
            tbirf     <= '0' after tpd;
            tailf     <= '0' after tpd;
            tbilf     <= '0' after tpd;
            air       <= '0' after tpd;
            bir       <= '1' after tpd;
            ail       <= '1' after tpd; -- Single Pixel Test Version
            bil       <= '0' after tpd; -- Single Pixel Test Version
            --bil       <= '1' after tpd; -- Correct Version
            --ail       <= '0' after tpd; -- Correct Version
         end if;

         rsts    <= iasicRst and (not idisSwitcher) after tpd;
         asicRst <= iasicRst                        after tpd;
         parf    <= iparf and (not idisSwitcher)    after tpd;
         pbrf    <= '0'                             after tpd;
         palf    <= '0'                             after tpd;  -- Single Pixel Test Version
         pblf    <= iparf and (not idisSwitcher)    after tpd;  -- Single Pixel Test Version
         --pblf    <= '0'                             after tpd; -- Correct Version
         --palf    <= iparf and (not idisSwitcher)    after tpd; -- Correct Version

      end if;
   end process;


   -- Debug output select
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         debugOut <= '0' after tpd;
      elsif rising_edge(sysClk250) then
         case debugSel is 
            when "0000" => debugOut <= iasicSc   after tpd;
            when "0001" => debugOut <= iasicSc and (not scTotCount(0)) after tpd;
            when "0010" => debugOut <= iasicSc and (not scTotCount(0)) and (not scTotCount(1)) after tpd;
            when "0011" => debugOut <= iasicSc and (not scTotCount(0)) and (not scTotCount(1)) and (not scTotCount(2)) after tpd;
            when "0100" => debugOut <= iasicSc and (not scTotCount(0)) and (not scTotCount(1)) and (not scTotCount(2)) and (not scTotCount(3)) after tpd;
            when "0101" => debugOut <= iasicMClk after tpd;
            when "0110" => debugOut <= iasicCClk after tpd;
            when "0111" => debugOut <= iadcValid after tpd;
            when "1000" => debugOut <= iadcClk   after tpd;
            when "1001" => debugOut <= iswScOut  after tpd;
            when "1010" => debugOut <= itif      after tpd;
            when "1011" => debugOut <= '0'       after tpd;
            when others => debugOut <= '0'       after tpd;
         end case;
      end if;
   end process;


   -- Sample command enable with 250Mhz clock
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         tmpCmdEn1   <= '0'  after tpd;
         tmpCmdEn2   <= '0'  after tpd;
         tmpCmdEn3   <= '0'  after tpd;
         intCmdEn    <= '0'  after tpd;
         tmpExtTrig1 <= '0'  after tpd;
         tmpExtTrig2 <= '0'  after tpd;
         tmpExtTrig3 <= '0'  after tpd;
         intExtTrig  <= '0'  after tpd;
      elsif rising_edge(sysClk250) then
         tmpCmdEn1 <= cmdEn                                                   after tpd;
         tmpCmdEn2 <= tmpCmdEn1                                               after tpd;
         tmpCmdEn3 <= tmpCmdEn2                                               after tpd;
         intCmdEn  <= tmpCmdEn2 and (not tmpCmdEn3) and (not iasicRst)        after tpd;
         tmpExtTrig1 <= extTrig                                               after tpd;
         tmpExtTrig2 <= tmpExtTrig1                                           after tpd;
         tmpExtTrig3 <= tmpExtTrig2                                           after tpd;
         intExtTrig  <= tmpExtTrig2 and (not tmpExtTrig3) and (not iasicRst)  after tpd;
      end if;
   end process;


   -- Delayed copy of incoming start signal
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         ptCount     <= (others=>'0') after tpd;
         ptStrobe    <= '0'           after tpd;
         ptDlyEnable <= '0'           after tpd;
         intCmdReg   <= '0'           after tpd;
      elsif rising_edge(sysClk250) then

         -- Register cmdEn
         if intCmdEn = '1' then
            intCmdReg <= '1' after tpd;
         elsif ptDlyEnable = '1' then
            intCmdReg <= '0' after tpd;
         end if;

         if (intCmdEn = '1' and enExtTrig = '0') or 
            (intCmdReg = '1' and intExtTrig = '1' and enExtTrig = '1') then 
            ptDlyEnable <= '1'      after tpd;
            ptCount     <= iptDelay after tpd;
         else
            if ptDlyEnable = '1' then
               if ptCount = 0 then
                  ptStrobe    <= '1' after tpd;
                  ptDlyEnable <= '0' after tpd;
               else 
                  ptCount  <= ptCount - 1 after tpd;
               end if;
            else
               ptStrobe <= '0' after tpd;
            end if;
         end if;
      end if;
   end process;


   -- SC Enable & Start Signal
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         scDlyCount   <= (others=>'0') after tpd;
         scDlyCountEn <= '0'           after tpd;
         scEnable     <= '0'           after tpd;
         scStart      <= '0'           after tpd;
         iasicRst     <= '0'           after tpd;
         iparf        <= '0'           after tpd;
         rstCount     <= (others=>'0') after tpd;
         adcDone      <= '0'           after tpd;
      elsif rising_edge(sysClk250) then
         if ptStrobe = '1' then 
            scDlyCountEn <= '1'           after tpd;
            scDlyCount   <= iscDelay      after tpd;
            iasicRst     <= '1'           after tpd;
            rstCount     <= (others=>'0') after tpd;
         else
            if scDlyCountEn = '1' then
               if scDlyCount = 0 then
                  scEnable     <= '1' after tpd;
                  scStart      <= '1' after tpd;
                  scDlyCountEn <= '0' after tpd;
               else 
                  scDlyCount <= scDlyCount - 1 after tpd;
               end if;
            else
               if scDone = '1' then
                  scEnable <= '0' after tpd;
               end if;
               scStart <= '0' after tpd;
            end if;

            if scEnable = '1' then
               adcDone  <= '0'           after tpd;
               iasicRst <= '1'           after tpd;
               iparf    <= '1'           after tpd;
               rstCount <= (others=>'0') after tpd;
            elsif rstCount = x"FFFF" then
               adcDone  <= '0' after tpd;
               iasicRst <= '0' after tpd;
               iparf    <= '0' after tpd;
            else
               if rstCount > x"FFF0" then
                  adcDone  <= '1' after tpd;
               else
                  adcDone  <= '0' after tpd;
               end if;

               if rstCount > x"FF00" then
                  iparf    <= '0' after tpd;
               elsif scDlyCount < x"1F" then
                  iparf  <= '1' after tpd;
               end if;
               rstCount <= rstCount + 1 after tpd;
            end if;
         end if;
      end if;
   end process;


   -- SC Clock Generation
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         scPerCount  <= (others=>'0') after tpd;
         scTotCount  <= (others=>'0') after tpd;
         scDone      <= '0'           after tpd;
         iasicSc     <= '0'           after tpd;
         iswSc       <= '0'           after tpd;
         iswScDly    <= (others=>'0') after tpd;
         iswScOut    <= '0'           after tpd;
         itif        <= '0'           after tpd;
         scSwEnable  <= '0'           after tpd;
         scAdcEnable <= '0'           after tpd;
         stopSc      <= '0'           after tpd;
      elsif rising_edge(sysClk250) then

         iswScDly <= iswScDly(22 downto 0) & iswSc after tpd;
         iswScOut <= iswScDly(23)                  after tpd;

         if scEnable = '0' then
            scSwEnable  <= '0' after tpd;
            scAdcEnable <= '0' after tpd;
            iasicSc     <= '0' after tpd;
            iswSc       <= '0' after tpd;
            scDone      <= '0' after tpd;
            itif        <= '0' after tpd;
            stopSc      <= '0' after tpd;

         -- Startup Pulse
         elsif scStart = '1' then
            scTotCount <= (others=>'0') after tpd;
            scPerCount <= (others=>'0') after tpd;
            iasicSc    <= '1'           after tpd;
            iswSc      <= '0'           after tpd;
            stopSc     <= '0'           after tpd;

         -- High Cycle
         elsif iasicSc = '1' then
            if scPerCount = iscPosWidth then
               iasicSc     <= '0'           after tpd;
               iswSc       <= '0'           after tpd;
               scPerCount  <= (others=>'0') after tpd;
            else
               if scPerCount = 49 and scSwEnable = '1' and scAdcEnable = '0' and scTotCount = 1 then
                  itif <= '1';
               end if;
               scPerCount <= scPerCount + 1 after tpd;
            end if;

         -- Low Cycle
         else
            if scPerCount = iscNegWidth then

               if scTotCount > iscStopCnt and iscStopCnt /= 0 then
                  stopSc <= '1' after tpd;
               else
                  stopSc <= '0' after tpd;
               end if;

               if scTotCount = iscCount then 
                  scDone      <= '1' after tpd;
                  scSwEnable  <= '0' after tpd;
                  scAdcEnable <= '0' after tpd;
               else
                  iasicSc    <= '1'            after tpd;
                  scPerCount <= (others=>'0')  after tpd;

                  if scAdcEnable = '0' and scTotCount = 1 then
                     scTotCount  <= (others=>'0')  after tpd;
                     scAdcEnable <= '1'            after tpd;
                  else
                     scTotCount <= scTotCount + 1 after tpd;
                  end if;

                  if scSwEnable = '0' and scTotCount = 0 then
                     iswSc      <= '1'            after tpd;
                     scSwEnable <= '1'            after tpd;
                  else
                     iswSc      <= scSwEnable     after tpd;
                  end if;
               end if;
            else
               if scPerCount = 49 then
                  itif <= '0';
               end if;
               scPerCount <= scPerCount + 1 after tpd;
            end if;
         end if;
      end if;
   end process;


   -- CCK Clock Generation
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         cckPerCount <= (others=>'0') after tpd;
         iasicCClk   <= '0'           after tpd;
      elsif rising_edge(sysClk250) then
         if scEnable = '0' then
            iasicCClk   <= '0'           after tpd;
            cckPerCount <= (others=>'0') after tpd;

         -- High Cycle
         elsif iasicCClk = '1' then
            if cckPerCount = 0 then
               iasicCClk   <= '0'          after tpd;
               cckPerCount <= icckNegWidth after tpd;
            else
               cckPerCount <= cckPerCount - 1 after tpd;
            end if;

         -- Low Cycle
         else
            if cckPerCount = 0 then
               iasicCClk   <= '1'          after tpd;
               cckPerCount <= icckPosWidth after tpd;
            else
               cckPerCount <= cckPerCount - 1 after tpd;
            end if;
         end if;
      end if;
   end process;


   -- MCK Clock Generation
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         mckPerCount  <= (others=>'0') after tpd;
         mckTotCount  <= (others=>'0') after tpd;
         mckDlyCount  <= (others=>'0') after tpd;
         iasicMClk    <= '0'           after tpd;
      elsif rising_edge(sysClk250) then

         -- Detect start of SC cycle
         if iasicSc = '1' and mckTotCount = 0 then
            mckPerCount <= (others=>'0') after tpd;
            mckDlyCount <= imckDelay     after tpd;
            mckTotCount <= "10000"       after tpd;
            iasicMClk   <= '0'           after tpd;

         -- Delay Period
         elsif mckDlyCount = 0 then

            -- Cycle was low
            if iasicMClk = '0' then
               if mckPerCount = 0 then
                  if mckTotCount /= 0 then
                     mckPerCount <= imckPosWidth after tpd;
                     iasicMClk   <= '1'          after tpd;
                  end if;
               else
                  mckPerCount <= mckPerCount - 1 after tpd;
               end if;
               
            -- Cycle was high
            else
               if mckPerCount = 0 then
                  mckPerCount <= imckNegWidth    after tpd;
                  mckTotCount <= mckTotCount - 1 after tpd;
                  iasicMClk   <= '0'             after tpd;
               else
                  mckPerCount <= mckPerCount - 1 after tpd;
               end if;
            end if;
         elsif iasicSc = '0' then
            mckDlyCount <= mckDlyCount - 1 after tpd;
         end if;
      end if;
   end process;


   -- ADC Clock Generation
   process ( sysClk250, intRst250 ) begin
      if intRst250 = '1' then
         adcPerCount  <= (others=>'0') after tpd;
         adcPhCount   <= (others=>'0') after tpd;
         adcPhZero    <= '0'           after tpd;
         adcPhZeroDly <= '0'           after tpd;
         iadcClk      <= '0'           after tpd;
         adcDlyCount  <= (others=>'0') after tpd;
         iadcValid    <= '0'           after tpd;
         adcTotCount  <= (others=>'0') after tpd;
      elsif rising_edge(sysClk250) then

         -- Preset period count on incoming start signal
         if intCmdEn = '1' then
            adcPhCount <= iadcPhase after tpd;
            adcPhZero  <= '0'      after tpd;
         elsif adcPhCount /= 0 then
            adcPhCount <= adcPhCount - 1 after tpd;
         else
            adcPhZero  <= '1'      after tpd;
         end if;

         -- Delayed copy of phase zero
         adcPhZeroDly <= adcPhZero after tpd;

         -- Adjust clock phase
         if adcPhZero = '1' and adcPhZeroDly = '0' then
            adcPerCount <= iadcClkPer   after tpd;
            iadcClk     <= '1'         after tpd;

         -- Transition Clock
         elsif adcPerCount = 0 then
            adcPerCount <= iadcClkPer   after tpd;
            iadcClk     <= not iadcClk after tpd;
         else
            adcPerCount <= adcPerCount - 1 after tpd;
         end if;

         -- Generate ADC Enable
         if iswSc = '1' and iadcValid = '0' and scAdcEnable = '1' then
            adcTotCount <= iperMclkCount + 1 after tpd;
            adcDlyCount <= iadcDelay         after tpd;
            iadcValid   <= '0'               after tpd;

         -- Delay Period
         elsif adcDlyCount = 0 then
            if adcPerCount = 0 and iadcClk = '0' then
               if adcTotCount = 1 then
                  iadcValid   <= '0' after tpd;
               else
                  if iadcValid = '1' then
                     adcTotCount <= adcTotCount - 1 after tpd;
                  end if;
                  iadcValid   <= '1' after tpd;
               end if;
            end if;
         elsif iswSc = '0' and scAdcEnable = '1' then
            adcDlyCount <= adcDlyCount - 1 after tpd;
         end if;
      end if;
   end process;

end ClockGen;

