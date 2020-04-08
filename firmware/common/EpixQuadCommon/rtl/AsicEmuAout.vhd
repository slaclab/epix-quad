-------------------------------------------------------------------------------
-- File       : AsicEmuAout.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Emulate ASIC Analog Output for Readout Testing
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
use surf.AxiStreamPkg.all;

entity AsicEmuAout is
   generic (
      TPD_G             : time                  := 1 ns;
      INDEX_G           : natural               := 0
   );
   port (
      -- System Clock (100 MHz)
      sysClk            : in  sl;
      sysRst            : in  sl;
      -- Run control
      acqBusy           : in  sl;
      asicRoClk         : in  sl;
      -- Test data output
      testStream        : out AxiStreamMasterType
   );
end AsicEmuAout;


-- Define architecture
architecture RTL of AsicEmuAout is
   
   type RegType is record
      clkCount             : slv(31 downto 0);
      txMaster             : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      clkCount             => (others=>'0'),
      txMaster             => AXI_STREAM_MASTER_INIT_C
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

   comb : process (sysRst, r, asicRoClkEdge, acqBusy) is
      variable v      : RegType;
   begin
      v := r;
      
      if acqBusy = '0' then
         v.clkCount := (others=>'0');
      elsif asicRoClkEdge = '1' then
         v.clkCount := r.clkCount + 1;
      end if;
      
      -- Test stream always valid
      v.txMaster.tValid := '1';
      v.txMaster.tLast  := '0';
      v.txMaster.tUser  := (others => '0');
      v.txMaster.tKeep  := (others => '1');
      v.txMaster.tStrb  := (others => '1');
      
      -- MSB contain INDEX_G
      -- LSB contain clkCount/4
      v.txMaster.tData(13 downto 0) := toSlv(INDEX_G,6) & r.clkCount(9 downto 2);
      
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
      
      testStream <= v.txMaster;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end RTL;
