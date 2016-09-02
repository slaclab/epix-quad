-------------------------------------------------------------------------------
-- Title         : Petacache SliceCore FPGA, FMC Dimm ID Prom Block
-- Project       : Petacache RCE Board
-------------------------------------------------------------------------------
-- File          : SliceDimmId.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/19/2007
-------------------------------------------------------------------------------
-- Description:
-- Contains controller for DS2411 serial ID Prom On Flash DIMM.
-- SerClkIn is asserted for one clock every 6.55us.
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/19/2007: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity SliceDimmId is 
   port ( 

      -- PGP Clock & Reset Signals
      pgpClk    : in  std_logic;
      pgpRst    : in  std_logic;
      serClkEn  : in  std_logic;

      -- FMC DIMM ID Prom Signals
      fdSerDin  : in  std_logic;
      fdSerDout : out std_logic;
      fdSerDenL : out std_logic;

      -- Serial Number
      fdSerial  : out std_logic_vector(63 downto 0);
      fdValid   : out std_logic
   );
end SliceDimmId;


-- Define architecture
architecture SliceDimmId of SliceDimmId is

   -- Local Signals
   signal setOutLow   : std_logic;
   signal fdValidSet  : std_logic;
   signal bitSet      : std_logic;
   signal bitCntRst   : std_logic;
   signal bitCntEn    : std_logic;
   signal timeCntRst  : std_logic;
   signal timeCnt     : std_logic_vector(6  downto 0);
   signal bitCnt      : std_logic_vector(5  downto 0);

   -- States
   constant ST_START : std_logic_vector(2 downto 0) := "000";
   constant ST_RESET : std_logic_vector(2 downto 0) := "001";
   constant ST_WAIT  : std_logic_vector(2 downto 0) := "010";
   constant ST_WRITE : std_logic_vector(2 downto 0) := "011";
   constant ST_PAUSE : std_logic_vector(2 downto 0) := "100";
   constant ST_READ  : std_logic_vector(2 downto 0) := "101";
   constant ST_DONE  : std_logic_vector(2 downto 0) := "110";
   signal   curState : std_logic_vector(2 downto 0);
   signal   nxtState : std_logic_vector(2 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Dout is always zero
   fdSerDout <= '0';
   fdSerDenL <= not setOutLow;


   -- Sync state logic
   process ( pgpClk, pgpRst ) begin
      if pgpRst = '1' then
         fdSerial  <= (others=>'0') after tpd;
         fdValid   <= '0'           after tpd;
         timeCnt   <= (others=>'0') after tpd;
         bitCnt    <= (others=>'0') after tpd;
         curState  <= ST_START      after tpd;
      elsif rising_edge(pgpClk) then

         -- Shift new serial data
         if fdValidSet = '1' then
            fdValid <= '1' after tpd;
         end if;

         -- Bit Set Of Received Data
         if bitSet = '1' then
            fdSerial(conv_integer(bitCnt)) <= fdSerDin after tpd;
         end if;

         -- Bit Counter
         if bitCntRst = '1' then
            bitCnt <= (others=>'0') after tpd;
         elsif bitCntEn = '1' then
            bitCnt <= bitCnt + 1 after tpd;
         end if;

         -- Time Counter
         if timeCntRst = '1' then
            timeCnt <= (others=>'0') after tpd;
         elsif serClkEn = '1' then
            timeCnt <= timeCnt + 1 after tpd;
         end if;

         -- State
         curState <= nxtState after tpd;

      end if;
   end process;


   -- State Machine
   process ( curState, timeCnt, bitCnt, serClkEn  ) begin

      -- State machine
      case curState is

         -- Start State
         when ST_START =>
            setOutLow   <= '0';
            fdValidSet  <= '0';
            bitSet      <= '0';
            bitCntRst   <= '1';
            bitCntEn    <= '0';

            -- Wait 830us
            if timeCnt = 127 then
               nxtState   <= ST_RESET;
               timeCntRst <= '1';
            else
               nxtState   <= curState;
               timeCntRst <= '0';
            end if;

         -- Reset Link
         when ST_RESET =>
            setOutLow   <= '1';
            fdValidSet  <= '0';
            bitSet      <= '0';
            bitCntRst   <= '1';
            bitCntEn    <= '0';

            -- Continue for 500us
            if timeCnt = 77 then
               nxtState   <= ST_WAIT;
               timeCntRst <= '1';
            else
               nxtState   <= curState;
               timeCntRst <= '0';
            end if;

         -- Wait after reset
         when ST_WAIT =>
            setOutLow   <= '0';
            fdValidSet  <= '0';
            bitSet      <= '0';
            bitCntRst   <= '1';
            bitCntEn    <= '0';

            -- Wait 500us
            if timeCnt = 77 then
               nxtState   <= ST_WRITE;
               timeCntRst <= '1';
            else
               nxtState   <= curState;
               timeCntRst <= '0';
            end if;

         -- Write Command Bits To PROM (0x33)
         when ST_WRITE =>
            fdValidSet  <= '0';
            bitSet      <= '0';

            -- Assert start pulse for 12us
            if timeCnt < 2 then
               timeCntRst <= '0';
               bitCntEn   <= '0';
               bitCntRst  <= '0';
               setOutLow  <= '1';
               bitCntEn   <= '0';
               nxtState   <= curState;

            -- Output write value for 52uS
            elsif timeCnt < 10 then
               if bitCnt = 2 or bitCnt = 3 or bitCnt = 6 or bitCnt = 7 then 
                 setOutLow <= '1';
               else
                 setOutLow <= '0';
               end if;
               nxtState   <= curState;
               timeCntRst <= '0';
               bitCntRst  <= '0';
               bitCntEn   <= '0';

            -- Recovery Time
            elsif timeCnt < 12 then
               setOutLow  <= '0';
               nxtState   <= curState;
               timeCntRst <= '0';
               bitCntRst  <= '0';
               bitCntEn   <= '0';

            -- Done with bit
            else
               timeCntRst <= '1';
               bitCntEn   <= '1';
               setOutLow  <= '0';

               -- Done with write
               if bitCnt = 7 then
                  bitCntRst <= '1';
                  nxtState  <= ST_PAUSE;
               else
                  bitCntRst <= '0';
                  nxtState  <= curState;
               end if;
            end if;

         -- Delay after write
         when ST_PAUSE =>
            setOutLow   <= '0';
            fdValidSet  <= '0';
            bitSet      <= '0';
            bitCntRst   <= '1';
            bitCntEn    <= '0';

            -- Wait 60us
            if timeCnt = 10 then
               nxtState   <= ST_READ;
               timeCntRst <= '1';
            else
               nxtState   <= curState;
               timeCntRst <= '0';
            end if;

         -- Read Data Bits From Prom
         when ST_READ =>
            fdValidSet  <= '0';

            -- Assert start pulse for 12us
            if timeCnt < 2 then
               timeCntRst <= '0';
               bitCntEn   <= '0';
               bitCntRst  <= '0';
               setOutLow  <= '1';
               bitSet     <= '0';
               nxtState   <= curState;

            -- Sample data at 13.1uS
            elsif timeCnt = 2 and serClkEn = '1' then
               setOutLow  <= '0';
               bitCntEn   <= '0';
               timeCntRst <= '0';
               bitCntRst  <= '0';
               bitSet     <= '1';
               nxtState   <= curState;

            -- Recovery
            elsif timeCnt < 12 then
               setOutLow  <= '0';
               timeCntRst <= '0';
               bitCntEn   <= '0';
               bitSet     <= '0';
               bitCntRst  <= '0';
               nxtState   <= curState;

            -- Done with bit
            else
               setOutLow  <= '0';
               timeCntRst <= '1';
               bitCntEn   <= '1';
               bitSet     <= '0';

               -- Done with write
               if bitCnt = 63 then
                  bitCntRst <= '1';
                  nxtState  <= ST_DONE;
               else
                  bitCntRst <= '0';
                  nxtState  <= curState;
               end if;
            end if;

         -- Done with read
         when ST_DONE =>
            fdValidSet <= '1';
            timeCntRst <= '1';
            bitCntRst  <= '1';
            bitCntEn   <= '0';
            setOutLow  <= '0';
            bitSet     <= '0';
            nxtState   <= curState;

         when others =>
            fdValidSet <= '0';
            timeCntRst <= '1';
            bitCntRst  <= '1';
            bitCntEn   <= '0';
            setOutLow  <= '0';
            bitSet     <= '0';
            nxtState   <= ST_START;
      end case;
   end process;

end SliceDimmId;

