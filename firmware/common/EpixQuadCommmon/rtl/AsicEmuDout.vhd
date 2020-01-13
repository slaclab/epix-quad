-------------------------------------------------------------------------------
-- File       : AsicEmuDout.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Emulate ASIC Output for Readout Testing
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;

entity AsicEmuDout is
   generic (
      TPD_G             : time                     := 1 ns;
      BANK_COLS_G       : natural range 1 to 64    := 48;
      BANK_REVERSE_G    : sl                       := '0';
      BANK_ROW_PAT_G    : Slv64Array(3 downto 0)   := (others=>x"0000000080000000")
   );
   port (
      -- System Clock (100 MHz)
      sysClk            : in  sl;
      sysRst            : in  sl;
      -- Run control
      acqBusy           : in  sl;
      asicRoClk         : in  sl;
      roClkTail         : in  slv(7 downto 0);
      -- Test data output
      asicDoutTest      : out sl
   );
end AsicEmuDout;


-- Define architecture
architecture RTL of AsicEmuDout is
   
   constant BANK_COLS_C : natural := BANK_COLS_G - 1;
   
   type RegType is record
      latCount    : slv(7 downto 0);
      bankCount   : slv(1 downto 0);
      colCount    : natural range 0 to 63;
   end record RegType;

   constant REG_INIT_C : RegType := (
      latCount    => (others=>'0'),
      bankCount   => (others=>'0'),
      colCount    => 0
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal asicRoClkEdge : sl;
   
begin
   
   U_AsicRoClkEdge : entity surf.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysRst,
         dataIn     => asicRoClk,
         risingEdge => asicRoClkEdge
      );

   comb : process (sysRst, r, asicRoClkEdge, acqBusy, roClkTail) is
      variable v      : RegType;
   begin
      v := r;
      
      -- latency counter
      if acqBusy = '0' then
         v.latCount := roClkTail;
      elsif r.latCount > 0 and asicRoClkEdge = '1' then
         v.latCount := r.latCount - 1;
      end if;
      
      -- bank counter 0 to 3
      if acqBusy = '0' then
         v.bankCount := (others=>'0');
      elsif asicRoClkEdge = '1' and r.latCount = 0 then
         v.bankCount := r.bankCount + 1;
      end if;
      
      -- column counter
      if acqBusy = '0' then
         v.colCount := 0;
      elsif asicRoClkEdge = '1' and r.latCount = 0 and r.bankCount = "11" then
         if r.colCount < BANK_COLS_C then
            v.colCount := r.colCount + 1;
         else
            v.colCount := 0;
         end if;
      end if;
      
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

   end process comb;
   
   asicDoutTest <= 
      BANK_ROW_PAT_G(conv_integer(r.bankCount))(conv_integer(r.colCount))                 when r.latCount = 0 and BANK_REVERSE_G = '0' else
      BANK_ROW_PAT_G(conv_integer(r.bankCount))(conv_integer(BANK_COLS_C - r.colCount))   when r.latCount = 0 and BANK_REVERSE_G = '1' else
      '0';

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end RTL;

