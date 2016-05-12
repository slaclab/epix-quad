library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Version.all;

package CpixPkg is
   
   constant CPIX_NUM_AXI_MASTER_SLOTS_C : natural := 2;
   constant CPIX_NUM_AXI_SLAVE_SLOTS_C : natural := 2;

   constant EPIX_REG_AXI_INDEX_C  : natural := 0;
   constant CPIX_REG_AXI_INDEX_C  : natural := 1;
   
   constant EPIX_REG_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00000000";
   constant CPIX_REG_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"04000000";
   
   constant CPIX_AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(CPIX_NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      EPIX_REG_AXI_INDEX_C      => (
         baseAddr             => EPIX_REG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      CPIX_REG_AXI_INDEX_C      => (
         baseAddr             => CPIX_REG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003")
   );
   
   type CpixConfigType is record
      cpixRunToAcq         : slv(31 downto 0);
      cpixR0ToAcq          : slv(31 downto 0);
      cpixAcqWidth         : slv(31 downto 0);
      cpixAcqToCnt         : slv(31 downto 0);
      cpixSyncWidth        : slv(31 downto 0);
      cpixSROWidth         : slv(31 downto 0);
      cpixNRuns            : slv(31 downto 0);
      cpixCntAnotB         : slv(31 downto 0);
      cpixAsicPinControl   : slv(31 downto 0);
      cpixAsicPins         : slv(31 downto 0);
      cpixErrorRst         : sl;
      syncMode             : slv(1 downto 0);
      doutResync           : slv(1 downto 0);
      doutDelay            : Slv5Array(1 downto 0);
   end record;
   constant CPIX_CONFIG_INIT_C : CpixConfigType := (
      cpixRunToAcq         => (others => '0'),
      cpixR0ToAcq          => (others => '0'),
      cpixAcqWidth         => (others => '0'),
      cpixAcqToCnt         => (others => '0'),
      cpixSyncWidth        => (others => '0'),
      cpixSROWidth         => (others => '0'),
      cpixNRuns            => (others => '0'),
      cpixCntAnotB         => x"55555555",
      cpixAsicPinControl   => (others => '0'),
      cpixAsicPins         => (others => '0'),
      cpixErrorRst         => '0',
      syncMode             => (others => '0'),
      doutResync           => (others => '0'),
      doutDelay            => (others => (others => '0'))
   );
   
   type CpixStatusType is record
      cpixAsicInSync       : slv(1 downto 0);
      cpixFrameErr         : Slv32Array(1 downto 0);
      cpixCodeErr          : Slv32Array(1 downto 0);
      cpixTimeoutErr       : Slv32Array(1 downto 0);
   end record;
   constant CPIX_STATUS_INIT_C : CpixStatusType := (
      cpixAsicInSync       => (others => '0'),
      cpixFrameErr         => (others => (others => '0')),
      cpixCodeErr          => (others => (others => '0')),
      cpixTimeoutErr       => (others => (others => '0'))
   );
   
end CpixPkg;

package body CpixPkg is

   
end package body CpixPkg;
