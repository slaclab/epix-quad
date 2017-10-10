------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

package EpixPkgGen2 is
   
   type AsicType is (EPIX100A_C, EPIX10KA_C, EPIX10KP_C, EPIXS_C);

   -- AXI-Lite Constants
   constant NUM_AXI_MASTER_SLOTS_C : natural := 14;
   constant NUM_AXI_SLAVE_SLOTS_C : natural := 4;
   
   constant EPIXREGS_AXI_INDEX_C    : natural := 0;
   constant PREPRDOUT_AXI_INDEX_C   : natural := 1;
   constant MULTIPIX_AXI_INDEX_C    : natural := 2;
   constant PGPSTAT_AXI_INDEX_C     : natural := 3;
   constant SACIREGS_AXI_INDEX_C    : natural := 4;
   constant VERSION_AXI_INDEX_C     : natural := 5;
   constant BOOTMEM_AXI_INDEX_C     : natural := 6;
   constant ADCTEST_AXI_INDEX_C     : natural := 7;
   constant ADC0_RD_AXI_INDEX_C     : natural := 8;
   constant ADC1_RD_AXI_INDEX_C     : natural := 9;
   constant ADC2_RD_AXI_INDEX_C     : natural := 10;
   constant ADC_CFG_AXI_INDEX_C     : natural := 11;
   constant MEM_LOG_AXI_INDEX_C     : natural := 12;
   constant DOUT10KA_AXI_INDEX_C    : natural := 13;
   constant TESTMEM_AXI_INDEX_C     : natural := 14;
   
   constant EPIXREGS_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"00000000";
   constant PREPRDOUT_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00100000";
   constant MULTIPIX_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"00200000";
   constant PGPSTAT_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00300000";
   constant SACIREGS_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"02000000";
   constant VERSION_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"08000000";
   constant BOOTMEM_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"0C000000";
   constant ADCTEST_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"10000000";
   constant ADC0_RD_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"14000000";
   constant ADC1_RD_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"18000000";
   constant ADC2_RD_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"1C000000";
   constant ADC_CFG_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"20000000";
   constant MEM_LOG_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"24000000";
   constant DOUT10KA_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"28000000";
   constant TESTMEM_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"2C000000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      EPIXREGS_AXI_INDEX_C    => (
         baseAddr             => EPIXREGS_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      PREPRDOUT_AXI_INDEX_C   => (
         baseAddr             => PREPRDOUT_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      MULTIPIX_AXI_INDEX_C    => (
         baseAddr             => MULTIPIX_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      PGPSTAT_AXI_INDEX_C     => (
         baseAddr             => PGPSTAT_AXI_BASE_ADDR_C,
         addrBits             => 20,
         connectivity         => x"FFFF"),
      SACIREGS_AXI_INDEX_C    => (
         baseAddr             => SACIREGS_AXI_BASE_ADDR_C,
         addrBits             => 24,
         connectivity         => x"FFFF"),
      VERSION_AXI_INDEX_C     => (
         baseAddr             => VERSION_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      BOOTMEM_AXI_INDEX_C     => (
         baseAddr             => BOOTMEM_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      ADCTEST_AXI_INDEX_C     => (
         baseAddr             => ADCTEST_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      ADC0_RD_AXI_INDEX_C     => (
         baseAddr             => ADC0_RD_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      ADC1_RD_AXI_INDEX_C      => (
         baseAddr             => ADC1_RD_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      ADC2_RD_AXI_INDEX_C     => (
         baseAddr             => ADC2_RD_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      ADC_CFG_AXI_INDEX_C     => (
         baseAddr             => ADC_CFG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      MEM_LOG_AXI_INDEX_C     => (
         baseAddr             => MEM_LOG_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      DOUT10KA_AXI_INDEX_C     => (
         baseAddr             => DOUT10KA_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF")
--      TESTMEM_AXI_INDEX_C     => (
--         baseAddr             => TESTMEM_AXI_BASE_ADDR_C,
--         addrBits             => 26,
--         connectivity         => x"FFFF")
   );
   
   constant NUM_FAST_ADCS_C  : natural := 3;
   constant NUM_ASICS_C      : natural := 4;
   
   type EpixConfigType is record
      runTriggerEnable   : sl;
      runTriggerDelay    : slv(31 downto 0);
      daqTriggerEnable   : sl;
      daqTriggerDelay    : slv(31 downto 0);
      acqCountReset      : sl;
      vguardDacSetting   : slv(15 downto 0);
      powerEnable        : slv( 7 downto 0);
      seqCountReset      : sl;
      asicMask           : slv(NUM_ASICS_C-1 downto 0);
      autoRunEn          : sl;
      autoTrigPeriod     : slv(31 downto 0);
      autoDaqEn          : sl;
      doutPipelineDelay  : slv(31 downto 0);
      acqToAsicR0Delay   : slv(31 downto 0);
      asicR0ToAsicAcq    : slv(31 downto 0);
      asicAcqWidth       : slv(31 downto 0);
      asicAcqLToPPmatL   : slv(31 downto 0);
      asicRoClkHalfT     : slv(31 downto 0);
      asicPreAcqTime     : slv(31 downto 0);
      adcReadsPerPixel   : slv(31 downto 0);
      adcClkHalfT        : slv(31 downto 0);
      totalPixelsToRead  : slv(31 downto 0);
      asicPins           : slv( 5 downto 0);
      manualPinControl   : slv( 5 downto 0);
      adcStreamMode      : sl;
      testPattern        : sl;
      asicR0Mode         : sl;
      asicR0Width        : slv(31 downto 0);
      pipelineDelayA0    : slv(31 downto 0);
      pipelineDelayA1    : slv(31 downto 0);
      pipelineDelayA2    : slv(31 downto 0);
      pipelineDelayA3    : slv(31 downto 0);
      asicPpmatToReadout : slv(31 downto 0);
      tpsDelay           : slv(15 downto 0);
      tpsEdge            : sl;
      requestStartupCal  : sl;
      startupAck         : sl;
      startupFail        : sl;
      pgpTrigEn          : sl;
      monitorEnable      : sl;
      requestConfDump    : sl;
      dbgReg             : slv(4 downto 0);
   end record;
   type EpixConfigArray is array (natural range <>) of EpixConfigType;
   constant EPIX_CONFIG_INIT_C : EpixConfigType := (
      runTriggerEnable   => '0',
      runTriggerDelay    => (others => '0'),
      daqTriggerEnable   => '0',
      daqTriggerDelay    => (others => '0'),
      acqCountReset      => '0',
      vguardDacSetting   => (others => '0'),
      powerEnable        => (others => '0'),
      seqCountReset      => '0',
      asicMask           => (others => '0'),
      autoRunEn          => '0',
      autoTrigPeriod     => x"000CB735",
      autoDaqEn          => '0',
      doutPipelineDelay  => (others => '0'),
      acqToAsicR0Delay   => (others => '0'),
      asicR0ToAsicAcq    => (others => '0'),
      asicAcqWidth       => (others => '0'),
      asicAcqLToPPmatL   => (others => '0'),
      asicRoClkHalfT     => x"0000000A",
      asicPreAcqTime     => (others => '0'),
      adcReadsPerPixel   => x"00000001",
      adcClkHalfT        => x"00000001",
      totalPixelsToRead  => x"000084C0",
      asicPins           => (others => '0'),
      manualPinControl   => (others => '0'),
      adcStreamMode      => '0',
      testPattern        => '0',
      asicR0Mode         => '0',
      asicR0Width        => (others => '0'),
      pipelineDelayA0    => (others => '0'),
      pipelineDelayA1    => (others => '0'),
      pipelineDelayA2    => (others => '0'),
      pipelineDelayA3    => (others => '0'),
      asicPpmatToReadout => (others => '0'),
      tpsDelay           => (others => '0'),
      tpsEdge            => '0',
      requestStartupCal  => '1',
      startupAck         => '0',
      startupFail        => '0',
      pgpTrigEn          => '0',
      monitorEnable      => '0',
      requestConfDump    => '0',
      dbgReg             => (others => '0')
   );
   
   type EpixStatusType is record
      acqCount           : slv(31 downto 0);
      iDelayCtrlRdy      : sl;
      seqCount           : slv(31 downto 0);
      startupAck         : sl;
      startupFail        : sl;
      envData            : Slv32Array(8 downto 0);
   end record;
   type EpixStatusArray is array (natural range <>) of EpixStatusType;
   constant EPIX_STATUS_INIT_C : EpixStatusType := (
      acqCount           => (others => '0'),
      iDelayCtrlRdy      => '0',
      seqCount           => (others => '0'),
      startupAck         => '0',
      startupFail        => '0',
      envData            => (others => (others => '0'))
   );

   --Functions to allow use of EPIX100 or 10k
   function saciClkPeriod(version: AsicType) return real;
   function getNumColumns ( version : AsicType ) return integer;
   function getWordsPerSuperRow ( version : AsicType ) return integer;

   -- constant NCOL_C : integer := getNumColumns(FPGA_VERSION_C);
   -- --Number of columns in ePix "super row"
   -- -- (columns / ch) * (channels / asic) * (asics / row) / (adc values / word)
   -- -- constant WORDS_PER_SUPER_ROW_C : integer := NCOL_C * 4 * 2 / 2; 
   -- constant WORDS_PER_SUPER_ROW_C  : integer := getWordsPerSuperRow(FPGA_VERSION_C);
   
   constant EPIX100_COLS_PER_ROW   : integer := 96;
   constant EPIX10K_COLS_PER_ROW   : integer := 48;
   constant EPIX10KA_COLS_PER_ROW  : integer := 48;
   constant EPIXS_COLS_PER_ROW     : integer := 10;
   constant EPIX100A_ROWS_PER_ASIC : integer := 352;
   
   procedure globalToLocalPixel( signal   version    : in AsicType; 
                                 signal   globalRow  : in slv; 
                                 signal   globalCol  : in slv; 
                                 signal   calRowFlag : in sl; 
                                 signal   calBotFlag : in sl;
                                 signal   inputData  : in Slv16Array;
                                 variable localAsic  : inout slv; 
                                 variable localRow   : inout slv; 
                                 variable localCol   : inout slv;
                                 variable localData  : inout Slv16Array);
   procedure globalToLocalPixelEpix100A( signal   version    : in AsicType; 
                                         signal   globalRow  : in slv; 
                                         signal   globalCol  : in slv; 
                                         signal   calRowFlag : in sl; 
                                         signal   calBotFlag : in sl;
                                         signal   inputData  : in Slv16Array;
                                         variable localAsic  : inout slv; 
                                         variable localRow   : inout slv; 
                                         variable localCol   : inout slv;
                                         variable localData  : inout Slv16Array) ;   
   
end EpixPkgGen2;

package body EpixPkgGen2 is
   
   function saciClkPeriod(version: AsicType) return real is
   begin
      if (version = EPIX10KA_C) then
         return 1.00E-6;   -- 1MHz
      else
         return 0.25E-6;   -- 4MHz
      end if;
   end function; 
   
   function getNumColumns (version : AsicType ) return integer is
   begin
      --Epix100a
      if (version = EPIX100A_C) then
         return EPIX100_COLS_PER_ROW;
      --Epix 10kp
      elsif (version = EPIX10KP_C) then
         return EPIX10K_COLS_PER_ROW;
      --Epix 10ka
      elsif (version = EPIX10KA_C) then
         return EPIX10KA_COLS_PER_ROW;
      --Epix S
      elsif (version = EPIXS_C) then
         return EPIXS_COLS_PER_ROW;
      --Other (default to Epix 100)
      else
         return EPIX100_COLS_PER_ROW;
      end if; 
   end function;

   function getWordsPerSuperRow (version : AsicType ) return integer is
      variable NCOL_C   : integer;
   begin
      NCOL_C := getNumColumns(version);
      --EpixS reads only the active ASICs
      if (version = EPIXS_C) then
         return EPIXS_COLS_PER_ROW * 2 / 2;
      --Other
      else
         return NCOL_C * 4 * 2 / 2;
      end if; 
   end function;
   
   procedure globalToLocalPixel (
       signal   version    : in AsicType;
       signal   globalRow  : in slv;
       signal   globalCol  : in slv;
       signal   calRowFlag : in sl;
       signal   calBotFlag : in sl;
       signal   inputData  : in Slv16Array;
       variable localAsic  : inout slv;
       variable localRow   : inout slv;
       variable localCol   : inout slv;
       variable localData  : inout Slv16Array)
   is
   begin 
      assert (version = EPIX100A_C) report "Multi-pixel writes not supported for this ASIC!" severity warning;   
      if version = EPIX100A_C then
         globalToLocalPixelEpix100A(version,globalRow,globalCol,calRowFlag,calBotFlag,inputData,localAsic,localRow,localCol,localData);
      end if;
   end procedure globalToLocalPixel;
   
   procedure globalToLocalPixelEpix100A (
       signal   version    : in AsicType;
       signal   globalRow  : in slv;
       signal   globalCol  : in slv;
       signal   calRowFlag : in sl;
       signal   calBotFlag : in sl;
       signal   inputData  : in Slv16Array;
       variable localAsic  : inout slv;
       variable localRow   : inout slv;
       variable localCol   : inout slv;
       variable localData  : inout Slv16Array)
   is
      variable asicCol  : slv(9 downto 0);
      variable NCOL_C   : integer;
   begin 
      NCOL_C := getNumColumns(version);
      -- Top 2 ASICs
      if (globalRow < EPIX100A_ROWS_PER_ASIC and calRowFlag = '0') or (calRowFlag = '1' and calBotFlag = '0') then
         -- ASIC 2 (upper left)
         if globalCol < NCOL_C * 4 then
            localAsic := "10";
            asicCol   := NCOL_C * 4 - globalCol - 1;
         -- ASIC 1 (upper right)
         else
            localAsic := "01";
            asicCol   := NCOL_C * 4 * 2 - 1 - globalCol;
         end if;
         -- For both top ASICs, translate row to local space
         if calRowFlag = '1' then
            localRow := conv_std_logic_vector(EPIX100A_ROWS_PER_ASIC,localRow'length);
         else
            localRow := EPIX100A_ROWS_PER_ASIC - 1 - globalRow;
         end if;
         -- Readout order for top ASICs is 3->0
         for i in 0 to 3 loop
            localData(3-i) := inputData(i);
         end loop;
      -- Bottom two ASICs
      else
         -- ASIC 3 (lower left)
         if (globalCol < NCOL_C * 4) then
            localAsic := "11";
            asicCol   := globalCol;
         -- ASIC 0 (lower right)
         else
            localAsic := "00";
            asicCol   := globalCol - NCOL_C * 4;
         end if;
         -- For both bottom ASICs, translate row to local space
         if calRowFlag = '1' then
            localRow := conv_std_logic_vector(EPIX100A_ROWS_PER_ASIC,localRow'length);
         else
            localRow := globalRow - EPIX100A_ROWS_PER_ASIC;
         end if;
         -- Readout order for bottom ASICs is 0->3
         for i in 0 to 3 loop
            localData(i) := inputData(i);
         end loop;
      end if;
      -- Decode column to column within a bank   
      if asicCol  < NCOL_C then
         localCol := asicCol;
      elsif asicCol < NCOL_C * 2 then
         localCol := asicCol - NCOL_C;
      elsif asicCol < NCOL_C * 3 then
         localCol := asicCol - NCOL_C * 2;
      else
         localCol := asicCol - NCOL_C * 3;
      end if;
   end procedure globalToLocalPixelEpix100A;     
   
end package body EpixPkgGen2;
