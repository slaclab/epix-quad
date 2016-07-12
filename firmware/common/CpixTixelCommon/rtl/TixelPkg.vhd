library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Version.all;
use work.EpixPkgGen2.all;

package TixelPkg is

   constant NUMBER_OF_ASICS   : natural := 2;   
   
   constant TIXEL_NUM_AXI_MASTER_SLOTS_C : natural := 10;
   constant TIXEL_NUM_AXI_SLAVE_SLOTS_C : natural := 2;

   constant EPIX_REG_AXI_INDEX_C    : natural := 0;
   constant TIXEL_REG_AXI_INDEX_C   : natural := 9;
   
   constant EPIX_REG_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00000000";
   constant TIXEL_REG_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"04000000";
   
   constant TIXEL_AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(TIXEL_NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      EPIX_REG_AXI_INDEX_C      => (
         baseAddr             => EPIX_REG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      TIXEL_REG_AXI_INDEX_C      => (
         baseAddr             => TIXEL_REG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      VERSION_AXI_INDEX_C      => (
         baseAddr             => VERSION_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      BOOTMEM_AXI_INDEX_C      => (
         baseAddr             => BOOTMEM_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      ADCTEST_AXI_INDEX_C      => (
         baseAddr             => ADCTEST_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      ADC0_RD_AXI_INDEX_C      => (
         baseAddr             => ADC0_RD_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      ADC1_RD_AXI_INDEX_C      => (
         baseAddr             => ADC1_RD_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      ADC2_RD_AXI_INDEX_C      => (
         baseAddr             => ADC2_RD_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      ADC_CFG_AXI_INDEX_C      => (
         baseAddr             => ADC_CFG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003"),
      MEM_LOG_AXI_INDEX_C      => (
         baseAddr             => MEM_LOG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003")
   );
   
   type TixelConfigType is record
      tixelReadouts        : slv(3 downto 0);
      tixelRunToR0         : slv(31 downto 0);
      tixelR0ToStart       : slv(31 downto 0);
      tixelStartToTpulse   : slv(31 downto 0);
      tixelTpulseToAcq     : slv(31 downto 0);
      tixelSyncMode        : slv(1 downto 0);
      tixelAsicPinControl  : slv(31 downto 0);
      tixelAsicPins        : slv(31 downto 0);
      tixelErrorRst        : sl;
      forceFrameRead       : sl;
      doutResync           : slv(NUMBER_OF_ASICS-1 downto 0);
      doutDelay            : Slv5Array(NUMBER_OF_ASICS-1 downto 0);
      tixelDebug           : slv(4 downto 0);
   end record;
   constant TIXEL_CONFIG_INIT_C : TixelConfigType := (
      tixelReadouts        => x"1",
      tixelRunToR0         => (others => '0'),
      tixelR0ToStart       => (others => '0'),
      tixelStartToTpulse   => (others => '0'),
      tixelTpulseToAcq     => (others => '0'),
      tixelSyncMode        => (others => '0'),
      tixelAsicPinControl  => (others => '0'),
      tixelAsicPins        => (others => '0'),
      tixelErrorRst        => '0',
      forceFrameRead       => '0',
      doutResync           => (others => '0'),
      doutDelay            => (others => (others => '0')),
      tixelDebug           => (others => '0')
   );
   
   type TixelStatusType is record
      tixelAsicInSync       : slv(NUMBER_OF_ASICS-1 downto 0);
      tixelFramesGood       : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
      tixelFrameErr         : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
      tixelCodeErr          : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
      tixelTimeoutErr       : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
   end record;
   constant TIXEL_STATUS_INIT_C : TixelStatusType := (
      tixelAsicInSync       => (others => '0'),
      tixelFramesGood       => (others => (others => '0')),
      tixelFrameErr         => (others => (others => '0')),
      tixelCodeErr          => (others => (others => '0')),
      tixelTimeoutErr       => (others => (others => '0'))
   );
   
end TixelPkg;

package body TixelPkg is

   
end package body TixelPkg;
