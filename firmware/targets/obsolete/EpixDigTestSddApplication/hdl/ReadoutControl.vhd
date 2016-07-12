-------------------------------------------------------------------------------
-- Title         : Acquisition Control Block
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : ReadoutControl.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- Acquisition control block
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.EpixTypes.all;
use work.Pgp2AppTypesPkg.all;

entity ReadoutControl is
   generic (
      ADDR_WIDTH_G : integer := 13);
   port (
      -- Clocks and reset
      sysClk      : in  sl;
      sysClkRst   : in  sl;
      -- Configuration
      epixConfig  : in  EpixConfigType;
      -- Data for headers
      acqCount    : in  slv(31 downto 0);
      seqCount    : out slv(31 downto 0);
      -- Run control
      acqStart    : in  sl;
      readValid   : in  slv(MAX_OVERSAMPLE-1 downto 0);
      readDone    : out sl;
      acqBusy     : in  sl;
      dataSend    : in  sl;
      readTps     : in  sl;
      -- ADC Data
      adcValid    : in  slv(19 downto 0);
      adcData     : in  word16_array(19 downto 0);
      -- Slow ADC data
      slowAdcData : in  word16_array(15 downto 0);
      -- Data Out
      frameTxIn   : out UsBuff32InType;
      frameTxOut  : in  UsBuff32OutType;
      -- MPS
      mpsOut      : out sl);
end ReadoutControl;

-- Define architecture
architecture rtl of ReadoutControl is
   constant MAX_ADDR_C : slv((ADDR_WIDTH_G-1) downto 0) := (others => '1');
   constant MAX_CH_C   : integer                        := 8;

   type StateType is (
      IDLE_S,
      START_HDR_S,
      SDD_DATA_S,
      TEMP_DATA_S,
      STOP_S);
   signal state : StateType := IDLE_S;
   signal dataSendEdge,
      rdEn,
      ack : sl := '0';
   signal chPntr : integer range 0 to (MAX_CH_C-1) := 0;
   signal req    : slv((MAX_CH_C-1) downto 0)      := (others => '0');
   signal raddr  : slv((ADDR_WIDTH_G-1) downto 0)  := (others => '0');
   signal rdata  : Slv16Array(0 to (MAX_CH_C-1));
   signal intSeqCount : slv(31 downto 0) := (others => '0');
   signal seqCountEnable : sl := '0';

begin
   -- Sequence/frame counter goes out to register control
   seqCount <= intSeqCount;
   -- Default mps to '0' for now.
   mpsOut <= '0';

   -- Edge detection for signals that interface with other blocks
   U_DataSendEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => dataSend,
         risingEdge => dataSendEdge);

   GEN_BUFFER :
   for i in (MAX_CH_C-1) downto 0 generate
      U_BurstBuffer : entity work.BurstBuffer
         generic map (
            ADDR_WIDTH_G => ADDR_WIDTH_G)
         port map (
            sysClk    => sysClk,
            sysClkRst => sysClkRst,
            trig      => dataSendEdge,
            ack       => ack,
            raddr     => raddr,
            rdata     => rdata(i),
            req       => req(i),
            adcValid  => adcValid(2*i),
            adcData   => adcData(2*i));     
   end generate GEN_BUFFER;

   process (sysClk)
   begin
      if rising_edge(sysClk) then
         rdEn                    <= '0';
         frameTxIn.frameTxEnable <= '0';
         frameTxIn.frameTxSOF    <= '0';
         frameTxIn.frameTxEOF    <= '0';
         frameTxIn.frameTxEOFE   <= '0';
         readDone                <= '0';
         seqCountEnable          <= '0';
         if sysClkRst = '1' then
            chPntr    <= 0;
            raddr     <= (others => '0');
            ack       <= '0';
            frameTxIn <= UsBuff32InInit;
            state     <= IDLE_S;
         elsif (frameTxOut.frameTxAfull = '0') and (rdEn = '0') then
            case (state) is
               ----------------------------------------------------------------------
               when IDLE_S =>
                  if uAnd(req) = '1' then
                     state <= START_HDR_S;
                     seqCountEnable <= '1';
                  end if;
                  ----------------------------------------------------------------------
               when START_HDR_S =>
                  chPntr <= chPntr + 1;
                  case (chPntr) is
                     when 0 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxSOF    <= '1';
                        frameTxIn.frameTxData   <= (others => '0');
                     when 1 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= x"0000" & acqCount(15 downto 0);
                     when 2 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= intSeqCount;
                     when 3 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= (others => '0');
                     when 4 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= (others => '0');
                     when 5 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= (others => '0');
                     when 6 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= (others => '0');
                     when 7 =>
                        frameTxIn.frameTxEnable <= '1';
                        frameTxIn.frameTxData   <= (others => '0');
                        chPntr                  <= 0;
                        state                   <= SDD_DATA_S;
                     when others =>
                        frameTxIn.frameTxData <= (others => '0');
                  end case;
                  ----------------------------------------------------------------------
               when SDD_DATA_S =>
                  rdEn  <= '1';
                  raddr <= raddr + 1;
                  if raddr(0) = '0' then
                     if (epixConfig.testPattern = '0') then
                        frameTxIn.frameTxData(15 downto 0)  <= rdata(chPntr);
                     else
                        frameTxIn.frameTxData(15 downto 0)  <= conv_std_logic_vector(chPntr,3) & raddr;
                     end if;
                     frameTxIn.frameTxData(31 downto 16) <= x"0000";
                  else
                     frameTxIn.frameTxEnable             <= '1';
                     if (epixConfig.testPattern = '0') then 
                        frameTxIn.frameTxData(31 downto 16) <= rdata(chPntr);
                     else
                        frameTxIn.frameTxData(31 downto 16) <= conv_std_logic_vector(chPntr,3) & raddr;
                     end if;
                  end if;
                  if raddr = MAX_ADDR_C then
                     frameTxIn.frameTxEnable <= '1';  --force write if odd size
                     raddr                   <= (others => '0');
                     chPntr                  <= chPntr + 1;
                     if chPntr = (MAX_CH_C-1) then
                        chPntr <= 0;
                        state  <= TEMP_DATA_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when TEMP_DATA_S =>
                  ack <= '1';
                  if adcValid((2*chPntr)+1) = '1' then
                     chPntr <= chPntr + 1;
                     raddr  <= raddr + 1;
                     if raddr(0) = '0' then
                        frameTxIn.frameTxData(15 downto 0)  <= adcData((2*chPntr)+1);
                        frameTxIn.frameTxData(31 downto 16) <= x"0000";
                     else
                        frameTxIn.frameTxEnable             <= '1';
                        frameTxIn.frameTxData(31 downto 16) <= adcData((2*chPntr)+1);
                     end if;
                     if chPntr = (MAX_CH_C-1) then
                        frameTxIn.frameTxEnable <= '1';  --force write if odd size
                        chPntr                  <= 0;
                        raddr                   <= (others => '0');
                        state                   <= STOP_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when STOP_S =>
                  ack                     <= '0';
                  frameTxIn.frameTxEnable <= '1';
                  frameTxIn.frameTxEOF    <= '1';
                  frameTxIn.frameTxData   <= x"00000000";  --stop header 
                  readDone                <= '1';
                  state                   <= IDLE_S;
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

   --Sequence/frame counter
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         intSeqCount <= (others => '0');
      elsif rising_edge(sysClk) then
         if epixConfig.seqCountReset = '1' then
            intSeqCount <= (others => '0');
         elsif seqCountEnable = '1' then
            intSeqCount <= intSeqCount + 1;
          end if;
      end if;
   end process;

end rtl;

