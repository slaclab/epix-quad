------------------------------------------------------------------------------
-- This file is part of 'EPixHR Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPixHR Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

package EpixHRPkg is

   constant NUMBER_OF_ASICS_C : natural := 2;   
   
   constant EPIXHR_NUM_AXI_MASTER_SLOTS_C : natural := 22;
   constant EPIXHR_NUM_AXI_SLAVE_SLOTS_C : natural := 3;
   
   constant VERSION_AXI_INDEX_C      : natural := 0;
   constant EPIXHR_REG_AXI_INDEX_C   : natural := 1;
   constant TRIG_REG_AXI_INDEX_C     : natural := 2;
   constant MONADC_REG_AXI_INDEX_C   : natural := 3;
   constant SACIREGS_AXI_INDEX_C     : natural := 4;
   constant PREPRDOUT_AXI_INDEX_C    : natural := 5;
   constant PGPSTAT_AXI_INDEX_C      : natural := 6;
   constant BOOTMEM_AXI_INDEX_C      : natural := 7;
   constant ADCTEST_AXI_INDEX_C      : natural := 8;
   constant ADC_RD_AXI_INDEX_C       : natural := 9;
   constant ADC_CFG_AXI_INDEX_C      : natural := 10;
   constant MEM_LOG_AXI_INDEX_C      : natural := 11;
   constant SCOPE_REG_AXI_INDEX_C    : natural := 12;
   constant DAC8812_REG_AXI_INDEX_C  : natural := 13;
   constant DACWFMEM_REG_AXI_INDEX_C : natural := 14;
   constant PLLREGS_AXI_INDEX_C      : natural := 15;
   constant DESER0_AXI_INDEX_C       : natural := 16;
   constant DESER1_AXI_INDEX_C       : natural := 17;
   constant ASICS0_AXI_INDEX_C       : natural := 18;
   constant ASICS1_AXI_INDEX_C       : natural := 19;
   constant TS_AXI_INDEX_C           : natural := 20;
   constant TS_AXI_INDEX2_C          : natural := 21;
   
   constant VERSION_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00000000";
   constant EPIXHR_REG_AXI_BASE_ADDR_C : slv(31 downto 0) := X"01000000";
   constant TRIG_REG_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"02000000";
   constant MONADC_REG_AXI_BASE_ADDR_C : slv(31 downto 0) := X"03000000";
   constant SACIREGS_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"04000000";
   constant PREPRDOUT_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"05000000";
   constant PGPSTAT_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"06000000";
   constant BOOTMEM_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"07000000";
   constant ADCTEST_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"08000000";
   constant ADC_RD_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"09000000";
   constant ADC_CFG_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"0A000000";
   constant MEM_LOG_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"0B000000";
   constant SCOPE_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"0C000000";
   constant DAC8812_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"0D000000";
   constant DACWFMEM_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"0E000000";
   constant PLLREGS_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"0F000000";
   constant DESER0_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"10000000";
   constant DESER1_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"11000000";
   constant ASICS0_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"12000000";
   constant ASICS1_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"13000000";
   constant TS_AXI_BASE_ADDR_C         : slv(31 downto 0) := X"14000000";
   constant TS_AXI_BASE_ADDR2_C        : slv(31 downto 0) := X"15000000";
   
   constant EPIXHR_AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(EPIXHR_NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      VERSION_AXI_INDEX_C      => (
         baseAddr             => VERSION_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      EPIXHR_REG_AXI_INDEX_C      => ( 
         baseAddr             => EPIXHR_REG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      TRIG_REG_AXI_INDEX_C      => ( 
         baseAddr             => TRIG_REG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      MONADC_REG_AXI_INDEX_C      => ( 
         baseAddr             => MONADC_REG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      SACIREGS_AXI_INDEX_C    => (
         baseAddr             => SACIREGS_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      PREPRDOUT_AXI_INDEX_C   => (
         baseAddr             => PREPRDOUT_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      PGPSTAT_AXI_INDEX_C     => (
         baseAddr             => PGPSTAT_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      BOOTMEM_AXI_INDEX_C      => ( 
         baseAddr             => BOOTMEM_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADCTEST_AXI_INDEX_C      => ( 
         baseAddr             => ADCTEST_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADC_RD_AXI_INDEX_C      => ( 
         baseAddr             => ADC_RD_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ADC_CFG_AXI_INDEX_C      => ( 
         baseAddr             => ADC_CFG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      MEM_LOG_AXI_INDEX_C      => ( 
         baseAddr             => MEM_LOG_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      SCOPE_REG_AXI_INDEX_C      => ( 
         baseAddr             => SCOPE_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      DAC8812_REG_AXI_INDEX_C      => ( 
         baseAddr             => DAC8812_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      DACWFMEM_REG_AXI_INDEX_C      => ( 
         baseAddr             => DACWFMEM_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      PLLREGS_AXI_INDEX_C      => ( 
         baseAddr             => PLLREGS_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      DESER0_AXI_INDEX_C      => ( 
         baseAddr             => DESER0_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      DESER1_AXI_INDEX_C      => ( 
         baseAddr             => DESER1_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ASICS0_AXI_INDEX_C      => ( 
         baseAddr             => ASICS0_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      ASICS1_AXI_INDEX_C      => ( 
         baseAddr             => ASICS1_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      TS_AXI_INDEX_C          => ( 
         baseAddr             => TS_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      TS_AXI_INDEX2_C         => ( 
         baseAddr             => TS_AXI_BASE_ADDR2_C,
         addrBits             => 24,
         connectivity         => x"FFFF")
   );
   
   type EpixHRConfigType is record
      powerEnable          : slv(3 downto 0);
      asicMask             : slv(NUMBER_OF_ASICS_C-1 downto 0);
      acqCnt               : slv(31 downto 0);
      requestStartupCal    : sl;
      startupAck           : sl;
      startupFail          : sl;
      epixhrDbgSel1         : slv(4 downto 0);
      epixhrDbgSel2         : slv(4 downto 0);
   end record;
   constant EPIXHR_CONFIG_INIT_C : EpixHRConfigType := (
      powerEnable          => (others => '0'),
      asicMask             => (others => '0'),
      acqCnt               => (others => '0'),
      requestStartupCal    => '1',
      startupAck           => '0',
      startupFail          => '0',
      epixhrDbgSel1         => (others => '0'),
      epixhrDbgSel2         => (others => '0')
   );
   

   
   
end EpixHRPkg;

package body EpixHRPkg is

   
end package body EpixHRPkg;
