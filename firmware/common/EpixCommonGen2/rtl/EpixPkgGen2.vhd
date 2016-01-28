library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.Version.all;

package EpixPkgGen2 is

   -- AXI-Lite Constants
   constant NUM_AXI_MASTER_SLOTS_C : natural := 1;
   constant NUM_AXI_SLAVE_SLOTS_C : natural := 2;

   constant COMMON_AXI_INDEX_C  : natural := 0;
   
   constant COMMON_AXI_BASE_ADDR_C    : slv(31 downto 0) := X"00000000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      COMMON_AXI_INDEX_C      => (
         baseAddr             => COMMON_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"0003")
   );

   type DataDelayArray is array(2 downto 0) of Slv5Array(7 downto 0);
   
   constant NUM_FAST_ADCS_C  : natural := 3;
   constant NUM_ASICS_C      : natural := 4;
   constant MAX_OVERSAMPLE_C : integer := 1;
   
   type EpixConfigType is record
      runTriggerEnable   : sl;
      runTriggerDelay    : slv(31 downto 0);
      daqTriggerEnable   : sl;
      daqTriggerDelay    : slv(31 downto 0);
      acqCountReset      : sl;
      vguardDacSetting   : slv(15 downto 0);
      powerEnable        : slv( 7 downto 0);
      frameDelay         : Slv5Array(NUM_FAST_ADCS_C-1 downto 0);
      seqCountReset      : sl;
      asicMask           : slv(NUM_ASICS_C-1 downto 0);
      autoRunEn          : sl;
      autoTrigPeriod     : slv(31 downto 0);
      autoDaqEn          : sl;
      adcPdwn            : slv(NUM_FAST_ADCS_C-1 downto 0);
      doutPipelineDelay  : slv(31 downto 0);
      acqToAsicR0Delay   : slv(31 downto 0);
      asicR0ToAsicAcq    : slv(31 downto 0);
      asicAcqWidth       : slv(31 downto 0);
      asicAcqLToPPmatL   : slv(31 downto 0);
      asicRoClkHalfT     : slv(31 downto 0);
      adcReadsPerPixel   : slv(31 downto 0);
      adcClkHalfT        : slv(31 downto 0);
      totalPixelsToRead  : slv(31 downto 0);
      saciClkBit         : slv(31 downto 0);
      asicPins           : slv( 5 downto 0);
      manualPinControl   : slv( 5 downto 0);
      prePulseR0         : sl;
      adcStreamMode      : sl;
      testPattern        : sl;
      syncMode           : slv( 1 downto 0);
      asicR0Mode         : sl;
      asicR0Width        : slv(31 downto 0);
      pipelineDelay      : slv(31 downto 0);
      pipelineDelayA0    : slv(31 downto 0);
      pipelineDelayA1    : slv(31 downto 0);
      pipelineDelayA2    : slv(31 downto 0);
      pipelineDelayA3    : slv(31 downto 0);
      syncWidth          : slv(15 downto 0);
      syncDelay          : slv(15 downto 0);
      prePulseR0Width    : slv(31 downto 0);
      prePulseR0Delay    : slv(31 downto 0);
      asicPpmatToReadout : slv(31 downto 0);
      tpsDelay           : slv(15 downto 0);
      tpsEdge            : sl;
      dataDelay          : DataDelayArray;
      requestStartupCal  : sl;
   end record;
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
      adcPdwn            => (others => '0'),
      doutPipelineDelay  => (others => '0'),
      acqToAsicR0Delay   => (others => '0'),
      asicR0ToAsicAcq    => (others => '0'),
      asicAcqWidth       => (others => '0'),
      asicAcqLToPPmatL   => (others => '0'),
      asicRoClkHalfT     => x"0000000A",
      adcReadsPerPixel   => x"00000001",
      adcClkHalfT        => x"00000001",
      totalPixelsToRead  => x"000084C0",
      saciClkBit         => (others => '0'),
      asicPins           => (others => '0'),
      manualPinControl   => (others => '0'),
      prePulseR0         => '0',
      adcStreamMode      => '0',
      testPattern        => '0',
      syncMode           => (others => '0'),
      asicR0Mode         => '0',
      asicR0Width        => (others => '0'),
      pipelineDelay      => (others => '0'),
      pipelineDelayA0    => (others => '0'),
      pipelineDelayA1    => (others => '0'),
      pipelineDelayA2    => (others => '0'),
      pipelineDelayA3    => (others => '0'),
      syncWidth          => (others => '0'),
      syncDelay          => (others => '0'),
      prePulseR0Width    => (others => '0'),
      prePulseR0Delay    => (others => '0'),
      asicPpmatToReadout => (others => '0'),
      tpsDelay           => (others => '0'),
      tpsEdge            => '0',
      frameDelay         => (others => (others => '0')),
      dataDelay          => (others => (others => (others => '0'))),
      requestStartupCal  => '1'
   );
   
   type EpixStatusType is record
      acqCount           : slv(31 downto 0);
      iDelayCtrlRdy      : sl;
      seqCount           : slv(31 downto 0);
      startupAck         : sl;
      startupFail        : sl;
      slowAdcData        : Slv16Array(7 downto 0);
      slowAdc2Data       : Slv24Array(8 downto 0);
      envData            : Slv32Array(8 downto 0);
   end record;
   constant EPIX_STATUS_INIT_C : EpixStatusType := (
      acqCount           => (others => '0'),
      iDelayCtrlRdy      => '0',
      seqCount           => (others => '0'),
      startupAck         => '0',
      startupFail        => '0',
      slowAdcData        => (others => (others => '0')),
      slowAdc2Data       => (others => (others => '0')),
      envData            => (others => (others => '0'))
   );

   --Functions to allow use of EPIX100 or 10k
   function getNumColumns ( version : slv ) return integer;
   function getWordsPerSuperRow ( version : slv ) return integer;

   constant NCOL_C : integer := getNumColumns(FPGA_VERSION_C);
   --Number of columns in ePix "super row"
   -- (columns / ch) * (channels / asic) * (asics / row) / (adc values / word)
   -- constant WORDS_PER_SUPER_ROW_C : integer := NCOL_C * 4 * 2 / 2; 
   constant WORDS_PER_SUPER_ROW_C  : integer := getWordsPerSuperRow(FPGA_VERSION_C);
   constant EPIX100_COLS_PER_ROW   : integer := 96;
   constant EPIX10K_COLS_PER_ROW   : integer := 48;
   constant EPIXS_COLS_PER_ROW     : integer := 10;
   constant EPIX100A_ROWS_PER_ASIC : integer := 352;
   
   procedure globalToLocalPixel( constant asicType   : in slv; 
                                 signal   globalRow  : in slv; 
                                 signal   globalCol  : in slv; 
                                 signal   calRowFlag : in sl; 
                                 signal   calBotFlag : in sl;
                                 signal   inputData  : in Slv16Array;
                                 variable localAsic  : inout slv; 
                                 variable localRow   : inout slv; 
                                 variable localCol   : inout slv;
                                 variable localData  : inout Slv16Array);
   procedure globalToLocalPixelEpix100A( signal   globalRow  : in slv; 
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

   function getNumColumns (version : slv ) return integer is
   begin
      assert (version(31 downto 24) = x"E0" or 
              version(31 downto 24) = x"EA" or
              version(31 downto 24) = x"E2" or
              version(31 downto 24) = x"E3") report "Unable to determine ASIC type from version string!" severity failure;
      --Epix 100p and Epix100a
      if (version(31 downto 24) = x"E0" or version(31 downto 24) = x"EA") then
         return EPIX100_COLS_PER_ROW;
      --Epix 10k
      elsif (version(31 downto 24) = x"E2") then
         return EPIX10K_COLS_PER_ROW;
      --Epix S
      elsif (version(31 downto 24) = x"E3") then
         return EPIXS_COLS_PER_ROW;
      --Other (default to Epix 100)
      else
         return EPIX100_COLS_PER_ROW;
      end if; 
   end function;

   function getWordsPerSuperRow (version : slv ) return integer is
   begin
      --EpixS reads only the active ASICs
      if (version(31 downto 24) = x"E3") then
         return EPIXS_COLS_PER_ROW * 2 / 2;
      --Other
      else
         return NCOL_C * 4 * 2 / 2;
      end if; 
   end function;

   procedure globalToLocalPixel (
       constant asicType   : in slv;
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
      assert (asicType = x"EA") report "Multi-pixel writes not supported for this ASIC!" severity warning;   
      if asicType = x"EA" then
         globalToLocalPixelEpix100A(globalRow,globalCol,calRowFlag,calBotFlag,inputData,localAsic,localRow,localCol,localData);
      end if;
   end procedure globalToLocalPixel;
   
   procedure globalToLocalPixelEpix100A (
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
   begin 
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
