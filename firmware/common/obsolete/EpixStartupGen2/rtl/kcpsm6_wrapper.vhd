-------------------------------------------------------------------------------
-- Title         : KCPSM6 Wrapper
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : kcpsm6_wrapper.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 04/09/2015
-------------------------------------------------------------------------------
-- Description:
-- Wrapper for KCPSM6, including the processor and the ROM.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/06/2015: created.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.StdRtlPkg.all;

entity kcpsm6_wrapper is
   Generic (
      HW_BUILD_BYTE_G      : slv( 7 downto 0) := x"00";
      INTERRUPT_VECTOR_G   : slv(11 downto 0) := x"3FF";
      SCRATCHPAD_SIZE_G    : integer          := 64;
      FPGA_FAMILY_G        : string           := "7S"; --'S6', 'V6' or '7S'
      RAM_SIZE_KWORDS_G    : integer          := 2;    --Program size '1', '2' or '4'
      JTAG_LOADER_ENABLE_G : integer          := 1     --Include JTAG Loader when set to '1' 
   );
   Port (      
      port_id        : out slv(7 downto 0);
      write_strobe   : out sl;
      k_write_strobe : out sl;
      read_strobe    : out sl;
      out_port       : out slv(7 downto 0);
      in_port        : in  slv(7 downto 0);
      interrupt      : in  sl;
      interrupt_ack  : out sl;
      kcpsm6_sleep   : in  sl := '0';
      reset          : in  sl;
      clk            : in  sl
   );
end kcpsm6_wrapper;

architecture kcpsm6_wrapper of kcpsm6_wrapper is
   
   signal address        : slv(11 downto 0);
   signal instruction    : slv(17 downto 0);
   signal bram_enable    : sl;
   signal kcpsm6_reset   : sl;
   signal rdl            : sl;
   
   attribute keep : boolean;
   attribute keep of address : signal is true;
   attribute keep of instruction : signal is true;
   attribute keep of bram_enable : signal is true;


begin

  processor : entity work.kcpsm6
    generic map ( 
      hwbuild                 => HW_BUILD_BYTE_G, 
      interrupt_vector        => INTERRUPT_VECTOR_G,
      scratch_pad_memory_size => SCRATCHPAD_SIZE_G
    )
    port map(      
      address        => address,
      instruction    => instruction,
      bram_enable    => bram_enable,
      port_id        => port_id,
      write_strobe   => write_strobe,
      k_write_strobe => k_write_strobe,
      out_port       => out_port,
      read_strobe    => read_strobe,
      in_port        => in_port,
      interrupt      => interrupt,
      interrupt_ack  => interrupt_ack,
      sleep          => kcpsm6_sleep,
      reset          => kcpsm6_reset,
      clk            => clk
   );

   --Adjust name of this component to match your compiled output
   program_rom : entity work.EpixStartupCode
      generic map(             
--         ROM_FILE => "../code/EpixStartupCode.mem",
--         STYLE    => "BLOCK" -- "DISTRIBUTED" also possible
--      )
         C_FAMILY             => FPGA_FAMILY_G,
         C_RAM_SIZE_KWORDS    => RAM_SIZE_KWORDS_G,
         C_JTAG_LOADER_ENABLE => JTAG_LOADER_ENABLE_G)
      port map(      
         --Clock         => clk,
         --Enable        => bram_enable,
         --Address       => address,
         --Instruction   => instruction
         address     => address,      
         instruction => instruction,
         enable      => bram_enable,
         rdl         => rdl,
         clk         => clk
      );

  kcpsm6_reset <= reset or rdl;
                       
end kcpsm6_wrapper;

