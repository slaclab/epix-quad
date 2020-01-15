-------------------------------------------------------------------------------
-- Title      : Ping pong readout buffer
-- Project    : EPIX Readout
-------------------------------------------------------------------------------
-- File       : EpixRowBlockRam.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block ram to handle a row.
-- Ping pongs between two rows' worth of blockram to accommodate reordering of
-- data out.
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

use work.EpixPkgGen2.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity EpixRowBlockRam is
   generic (
      TPD_G : time := 1 ns;
      ASIC_TYPE_G  : AsicType
   );
   port (
      -- Clocks and reset
      sysClk              : in    std_logic;
      sysClkRst           : in    std_logic;

      -- Data in interface
      wrReset             : in    std_logic;
      wrData              : in    std_logic_vector(15 downto 0);
      wrEn                : in    std_logic;

      -- Data out interface
      rdOrder             : in    std_logic;
      rdReady             : out   std_logic;
      rdStart             : in    std_logic;
      overflow            : out   std_logic;
      rdData              : out   std_logic_vector(15 downto 0);
      dataValid           : out   std_logic;

      -- Toggle used for checks and generating test patterns
      testPattern         : in    std_logic

   );
end EpixRowBlockRam;


-- Define architecture
architecture EpixRowBlockRam of EpixRowBlockRam is
   
   constant NCOL_C       : integer          := getNumColumns(ASIC_TYPE_G);

   signal iRdEn    : std_logic;
   signal iRdInc   : std_logic;
   signal iRdDec   : std_logic;
   signal iRdSet   : std_logic;
   signal iRdAddr  : std_logic_vector(7 downto 0);
   signal iWrAddr  : std_logic_vector(7 downto 0);
   signal iRdCol   : unsigned(6 downto 0);
   signal iRdRow   : unsigned(0 downto 0);
   signal iWrCol   : unsigned(6 downto 0);
   signal iWrRow   : unsigned(0 downto 0);
   signal iRdColTp : unsigned(6 downto 0);
   signal iRdRowTp : unsigned(0 downto 0);
   signal iWrRowRising   : std_logic;
   signal iWrRowFalling  : std_logic;
   signal iRdStartEdge   : std_logic;
   signal iRdReady       : std_logic;
   signal iRdData        : std_logic_vector(15 downto 0);
   type state is (IDLE_S, SET_ROW_S, RD_FWD_S, RD_BKD_S);
   signal curState : state := IDLE_S;
   signal nxtState : state := IDLE_S;

begin

   --Choose normal data or test pattern for output
   rdData <= iRdData when testPattern = '0' else
             x"00" & std_logic_vector(iRdRowTp) & std_logic_vector(iRdColTp);
   --Test pattern row and column should lag by 1 to match
   --the blockram latency.
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wrReset = '1' then
            iRdColTp <= (others => '0');
            iRdRowTp <= (others => '0');
         else
            iRdColTp <= iRdCol;
            iRdRowTp <= iRdRow;
         end if;
      end if;
   end process;

   --Map addresses to flat space
   iRdAddr <= std_logic_vector(iRdRow) & std_logic_vector(iRdCol);
   iWrAddr <= std_logic_vector(iWrRow) & std_logic_vector(iWrCol);

   --Write addressing.  Write sequentially into memory.
   --Upper block will reset at the beginning of a readout
   --cycle.  Then just write in order.
   --Increment only on a write enable.
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wrReset = '1' then
            iWrCol <= (others => '0');
            iWrRow <= (others => '0');
         elsif wrEn = '1' then
            if iWrCol = NCOL_C-1 then
               iWrCol <= (others => '0');
               iWrRow <= iWrRow + 1;
            else 
               iWrCol <= iWrCol + 1;
            end if; 
         end if;
      end if;
   end process;

   --Read addressing.  Triggered when iWrRow changes state.
   --On this condition, dump last row out (to FIFO).
   --Asynchronous state outputs and next state logic
   process(curState,rdOrder,iRdCol,iRdStartedge) begin
      --Defaults 
      iRdEn     <= '0';
      iRdInc    <= '0';
      iRdDec    <= '0';
      iRdSet    <= '0';
      nxtState <= curState;
      case curState is 
         when IDLE_S    =>
            if iRdStartEdge = '1' then
               nxtState <= SET_ROW_S;
            end if;
         when SET_ROW_S =>
            iRdSet <= '1';
            if rdOrder = '0' then
               nxtState <= RD_FWD_S;
            else
               nxtState <= RD_BKD_S;
            end if;
         when RD_FWD_S  =>
            iRdInc    <= '1';
            iRdEn     <= '1';
            if (iRdCol = NCOL_C-1) then
               nxtState <= IDLE_S;
            end if;
         when RD_BKD_S  =>
            iRdDec    <= '1';
            iRdEn     <= '1';
            if (iRdCol = 0) then
               nxtState <= IDLE_S;
            end if;
      end case;
   end process;
   --Synchronous state switch
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            curState <= IDLE_S;
         else
            curState <= nxtState;
         end if;   
      end if;
   end process;

   --Data valid should lag read enable by 1 since data
   --doesn't appear on the output until rdEn + a clock
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wrReset = '1' then
            dataValid <= '0';
         else
            dataValid <= iRdEn;
         end if;
      end if;
   end process;

   --Ready and overflow detection
   rdReady <= iRdReady;
   --
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wrReset = '1' then
            iRdReady <= '0';
            overflow  <= '0';            
         elsif iRdReady = '1' and (iWrRowRising = '1' or iWrRowFalling = '1') then
            overflow <= '1';
         elsif iRdReady = '1' and iRdStartEdge = '1' then
            iRdReady <= '0';
         elsif iRdReady = '0' and (iWrRowRising = '1' or iWrRowFalling = '1') then
            iRdReady <= '1';
         end if;
      end if;
   end process;

   --Edge detection for changing rows 
   U_RowChangeEdge : entity surf.SynchronizerEdge
      port map (
         clk         => sysClk,
         rst         => sysClkRst,
         dataIn      => std_logic(iWrRow(0)),
         risingEdge  => iWrRowRising,
         fallingEdge => iWrRowFalling
      );
   --Edge detection for read initiation
   U_StartReadEdge : entity surf.SynchronizerEdge
      port map (
         clk         => sysClk,
         rst         => sysClkRst,
         dataIn      => rdStart,
         risingEdge  => iRdStartEdge
      );

   --Set read row to opposite of that being written right now
   --Implement increment or decrement for read column
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or wrReset = '1' then
            iRdRow <= (others => '0');
            iRdCol <= (others => '0');
         else
            if iRdSet = '1' then
               iRdRow <= iWrRow + 1;
               if rdOrder = '0' then
                  iRdCol <= (others => '0');
               else
                  iRdCol <= to_unsigned(NCOL_C-1,7);
               end if;
            elsif iRdInc = '1' then
               iRdCol <= iRdCol + 1;
            elsif iRdDec = '1' then
               iRdCol <= iRdCol - 1;
            end if;
         end if;
      end if;
   end process;

   
   --Instantiate a blockram for the ping-pong scheme
   --Size is minimum 2 * 96 = 192 values (ePix 100)
   --                2 * 48 = 96 values (ePix 10k)
   U_RowBuffer : entity surf.SimpleDualPortRam
      generic map (
         DATA_WIDTH_G => 16,
         ADDR_WIDTH_G => 8
      )
      port map (
         --Write ports
         clka  => sysClk,
         wea   => wrEn,
         addra => iWrAddr,
         dina  => wrData,
         --Read ports
         clkb  => sysClk,
         enb   => iRdEn,
         addrb => iRdAddr,
         doutb => iRdData 
      );

end EpixRowBlockRam;

