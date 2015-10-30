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
use work.StdRtlPkg.all;

entity SlowAdcCntrl is 
   generic (
      TPD_G           	: time := 1 ns;
      CLK_PERIOD_G      : real := 10.0E-9;	-- 100MHz
      SPI_SCLK_PERIOD_G : real := 1.0E-6  	-- 1 MHz
   );
   port ( 
      -- Master system clock
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- Operation Control
      adcStart        : in  std_logic;
      adcData         : out Slv24Array(9 downto 0);
      adcStrobe       : out std_logic;

      -- ADC Control Signals
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
   constant r0_refhi :     std_logic_vector(0 downto 0) := "0";      -- "0" - Vref 1.25, "1" - Vref 2.5
   constant r0_bufen :     std_logic_vector(0 downto 0) := "0";      -- "0" - buffer disabled, "1" - buffer enabled
   constant r2_idac1r :    std_logic_vector(1 downto 0) := "10";     -- "00" - off, "01" - range 1 ... "11" - range 3
   constant r2_idac2r :    std_logic_vector(1 downto 0) := "10";     -- "00" - off, "01" - range 1 ... "11" - range 3
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
   
   TYPE STATE_TYPE IS (IDLE, INIT_BYTE, INIT_WAIT, WAIT_TRIG, ACQ_BYTE, ACQ_WAIT, MUX_EXT_ON, MUX_TEMP);
   SIGNAL state, next_state   : STATE_TYPE;

   
   
   signal adcDrdyEn :      std_logic;
   signal adcDrdyD1 :      std_logic;
   signal adcDrdyD2 :      std_logic;
   signal init_out :       std_logic;
   signal spi_wr_en :      std_logic;
   signal spi_wr_data :    std_logic_vector(7 downto 0);
   signal spi_rd_en :      std_logic;
   signal spi_rd_data :    std_logic_vector(7 downto 0);
   signal init_data :      std_logic_vector(7 downto 0);
   signal acq_data :       std_logic_vector(7 downto 0);
   signal byte_counter :   integer range 0 to 13;
   signal byte_rst :       std_logic;
   signal byte_en :        std_logic;
   signal ain_sel  :       std_logic_vector(3 downto 0);
   signal ain_counter :    integer range 0 to 9;
   signal ain_rst :        std_logic;
   signal ain_en :         std_logic;

begin

   -- Drdy sync and falling edge detector
   process ( sysClk ) 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            adcDrdyD1 <= '0';
            adcDrdyD2 <= '0';
         else
            adcDrdyD1 <= adcDrdy;
            adcDrdyD2 <= adcDrdyD1;
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
         CLK_PERIOD_G      => CLK_PERIOD_G,
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
         spiCsL(0)=> adcCsL,
         spiSclk  => adcSclk,
         spiSdi   => adcDin,
         spiSdo   => adcDout
      );
   
   -- ADC write MUX
   spi_wr_data <= init_data when init_out = '1' else acq_data;
   
   
   
   -- ADC initialization data MUX
   init_data <=   
      cmd_reset               when byte_counter = 0 else    -- reset command
      cmd_wr_reg & "0000"     when byte_counter = 1 else    -- write register command starting from reg 0
      "00001010"              when byte_counter = 2 else    -- write register command write 10 registers
      adc_setup_regs(0)       when byte_counter = 3 else    -- write registers 0 to 9
      adc_setup_regs(1)       when byte_counter = 4 else 
      adc_setup_regs(2)       when byte_counter = 5 else 
      adc_setup_regs(3)       when byte_counter = 6 else 
      adc_setup_regs(4)       when byte_counter = 7 else 
      adc_setup_regs(5)       when byte_counter = 8 else 
      adc_setup_regs(6)       when byte_counter = 9 else 
      adc_setup_regs(7)       when byte_counter = 10 else 
      adc_setup_regs(8)       when byte_counter = 11 else 
      adc_setup_regs(9)       when byte_counter = 12 else 
      "00000000";
   
   -- ADC acquisition data MUX
   acq_data <=   
      cmd_wr_reg & "0001"     when byte_counter = 0 else    -- write register command with MUX reg address
      "00000001"              when byte_counter = 1 else    -- write register command write 1 register
      ain_sel & "1000"        when byte_counter = 2 and ain_counter < 8 else    -- write register data with selected ain
      "0111"  & "1000"        when byte_counter = 2 and ain_counter = 8 else    -- write register data with ain no 7
      "1111"  & "1111"        when byte_counter = 2 and ain_counter = 9 else    -- write register data with selected internal diode
      cmd_wr_reg & "0110"     when byte_counter = 3 else    -- write register command with DIO reg address
      "00000001"              when byte_counter = 4 else    -- write register command write 1 register
      "00000001"              when byte_counter = 5 and ain_counter = 8 else    -- write register data, switch external MUX
      "00000000"              when byte_counter = 5 and ain_counter /= 8 else   -- write register data, do not switch external MUX
      cmd_dsync               when byte_counter = 6 else    -- DSYNC command
      cmd_rdata               when byte_counter = 7 else    -- read data command
      "00000000";

   -- byte select counter counter
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

   fsm_cmb_p: process ( state, adcDrdyEn, spi_rd_en, byte_counter, ain_counter, adcStart) 
   begin
      next_state <= state;
      byte_en <= '0';
      byte_rst <= '0';
      ain_en <= '0';
      ain_rst <= '0';
      spi_wr_en <= '0';
      init_out <= '0';
      
      case state is
      
         when IDLE =>
            byte_rst <= '1';
            ain_rst <= '1';
            next_state <= INIT_BYTE;
         
         when INIT_BYTE => 
            spi_wr_en <= '1';
            byte_en <= '1';
            init_out <= '1';
            next_state <= INIT_WAIT;
            
         when INIT_WAIT =>
            init_out <= '1';
            if spi_rd_en = '1' then
               if byte_counter < 13 then
                  next_state <= INIT_BYTE;
               else
                  next_state <= WAIT_TRIG;
               end if;
            end if;
         
         when WAIT_TRIG => 
            byte_rst <= '1';
            --if adcStart = '1' then
               next_state <= ACQ_BYTE;
            --else
            --   next_state <= WAIT_TRIG;
            --end if;
         
         when ACQ_BYTE => 
            if byte_counter = 6 and ain_counter < 9 then
               ain_en <= '1';
            elsif byte_counter = 6 and ain_counter >= 9 then
               ain_rst <= '1';
            end if;
            spi_wr_en <= '1';
            byte_en <= '1';
            next_state <= ACQ_WAIT;
            
         when ACQ_WAIT => 
            if spi_rd_en = '1' then
               if byte_counter < 8 then
                  next_state <= ACQ_BYTE;
               else
                  next_state <= WAIT_TRIG;   -- change to new state WAIT_DATA, READ_DATA ...
               end if;
            end if;
         
         when others =>
            next_state <= IDLE;
      
      end case;
      
   end process;

end RTL;

