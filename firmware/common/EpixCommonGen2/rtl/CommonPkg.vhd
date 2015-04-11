library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

package CommonPkg is

   -- AXI-Lite Constants
   constant NUM_AXI_MASTERS_C : natural := 2;

   constant VERSION_AXI_INDEX_C    : natural := 0;
   constant COMMON_AXI_INDEX_C     : natural := 1;
   
   constant VERSION_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00000000";
   constant COMMON_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00001000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_AXI_INDEX_C    => (
         baseAddr            => VERSION_AXI_BASE_ADDR_C,
         addrBits            => 12,
         connectivity        => X"0001"),
      COMMON_AXI_INDEX_C     => (
         baseAddr            => COMMON_AXI_BASE_ADDR_C,
         addrBits            => 12,
         connectivity        => x"0001")
      );  
      
   type adcChDelayArray is array ( natural range <> ) of Slv5Array(7 downto 0);

   type CommonStatusType is record
      txReady        : sl;
      rxReady        : sl;
      eventCount     : slv(31 downto 0);
   end record;
   constant COMMON_STATUS_INIT_C : CommonStatusType := (
      '0',
      '0',
      (others => '0')
   ); 

   type CommonConfigType is record
      eventTrigger      : sl;
      enAutoTrigger     : sl;
      autoTrigPeriod    : slv(31 downto 0);
      packetSize        : slv(31 downto 0);
      chToRead          : slv(4 downto 0);
      frameDelay        : Slv5Array(2 downto 0);
      dataDelay         : adcChDelayArray(1 downto 0);
      monDataDelay      : Slv5Array(3 downto 0);
   end record;
   constant COMMON_CONFIG_INIT_C : CommonConfigType := (
      eventTrigger      => '0',
      enAutoTrigger     => '0',
      autoTrigPeriod    => x"0013DE43",
      packetSize        => x"00000100",
      chToRead          => (others => '0'),
      frameDelay        => (others => (others => '0')),
      dataDelay         => (others => (others => (others => '0'))),
      monDataDelay      => (others => (others => '0'))
   );

      
end package;
