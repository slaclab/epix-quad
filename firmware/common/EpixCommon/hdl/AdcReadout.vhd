-------------------------------------------------------------------------------
-- Title         : ADC Readout Control
-- Project       : EPXI Readout
-------------------------------------------------------------------------------
-- File          : AdcReadout.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- ADC Readout Controller
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.EpixTypes.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity AdcReadout is
   generic (
      NUM_CHANNELS_G : integer range 1 to 8 := 8;
      EN_DELAY_G     : integer range 0 to 1 := 1;
      USE_ADC_CLK_G  : boolean := true
   );
   port ( 

      -- Master system clock, 125Mhz
      sysClk        : in  std_logic;
      sysClkRst     : in  std_logic;
      -- Multiplied system clock, 350 MHz
      sysDataClock  : in  std_logic;

      -- ADC Configuration
      frameDelay    : in  std_logic_vector(5 downto 0);
      dataDelay     : in  word6_array(NUM_CHANNELS_G-1 downto 0);

      -- Status
      frameSwapOut  : out std_logic;

      -- ADC Demux Interface
      adcValid      : out std_logic_vector(NUM_CHANNELS_G-1 downto 0);
      adcData       : out word16_array(NUM_CHANNELS_G-1 downto 0);
      
      -- ADC Interface Signals
      adcFClkP      : in  std_logic;
      adcFClkM      : in  std_logic;
      adcDClkP      : in  std_logic;
      adcDClkM      : in  std_logic;
      adcChP        : in  std_logic_vector(NUM_CHANNELS_G-1 downto 0);
      adcChM        : in  std_logic_vector(NUM_CHANNELS_G-1 downto 0)
   );

end AdcReadout;


-- Define architecture
architecture AdcReadout of AdcReadout is

   -- Local Signals
   signal adcBitClkIo     : std_logic;
   signal adcBitClkR      : std_logic;
   signal adcFramePad     : std_logic;
   signal adcFrameDly     : std_logic;
   signal adcFrameNegIn   : std_logic;
   signal adcFramePosIn   : std_logic;
   signal adcFrameNeg     : std_logic_vector(6 downto 0);
   signal adcFramePos     : std_logic_vector(6 downto 0);
   signal adcFrameNegRegA : std_logic_vector(6 downto 0);
   signal adcFramePosRegA : std_logic_vector(6 downto 0);
   signal adcFrameNegRegB : std_logic_vector(6 downto 0);
   signal adcDataPad      : std_logic_vector(7 downto 0);
   signal adcDataDly      : std_logic_vector(7 downto 0);
   signal adcDataNegIn    : std_logic_vector(7 downto 0);
   signal adcDataPosIn    : std_logic_vector(7 downto 0);
   signal adcDataNeg      : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataPos      : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataNegRegA  : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataPosRegA  : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataNegRegB  : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataPosRegB  : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataNegRegC  : word7_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataInt      : word16_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataOut      : word16_array(NUM_CHANNELS_G-1 downto 0);
   signal adcDataRd       : std_logic_vector(NUM_CHANNELS_G-1 downto 0);
   signal adcDataWr       : std_logic;
   signal frameEnable     : std_logic;
   signal frameSwap       : std_logic;
   signal adcBitRst0      : std_logic;
   signal adcBitRst1      : std_logic;
   signal adcBitRst       : std_logic;
   signal tmpAdcClkRaw    : std_logic;
   signal tmpAdcClk       : std_logic;
   signal inputCount      : word6_array(NUM_CHANNELS_G-1 downto 0);
   
   signal frameDelayCe  : sl;
   signal frameDelayInc : sl;
   signal dataDelayCe   : slv(NUM_CHANNELS_G-1 downto 0);
   signal dataDelayInc  : slv(NUM_CHANNELS_G-1 downto 0);
   
   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   frameSwapOut <= frameSwap;

   AdcClk_I_Ibufds : IBUFDS
      generic map (
         DIFF_TERM  => true,
         IOSTANDARD => "LVDS_25"
      ) port map (
         I  => adcDClkP,
         IB => adcDClkM,
         O  => tmpAdcClkRaw
      );    
   
   --------------------------------
   -- Clock Input (standard ADC clock used)
   --------------------------------
   G_AdcDoClk : if USE_ADC_CLK_G = true generate
      -- ADC frame delay
      U_FrameDelay : IODELAY 
         generic map (
            DELAY_SRC             => "I",
            HIGH_PERFORMANCE_MODE => true,
            IDELAY_TYPE           => "FIXED",
            IDELAY_VALUE          => 0, -- Here
            ODELAY_VALUE          => 0,
            REFCLK_FREQUENCY      => 200.0,
            SIGNAL_PATTERN        => "CLOCK"
         ) port map (
            DATAOUT  => tmpAdcClk,
            C        => '0',
            CE       => '0',
            DATAIN   => '0',
            IDATAIN  => tmpAdcClkRaw,
            INC      => '0',
            ODATAIN  => '0',
            RST      => '0',
            T        => '0'
         );

      -- IO Clock
      U_BUFIO : BUFIO Port map ( O => adcBitClkIo, I => tmpAdcClk );

      -- Regional clock
      U_AdcBitClkR : BUFR
         generic map (
            BUFR_DIVIDE => "1",
            SIM_DEVICE  => "VIRTEX5"
         ) port map (
            I   => tmpAdcClk,
            O   => adcBitClkR,
            CE  => '1',
            CLR => '0'
         );
   end generate G_AdcDoClk;
   --------------------------------
   -- Clock Input (use locally generated clock)
   --------------------------------
   G_LocalClk : if USE_ADC_CLK_G = false generate
         adcBitClkR  <= sysDataClock;
         adcBitClkIo <= sysDataClock;
   end generate G_LocalClk;
   
   -- Regional clock reset
   process ( adcBitClkR, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         adcBitRst0  <= '1' after tpd;
         adcBitRst1  <= '1' after tpd;
         adcBitRst   <= '1' after tpd;
      elsif rising_edge(adcBitClkR) then
         adcBitRst0  <= '0'        after tpd;
         adcBitRst1  <= adcBitRst0 after tpd;
         adcBitRst   <= adcBitRst1 after tpd;
      end if;
   end process;

   --------------------------------
   -- Frame Input
   --------------------------------

   -- Frame signal input
   U_FrameIn : IBUFDS 
      generic map (
         DIFF_TERM => true
      ) port map ( 
         I  => adcFClkP,
         IB => adcFClkM,
         O  => adcFramePad
      );

   FDEL_GEN: if EN_DELAY_G = 1 generate

      -- ADC frame delay
      U_FrameDelay : IODELAY 
         generic map (
            DELAY_SRC             => "I",
            HIGH_PERFORMANCE_MODE => true,
            IDELAY_TYPE           => "VARIABLE",
            IDELAY_VALUE          => 0, -- Here
            ODELAY_VALUE          => 0,
            REFCLK_FREQUENCY      => 200.0,
            SIGNAL_PATTERN        => "CLOCK"
         ) port map (
            DATAOUT  => adcFrameDly,
            C        => sysClk,
            CE       => frameDelayCe,
            DATAIN   => '0',
            IDATAIN  => adcFramePad,
            INC      => frameDelayInc,
            ODATAIN  => '0',
            RST      => sysClkRst,
            T        => '0'
         );
      U_FrameDelayManger : entity work.DelayManager
         generic map (
            TPD_G => tpd
         ) port map (
            sysClk      => sysClk,
            sysClkRst   => sysClkRst,
            delayIn     => frameDelay,
            delayCe     => frameDelayCe,
            delayIncDir => frameDelayInc
         );
   end generate;

   FDEL_BP_GEN: if EN_DELAY_G = 0 generate
      adcFrameDly <= adcFramePad;
   end generate;

   -- Frame signal DDR input
   U_FrameDdr : IDDR 
      generic map (
         DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",
         INIT_Q1      => '0',
         INIT_Q2      => '0',
         SRTYPE       => "SYNC"
      ) port map (
         Q1  => adcFramePosIn,
         Q2  => adcFrameNegIn,
         C   => adcBitClkIo,
         CE  => '1',
         D   => adcFrameDly,
         R   => '0',
         S   => '0'
      );

   -- Shift frame signal, MSB first
   process ( adcBitClkR, adcBitRst ) begin
      if ( adcBitRst = '1' ) then
         adcFrameNeg     <= (others=>'0') after tpd;
         adcFramePos     <= (others=>'0') after tpd;
         adcFrameNegRegA <= (others=>'0') after tpd;
         adcFramePosRegA <= (others=>'0') after tpd;
         adcFrameNegRegB <= (others=>'0') after tpd;
         frameEnable     <= '0'           after tpd;
         frameSwap       <= '0'           after tpd;
         adcDataWr       <= '0'           after tpd;
      elsif rising_edge(adcBitClkR) then

         -- Shift in frame, msb first
         adcFrameNeg <= adcFrameNeg(5 downto 0) & adcFrameNegIn after tpd;
         adcFramePos <= adcFramePos(5 downto 0) & adcFramePosIn after tpd;

         -- Register frame
         adcFrameNegRegA <= adcFrameNeg     after tpd;
         adcFramePosRegA <= adcFramePos     after tpd;
         adcFrameNegRegB <= adcFrameNegRegA after tpd;

         -- Frame matches without bit swap
         if ( adcFramePosRegA = "1111000" and adcFrameNegRegA = "1110000" ) then
            frameEnable <= '1' after tpd;
            frameSwap   <= '0' after tpd;

         -- Frame matches with bit swap
         elsif ( adcFramePosRegA = "1110000" and adcFrameNegRegB = "1111000" ) then
            frameEnable <= '1' after tpd;
            frameSwap   <= '1' after tpd;
         else
            frameEnable <= '0' after tpd;
         end if;

         -- FIFO write control
         adcDataWr <= frameEnable after tpd;
      end if;
   end process;


   --------------------------------
   -- Data Input, 8 channels
   --------------------------------
   GenData : for i in NUM_CHANNELS_G-1 downto 0 generate 

      -- Frame signal input
      U_DataIn : IBUFDS 
         generic map (
            DIFF_TERM => true
         ) port map ( 
            I  => adcChP(i),
            IB => adcChM(i),
            O  => adcDataPad(i)
         );

      DDEL_GEN: if EN_DELAY_G = 1 generate
         -- ADC input delay
         U_InDelay : IODELAY 
            generic map (
               DELAY_SRC             => "I",
               HIGH_PERFORMANCE_MODE => true,
               IDELAY_TYPE           => "VARIABLE",
               IDELAY_VALUE          => 0,
               ODELAY_VALUE          => 0,
               REFCLK_FREQUENCY      => 200.0,
               SIGNAL_PATTERN        => "DATA"
            ) port map (
               DATAOUT  => adcDataDly(i),
               C        => sysClk,
               CE       => dataDelayCe(i),
               DATAIN   => '0',
               IDATAIN  => adcDataPad(i),
               INC      => dataDelayInc(i),
               ODATAIN  => '0',
               RST      => sysClkRst,
               T        => '0'
            );
         U_DataDelayManger : entity work.DelayManager
            generic map (
               TPD_G => tpd
            ) port map (
               sysClk      => sysClk,
               sysClkRst   => sysClkRst,
               delayIn     => dataDelay(i),
               delayCe     => dataDelayCe(i),
               delayIncDir => dataDelayInc(i)
            );
      end generate;

      DDEL_BP_GEN: if EN_DELAY_G = 0 generate
         adcDataDly(i) <= adcDataPad(i);
      end generate;

      -- Data signal DDR input
      U_DataDdr : IDDR 
         generic map (
            DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",
            INIT_Q1      => '0',
            INIT_Q2      => '0',
            SRTYPE       => "SYNC"
         ) port map (
            Q1  => adcDataPosIn(i),
            Q2  => adcDataNegIn(i),
            C   => adcBitClkIo,
            CE  => '1',
            D   => adcDataDly(i),
            R   => '0',
            S   => '0'
         );

      -- Shift data signal, MSB first
      process ( adcBitClkR, adcBitRst ) begin
         if ( adcBitRst = '1' ) then
            adcDataNeg(i)     <= (others=>'0') after tpd;
            adcDataPos(i)     <= (others=>'0') after tpd;
            adcDataNegRegA(i) <= (others=>'0') after tpd;
            adcDataPosRegA(i) <= (others=>'0') after tpd;
            adcDataNegRegB(i) <= (others=>'0') after tpd;
            adcDataPosRegB(i) <= (others=>'0') after tpd;
            adcDataNegRegC(i) <= (others=>'0') after tpd;
            adcDataInt(i)     <= (others=>'0') after tpd;
         elsif rising_edge(adcBitClkR) then

            -- Shift in frame, msb first
            adcDataNeg(i) <= adcDataNeg(i)(5 downto 0) & adcDataNegIn(i) after tpd;
            adcDataPos(i) <= adcDataPos(i)(5 downto 0) & adcDataPosIn(i) after tpd;

            -- Register frame
            adcDataNegRegA(i) <= adcDataNeg(i)     after tpd;
            adcDataPosRegA(i) <= adcDataPos(i)     after tpd;
            adcDataNegRegB(i) <= adcDataNegRegA(i) after tpd;
            adcDataPosRegB(i) <= adcDataPosRegA(i) after tpd;
            adcDataNegRegC(i) <= adcDataNegRegB(i) after tpd;

            -- Form data frame, swap bits if neccessary
            if frameSwap = '1' then
               adcDataInt(i)(13) <= adcDataNegRegC(i)(6) after tpd;
               adcDataInt(i)(12) <= adcDataPosRegB(i)(6) after tpd;
               adcDataInt(i)(11) <= adcDataNegRegC(i)(5) after tpd;
               adcDataInt(i)(10) <= adcDataPosRegB(i)(5) after tpd;
               adcDataInt(i)(9)  <= adcDataNegRegC(i)(4) after tpd;
               adcDataInt(i)(8)  <= adcDataPosRegB(i)(4) after tpd;
               adcDataInt(i)(7)  <= adcDataNegRegC(i)(3) after tpd;
               adcDataInt(i)(6)  <= adcDataPosRegB(i)(3) after tpd;
               adcDataInt(i)(5)  <= adcDataNegRegC(i)(2) after tpd;
               adcDataInt(i)(4)  <= adcDataPosRegB(i)(2) after tpd;
               adcDataInt(i)(3)  <= adcDataNegRegC(i)(1) after tpd;
               adcDataInt(i)(2)  <= adcDataPosRegB(i)(1) after tpd;
               adcDataInt(i)(1)  <= adcDataNegRegC(i)(0) after tpd;
               adcDataInt(i)(0)  <= adcDataPosRegB(i)(0) after tpd;
            else
               adcDataInt(i)(13) <= adcDataPosRegB(i)(6) after tpd;
               adcDataInt(i)(12) <= adcDataNegRegB(i)(6) after tpd;
               adcDataInt(i)(11) <= adcDataPosRegB(i)(5) after tpd;
               adcDataInt(i)(10) <= adcDataNegRegB(i)(5) after tpd;
               adcDataInt(i)(9)  <= adcDataPosRegB(i)(4) after tpd;
               adcDataInt(i)(8)  <= adcDataNegRegB(i)(4) after tpd;
               adcDataInt(i)(7)  <= adcDataPosRegB(i)(3) after tpd;
               adcDataInt(i)(6)  <= adcDataNegRegB(i)(3) after tpd;
               adcDataInt(i)(5)  <= adcDataPosRegB(i)(2) after tpd;
               adcDataInt(i)(4)  <= adcDataNegRegB(i)(2) after tpd;
               adcDataInt(i)(3)  <= adcDataPosRegB(i)(1) after tpd;
               adcDataInt(i)(2)  <= adcDataNegRegB(i)(1) after tpd;
               adcDataInt(i)(1)  <= adcDataPosRegB(i)(0) after tpd;
               adcDataInt(i)(0)  <= adcDataNegRegB(i)(0) after tpd;
            end if;
         end if;
      end process;

      -- Data FIFO
      U_DataFifo : entity work.FifoMux
         generic map (
            TPD_G              => tpd,
            CASCADE_SIZE_G     => 1, 
            LAST_STAGE_ASYNC_G => true,
            RST_POLARITY_G     => '1', 
            RST_ASYNC_G        => false,
            GEN_SYNC_FIFO_G    => false,
            BRAM_EN_G          => false,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => false,
            ALTERA_RAM_G       => "M9K",
            USE_BUILT_IN_G     => false,
            XIL_DEVICE_G       => "VIRTEX5",
            SYNC_STAGES_G      => 3,
            PIPE_STAGES_G      => 0,
            WR_DATA_WIDTH_G    => 16,
            RD_DATA_WIDTH_G    => 16,
            LITTLE_ENDIAN_G    => false,
            ADDR_WIDTH_G       => 4,
            INIT_G             => "0",
            FULL_THRES_G       => 1,
            EMPTY_THRES_G      => 1           
         )
         port map (
            -- Resets
            rst           => adcBitRst,
            --Write Ports (wr_clk domain)
            wr_clk        => adcBitClkR,
            wr_en         => adcDataWr,
            din           => adcDataInt(i),
            full          => open,
            --Read Ports (rd_clk domain)
            rd_clk        => sysClk,
            rd_en         => adcDataRd(i),
            dout          => adcDataOut(i),
            valid         => adcdataRd(i),
            empty         => open
         );

      -- Connect external signals
      process ( sysClk, sysClkRst ) begin
         if ( sysClkRst = '1' ) then
            adcValid(i) <= '0'           after tpd;
            adcData(i)  <= (others=>'0') after tpd;
         elsif rising_edge(sysClk) then
            adcValid(i) <= adcDataRd(i)  after tpd;
            adcData(i)  <= adcDataOut(i) after tpd;
         end if;
      end process;
   end generate;

end AdcReadout;

