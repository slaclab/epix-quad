-------------------------------------------------------------------------------
-- File       : MovingAvg.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;

entity MovingAvg is
   generic (
      TPD_G          : time  := 1 ns;
      CTRL_BITS_G    : natural range 1 to 4 := 3;
      DATA_BITS_G    : natural range 1 to 32 := 16
   );
   port (
      clk            : in  sl;
      rst            : in  sl;
      -- moving window size is 2**(sizeCtrl+1)
      sizeCtrl       : in  slv(CTRL_BITS_G-1 downto 0);
      sizeCtrlSet    : in  sl;
      -- minimum size is restriced by FIFO latency
      -- actSizeCtrl read back actual window size
      actSizeCtrl    : out slv(CTRL_BITS_G-1 downto 0);
      dataIn         : in  slv(DATA_BITS_G-1 downto 0);
      dataOut        : out slv(DATA_BITS_G-1 downto 0);
      dataOutValid   : out sl
   );
end MovingAvg;

architecture rtl of MovingAvg is
   
   constant SIZE_BITS_C : natural := 2**CTRL_BITS_G;
   constant ACC_BITS_C  : natural := SIZE_BITS_C + DATA_BITS_G;
   
   type StateType is (
      IDLE_S,
      FILL_S,
      EMPTY_S,
      RUN_S
   );
   
   type RegType is record
      state          : StateType;
      rstCnt         : slv(1 downto 0);
      accReg         : slv(ACC_BITS_C-1 downto 0);
      accCnt         : slv(SIZE_BITS_C-1 downto 0);
      fifoWr         : sl;
      fifoRd         : sl;
      fifoRst        : sl;
      fifoOut        : slv(DATA_BITS_G-1 downto 0);
      dataOut        : slv(DATA_BITS_G-1 downto 0);
      dataOutValid   : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      rstCnt         => (others => '1'),
      accReg         => (others => '0'),
      accCnt         => (others => '0'),
      fifoWr         => '0',
      fifoRd         => '0',
      fifoRst        => '0',
      fifoOut        => (others => '0'),
      dataOut        => (others => '0'),
      dataOutValid   => '0'
   );
   
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal fifoOut    : slv(DATA_BITS_G-1 downto 0);
   
begin
   
   -- register logic
   comb : process (rst, reg, dataIn, fifoOut, sizeCtrl, sizeCtrlSet) is
      variable vreg : RegType;
      variable accSize : natural;
      variable actSize : natural;
   begin
      -- Latch the current value
      vreg := reg;
      
      vreg.fifoRst := '0';
      vreg.fifoOut := fifoOut;
      
      ----------------------------------------------------------------------
      -- moving average state machine
      ----------------------------------------------------------------------
      
      for i in 0 to 2**CTRL_BITS_G-1 loop
         -- minimum window size due to FIFO latency
         if sizeCtrl = i and i < 1 then
            accSize := 3;
            actSize := 1;
         -- all other window sizes
         elsif sizeCtrl = i then
            accSize := 2**(i+1)-1;
            actSize := i;
         else -- avoids inferring latch
            accSize := 3;
            actSize := 1;
         end if;
      end loop;
      
      case reg.state is
         
         when IDLE_S =>
            vreg.rstCnt := reg.rstCnt - 1;
            vreg.fifoRd := '0';
            vreg.fifoWr := '0';
            vreg.fifoRst := '0';
            vreg.dataOutValid := '0';
            vreg.accReg := (others=>'0');
            vreg.accCnt := (others=>'0');
            if reg.rstCnt = "11" then
               vreg.fifoRst := '1';
            elsif reg.rstCnt = 0 then
               vreg.state := FILL_S;
               vreg.fifoWr := '1';
            end if;
         
         when FILL_S =>
            vreg.accReg := reg.accReg + dataIn;
            vreg.accCnt := reg.accCnt + 1;
            if reg.accCnt = accSize-1 then
               -- start reading and buffering to avoid overflow when accSize is max (= FIFO size)
               vreg.fifoRd := '1';
            elsif reg.accCnt = accSize then
               vreg.accCnt := reg.accCnt;
               vreg.state := RUN_S;
            end if;
         
         when RUN_S =>
            vreg.accReg := reg.accReg + dataIn - reg.fifoOut;
            vreg.dataOutValid := '1';
            if sizeCtrlSet = '1' then
               vreg.state := IDLE_S;
            end if;
         
         when others =>
            vreg.state := IDLE_S;
         
      end case;
      
      -- divide ACC by set window size
      for i in 0 to 2**CTRL_BITS_G-1 loop
         -- minimum window size due to FIFO latency
         if sizeCtrl = i and i < 1 then
            vreg.dataOut := reg.accReg(DATA_BITS_G-1+2 downto 0+2);
            -- add 1 if reminder is > 0.5
            if reg.accReg(1 downto 0) > 2 then
               vreg.dataOut := vreg.dataOut + 1;
            end if;
         -- all other window sizes
         elsif sizeCtrl = i then
            vreg.dataOut := reg.accReg(DATA_BITS_G-1+i+1 downto 0+i+1);
            -- add 1 if reminder is > 0.5
            if reg.accReg(i downto 0) > 2**i then
               vreg.dataOut := vreg.dataOut + 1;
            end if;
         end if;
      end loop;
      
      
      -- Reset      
      if (rst = '1') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn <= vreg;
      actSizeCtrl    <= toSlv(actSize, CTRL_BITS_G);
      dataOutValid   <= reg.dataOutValid;
      dataOut        <= reg.dataOut;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seq;
   
   ----------------------------------------------------------------------
   -- Streaming out FIFO
   ----------------------------------------------------------------------
   
   U_FifoCascade : entity surf.FifoCascade
   generic map (
      TPD_G                => TPD_G,
      CASCADE_SIZE_G       => 1,
      LAST_STAGE_ASYNC_G   => false, 
      GEN_SYNC_FIFO_G      => true,
      FWFT_EN_G            => true,
      DATA_WIDTH_G         => DATA_BITS_G,
      ADDR_WIDTH_G         => SIZE_BITS_C
   )
   port map (
      rst           => regIn.fifoRst,
      wr_clk        => clk,
      wr_en         => reg.fifoWr,
      din           => dataIn,
      rd_clk        => clk,
      rd_en         => reg.fifoRd,
      dout          => fifoOut
   );
   
end rtl;
