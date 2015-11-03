-------------------------------------------------------------------------------
-- Title         : ADS1217 ADC Controller
-- Project       : EPIX Detector
-------------------------------------------------------------------------------
-- File          : SlowAdcCntrl.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 10/29/2015
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for reading the voltages, currents and strongback  
-- temperatures from the ADS1217 on the generation 2 EPIX analog board.
-- The ADS1217 is an 8 channel ADC.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Maciej Kwiatkowski. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/29/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;
use work.StdRtlPkg.all;

entity SlowAdcCntrl is 
   generic (
      TPD_G           	: time := 1 ns;
      SYS_CLK_PERIOD_G  : real := 10.0E-9;	-- 100MHz
      ADC_CLK_PERIOD_G  : real := 200.0E-9;	-- 5MHz
      SPI_SCLK_PERIOD_G : real := 1.0E-6  	-- 1MHz
   );
   port ( 
      -- Master system clock
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- Operation Control
      adcStart        : in  std_logic;
      adcData         : out Slv24Array(9 downto 0);

      -- ADC Control Signals
      adcRefClk     : out   std_logic;
      adcDrdy       : in    std_logic;
      adcSclk       : out   std_logic;
      adcDout       : in    std_logic;
      adcCsL        : out   std_logic;
      adcDin        : out   std_logic
   );
end SlowAdcCntrl;


-- Define architecture
architecture RTL of SlowAdcCntrl is

   constant r0_speed :     std_logic_vector(0 downto 0) := "0";      -- "0" - fosc/128, "1" - fosc/256
   constant r0_refhi :     std_logic_vector(0 downto 0) := "1";      -- "0" - Vref 1.25, "1" - Vref 2.5
   constant r0_bufen :     std_logic_vector(0 downto 0) := "0";      -- "0" - buffer disabled, "1" - buffer enabled
   constant r2_idac1r :    std_logic_vector(1 downto 0) := "01";     -- "00" - off, "01" - range 1 (0.5mA) ... "11" - range 3 (2mA)
   constant r2_idac2r :    std_logic_vector(1 downto 0) := "01";     -- "00" - off, "01" - range 1 (0.5mA) ... "11" - range 3 (2mA)
   constant r2_pga :       std_logic_vector(2 downto 0) := "000";    -- PGA 1 to 128
   constant r3_idac1 :     std_logic_vector(7 downto 0) := CONV_STD_LOGIC_VECTOR(51, 8);    -- I DAC1 0 to max range
   constant r4_idac2 :     std_logic_vector(7 downto 0) := CONV_STD_LOGIC_VECTOR(51, 8);    -- I DAC2 0 to max range
   constant r5_r6_dec0 :   std_logic_vector(10 downto 0) := CONV_STD_LOGIC_VECTOR(195, 11); -- Decimation value
   constant r6_ub :        std_logic_vector(0 downto 0) := "1";      -- "0" - bipolar, "1" - unipolar
   constant r6_mode :      std_logic_vector(1 downto 0) := "00";     -- "00" - auto, "01" - fast ...
   
   constant adc_setup_regs : Slv8Array(9 downto 0) := (
      0 => "000" & r0_speed & "1" & r0_refhi & r0_bufen & "0",
      1 => "00001000",  -- start with MUX set to Ain0 and Comm
      2 => "0" & r2_idac1r & r2_idac2r & r2_pga,
      3 => r3_idac1,
      4 => r4_idac2,
      5 => "00000000",  -- offset DAC leave default
      6 => "00000000",  -- DIO leave default
      7 => "11111110",  -- change bit 0 DIR to output
      8 => r5_r6_dec0(7 downto 0),
      9 => "0" & r6_ub & r6_mode & "0" & r5_r6_dec0(10 downto 8)
   );
   
   constant cmd_wr_reg :   std_logic_vector(3 downto 0) := "0101";
   constant cmd_reset :    std_logic_vector(7 downto 0) := "11111110";
   constant cmd_dsync :    std_logic_vector(7 downto 0) := "11111100";
   constant cmd_rdata :    std_logic_vector(7 downto 0) := "00000001";
   
   constant adc_refclk_t: integer := integer(ceil((ADC_CLK_PERIOD_G/SYS_CLK_PERIOD_G)/2.0))-1;
   constant rd_cmd_wait_t: integer := integer(ceil(ADC_CLK_PERIOD_G/SYS_CLK_PERIOD_G*50.0))-1;
   
   TYPE STATE_TYPE IS (IDLE, RESET, INIT_CMD, INIT_WAIT, WAIT_TRIG, ACQ_CMD, ACQ_WAIT, WAIT_DRDY, READ_CMD, READ_WAIT, WAIT_DATA, READ_DATA, STORE_DATA);
   SIGNAL state, next_state   : STATE_TYPE;   
   
   signal adcDrdyEn :      std_logic;
   signal adcDrdyD1 :      std_logic;
   signal adcDrdyD2 :      std_logic;
   signal sel_init_cmds :  std_logic;
   signal spi_wr_en :      std_logic;
   signal spi_wr_data :    std_logic_vector(7 downto 0);
   signal spi_rd_en :      std_logic;
   signal spi_rd_en_d1 :   std_logic;
   signal spi_rd_data :    std_logic_vector(7 downto 0);
   signal init_cmds :      std_logic_vector(7 downto 0);
   signal acq_cmds :       std_logic_vector(7 downto 0);
   signal cmd_counter :    integer range 0 to 13;
   signal cmd_rst :        std_logic;
   signal cmd_en :         std_logic;
   signal ain_sel  :       std_logic_vector(3 downto 0);
   signal ain_counter :    integer range 0 to 9;
   signal ain_rst :        std_logic;
   signal ain_en :         std_logic;
   signal byte_counter :   integer range 0 to 3;
   signal byte_rst :       std_logic;
   signal byte_en :        std_logic;
   signal ch_counter :     integer range 0 to 9;
   signal channel_en :     std_logic;
   
   signal wait_counter :   integer range 0 to rd_cmd_wait_t;
   signal wait_load :      std_logic;
   signal wait_done :      std_logic;
   
   signal data_23_16 :     std_logic_vector(7 downto 0);
   signal data_15_08 :     std_logic_vector(7 downto 0);
   
   signal ref_counter :    integer range 0 to adc_refclk_t;
   signal ref_clk :        std_logic;
   signal ref_clk_en :     std_logic;
   
   signal adc_reset_en :   std_logic;
   signal adc_reset_done : std_logic;
   signal sel_reset_out :  std_logic;
   signal adcSclkM :       std_logic;
   signal adcSclkR :       std_logic;

begin

   -- ADC reset pattern generator
   ADC_rst_i: entity work.SlowAdcReset
   port map ( 
      sysClk          => sysClk,
      sysClkRst       => sysClkRst,
      reset_en        => adc_reset_en,
      tosc_en         => ref_clk_en,
      reset_pattern   => adcSclkR,
      reset_done      => adc_reset_done
   );

   -- ADC reference clock counter
   ref_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            ref_counter <= 0;
            ref_clk <= '0';
         elsif ref_counter >= adc_refclk_t then
            ref_counter <= 0;
            ref_clk <= not ref_clk;
         else
            ref_counter <= ref_counter + 1;
         end if;
      end if;
   end process;
   adcRefClk <= ref_clk;
   ref_clk_en <= '1' when ref_clk = '1' and ref_counter >= adc_refclk_t else '0';

   -- Drdy sync and falling edge detector
   process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            adcDrdyD1 <= '0';
            adcDrdyD2 <= '0';
            spi_rd_en_d1 <= '0';
         else
            adcDrdyD1 <= adcDrdy;
            adcDrdyD2 <= adcDrdyD1;
            spi_rd_en_d1 <= spi_rd_en;
         end if;
      end if;
   end process;
   
   adcDrdyEn <= adcDrdyD2 and not adcDrdyD1;

   -- Instance of the SPI Master controller
   SPI_Master_i: entity work.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 8,
         CPHA_G            => '1',
         CPOL_G            => '1',
         CLK_PERIOD_G      => SYS_CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_G
      )
      port map (
         --Global Signals
         clk      => sysClk,
         sRst     => sysClkRst,
         -- Parallel interface
         chipSel  => "0",
         wrEn     => spi_wr_en,
         wrData   => spi_wr_data,
         rdEn     => spi_rd_en,
         rdData   => spi_rd_data,
         --SPI interface
         --spiCsL(0)=> adcCsL,
         spiCsL(0)=> open,
         spiSclk  => adcSclkM,
         spiSdi   => adcDin,
         spiSdo   => adcDout
      );
   adcSclk <= adcSclkM when sel_reset_out = '0' else adcSclkR;
   -- ADC write MUX
   spi_wr_data <= init_cmds when sel_init_cmds = '1' else acq_cmds;
   
   
   
   -- ADC initialization commands MUX. Written just once.
   init_cmds <=   
      cmd_wr_reg & "0000"     when cmd_counter = 0 else    -- write register command starting from reg 0
      "00001001"              when cmd_counter = 1 else    -- write register command write 10 registers
      adc_setup_regs(0)       when cmd_counter = 2 else    -- write registers 0 to 9
      adc_setup_regs(1)       when cmd_counter = 3 else 
      adc_setup_regs(2)       when cmd_counter = 4 else 
      adc_setup_regs(3)       when cmd_counter = 5 else 
      adc_setup_regs(4)       when cmd_counter = 6 else 
      adc_setup_regs(5)       when cmd_counter = 7 else 
      adc_setup_regs(6)       when cmd_counter = 8 else 
      adc_setup_regs(7)       when cmd_counter = 9 else 
      adc_setup_regs(8)       when cmd_counter = 10 else 
      adc_setup_regs(9)       when cmd_counter = 11 else 
      "00000000";
   
   -- Single channel acquisition commands MUX. Written in loop after every trigger.
   acq_cmds <=   
      cmd_wr_reg & "0001"     when cmd_counter = 0 else    -- write register command with MUX reg address
      "00000000"              when cmd_counter = 1 else    -- write register command write 1 register
      ain_sel & "1000"        when cmd_counter = 2 and ain_counter < 8 else    -- write register data with selected ain
      "1111"  & "1111"        when cmd_counter = 2 and ain_counter = 8 else    -- write register data with selected internal diode
      "0111"  & "1000"        when cmd_counter = 2 and ain_counter = 9 else    -- write register data with ain no 7
      cmd_wr_reg & "0110"     when cmd_counter = 3 else    -- write register command with DIO reg address
      "00000000"              when cmd_counter = 4 else    -- write register command write 1 register
      "00000001"              when cmd_counter = 5 and ain_counter = 9 else    -- write register data, switch external MUX
      "00000000"              when cmd_counter = 5 and ain_counter /= 9 else   -- write register data, do not switch external MUX
      cmd_dsync               when cmd_counter = 6 else    -- DSYNC command
      "00000000"              when cmd_counter = 7 else    -- send zeros to release reset after DSYNC
      cmd_rdata               when cmd_counter = 8 else    -- RDATA command
      "00000000";

   -- comand select counter counter
   cmd_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or cmd_rst = '1' then
            cmd_counter <= 0;
         elsif cmd_en = '1' then
            cmd_counter <= cmd_counter + 1;         
         end if;
      end if;
   end process;
   
   -- analog input select counter
   ain_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or ain_rst = '1' then
            ain_counter <= 0;
         elsif ain_en = '1' then
            ain_counter <= ain_counter + 1;         
         end if;
      end if;
   end process;
   ain_sel <= CONV_STD_LOGIC_VECTOR(ain_counter, 4);
   
   -- data wait delay counter
   wait_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            wait_counter <= 0;
         elsif wait_load = '1' then
            wait_counter <= rd_cmd_wait_t;       
         elsif wait_done = '0' then
            wait_counter <= wait_counter - 1;
         end if;
      end if;
   end process;
   wait_done <= '1' when wait_counter = 0 else '0';
   
   -- read byte counter
   byte_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' or byte_rst = '1' then
            byte_counter <= 0;
         elsif byte_en = '1' then
            byte_counter <= byte_counter + 1;         
         end if;
      end if;
   end process;
   
   -- acquisition chanel counter
   ch_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            ch_counter <= 0;
         elsif channel_en = '1' then
            if ch_counter < 9 then
               ch_counter <= ch_counter + 1;
            else
               ch_counter <= 0;
            end if;
         end if;
      end if;
   end process;
   
   -- acquisition data storage
   data_reg_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            data_23_16 <= (others=>'0');
            data_15_08 <= (others=>'0');
         elsif byte_counter = 0 and spi_rd_en = '1' and spi_rd_en_d1 = '0' then
            data_23_16 <= spi_rd_data;
         elsif byte_counter = 1 and spi_rd_en = '1' and spi_rd_en_d1 = '0' then
            data_15_08 <= spi_rd_data;
         elsif byte_counter = 2 and spi_rd_en = '1' and spi_rd_en_d1 = '0' then
            adcData(ch_counter) <= data_23_16 & data_15_08 & spi_rd_data;
         end if;
      end if;
   end process;
   
   -- One time init and readout loop FSM
   fsm_cnt_p: process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            state <= IDLE;
         else
            state <= next_state;         
         end if;
      end if;
   end process;

   fsm_cmb_p: process ( state, adcDrdyEn, adcDrdyD2, spi_rd_en, cmd_counter, ain_counter, byte_counter, adcStart, wait_done, adc_reset_done) 
   begin
      next_state <= state;
      cmd_en <= '0';
      cmd_rst <= '0';
      ain_en <= '0';
      ain_rst <= '0';
      byte_en <= '0';
      byte_rst <= '0';
      spi_wr_en <= '0';
      sel_init_cmds <= '0';
      sel_reset_out <= '0';
      channel_en <= '0';
      wait_load <= '0';
      adc_reset_en <= '0';
      adcCsL <= '0';
      
      case state is
      
         when IDLE =>
            adcCsL <= '1';
            cmd_rst <= '1';
            ain_rst <= '1';
            adc_reset_en <= '1';
            sel_reset_out <= '1';
            next_state <= RESET;
         
         when RESET => 
            sel_reset_out <= '1';
            if adc_reset_done = '1' then
               next_state <= INIT_CMD;
            end if;
         
         when INIT_CMD => 
            spi_wr_en <= '1';
            cmd_en <= '1';
            sel_init_cmds <= '1';
            next_state <= INIT_WAIT;
            
         when INIT_WAIT =>
            sel_init_cmds <= '1';
            if spi_rd_en = '1' then
               if cmd_counter < 12 then
                  next_state <= INIT_CMD;
               else
                  next_state <= WAIT_TRIG;
               end if;
            end if;
         
         when WAIT_TRIG => 
            cmd_rst <= '1';
            if adcStart = '1' then
               next_state <= ACQ_CMD;
            else
               next_state <= WAIT_TRIG;
            end if;
         
         when ACQ_CMD => 
            if cmd_counter = 6 and ain_counter < 9 then
               ain_en <= '1';
            elsif cmd_counter = 6 and ain_counter >= 9 then
               ain_rst <= '1';
            end if;
            spi_wr_en <= '1';
            cmd_en <= '1';
            next_state <= ACQ_WAIT;
            
         when ACQ_WAIT => 
            if spi_rd_en = '1' then
               if cmd_counter < 8 then
                  next_state <= ACQ_CMD;
               else
                  next_state <= WAIT_DRDY;   
               end if;
            end if;
         
         when WAIT_DRDY =>
            adcCsL <= '1';
            --if adcDrdyEn = '1' then
            if adcDrdyD2 = '0' then
               next_state <= READ_CMD;
            end if;
         
         when READ_CMD => 
            spi_wr_en <= '1';
            cmd_en <= '1';
            next_state <= READ_WAIT;
            
         when READ_WAIT => 
            wait_load <= '1';
            if spi_rd_en = '1' then
               next_state <= WAIT_DATA;
            end if;
         
         when WAIT_DATA => 
            byte_rst <= '1';
            if wait_done = '1' then
               next_state <= READ_DATA;
            end if;
         
         when READ_DATA =>
            spi_wr_en <= '1';
            next_state <= STORE_DATA;
         
         when STORE_DATA =>
            if spi_rd_en = '1' then
               if byte_counter < 2 then
                  next_state <= READ_DATA;
                  byte_en <= '1';
               else
                  next_state <= WAIT_TRIG;
                  channel_en <= '1';
                  byte_en <= '1';
               end if;
            end if;
         
         when others =>
            next_state <= IDLE;
      
      end case;
      
   end process;

end RTL;

