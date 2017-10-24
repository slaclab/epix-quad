-------------------------------------------------------------------------------
-- Title      : Cpix detector conversion look-up table
-------------------------------------------------------------------------------
-- File       : CpixLUT.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 03/09/2016
-- Last update: 03/09/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Cpix detector conversion look-up table
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.CpixLUTPkg.all;


library unisim;
use unisim.vcomponents.all;

entity Cpix2LUT is
   generic (
      TPD_G          : time      := 1 ns
   );
   port (
      sysClk         : in  std_logic;
      sysRst         : in  std_logic;
      
      -- input stream
      sDataIn    : in  std_logic_vector(19 downto 0);
      
      -- output stream
      sDataOut    : out std_logic_vector(19 downto 0)
      
   );
end Cpix2LUT;

architecture rtl of Cpix2LUT is

   signal lutAddress    : std_logic_vector(15 downto 0);
   signal lutData       : std_logic_vector(14 downto 0);
   signal dataMux       : std_logic_vector(15 downto 0);


begin
   
   
   seq_p: process ( sysClk ) 
   begin
      -- 1 stage pipeline
     
      -- output stream register
      if rising_edge(sysClk) then
         if sysRst = '1' then
            sDataOut <= (others => '0')      after TPD_G;
         else
            sDataOut(15 downto  0)           <= dataMux                after TPD_G;
            sDataOut(19 downto 16)           <= sDataIn(19 downto 16)  after TPD_G;
         end if;
      end if;
   end process;
   
   -- only data stream is replaced with LUT data
   dataMux <= '0' & lutData;
   
   -- LUT ram
   lutAddress <= '0' & sDataIn(6 downto 0) & sDataIn(15 downto 8);
   
   -- the input address is 15 bit therefore the lut size is 32kb
   -- the output converted data is 15 bit
   -- each output bit is stored in separate RAM block therefore 15 blocks
   CpixLUTRam_G : for i in 0 to 14 generate
      
      CpixLUTRam_U: RAMB36E1
      generic map 
      ( 
         READ_WIDTH_A         => 1,
         WRITE_WIDTH_A        => 1,
         DOA_REG              => 0,
         INIT_A               => X"000000000",
         RSTREG_PRIORITY_A    => "REGCE",
         SRVAL_A              => X"000000000",
         WRITE_MODE_A         => "WRITE_FIRST",
         READ_WIDTH_B         => 1,
         WRITE_WIDTH_B        => 1,
         DOB_REG              => 0,
         INIT_B               => X"000000000",
         RSTREG_PRIORITY_B    => "REGCE",
         SRVAL_B              => X"000000000",
         WRITE_MODE_B         => "WRITE_FIRST",
         INIT_FILE            => "NONE",
         SIM_COLLISION_CHECK  => "ALL",
         RAM_MODE             => "TDP",
         RDADDR_COLLISION_HWCONFIG => "DELAYED_WRITE",
         EN_ECC_READ          => FALSE,
         EN_ECC_WRITE         => FALSE,
         RAM_EXTENSION_A      => "NONE",
         RAM_EXTENSION_B      => "NONE",
         SIM_DEVICE           => "7SERIES",
         INIT_00              => CPIX_NORMAL_INIT_00_BITS_C(i),
         INIT_01              => CPIX_NORMAL_INIT_01_BITS_C(i),
         INIT_02              => CPIX_NORMAL_INIT_02_BITS_C(i),
         INIT_03              => CPIX_NORMAL_INIT_03_BITS_C(i),
         INIT_04              => CPIX_NORMAL_INIT_04_BITS_C(i),
         INIT_05              => CPIX_NORMAL_INIT_05_BITS_C(i),
         INIT_06              => CPIX_NORMAL_INIT_06_BITS_C(i),
         INIT_07              => CPIX_NORMAL_INIT_07_BITS_C(i),
         INIT_08              => CPIX_NORMAL_INIT_08_BITS_C(i),
         INIT_09              => CPIX_NORMAL_INIT_09_BITS_C(i),
         INIT_0A              => CPIX_NORMAL_INIT_0A_BITS_C(i),
         INIT_0B              => CPIX_NORMAL_INIT_0B_BITS_C(i),
         INIT_0C              => CPIX_NORMAL_INIT_0C_BITS_C(i),
         INIT_0D              => CPIX_NORMAL_INIT_0D_BITS_C(i),
         INIT_0E              => CPIX_NORMAL_INIT_0E_BITS_C(i),
         INIT_0F              => CPIX_NORMAL_INIT_0F_BITS_C(i),
         INIT_10              => CPIX_NORMAL_INIT_10_BITS_C(i),
         INIT_11              => CPIX_NORMAL_INIT_11_BITS_C(i),
         INIT_12              => CPIX_NORMAL_INIT_12_BITS_C(i),
         INIT_13              => CPIX_NORMAL_INIT_13_BITS_C(i),
         INIT_14              => CPIX_NORMAL_INIT_14_BITS_C(i),
         INIT_15              => CPIX_NORMAL_INIT_15_BITS_C(i),
         INIT_16              => CPIX_NORMAL_INIT_16_BITS_C(i),
         INIT_17              => CPIX_NORMAL_INIT_17_BITS_C(i),
         INIT_18              => CPIX_NORMAL_INIT_18_BITS_C(i),
         INIT_19              => CPIX_NORMAL_INIT_19_BITS_C(i),
         INIT_1A              => CPIX_NORMAL_INIT_1A_BITS_C(i),
         INIT_1B              => CPIX_NORMAL_INIT_1B_BITS_C(i),
         INIT_1C              => CPIX_NORMAL_INIT_1C_BITS_C(i),
         INIT_1D              => CPIX_NORMAL_INIT_1D_BITS_C(i),
         INIT_1E              => CPIX_NORMAL_INIT_1E_BITS_C(i),
         INIT_1F              => CPIX_NORMAL_INIT_1F_BITS_C(i),
         INIT_20              => CPIX_NORMAL_INIT_20_BITS_C(i),
         INIT_21              => CPIX_NORMAL_INIT_21_BITS_C(i),
         INIT_22              => CPIX_NORMAL_INIT_22_BITS_C(i),
         INIT_23              => CPIX_NORMAL_INIT_23_BITS_C(i),
         INIT_24              => CPIX_NORMAL_INIT_24_BITS_C(i),
         INIT_25              => CPIX_NORMAL_INIT_25_BITS_C(i),
         INIT_26              => CPIX_NORMAL_INIT_26_BITS_C(i),
         INIT_27              => CPIX_NORMAL_INIT_27_BITS_C(i),
         INIT_28              => CPIX_NORMAL_INIT_28_BITS_C(i),
         INIT_29              => CPIX_NORMAL_INIT_29_BITS_C(i),
         INIT_2A              => CPIX_NORMAL_INIT_2A_BITS_C(i),
         INIT_2B              => CPIX_NORMAL_INIT_2B_BITS_C(i),
         INIT_2C              => CPIX_NORMAL_INIT_2C_BITS_C(i),
         INIT_2D              => CPIX_NORMAL_INIT_2D_BITS_C(i),
         INIT_2E              => CPIX_NORMAL_INIT_2E_BITS_C(i),
         INIT_2F              => CPIX_NORMAL_INIT_2F_BITS_C(i),
         INIT_30              => CPIX_NORMAL_INIT_30_BITS_C(i),
         INIT_31              => CPIX_NORMAL_INIT_31_BITS_C(i),
         INIT_32              => CPIX_NORMAL_INIT_32_BITS_C(i),
         INIT_33              => CPIX_NORMAL_INIT_33_BITS_C(i),
         INIT_34              => CPIX_NORMAL_INIT_34_BITS_C(i),
         INIT_35              => CPIX_NORMAL_INIT_35_BITS_C(i),
         INIT_36              => CPIX_NORMAL_INIT_36_BITS_C(i),
         INIT_37              => CPIX_NORMAL_INIT_37_BITS_C(i),
         INIT_38              => CPIX_NORMAL_INIT_38_BITS_C(i),
         INIT_39              => CPIX_NORMAL_INIT_39_BITS_C(i),
         INIT_3A              => CPIX_NORMAL_INIT_3A_BITS_C(i),
         INIT_3B              => CPIX_NORMAL_INIT_3B_BITS_C(i),
         INIT_3C              => CPIX_NORMAL_INIT_3C_BITS_C(i),
         INIT_3D              => CPIX_NORMAL_INIT_3D_BITS_C(i),
         INIT_3E              => CPIX_NORMAL_INIT_3E_BITS_C(i),
         INIT_3F              => CPIX_NORMAL_INIT_3F_BITS_C(i),
         INIT_40              => CPIX_NORMAL_INIT_40_BITS_C(i),
         INIT_41              => CPIX_NORMAL_INIT_41_BITS_C(i),
         INIT_42              => CPIX_NORMAL_INIT_42_BITS_C(i),
         INIT_43              => CPIX_NORMAL_INIT_43_BITS_C(i),
         INIT_44              => CPIX_NORMAL_INIT_44_BITS_C(i),
         INIT_45              => CPIX_NORMAL_INIT_45_BITS_C(i),
         INIT_46              => CPIX_NORMAL_INIT_46_BITS_C(i),
         INIT_47              => CPIX_NORMAL_INIT_47_BITS_C(i),
         INIT_48              => CPIX_NORMAL_INIT_48_BITS_C(i),
         INIT_49              => CPIX_NORMAL_INIT_49_BITS_C(i),
         INIT_4A              => CPIX_NORMAL_INIT_4A_BITS_C(i),
         INIT_4B              => CPIX_NORMAL_INIT_4B_BITS_C(i),
         INIT_4C              => CPIX_NORMAL_INIT_4C_BITS_C(i),
         INIT_4D              => CPIX_NORMAL_INIT_4D_BITS_C(i),
         INIT_4E              => CPIX_NORMAL_INIT_4E_BITS_C(i),
         INIT_4F              => CPIX_NORMAL_INIT_4F_BITS_C(i),
         INIT_50              => CPIX_NORMAL_INIT_50_BITS_C(i),
         INIT_51              => CPIX_NORMAL_INIT_51_BITS_C(i),
         INIT_52              => CPIX_NORMAL_INIT_52_BITS_C(i),
         INIT_53              => CPIX_NORMAL_INIT_53_BITS_C(i),
         INIT_54              => CPIX_NORMAL_INIT_54_BITS_C(i),
         INIT_55              => CPIX_NORMAL_INIT_55_BITS_C(i),
         INIT_56              => CPIX_NORMAL_INIT_56_BITS_C(i),
         INIT_57              => CPIX_NORMAL_INIT_57_BITS_C(i),
         INIT_58              => CPIX_NORMAL_INIT_58_BITS_C(i),
         INIT_59              => CPIX_NORMAL_INIT_59_BITS_C(i),
         INIT_5A              => CPIX_NORMAL_INIT_5A_BITS_C(i),
         INIT_5B              => CPIX_NORMAL_INIT_5B_BITS_C(i),
         INIT_5C              => CPIX_NORMAL_INIT_5C_BITS_C(i),
         INIT_5D              => CPIX_NORMAL_INIT_5D_BITS_C(i),
         INIT_5E              => CPIX_NORMAL_INIT_5E_BITS_C(i),
         INIT_5F              => CPIX_NORMAL_INIT_5F_BITS_C(i),
         INIT_60              => CPIX_NORMAL_INIT_60_BITS_C(i),
         INIT_61              => CPIX_NORMAL_INIT_61_BITS_C(i),
         INIT_62              => CPIX_NORMAL_INIT_62_BITS_C(i),
         INIT_63              => CPIX_NORMAL_INIT_63_BITS_C(i),
         INIT_64              => CPIX_NORMAL_INIT_64_BITS_C(i),
         INIT_65              => CPIX_NORMAL_INIT_65_BITS_C(i),
         INIT_66              => CPIX_NORMAL_INIT_66_BITS_C(i),
         INIT_67              => CPIX_NORMAL_INIT_67_BITS_C(i),
         INIT_68              => CPIX_NORMAL_INIT_68_BITS_C(i),
         INIT_69              => CPIX_NORMAL_INIT_69_BITS_C(i),
         INIT_6A              => CPIX_NORMAL_INIT_6A_BITS_C(i),
         INIT_6B              => CPIX_NORMAL_INIT_6B_BITS_C(i),
         INIT_6C              => CPIX_NORMAL_INIT_6C_BITS_C(i),
         INIT_6D              => CPIX_NORMAL_INIT_6D_BITS_C(i),
         INIT_6E              => CPIX_NORMAL_INIT_6E_BITS_C(i),
         INIT_6F              => CPIX_NORMAL_INIT_6F_BITS_C(i),
         INIT_70              => CPIX_NORMAL_INIT_70_BITS_C(i),
         INIT_71              => CPIX_NORMAL_INIT_71_BITS_C(i),
         INIT_72              => CPIX_NORMAL_INIT_72_BITS_C(i),
         INIT_73              => CPIX_NORMAL_INIT_73_BITS_C(i),
         INIT_74              => CPIX_NORMAL_INIT_74_BITS_C(i),
         INIT_75              => CPIX_NORMAL_INIT_75_BITS_C(i),
         INIT_76              => CPIX_NORMAL_INIT_76_BITS_C(i),
         INIT_77              => CPIX_NORMAL_INIT_77_BITS_C(i),
         INIT_78              => CPIX_NORMAL_INIT_78_BITS_C(i),
         INIT_79              => CPIX_NORMAL_INIT_79_BITS_C(i),
         INIT_7A              => CPIX_NORMAL_INIT_7A_BITS_C(i),
         INIT_7B              => CPIX_NORMAL_INIT_7B_BITS_C(i),
         INIT_7C              => CPIX_NORMAL_INIT_7C_BITS_C(i),
         INIT_7D              => CPIX_NORMAL_INIT_7D_BITS_C(i),
         INIT_7E              => CPIX_NORMAL_INIT_7E_BITS_C(i),
         INIT_7F              => CPIX_NORMAL_INIT_7F_BITS_C(i)
      )
      port map (   
         ADDRARDADDR          => lutAddress,
         ENARDEN              => '1',
         CLKARDCLK            => sysClk,
         DOADO(31 downto 1)   => open,
         DOADO(0)             => lutData(i),
         DOPADOP              => open, 
         DIADI                => x"00000000",
         DIPADIP              => "0000", 
         WEA                  => "0000",
         REGCEAREGCE          => '0',
         RSTRAMARSTRAM        => '0',
         RSTREGARSTREG        => '0',
         ADDRBWRADDR          => "1111111111111111",
         ENBWREN              => '0',
         CLKBWRCLK            => '0',
         DOBDO                => open,
         DOPBDOP              => open, 
         DIBDI                => x"00000000",
         DIPBDIP              => "0000", 
         WEBWE                => "00000000",
         REGCEB               => '0',
         RSTRAMB              => '0',
         RSTREGB              => '0',
         CASCADEINA           => '0',
         CASCADEINB           => '0',
         INJECTDBITERR        => '0',
         INJECTSBITERR        => '0'
      );
      
   end generate CpixLUTRam_G;
   
   
end rtl;
