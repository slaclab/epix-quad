-------------------------------------------------------------------------------
-- File       : MovingAvg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-14
-- Last update: 2017-07-14
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'Wave8 Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Wave8 Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity MovingAvg is
   generic (
      TPD_G          : time  := 1 ns;
      DATA_BITS_G    : natural range 1 to 32 := 16
   );
   port (
      clk            : in  sl;
      rst            : in  sl;
      -- moving window size is 2**(sizeCtrl)
      sizeCtrl       : in  slv(2 downto 0);
      dataIn         : in  slv(DATA_BITS_G-1 downto 0);
      dataInValid    : in  sl := '1';
      dataOut        : out slv(DATA_BITS_G-1 downto 0);
      dataOutValid   : out sl
   );
end MovingAvg;

architecture rtl of MovingAvg is
   
   constant ACC_BITS_C  : natural := 8 + DATA_BITS_G;
   
   type StateType is (
      IDLE_S,
      FILL_S,
      RUN_S
   );
   
   type RegType is record
      state          : StateType;
      sizeCtrl       : slv(2 downto 0);
      accReg         : slv(ACC_BITS_C-1 downto 0);
      accCnt         : slv(7 downto 0);
      memWrAddr      : slv(7 downto 0);
      memRdAddr      : slv(7 downto 0);
      dataOut        : slv(DATA_BITS_G-1 downto 0);
      dataOutValid   : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      sizeCtrl       => (others => '0'),
      accReg         => (others => '0'),
      accCnt         => (others => '0'),
      memWrAddr      => (others => '0'),
      memRdAddr      => (others => '0'),
      dataOut        => (others => '0'),
      dataOutValid   => '0'
   );
   
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal memRdData    : slv(DATA_BITS_G-1 downto 0);
   
   attribute keep : boolean;
   attribute keep of reg : signal is true;
   
begin
   
   -- register logic
   comb : process (rst, reg, dataIn, dataInValid, memRdData, sizeCtrl) is
      variable vreg : RegType;
      variable accSize : natural;
      variable shiftSize : natural;
   begin
      -- Latch the current value
      vreg := reg;
      
      ----------------------------------------------------------------------
      -- power of two look up table
      ----------------------------------------------------------------------
      if sizeCtrl = 0 then
         accSize := 1;
      elsif sizeCtrl = 1 then
         accSize := 2;
      elsif sizeCtrl = 2 then
         accSize := 4;
      elsif sizeCtrl = 3 then
         accSize := 8;
      elsif sizeCtrl = 4 then
         accSize := 16;
      elsif sizeCtrl = 5 then
         accSize := 32;
      elsif sizeCtrl = 6 then
         accSize := 64;
      else
         accSize := 128;
      end if;
      
      shiftSize := conv_integer(sizeCtrl);
      
      ----------------------------------------------------------------------
      -- always write dataIn to ring buffer
      -- read shifted by the size of the avg window
      ----------------------------------------------------------------------
      if dataInValid = '1' then
         vreg.memWrAddr := reg.memWrAddr + 1;
         vreg.memRdAddr := reg.memWrAddr - accSize + 1;
      end if;
      
      ----------------------------------------------------------------------
      -- moving average state machine
      ----------------------------------------------------------------------
      
      case reg.state is
         
         when IDLE_S =>
            vreg.memWrAddr := (others=>'0');
            vreg.dataOutValid := '0';
            vreg.accReg := (others=>'0');
            vreg.accCnt := (others => '0');
            if accSize > 1 then
               vreg.state := FILL_S;
            else
               vreg.state := RUN_S;
            end if;
         
         when FILL_S =>
            if dataInValid = '1' then
               vreg.accReg := reg.accReg + dataIn;
               vreg.accCnt := reg.accCnt + 1;
               if reg.accCnt = accSize-1 then
                  vreg.accCnt := reg.accCnt;
                  vreg.state := RUN_S;
               end if;
            end if;
         
         when RUN_S =>
            if dataInValid = '1' then
               if accSize > 1 then
                  vreg.accReg := reg.accReg + dataIn - memRdData;
               else
                  vreg.accReg := resize(dataIn, ACC_BITS_C);
               end if;
               vreg.dataOutValid := '1';
            else
               vreg.dataOutValid := '0';
            end if;
         
         when others =>
            vreg.state := IDLE_S;
         
      end case;
      
      -- store size control
      -- reset FSM if size changed
      vreg.sizeCtrl := sizeCtrl;
      if sizeCtrl /= reg.sizeCtrl then
         vreg.state := IDLE_S;
         vreg.dataOutValid := '0';
      end if;
      
      
      -- Reset      
      if (rst = '1') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn          <= vreg;
      dataOutValid   <= reg.dataOutValid;
      dataOut        <= reg.accReg(DATA_BITS_G-1+shiftSize downto 0+shiftSize);
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seq;
   
   ----------------------------------------------------------------------
   -- Moving avg buffer
   ----------------------------------------------------------------------
   
   U_DualPortRam: entity work.DualPortRam
   generic map (
      TPD_G          => TPD_G,
      DATA_WIDTH_G   => DATA_BITS_G,
      ADDR_WIDTH_G   => 8
   )
   port map (
      -- Port A     
      clka    => clk,
      wea     => dataInValid,
      rsta    => '0',
      addra   => reg.memWrAddr,
      dina    => dataIn,
      -- Port B
      clkb    => clk,
      rstb    => '0',
      addrb   => reg.memRdAddr,
      doutb   => memRdData
   );
   
end rtl;
