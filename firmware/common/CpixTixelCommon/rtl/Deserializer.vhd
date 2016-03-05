-------------------------------------------------------------------------------
-- Title         : Tixel and cPix serial stream de-serializer
-- Project       : Tixel/cPix Detector
-------------------------------------------------------------------------------
-- File          : Deserializer.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 11/23/2015
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for deserialization of the 10b encoded
-- serial output data of the Tixel or Cpix ASIC.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Maciej Kwiatkowski. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/23/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity Deserializer is 
   generic (
      TPD_G             : time := 1 ns;
      IDELAYCTRL_FREQ_G : real := 200.0
   );
   port ( 
      bitClk         : in  std_logic;
      byteClk        : in  std_logic;
      byteClkRst     : in  std_logic;
      
      -- serial data in
      asicDoutP      : in  std_logic;
      asicDoutM      : in  std_logic;
      
      -- status
      patternCnt     : out std_logic_vector(31 downto 0);
      testDone       : out std_logic;
      inSync         : out std_logic;
      
      -- decoded data out
      dataOut        : out std_logic_vector(7 downto 0);
      dataKOut       : out std_logic;
      codeErr        : out std_logic;
      dispErr        : out std_logic;
      
      -- control
      resync         : in  std_logic;
      delay          : in  std_logic_vector(4 downto 0)
   );
end Deserializer;


-- Define architecture
architecture RTL of Deserializer is

   TYPE STATE_TYPE IS (BIT_SLIP, SLIP_WAIT, PT0_CHECK, PT1_CHECK, INSYNC_S);
   SIGNAL state, next_state   : STATE_TYPE;
   
   signal bitClkInv     : std_logic;
   signal asicDoutN     : std_logic;
   signal asicDout      : std_logic;
   signal asicDoutDly   : std_logic;
   signal pattern_ok    : std_logic;
   
   signal iserdese_out  : std_logic_vector(9 downto 0);
   signal shift1        : std_logic;
   signal shift2        : std_logic;
   signal slip          : std_logic;
   signal synced        : std_logic;
   signal delayCurr     : std_logic_vector(4 downto 0);
   signal delay_en      : std_logic;
   
   signal tst_counter   : unsigned(31 downto 0);
   signal tst_done      : std_logic;
   signal tr_counter    : unsigned(31 downto 0);
   
   signal wait_counter  : integer range 0 to 3;
   signal wait_cnt_rst  : std_logic;
   
   attribute keep :string;
   attribute keep of iserdese_out : signal is "true";
   attribute keep of pattern_ok : signal is "true";
   attribute keep of delay_en : signal is "true";
   
begin

   -- Input differential buffer
   U_IBUFDS : IBUFDS
   port map (
      I    => asicDoutP,
      IB   => asicDoutM,
      O    => asicDoutN
   );
   
   asicDout <= not asicDoutN;
   
   -- input delay taps
   U_IDELAYE2 : IDELAYE2
   generic map (
      DELAY_SRC             => "IDATAIN",
      HIGH_PERFORMANCE_MODE => "TRUE",
      IDELAY_TYPE           => "VAR_LOAD",
      IDELAY_VALUE          => 0,
      REFCLK_FREQUENCY      => IDELAYCTRL_FREQ_G,
      SIGNAL_PATTERN        => "DATA"
   )
   port map (
      C           => byteClk,
      REGRST      => '0',
      LD          => delay_en,
      CE          => '0',
      INC         => '1',
      CINVCTRL    => '0',
      CNTVALUEIN  => delay,
      IDATAIN     => asicDout,
      DATAIN      => '0',
      LDPIPEEN    => '0',
      DATAOUT     => asicDoutDly,
      CNTVALUEOUT => delayCurr
   );
   
   process (byteClk) begin
      if rising_edge(byteClk) then
         if (delay /= delayCurr) then
            delay_en <= '1';
         else 
            delay_en <= '0';
         end if;
      end if;
   end process;
   
   bitClkInv <= not bitClk;
   
   U_MasterISERDESE2 : ISERDESE2
   generic map (
      DATA_RATE         => "DDR",
      DATA_WIDTH        => 10,
      INTERFACE_TYPE    => "NETWORKING",
      DYN_CLKDIV_INV_EN => "FALSE",
      DYN_CLK_INV_EN    => "FALSE",
      NUM_CE            => 1,
      OFB_USED          => "FALSE",
      IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
      SERDES_MODE       => "MASTER"
   )
   port map (
      Q1           => iserdese_out(9),
      Q2           => iserdese_out(8),
      Q3           => iserdese_out(7),
      Q4           => iserdese_out(6),
      Q5           => iserdese_out(5),
      Q6           => iserdese_out(4),
      Q7           => iserdese_out(3),
      Q8           => iserdese_out(2),
      SHIFTOUT1    => shift1,        -- Cascade connection to Slave ISERDES
      SHIFTOUT2    => shift2,        -- Cascade connection to Slave ISERDES
      BITSLIP      => slip,          -- 1-bit Invoke Bitslip. This can be used with any 
                                     -- DATA_WIDTH, cascaded or not.
      CE1          => '1',           -- 1-bit Clock enable input
      CE2          => '1',           -- 1-bit Clock enable input
      CLK          => bitClk,     -- Fast Source Synchronous SERDES clock from BUFIO
      CLKB         => bitClkInv,  -- Locally inverted clock
      CLKDIV       => byteClk,       -- Slow clock driven by BUFR
      CLKDIVP      => '0',
      D            => '0',
      DDLY         => asicDoutDly,   -- 1-bit Input signal from IODELAYE1.
      RST          => byteClkRst,         -- 1-bit Asynchronous reset only.
      SHIFTIN1     => '0',
      SHIFTIN2     => '0',
      -- unused connections
      DYNCLKDIVSEL => '0',
      DYNCLKSEL    => '0',
      OFB          => '0',
      OCLK         => '0',
      OCLKB        => '0',
      O            => open            -- unregistered output of ISERDESE1
   );         

   U_SlaveISERDESE2 : ISERDESE2
   generic map (
      DATA_RATE         => "DDR",
      DATA_WIDTH        => 10,
      INTERFACE_TYPE    => "NETWORKING",
      DYN_CLKDIV_INV_EN => "FALSE",
      DYN_CLK_INV_EN    => "FALSE",
      NUM_CE            => 1,
      OFB_USED          => "FALSE",
      IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
      SERDES_MODE       => "SLAVE"
   )
   port map (
      Q1           => open,
      Q2           => open,
      Q3           => iserdese_out(1),
      Q4           => iserdese_out(0),
      Q5           => open,
      Q6           => open,
      Q7           => open,
      Q8           => open,
      SHIFTOUT1    => open,
      SHIFTOUT2    => open,
      SHIFTIN1     => shift1,        -- Cascade connections from Master ISERDES
      SHIFTIN2     => shift2,        -- Cascade connections from Master ISERDES
      BITSLIP      => slip,          -- 1-bit Invoke Bitslip. This can be used with any 
                                     -- DATA_WIDTH, cascaded or not.
      CE1          => '1',           -- 1-bit Clock enable input
      CE2          => '1',           -- 1-bit Clock enable input
      CLK          => bitClk,     -- Fast Source Synchronous SERDES clock from BUFIO
      CLKB         => bitClkInv,  -- Locally inverted clock
      CLKDIV       => byteClk,       -- Slow clock driven by BUFR.
      CLKDIVP      => '0',
      D            => '0',           -- Slave ISERDES module. No need to connect D, DDLY
      DDLY         => '0',
      RST          => byteClkRst,         -- 1-bit Asynchronous reset only.
      -- unused connections
      DYNCLKDIVSEL => '0',
      DYNCLKSEL    => '0',
      OFB          => '0',
      OCLK         => '0',
      OCLKB        => '0',
      O            => open            -- unregistered output of ISERDESE1
   ); 
   
   -- pattern is correct when K28.5+1 or K28.5-1 or D10.2
   --pattern_ok <= '1' when iserdese_out = "1100000101" or iserdese_out = "0011111010" or iserdese_out = "0101010101" else '0';
   pattern_ok <= '1' when iserdese_out = "1010000011" or iserdese_out = "0101111100" or iserdese_out = "1010101010" else '0';
   

   -- test counter
   tst_cnt_p: process ( byteClk ) 
   begin
      if rising_edge(byteClk) then
         if byteClkRst = '1' or resync = '1' then
            tst_counter <= (others=>'0') after TPD_G;
         elsif synced = '1' and tst_done = '0' then
            tst_counter <= tst_counter + 1 after TPD_G;
         end if;
      end if;
   end process;
   
   tst_done <= '1' when std_logic_vector(tst_counter) = x"0FFFFFFF" else '0';
   testDone <= tst_done;
   patternCnt <= std_logic_vector(tr_counter);

   
   -- good training pattern counter
   tr_cnt_p: process ( byteClk ) 
   begin
      if rising_edge(byteClk) then
         if byteClkRst = '1' or resync = '1' then
            tr_counter <= (others=>'0') after TPD_G;
         elsif synced = '1' and pattern_ok = '1' and tst_done = '0' then
            tr_counter <= tr_counter + 1 after TPD_G;
         end if;
      end if;
   end process;
   
      -- FSM wait counter
   wait_cnt_p: process ( byteClk ) 
   begin
      if rising_edge(byteClk) then
         if byteClkRst = '1' or wait_cnt_rst = '1' then
            wait_counter <= 0 after TPD_G;
         else
            wait_counter <= wait_counter + 1 after TPD_G;         
         end if;
      end if;
   end process;
   
   
   -- Data sync FSM
   fsm_cnt_p: process ( byteClk ) 
   begin
      if rising_edge(byteClk) then
         if byteClkRst = '1' then
            state <= BIT_SLIP after TPD_G;
         else
            state <= next_state after TPD_G;         
         end if;
      end if;
   end process;
   
   fsm_cmb_p: process (state, wait_counter, pattern_ok, resync) 
   begin
      next_state <= state;
      wait_cnt_rst <= '1';
      slip <= '0';
      synced <= '0';
      
      
      case state is
      
         when BIT_SLIP =>
            slip <= '1';
            next_state <= SLIP_WAIT;
      
         when SLIP_WAIT =>
            wait_cnt_rst <= '0';
            if wait_counter >= 2 then
               next_state <= PT0_CHECK; 
            end if;
         
         when PT0_CHECK =>
            if pattern_ok = '0' then
               next_state <= BIT_SLIP;
            else
               next_state <= PT1_CHECK;
            end if;
         
         when PT1_CHECK =>
            if pattern_ok = '0' then
               next_state <= BIT_SLIP;
            else
               next_state <= INSYNC_S;
            end if;
         
         when INSYNC_S => 
            synced <= '1';
            if resync = '1' then
               next_state <= BIT_SLIP;
            end if;
         
         when others =>
            next_state <= BIT_SLIP;
      
      end case;
      
   end process;
   
   inSync <= synced;
   
   --10b8b decoder
   U_Decode8b10b: entity work.Decoder8b10b
   generic map (
      NUM_BYTES_G => 1,
      RST_POLARITY_G => '0'
   )
   port map (
      clk         => byteClk,
      clkEn       => '1',
      rst         => synced,
      dataIn      => iserdese_out,
      dataOut     => dataOut,
      dataKOut(0) => dataKOut,
      codeErr(0)  => codeErr,
      dispErr(0)  => dispErr
   );

end RTL;

