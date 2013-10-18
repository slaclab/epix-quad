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
      -- Run control
      readStart   : in  sl;
      readValid   : in  sl;
      readDone    : in  sl;
      dataSend    : in  sl;
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

   type StateType is (
      IDLE_S,
      TEMP_DATA_S,
      SDD_DATA_S,
      STOP_S);
   signal state : StateType := IDLE_S;
   signal dataSendEdge,
      rdEn,
      ack : sl := '0';
   signal chPntr : integer range 0 to 15          := 0;
   signal req    : slv(7 downto 0)                := (others => '0');
   signal raddr  : slv((ADDR_WIDTH_G-1) downto 0) := (others => '0');
   signal rdata  : Slv16Array(0 to 7);

begin
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
   for i in 7 downto 0 generate
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
                     frameTxIn.frameTxEnable <= '1';
                     frameTxIn.frameTxSOF    <= '1';
                     frameTxIn.frameTxData   <= x"BABECAFE";  --start header
                     state                   <= TEMP_DATA_S;
                  end if;
                  ----------------------------------------------------------------------
               when TEMP_DATA_S =>
                  if adcValid((2*chPntr)+1) = '1' then
                     frameTxIn.frameTxEnable <= '1';
                     frameTxIn.frameTxData   <= x"0000" & adcData((2*chPntr)+1);
                     chPntr                  <= chPntr + 1;
                     if chPntr = 7 then
                        chPntr <= 0;
                        state  <= SDD_DATA_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when SDD_DATA_S =>
                  rdEn                    <= '1';
                  frameTxIn.frameTxEnable <= '1';
                  frameTxIn.frameTxData   <= x"0000" & rdata(chPntr);
                  raddr                   <= raddr + 1;
                  if raddr = MAX_ADDR_C then
                     raddr  <= (others => '0');
                     chPntr <= chPntr + 1;
                     if chPntr = 7 then
                        chPntr <= 0;
                        ack    <= '1';  --high for min. 2 cycles
                        state  <= STOP_S;
                     end if;
                  end if;
                  ----------------------------------------------------------------------
               when STOP_S =>
                  ack                     <= '0';
                  frameTxIn.frameTxEnable <= '1';
                  frameTxIn.frameTxEOF    <= '1';
                  frameTxIn.frameTxData   <= x"BEEFCAFE";  --stop header             
                  state                   <= IDLE_S;
                  ----------------------------------------------------------------------
            end case;
         end if;
      end if;
   end process;

end rtl;

