------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Version.all;
use work.EpixPkgGen2.all;

package CpixPkg is

   constant NUMBER_OF_ASICS   : natural := 2;
   
   constant CPIX_NUM_AXI_MASTER_SLOTS_C : natural := 10;
   constant CPIX_NUM_AXI_SLAVE_SLOTS_C : natural := 2;

   constant EPIX_REG_AXI_INDEX_C  : natural := 0;
   constant CPIX_REG_AXI_INDEX_C  : natural := 9;
   
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
      syncMode             : slv(NUMBER_OF_ASICS-1 downto 0);
      forceFrameRead       : sl;
      doutResync           : slv(NUMBER_OF_ASICS-1 downto 0);
      doutDelay            : Slv5Array(NUMBER_OF_ASICS-1 downto 0);
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
      forceFrameRead       => '0',
      doutResync           => (others => '0'),
      doutDelay            => (others => (others => '0'))
   );
   
   type CpixStatusType is record
      cpixAsicInSync       : slv(NUMBER_OF_ASICS-1 downto 0);
      cpixFramesGood       : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
      cpixFrameErr         : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
      cpixCodeErr          : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
      cpixTimeoutErr       : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
   end record;
   constant CPIX_STATUS_INIT_C : CpixStatusType := (
      cpixAsicInSync       => (others => '0'),
      cpixFramesGood       => (others => (others => '0')),
      cpixFrameErr         => (others => (others => '0')),
      cpixCodeErr          => (others => (others => '0')),
      cpixTimeoutErr       => (others => (others => '0'))
   );
   
end CpixPkg;

package body CpixPkg is

   
end package body CpixPkg;
