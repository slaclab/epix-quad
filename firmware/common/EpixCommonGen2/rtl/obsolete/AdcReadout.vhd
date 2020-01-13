-------------------------------------------------------------------------------
-- Title      : ADC Readout Control
-- Project    : ePixGen2
-------------------------------------------------------------------------------
-- File       : AdcReadout.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-- Receives ADC Data from an AD9592 chip.
-- Designed specifically for Xilinx 7 series FPGAs
-- Starting point from Ben Reese's AdcReadout7 from HPS project.
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

entity AdcReadout is
   generic (
      TPD_G             : time                 := 1 ns;
      NUM_CHANNELS_G    : natural range 1 to 8 := 8;
      IDELAYCTRL_FREQ_G : real                 := 200.0;
      ADC_INVERT_CH     : slv(7 downto 0)      := "00000000"
   );
   port (
      -- Master system clock 
      sysClk       : in sl;
      sysClkRst    : in sl;
      -- ADC configuration
      frameDelay   : in  slv(4 downto 0);
      -- The following is a hack to keep our data structures consistent between
      -- fully used and not fully used ADC channels.
      dataDelay    : in  Slv5Array(7 downto 0);
      --dataDelay    : in  Slv5Array(NUM_CHANNELS_G-1 downto 0);
      -- ADC demux interface
      adcValid     : out slv(NUM_CHANNELS_G-1 downto 0);
      adcData      : out Slv16Array(NUM_CHANNELS_G-1 downto 0);
      -- ADC interface signals
      adcFClkP     : in sl;
      adcFClkN     : in sl;
      adcDClkP     : in sl;
      adcDClkN     : in sl;
      adcChP       : in slv(NUM_CHANNELS_G-1 downto 0);
      adcChN       : in slv(NUM_CHANNELS_G-1 downto 0)
   );
end AdcReadout;

-- Define architecture
architecture rtl of AdcReadout is

   -------------------------------------------------------------------------------------------------
   -- ADC Readout Clocked Registers
   -------------------------------------------------------------------------------------------------
   type AdcRegType is record
      slip       : sl;
      count      : slv(8 downto 0);
      locked     : sl;
      fifoWrData : Slv16Array(NUM_CHANNELS_G-1 downto 0);
      fifoWrEn   : sl;
   end record;

   constant ADC_REG_INIT_C : AdcRegType := (
      slip       => '0',
      count      => (others => '0'),
      locked     => '0',
      fifoWrData => (others => (others => '0')),
      fifoWrEn   => '0');

   signal adcR   : AdcRegType := ADC_REG_INIT_C;
   signal adcRin : AdcRegType;
      
   -- Local Signals
   signal tmpAdcClk      : sl;
   signal adcBitClkIo    : sl;
   signal adcBitClkIoInv : sl;
   signal adcBitClkR     : sl;
   signal adcBitRst      : sl;
   
   signal adcFramePad   : sl;
   signal adcFrame      : slv(13 downto 0);
   signal adcDataPad    : slv(NUM_CHANNELS_G-1 downto 0);
   signal adcDataPadOut : slv(NUM_CHANNELS_G-1 downto 0);
   signal iAdcData      : Slv14Array(NUM_CHANNELS_G-1 downto 0);
   signal fifoDataOut   : slv(NUM_CHANNELS_G*16-1 downto 0);
   signal fifoDataIn    : slv(NUM_CHANNELS_G*16-1 downto 0);   

   signal iAdcValid     : slv(NUM_CHANNELS_G-1 downto 0);
   
   
begin

   -------------------------
   -- Clocking and resets --
   -------------------------
   AdcClk_I_Ibufds : IBUFDS
      generic map (
         DIFF_TERM  => true,
         IOSTANDARD => "LVDS_25"
      )
      port map (
         I  => adcDClkP,
         IB => adcDClkN,
         O  => tmpAdcClk
      );

   -- IO Clock
   U_BUFIO : BUFIO
      port map (
         I => tmpAdcClk,
         O => adcBitClkIo
      );
   adcBitClkIoInv <= not adcBitClkIo;

   -- Regional clock (ADC output clock divided by 7)
   U_AdcBitClkR : BUFR
      generic map (
         SIM_DEVICE  => "7SERIES",
         BUFR_DIVIDE => "7"
      )
      port map (
         I   => tmpAdcClk,
         O   => adcBitClkR,
         CE  => '1',
         CLR => '0'
      );

   -- Regional clock reset
   ADC_BITCLK_RST_SYNC : entity surf.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 5
      )
      port map (
         clk      => adcBitClkR,
         asyncRst => sysClkRst,
         syncRst  => adcBitRst);

   --------------------------------
   -- Deserializers              --
   --------------------------------
   -- Frame signal input
   U_FrameIn : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => adcFClkP,
         IB => adcFClkN,
         O  => adcFramePad);

   U_FRAME_DESERIALIZER : entity work.AdcDeserializer
      generic map (
         TPD_G             => TPD_G,
         IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G
      )
      port map (
         clkIo    => adcBitClkIo,
         clkIoInv => adcBitClkIoInv,
         clkR     => adcBitClkR,
         rst      => adcBitRst,
         slip     => adcR.slip,
         sysClk   => sysClk,
         setDelay => frameDelay,
         curDelay => open,
         iData    => adcFramePad,
         oData    => adcFrame);

   --------------------------------
   -- Data Input, 8 channels
   --------------------------------
   GenData : for i in NUM_CHANNELS_G-1 downto 0 generate

      -- Frame signal input
      U_DataIn : IBUFDS
         generic map (
            DIFF_TERM => true)
         port map (
            I  => adcChP(i),
            IB => adcChN(i),
            O  => adcDataPadOut(i));
      
      adcDataPad(i) <= adcDataPadOut(i) when ADC_INVERT_CH(i) = '0' else not adcDataPadOut(i);

      U_DATA_DESERIALIZER : entity work.AdcDeserializer
         generic map (
            TPD_G             => TPD_G,
            IDELAYCTRL_FREQ_G => IDELAYCTRL_FREQ_G
         )
         port map (
            clkIo    => adcBitClkIo,
            clkIoInv => adcBitClkIoInv,
            clkR     => adcBitClkR,
            rst      => adcBitRst,
            slip     => adcR.slip,
            sysClk   => sysClk,
            setDelay => dataDelay(i),
            iData    => adcDataPad(i),
            oData    => iAdcData(i));
   end generate;

   -------------------------------------------------------------------------------------------------
   -- ISERDESE2 bit slip logic
   -------------------------------------------------------------------------------------------------
   adcComb : process (adcR, iAdcData, adcFrame) is
      variable v : AdcRegType;
   begin
      v := adcR;

      ----------------------------------------------------------------------------------------------
      -- Slip bits until correct alignment seen
      ----------------------------------------------------------------------------------------------
      v.slip := '0';

      if (adcR.count = 0) then
         if (adcFrame = "11111110000000") then
            v.locked := '1';
         else
            v.locked := '0';
            v.slip   := '1';
            v.count  := adcR.count + 1;
         end if;
      end if;

      if (adcR.count /= 0) then
         v.count := adcR.count + 1;
      end if;

      ----------------------------------------------------------------------------------------------
      -- Look for Frame rising edges and write data to fifos
      ----------------------------------------------------------------------------------------------
      for i in NUM_CHANNELS_G-1 downto 0 loop
         if (adcR.locked = '1' and adcFrame = "11111110000000") then
            -- Locked, output adc data
            v.fifoWrData(i) := "00" & iAdcData(i);
         else
            -- Not locked
            v.fifoWrData(i) := "10" & "00000000000000";
         end if;
      end loop;

      adcRin <= v;
      
   end process adcComb;

   adcSeq : process (adcBitClkR, adcBitRst) is
   begin
      if (adcBitRst = '1') then
         adcR <= ADC_REG_INIT_C after TPD_G;
      elsif (rising_edge(adcBitClkR)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;
   
   
   --------------------------------------
   -- Synchronize data to sysClk       --
   --------------------------------------
   G_DataFifo : for i in 0 to NUM_CHANNELS_G-1 generate
      adcValid(i) <= iAdcValid(i);
      U_DataFifo : entity surf.SynchronizerFifo
         generic map (
            TPD_G         => TPD_G,
            DATA_WIDTH_G  => 16,
            ADDR_WIDTH_G  => 4,
            INIT_G        => "0"
         )
         port map (
            rst    => adcBitRst,
            wr_clk => adcBitClkR,
            wr_en  => '1', --Always write data
            din    => adcR.fifoWrData(i),
            rd_clk => sysClk,
            rd_en  => iAdcValid(i),
            valid  => iAdcValid(i),
            dout   => adcData(i)
         );
      end generate;

end rtl;

