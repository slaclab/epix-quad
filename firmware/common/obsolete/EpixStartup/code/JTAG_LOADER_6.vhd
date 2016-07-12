--
-------------------------------------------------------------------------------------------
-- Copyright © 2010, Xilinx, Inc.
-- This file contains confidential and proprietary information of Xilinx, Inc. and is
-- protected under U.S. and international copyright and other intellectual property laws.
-------------------------------------------------------------------------------------------
--
-- Disclaimer:
-- This disclaimer is not a license and does not grant any rights to the materials
-- distributed herewith. Except as otherwise provided in a valid license issued to
-- you by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE
-- MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY
-- DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY,
-- INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT,
-- OR FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable
-- (whether in contract or tort, including negligence, or under any other theory
-- of liability) for any loss or damage of any kind or nature related to, arising
-- under or in connection with these materials, including for any direct, or any
-- indirect, special, incidental, or consequential loss or damage (including loss
-- of data, profits, goodwill, or any type of loss or damage suffered as a result
-- of any action brought by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-safe, or for use in any
-- application requiring fail-safe performance, such as life-support or safety
-- devices or systems, Class III medical devices, nuclear facilities, applications
-- related to the deployment of airbags, or any other applications that could lead
-- to death, personal injury, or severe property or environmental damage
-- (individually and collectively, "Critical Applications"). Customer assumes the
-- sole risk and liability of any use of Xilinx products in Critical Applications,
-- subject only to applicable laws and regulations governing limitations on product
-- liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
--
-------------------------------------------------------------------------------------------
--
-- JTAG Loader 6 - Version 6.00
-- Kris Chaplin 4 February 2010



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

entity jtag_loader_6 is
generic(
                     C_JTAG_LOADER_DISABLE : integer := 0;
                                  C_FAMILY : string := "VIRTEX5";
                           C_NUM_PICOBLAZE : integer := 1;
                     C_BRAM_MAX_ADDR_WIDTH : integer := 10;
        C_PICOBLAZE_INSTRUCTION_DATA_WIDTH : integer := 18;
                              C_JTAG_CHAIN : integer := 2;
                            C_ADDR_WIDTH_0 : integer := 10;
                            C_ADDR_WIDTH_1 : integer := 10;
                            C_ADDR_WIDTH_2 : integer := 10;
                            C_ADDR_WIDTH_3 : integer := 10;
                            C_ADDR_WIDTH_4 : integer := 10;
                            C_ADDR_WIDTH_5 : integer := 10;
                            C_ADDR_WIDTH_6 : integer := 10;
                            C_ADDR_WIDTH_7 : integer := 10);
port(
        picoblaze_reset : out std_logic_vector(C_NUM_PICOBLAZE-1 downto 0);
                jtag_en : out std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) := (others => '0');
               jtag_din : out std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0) := (others => '0');
              jtag_addr : out std_logic_vector(C_BRAM_MAX_ADDR_WIDTH-1 downto 0) := (others => '0');
               jtag_clk : out std_logic := '0';
                jtag_we : out std_logic := '0';
            jtag_dout_0 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_1 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_2 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_3 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_4 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_5 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_6 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
            jtag_dout_7 : in  std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0));
end jtag_loader_6;

architecture Behavioral of jtag_loader_6 is

        COMPONENT bscan_logic
        generic(
                        C_JTAG_CHAIN : integer := 2;
                C_BUFFER_SHIFT_CLOCK : boolean := TRUE;
                            C_FAMILY : string := "SPARTAN6");
        PORT(
                shift_dout : in std_logic;          
                 shift_clk : out std_logic;
                   bram_en : out std_logic;
                 shift_din : out std_logic;
               bram_strobe : out std_logic;
                   capture : out std_logic;
                     shift : out std_logic);
        END COMPONENT;

        COMPONENT jtag_shifter
        generic (       
                                   C_NUM_PICOBLAZE : integer := 1;
                             C_BRAM_MAX_ADDR_WIDTH : integer := 10;
                C_PICOBLAZE_INSTRUCTION_DATA_WIDTH : integer := 18
        );
        PORT(
                     shift_clk : in std_logic;
                     shift_din : in std_logic;  
                         shift : in std_logic;
                    shift_dout : out std_logic;
                control_reg_ce : out std_logic;
                       bram_ce : out std_logic_vector(C_NUM_PICOBLAZE-1 downto 0);
                        bram_a : out std_logic_vector(C_BRAM_MAX_ADDR_WIDTH-1 downto 0);
                      din_load : in std_logic;
                           din : in std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
                        bram_d : out std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
                       bram_we : out std_logic);
        END COMPONENT;
        
        COMPONENT control_registers
        generic ( 
                                   C_NUM_PICOBLAZE : integer := 1;
                C_PICOBLAZE_INSTRUCTION_DATA_WIDTH : integer := 18;
                                    C_ADDR_WIDTH_0 : integer := 10;
                                    C_ADDR_WIDTH_1 : integer := 10;
                                    C_ADDR_WIDTH_2 : integer := 10;
                                    C_ADDR_WIDTH_3 : integer := 10;
                                    C_ADDR_WIDTH_4 : integer := 10;
                                    C_ADDR_WIDTH_5 : integer := 10;
                                    C_ADDR_WIDTH_6 : integer := 10;
                                    C_ADDR_WIDTH_7 : integer := 10;
                             C_BRAM_MAX_ADDR_WIDTH : integer := 10);
        PORT(
                             en : in std_logic;
                             ce : in std_logic;
                            wnr : in std_logic;
                            clk : in std_logic;
                              a : in std_logic_vector(3 downto 0);
                            din : in std_logic_vector(7 downto 0);          
                           dout : out std_logic_vector(7 downto 0);
                picoblaze_reset : out std_logic_vector(C_NUM_PICOBLAZE-1 downto 0));
        END COMPONENT;

        signal shift_clk  : std_logic;
        signal shift_din  : std_logic;
        signal shift_dout : std_logic;
        signal shift      : std_logic;
        signal capture    : std_logic;

        signal control_reg_ce   : std_logic;
        signal bram_ce          : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0);
        signal bus_zero         : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) := (others => '0');
        signal jtag_en_int      : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0);
        signal jtag_en_expanded : std_logic_vector(7 downto 0) := (others => '0');
        signal jtag_addr_int    : std_logic_vector(C_BRAM_MAX_ADDR_WIDTH-1 downto 0);
        signal jtag_din_int     : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal control_din      : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0):= (others => '0');
        signal control_dout     : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0):= (others => '0');
        signal bram_dout_int    : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0) := (others => '0');
        signal jtag_we_int      : std_logic;
        signal jtag_clk_int     : std_logic;
        signal bram_ce_valid    : std_logic;
        signal din_load         : std_logic;

        signal jtag_dout_0_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_1_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_2_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_3_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_4_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_5_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_6_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal jtag_dout_7_masked  : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
        signal picoblaze_reset_int : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) := (others => '0');
        
begin

jtag_loader_gen: if (C_JTAG_LOADER_DISABLE = 0) generate

        Inst_bscan_logic: bscan_logic 
        GENERIC MAP (
                        C_JTAG_CHAIN => C_JTAG_CHAIN,
                C_BUFFER_SHIFT_CLOCK => TRUE,
                            C_FAMILY => C_FAMILY )
        PORT MAP(
                 shift_dout => shift_dout,
                  shift_clk => shift_clk,
                    bram_en => bram_ce_valid,
                  shift_din => shift_din,
                bram_strobe => jtag_clk_int,
                    capture => capture,
                      shift => shift );
                
        Inst_jtag_shifter: jtag_shifter 
        GENERIC MAP(
                                   C_NUM_PICOBLAZE => C_NUM_PICOBLAZE,
                             C_BRAM_MAX_ADDR_WIDTH => C_BRAM_MAX_ADDR_WIDTH,
                C_PICOBLAZE_INSTRUCTION_DATA_WIDTH => C_PICOBLAZE_INSTRUCTION_DATA_WIDTH )       
        PORT MAP(
                     shift_clk => shift_clk,
                     shift_din => shift_din,
                         shift => shift,
                    shift_dout => shift_dout,
                control_reg_ce => control_reg_ce,
                       bram_ce => bram_ce,
                        bram_a => jtag_addr_int,
                      din_load => din_load,
                           din => bram_dout_int,
                        bram_d => jtag_din_int,
                       bram_we => jtag_we_int );

        process (bram_ce, din_load, capture, bus_zero, control_reg_ce) begin
        if ( bram_ce = bus_zero ) then
                din_load <= capture and control_reg_ce;
        else
                din_load <= capture;
        end if;
        end process;

        Inst_control_registers: control_registers 
        GENERIC MAP(
                                   C_NUM_PICOBLAZE => C_NUM_PICOBLAZE,
                C_PICOBLAZE_INSTRUCTION_DATA_WIDTH => C_PICOBLAZE_INSTRUCTION_DATA_WIDTH,
                                    C_ADDR_WIDTH_0 => C_ADDR_WIDTH_0,
                                    C_ADDR_WIDTH_1 => C_ADDR_WIDTH_1,
                                    C_ADDR_WIDTH_2 => C_ADDR_WIDTH_2,
                                    C_ADDR_WIDTH_3 => C_ADDR_WIDTH_3,
                                    C_ADDR_WIDTH_4 => C_ADDR_WIDTH_4,
                                    C_ADDR_WIDTH_5 => C_ADDR_WIDTH_5,
                                    C_ADDR_WIDTH_6 => C_ADDR_WIDTH_6,
                                    C_ADDR_WIDTH_7 => C_ADDR_WIDTH_7,
                             C_BRAM_MAX_ADDR_WIDTH => C_BRAM_MAX_ADDR_WIDTH
        )
        PORT MAP(
                             en => bram_ce_valid,
                             ce => control_reg_ce,
                            wnr => jtag_we_int,
                            clk => jtag_clk_int,
                              a => jtag_addr_int(3 downto 0),
                            din => control_din(7 downto 0),
                           dout => control_dout(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-8),
                picoblaze_reset => picoblaze_reset_int
        );

        -- Qualify the blockram CS signal with bscan select output
        jtag_en_int <= bram_ce when bram_ce_valid = '1' else (others => '0');
        
        jtag_en_expanded(C_NUM_PICOBLAZE-1 downto 0) <= jtag_en_int;
        
        bram_dout_int <= control_dout or jtag_dout_0_masked or jtag_dout_1_masked or jtag_dout_2_masked or jtag_dout_3_masked or jtag_dout_4_masked or jtag_dout_5_masked or jtag_dout_6_masked or jtag_dout_7_masked;

        control_din <= jtag_din_int;
        
        jtag_dout_0_masked <= jtag_dout_0 when jtag_en_expanded(0) = '1' else (others => '0');
        jtag_dout_1_masked <= jtag_dout_1 when jtag_en_expanded(1) = '1' else (others => '0');
        jtag_dout_2_masked <= jtag_dout_2 when jtag_en_expanded(2) = '1' else (others => '0');
        jtag_dout_3_masked <= jtag_dout_3 when jtag_en_expanded(3) = '1' else (others => '0');
        jtag_dout_4_masked <= jtag_dout_4 when jtag_en_expanded(4) = '1' else (others => '0');
        jtag_dout_5_masked <= jtag_dout_5 when jtag_en_expanded(5) = '1' else (others => '0');
        jtag_dout_6_masked <= jtag_dout_6 when jtag_en_expanded(6) = '1' else (others => '0');
        jtag_dout_7_masked <= jtag_dout_7 when jtag_en_expanded(7) = '1' else (others => '0');
        
end generate;


        jtag_en <= jtag_en_int;
        jtag_din <= jtag_din_int;
        jtag_addr <= jtag_addr_int;
        jtag_clk <= jtag_clk_int;
        jtag_we <= jtag_we_int;
        picoblaze_reset <= picoblaze_reset_int;

end Behavioral;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity control_registers is
generic (                   C_NUM_PICOBLAZE : integer := 1;
         C_PICOBLAZE_INSTRUCTION_DATA_WIDTH : integer := 18;
                             C_ADDR_WIDTH_0 : integer := 10;
                             C_ADDR_WIDTH_1 : integer := 10;
                             C_ADDR_WIDTH_2 : integer := 10;
                             C_ADDR_WIDTH_3 : integer := 10;
                             C_ADDR_WIDTH_4 : integer := 10;
                             C_ADDR_WIDTH_5 : integer := 10;
                             C_ADDR_WIDTH_6 : integer := 10;
                             C_ADDR_WIDTH_7 : integer := 10;
                      C_BRAM_MAX_ADDR_WIDTH : integer := 10 );
                      
    Port (              en : in std_logic;
                        ce : in std_logic;
                       wnr : in std_logic;
                       clk : in std_logic;
                         a : in std_logic_vector (3 downto 0);
                       din : in std_logic_vector (7 downto 0);
                      dout : out std_logic_vector (7 downto 0);
           picoblaze_reset : out std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) );
end control_registers;

architecture Behavioral of control_registers is

        signal version             : std_logic_vector(7 downto 0) := "00000001";
        signal picoblaze_reset_int : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) := (others => '0');
        signal picoblaze_wait_int  : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) := (others => '0');
        signal dout_int            : std_logic_vector(7 downto 0) := (others => '0');
        signal num_picoblaze       : std_logic_vector(2 downto 0) := conv_std_logic_vector(C_NUM_PICOBLAZE-1,3);
        
        signal picoblaze_instruction_data_width : std_logic_vector(4 downto 0) := conv_std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1,5);

begin
        process(clk) begin
                if (clk'event and clk = '1') then
                        if (en = '1') and (wnr = '0') and (ce = '1') then
                                case (a) is 
                                when "0000" => -- 0 = version - returns (7 downto 4) illustrating number of PB
                                               --               and (3 downto 0) picoblaze instruction data width
                                        dout_int <= num_picoblaze & picoblaze_instruction_data_width;
                                when "0001" => -- 1 = PicoBlaze 0 reset / status
                                        if (C_NUM_PICOBLAZE >= 1) then 
                                                dout_int <= picoblaze_reset_int(0) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_0-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "0010" => -- 2 = PicoBlaze 1 reset / status
                                        if (C_NUM_PICOBLAZE >= 2) then 
                                                dout_int <= picoblaze_reset_int(1) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_1-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "0011" => -- 3 = PicoBlaze 2 reset / status
                                        if (C_NUM_PICOBLAZE >= 3) then 
                                                dout_int <= picoblaze_reset_int(2) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_2-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "0100" => -- 4 = PicoBlaze 3 reset / status
                                        if (C_NUM_PICOBLAZE >= 4) then 
                                                dout_int <= picoblaze_reset_int(3) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_3-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "0101" => -- 5 = PicoBlaze 4 reset / status
                                        if (C_NUM_PICOBLAZE >= 5) then 
                                                dout_int <= picoblaze_reset_int(4) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_4-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "0110" => -- 6 = PicoBlaze 5 reset / status
                                        if (C_NUM_PICOBLAZE >= 6) then 
                                                dout_int <= picoblaze_reset_int(5) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_5-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "0111" => -- 7 = PicoBlaze 6 reset / status
                                        if (C_NUM_PICOBLAZE >= 7) then 
                                                dout_int <= picoblaze_reset_int(6) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_6-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
        
                                when "1000" => -- 8 = PicoBlaze 7 reset / status
                                        if (C_NUM_PICOBLAZE >= 8) then 
                                                dout_int <= picoblaze_reset_int(7) & "00" & (conv_std_logic_vector(C_ADDR_WIDTH_7-1,5) );
                                        else 
                                                dout_int <= (others => '0');
                                        end if;
                                when "1111" =>
                                        dout_int <= conv_std_logic_vector(C_BRAM_MAX_ADDR_WIDTH -1,8);
                                when others =>
                                        dout_int <= (others => '0');
                                end case;
                        else 
                                dout_int <= (others => '0');
                        end if;
                end if;
        end process;

        dout <= dout_int;

        process(clk) begin
                if (clk'event and clk = '1') then
                        if (en = '1') and (wnr = '1') and (ce = '1') then
                                picoblaze_reset_int(C_NUM_PICOBLAZE-1 downto 0) <= din(C_NUM_PICOBLAZE-1 downto 0);
                        end if;
                end if;
        end process;    

        picoblaze_reset <= picoblaze_reset_int;

end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity jtag_shifter is
generic (
                           C_NUM_PICOBLAZE : integer := 1;
                     C_BRAM_MAX_ADDR_WIDTH : integer := 10;
        C_PICOBLAZE_INSTRUCTION_DATA_WIDTH : integer := 18
);

Port ( 
             shift_clk : in  std_logic;
             shift_din : in  std_logic;
                 shift : in  std_logic;
            shift_dout : out std_logic;
        control_reg_ce : out std_logic;
               bram_ce : out std_logic_vector(C_NUM_PICOBLAZE-1 downto 0);
                bram_a : out std_logic_vector(C_BRAM_MAX_ADDR_WIDTH-1 downto 0);
              din_load : in std_logic;
                   din : in std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
                bram_d : out std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0);
               bram_we : out std_logic );
end jtag_shifter;

architecture Behavioral of jtag_shifter is

        signal control_reg_ce_int : std_logic;
        signal bram_ce_int        : std_logic_vector(C_NUM_PICOBLAZE-1 downto 0) := (others => '0');
        signal bram_a_int         : std_logic_vector(C_BRAM_MAX_ADDR_WIDTH-1 downto 0) := (others => '0');
        signal bram_d_int         : std_logic_vector(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1 downto 0) := (others => '0');
        signal bram_we_int        : std_logic := '0';

begin

        control_reg_ce_shift : process (shift_clk)
        begin
                if shift_clk'event and shift_clk = '1' then
                        if (shift = '1') then
                                control_reg_ce_int <= shift_din;
                        end if;
                end if;
        end process;
        control_reg_ce <= control_reg_ce_int;
        
        bram_ce_shift : process (shift_clk)
        begin
                if shift_clk'event and shift_clk='1' then  
                        if (shift = '1') then
                        for i in 0 to C_NUM_PICOBLAZE-2 loop
                                bram_ce_int(i+1) <= bram_ce_int(i);
                        end loop;
                        bram_ce_int(0) <= control_reg_ce_int;
                        end if;
                end if;
        end process;
        
        bram_we_shift : process (shift_clk)
        begin
                if shift_clk'event and shift_clk='1' then  
                if (shift = '1') then
                                bram_we_int <= bram_ce_int(C_NUM_PICOBLAZE-1);
                end if;
                end if;
        end process;
        
        bram_a_shift : process (shift_clk)
        begin
                if shift_clk'event and shift_clk='1' then  
                if (shift = '1') then
                        for i in 0 to C_BRAM_MAX_ADDR_WIDTH-2 loop
                                bram_a_int(i+1) <= bram_a_int(i);
                        end loop;
                        bram_a_int(0) <= bram_we_int;
                end if;
                end if;
        end process;
        
        bram_d_shift : process (shift_clk)
        begin
                if shift_clk'event and shift_clk='1' then  
                if (din_load = '1') then
                        bram_d_int <= din;
                elsif (shift = '1') then
                        for i in 0 to C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-2 loop
                                bram_d_int(i+1) <= bram_d_int(i);
                        end loop;
                        bram_d_int(0) <= bram_a_int(C_BRAM_MAX_ADDR_WIDTH-1);
                end if;
                end if;
        end process;
        
        bram_ce <= bram_ce_int;
        bram_we <= bram_we_int;
        bram_d  <= bram_d_int;
        bram_a  <= bram_a_int;
        shift_dout <= bram_d_int(C_PICOBLAZE_INSTRUCTION_DATA_WIDTH-1);

end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library unisim;
use unisim.vcomponents.all;

entity bscan_logic is
generic(
                C_JTAG_CHAIN : integer :=2;
        C_BUFFER_SHIFT_CLOCK : boolean := TRUE;
                    C_FAMILY : string := "SPARTAN6" );
Port (
         shift_dout : in std_logic;
          shift_clk : out std_logic;
            bram_en : out std_logic;
          shift_din : out std_logic;
        bram_strobe : out std_logic;
            capture : out std_logic;
              shift : out std_logic );
end bscan_logic;

architecture low_level_definition of bscan_logic is

        component BSCAN_VIRTEX6
        generic(
                  JTAG_CHAIN : integer :=1;
                DISABLE_JTAG : boolean := FALSE );
        port(
                CAPTURE : out std_ulogic;
                   DRCK : out std_ulogic;
                  RESET : out std_ulogic;
                RUNTEST : out std_ulogic;
                    SEL : out std_ulogic;
                  SHIFT : out std_ulogic;
                    TCK : out std_ulogic;
                    TDI : out std_ulogic;
                    TMS : out std_ulogic;
                 UPDATE : out std_ulogic;
                    TDO : in std_ulogic );
        end component;

        component BSCAN_SPARTAN6
        generic(
                JTAG_CHAIN : integer :=1 );
        port(
                CAPTURE : out std_ulogic;
                   DRCK : out std_ulogic;
                  RESET : out std_ulogic;
                RUNTEST : out std_ulogic;
                    SEL : out std_ulogic;
                  SHIFT : out std_ulogic;
                    TCK : out std_ulogic;
                    TDI : out std_ulogic;
                    TMS : out std_ulogic;
                 UPDATE : out std_ulogic;
                    TDO : in std_ulogic );
        end component;

        component BSCAN_VIRTEX5
        generic(
                JTAG_CHAIN : integer :=1 );
        port(
                CAPTURE : out std_ulogic;
                   DRCK : out std_ulogic;
                  RESET : out std_ulogic;
                    SEL : out std_ulogic;
                  SHIFT : out std_ulogic;
                    TDI : out std_ulogic;
                 UPDATE : out std_ulogic;
                    TDO : in std_ulogic );
        end component;


        component BSCAN_VIRTEX4
        generic(
                JTAG_CHAIN : integer :=1 );
        port(
                CAPTURE : out std_ulogic;
                   DRCK : out std_ulogic;
                  RESET : out std_ulogic;
                    SEL : out std_ulogic;
                  SHIFT : out std_ulogic;
                    TDI : out std_ulogic;
                 UPDATE : out std_ulogic;
                    TDO : in std_ulogic );
        end component;
        
        signal drck : std_logic;

begin

        BSCAN_VIRTEX4_gen:
        if (C_FAMILY="VIRTEX4") generate
        begin
                BSCAN_BLOCK_inst : BSCAN_VIRTEX4
                generic map
                (
                        JTAG_CHAIN => C_JTAG_CHAIN
                )
                port map
                (
                        CAPTURE => capture,
                           DRCK => drck,
                          RESET => open,
                            SEL => bram_en,
                          SHIFT => shift,
                            TDI => shift_din,
                         UPDATE => bram_strobe,
                            TDO => shift_dout
                );
        end generate;

        BSCAN_VIRTEX5_gen:
        if (C_FAMILY="VIRTEX5") generate
        begin
                BSCAN_BLOCK_inst : BSCAN_VIRTEX5
                generic map
                (
                        JTAG_CHAIN => C_JTAG_CHAIN
                )
                port map
                (
                        CAPTURE => capture,
                           DRCK => drck,
                          RESET => open,
                            SEL => bram_en,
                          SHIFT => shift,
                            TDI => shift_din,
                         UPDATE => bram_strobe,
                            TDO => shift_dout
                );
        end generate;
                
        BSCAN_SPARTAN6_gen:
        if (C_FAMILY="SPARTAN6") generate
        begin
                BSCAN_BLOCK_inst : BSCAN_SPARTAN6
                generic map
                (
                        JTAG_CHAIN => C_JTAG_CHAIN
                )
                port map
                (
                        CAPTURE => capture,
                           DRCK => drck,
                          RESET => open,
                        RUNTEST => open,
                            SEL => bram_en,
                          SHIFT => shift,
                            TCK => open,
                            TDI => shift_din,
                            TMS => open,
                         UPDATE => bram_strobe,
                            TDO => shift_dout
                );
        end generate;   

        BSCAN_VIRTEX6_gen:
        if (C_FAMILY="VIRTEX6") generate
        begin
                BSCAN_BLOCK_inst : BSCAN_VIRTEX6
                generic map
                (
                          JTAG_CHAIN => C_JTAG_CHAIN,
                        DISABLE_JTAG => FALSE
                )
                port map
                (
                        CAPTURE => capture,
                           DRCK => drck,
                          RESET => open,
                        RUNTEST => open,
                            SEL => bram_en,
                          SHIFT => shift,
                            TCK => open,
                            TDI => shift_din,
                            TMS => open,
                         UPDATE => bram_strobe,
                            TDO => shift_dout);
        end generate;   
        
        BUFG_SHIFT_CLOCK_gen:
        if (C_BUFFER_SHIFT_CLOCK = TRUE) generate
        begin
        
        upload_clock: BUFG
        port map( I => drck,
                  O => shift_clk);
        
        end generate;
        
        NO_BUFG_SHIFT_CLOCK_gen:
        if (C_BUFFER_SHIFT_CLOCK = FALSE) generate
        begin
                shift_clk <= drck;
        end generate;
        
end low_level_definition;
