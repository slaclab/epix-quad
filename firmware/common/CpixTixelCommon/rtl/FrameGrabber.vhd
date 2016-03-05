-------------------------------------------------------------------------------
-- Title      : Frame grabber module
-------------------------------------------------------------------------------
-- File       : FrameGrabber.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 01/19/2016
-- Last update: 01/19/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: After SOF saves data into FIFO. Monitors for errors unitl EOF.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EpixPkgGen2.all;


library unisim;
use unisim.vcomponents.all;

entity FrameGrabber is
   generic (
      TPD_G                      : time      := 1 ns
   );
   port (
      -- global signals
      byteClk        : in  sl;
      byteClkRst     : in  sl;
      
      -- decoded data signals
      inSync         : in  sl;
      dataOut        : in  slv(7 downto 0);
      dataKOut       : in  sl;
      codeErr        : in  sl;
      dispErr        : in  sl;
      
      -- control/status signals
      frameRst       : in  sl;
      frameBytes     : in  slv(31 downto 0);
      frameDone      : out sl;
      frameError     : out sl;
      codeError      : out sl;
      
      -- data out signals
      rd_clk         : in  sl;
      rd_en          : in  sl;
      dout           : out slv(31 downto 0);
      valid          : out sl;
      empty          : out sl
   );
end FrameGrabber;

architecture rtl of FrameGrabber is
   
   TYPE STATE_TYPE IS (IDLE_S, WAIT_SOF_S, SOF_S, DATA_IN_S, EOF_S, DONE_S, ERROR_S);
   signal state, next_state   : STATE_TYPE; 
   signal globalRst  : sl; 
   signal errorDet   : sl; 
   signal byteCnt    : unsigned(31 downto 0); 
   signal byteWrEn   : sl; 
   signal overflow   : sl; 
   signal full       : sl; 
   
   constant SOF_C    : slv(7 downto 0) := x"F7";
   constant EOF_C    : slv(7 downto 0) := x"FD";
   constant D102_C   : slv(7 downto 0) := x"4A";
   
   attribute keep : string;
   attribute keep of state : signal is "true";
   
begin

   globalRst <= byteClkRst or frameRst;

   -----------------------------------------------
   -- FIFO instantiation
   -----------------------------------------------   
   U_AsicFifo : entity work.FifoMux
   generic map(
      WR_DATA_WIDTH_G => 8,
      RD_DATA_WIDTH_G => 32,
      GEN_SYNC_FIFO_G => false,
      ADDR_WIDTH_G    => 11,
      FWFT_EN_G       => true,
      USE_BUILT_IN_G  => false,
      EMPTY_THRES_G   => 1,
      LITTLE_ENDIAN_G => true
   )
   port map(
      rst           => globalRst,
      --Write ports
      wr_clk        => byteClk,
      wr_en         => byteWrEn,
      din           => dataOut,
      overflow      => overflow,
      full          => full,
      --Read ports
      rd_clk        => rd_clk,
      rd_en         => rd_en,
      dout          => dout,
      valid         => valid,
      empty         => empty
   );
   
   -----------------------------------------------
   -- Data save FSM
   -----------------------------------------------
   
   fsm_seq_p: process ( byteClk ) 
   begin
      -- FSM state register
      if rising_edge(byteClk) then
         if globalRst = '1' then
            state <= IDLE_S               after TPD_G;
         else
            state <= next_state           after TPD_G;         
         end if;
      end if;
      
      -- error flag register
      if rising_edge(byteClk) then
         if globalRst = '1' then
            codeError <= '0'               after TPD_G;
         elsif errorDet = '1' then
            codeError <= '1'               after TPD_G;         
         end if;
      end if;
      
      -- byte counter
      if rising_edge(byteClk) then
         if globalRst = '1' then
            byteCnt <= (others=>'0')      after TPD_G;
         elsif byteWrEn = '1' then
            byteCnt <= byteCnt + 1        after TPD_G;
         end if;
      end if;
      
      
   end process;
   

   fsm_cmb_p: process (state, inSync, codeErr, dispErr, dataKOut, dataOut, byteCnt, frameBytes, overflow, full) 
   begin
      next_state <= state;
      errorDet <= '0';
      byteWrEn <= '0';
      frameDone <= '0';
      frameError <= '0';
      
      case state is
      
         when IDLE_S =>
            if inSync = '1' and dataKOut = '1' and dataOut = SOF_C then
               next_state <= SOF_S;
            end if;
      
         when SOF_S =>
            if inSync = '1' and dataKOut = '0' and dataOut = D102_C then
               next_state <= DATA_IN_S;
            else
               next_state <= ERROR_S;
            end if;
         
         when DATA_IN_S =>
            byteWrEn <= '1';
         
            if inSync = '0' or codeErr = '1' or dispErr = '1' then
               errorDet <= '1';
            end if;
            
            if byteCnt > unsigned(frameBytes) or overflow = '1' or full = '1' then
               next_state <= ERROR_S;
            end if;
            
            if dataKOut = '1' and dataOut /= EOF_C then
               next_state <= ERROR_S;
            end if;
            
            if dataKOut = '1' and dataOut = EOF_C then
               byteWrEn <= '0';
               next_state <= EOF_S;
            end if;
         
         when EOF_S => 
            if byteCnt = unsigned(frameBytes) then
               next_state <= DONE_S;
            else
               next_state <= ERROR_S;
            end if;
         
         when DONE_S => 
            frameDone <= '1';
         
         when ERROR_S => 
            frameError <= '1';
            
         when others =>
            next_state <= ERROR_S;
      
      end case;
      
   end process;
   
   
end rtl;
