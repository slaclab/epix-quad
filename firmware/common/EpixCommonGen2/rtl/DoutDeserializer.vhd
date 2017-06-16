-------------------------------------------------------------------------------
-- Title         : DoutDeserializer
-- Project       : Epix10ka Detector
-------------------------------------------------------------------------------
-- File          : DoutDeserializer.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 6/16/2017
-------------------------------------------------------------------------------
-- Description: Deserializes EPIX10KA digital outputs. The ASIC has one output per 
-- 4 banks therefore 4 readout clock cycles are needed to output digital data.
-- It takes 10 roClk cycles before first valid data appears (verified with chipscope)
-- and the asicLatency should be set correspondingly for valid image readout.
-- Dout FIFOs mapping:
-- doutOut(15): ASIC3_BANK3
-- doutOut(14): ASIC3_BANK2
-- doutOut(13): ASIC3_BANK1
-- doutOut(12): ASIC3_BANK0
-- doutOut(11): ASIC2_BANK3
-- doutOut(10): ASIC2_BANK2
-- doutOut(9):  ASIC2_BANK1
-- doutOut(8):  ASIC2_BANK0
-- doutOut(7):  ASIC1_BANK3
-- doutOut(6):  ASIC1_BANK2
-- doutOut(5):  ASIC1_BANK1
-- doutOut(4):  ASIC1_BANK0
-- doutOut(3):  ASIC0_BANK3
-- doutOut(2):  ASIC0_BANK2
-- doutOut(1):  ASIC0_BANK1
-- doutOut(0):  ASIC0_BANK0
-------------------------------------------------------------------------------
-- This file is part of 'Epix Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 6/16/2017: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;

entity DoutDeserializer is 
   generic (
      TPD_G       : time := 1 ns
   );
   port ( 
      clk         : in  sl;
      rst         : in  sl;
      acqBusy     : in  sl;
      asicDout    : in  slv(3 downto 0);
      asicRoClk   : in  sl;
      asicLatency : in  slv(31 downto 0);
      doutOut     : out Slv2Array(15 downto 0);
      doutRd      : in  slv(15 downto 0)
   );
end DoutDeserializer;


-- Define architecture
architecture RTL of DoutDeserializer is
   
   type StateType is (IDLE_S, WAIT_S, STORE_S);
   
   type FsmType is record
      state          : StateType;
      stCnt          : slv(31 downto 0);
      asicRoClk      : sl;
      acqBusy        : sl;
      asicLatency    : slv(31 downto 0);
      fifoIn         : Slv1Array(15 downto 0);
      fifoWr         : slv(15 downto 0);
      fifoRst        : sl;
   end record;

   constant FSM_INIT_C : FsmType := (
      state          => IDLE_S,
      stCnt          => (others=>'0'),
      asicRoClk      => '0',
      acqBusy        => '0',
      asicLatency    => (others=>'0'),
      fifoIn         => (others=>(others=>'0')),
      fifoWr         => (others=>'0'),
      fifoRst        => '1'
   );
   
   signal f   : FsmType := FSM_INIT_C;
   signal fin : FsmType;
   
begin
   
   comb : process (rst, f, asicDout, asicLatency, asicRoClk) is
      variable fv             : FsmType;
      variable roClkRising    : sl;
      variable acqBusyRising  : sl;
   begin
      fv := f;
      
      -- sync
      fv.asicLatency := asicLatency;
      fv.asicRoClk := asicRoClk;
      fv.acqBusy := acqBusy;
      
      -- detect rising edge
      if f.asicRoClk = '0' and asicRoClk = '1' then
         roClkRising := '1';
      else 
         roClkRising := '0';
      end if;
      
      -- detect rising edge
      if f.acqBusy = '0' and acqBusy = '1' then
         acqBusyRising := '1';
      else 
         acqBusyRising := '0';
      end if;
      
      case f.state is
         when IDLE_S =>
            fv.fifoRst := '1';
            fv.stCnt := (others=>'0');
            fv.fifoIn := (others=>(others=>'0'));
            if roClkRising = '1' then
               fv.state := WAIT_S;
            end if;
         
         when WAIT_S =>
            -- wait configured roClk cycles
            -- before deserializing
            fv.fifoRst := '0';
            if roClkRising = '1' then
               if f.stCnt < f.asicLatency then
                  fv.stCnt := f.stCnt + 1;
               else
                  fv.stCnt := (others=>'0');
                  fv.state := STORE_S;
               end if;
            end if;
         
         when STORE_S =>
            if roClkRising = '1' then
               -- write douts to appropriate FIFOs on every roClkRising edge
               fv.fifoIn(0 +conv_integer(f.stCnt(1 downto 0)))(0) := asicDout(0);
               fv.fifoIn(4 +conv_integer(f.stCnt(1 downto 0)))(0) := asicDout(1);
               fv.fifoIn(8 +conv_integer(f.stCnt(1 downto 0)))(0) := asicDout(2);
               fv.fifoIn(12+conv_integer(f.stCnt(1 downto 0)))(0) := asicDout(3);
               if f.stCnt(1 downto 0) = "00" then
                  fv.fifoWr := "0001000100010001";
               elsif f.stCnt(1 downto 0) = "01" then
                  fv.fifoWr := "0010001000100010";
               elsif f.stCnt(1 downto 0) = "10" then
                  fv.fifoWr := "0100010001000100";
               else
                  fv.fifoWr := "1000100010001000";
               end if;
               -- count rising edges of roClk
               if f.stCnt = x"ffffffff" then -- should not happen
                  fv.state := IDLE_S;
               else
                  fv.stCnt := f.stCnt + 1;
               end if;
            else
               fv.fifoWr := (others=>'0');
            end if;
         
         when others =>
            fv.state := IDLE_S;
         
      end case;
      
      -- reset FSM when acquisition start is detected
      if acqBusyRising = '1' then
         fv.state := IDLE_S;
      end if;
      
      -- reset logic
      
      if (rst = '1') then
         fv := FSM_INIT_C;
      end if;

      -- outputs
      fin         <= fv;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         f <= fin after TPD_G;
      end if;
   end process seq;
   
   -- data out FIFOs
   G_DoutFifos : for i in 0 to 15 generate
      DoutFifo_U : entity work.FifoMux
      generic map (
         WR_DATA_WIDTH_G   => 1,
         RD_DATA_WIDTH_G   => 2,
         GEN_SYNC_FIFO_G   => true,
         ADDR_WIDTH_G      => 8,
         FWFT_EN_G         => true,
         LITTLE_ENDIAN_G   => true
      )
      port map (
         rst      => f.fifoRst,
         wr_clk   => clk,
         wr_en    => f.fifoWr(i),
         din      => f.fifoIn(i),
         rd_clk   => clk,
         rd_en    => doutRd(i),
         dout     => doutOut(i)
      );
   end generate;

end RTL;

