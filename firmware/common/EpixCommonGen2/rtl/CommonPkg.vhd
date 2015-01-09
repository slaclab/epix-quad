library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

package CommonPkg is

   -- AXI-Lite Constants
   constant NUM_AXI_MASTERS_C : natural := 1;

   constant VERSION_AXI_INDEX_C    : natural := 0;
   
   constant VERSION_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00000000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_AXI_INDEX_C    => (
         baseAddr            => VERSION_AXI_BASE_ADDR_C,
         addrBits            => 12,
         connectivity        => X"0001")
      );  
            
end package;
