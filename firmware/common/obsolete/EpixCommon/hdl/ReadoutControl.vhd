-------------------------------------------------------------------------------
-- Title         : Acquisition Control Block
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : ReadoutControl.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 12/08/2011
-------------------------------------------------------------------------------
-- Description:
-- Readout control block
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-- 07/07/2014: Updated style of primary state machine
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.EpixTypes.all;
use work.VcPkg.all;
use work.StdRtlPkg.all;
use work.Version.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity ReadoutControl is
   generic (
      TPD_G : time := 1 ns
   );
   port (

      -- Clocks and reset
      sysClk              : in    sl;
      sysClkRst           : in    sl;

      -- Configuration
      epixConfig          : in    EpixConfigType;

      -- Data for headers
      acqCount            : in    slv(31 downto 0);

      -- Frame counter out to register control
      seqCount            : out   slv(31 downto 0);

      -- Run control
      acqStart            : in    sl;
      readValid           : in    slv(MAX_OVERSAMPLE-1 downto 0);
      readDone            : out   sl;
      acqBusy             : in    sl;
      dataSend            : in    sl;
      readTps             : in    sl;

      -- ADC Data
      adcPulse            : in    sl;
      adcValid            : in    slv(19 downto 0);
      adcData             : in    word16_array(19 downto 0);

      -- Slow ADC data
      slowAdcData         : in    word16_array(15 downto 0);

      -- Data Out
      frameTxIn           : out   VcUsBuff32InType;
      frameTxOut          : in    VcUsBuff32OutType;

      -- MPS
      mpsOut              : out   sl;

      -- ASIC digital outputs
      asicDout            : in    slv(3 downto 0) 
   );
end ReadoutControl;

-- Define architecture
architecture ReadoutControl of ReadoutControl is

   -- Timeout in clock cycles between acqStart and sendData
   constant DAQ_TIMEOUT_C   : slv(31 downto 0) := conv_std_logic_vector(12500,32); --100 us at 125 MHz
   constant STUCK_TIMEOUT_C : slv(31 downto 0) := conv_std_logic_vector(1250000,32); --2 s at 125 MHz
   -- Depth of FIFO 
   constant CH_FIFO_ADDR_WIDTH_C : integer := 10;
   -- Hard coded words in the data stream for now
   constant LANE_C     : slv( 1 downto 0) := "00";
   constant VC_C       : slv( 1 downto 0) := "00";
   constant QUAD_C     : slv( 1 downto 0) := "00";
   constant OPCODE_C   : slv( 7 downto 0) := x"00";
   constant ZEROWORD_C : slv(31 downto 0) := x"00000000";
   -- Register delay for simulation
   constant TPD_C : time := 0.5 ns;

   
   -- State definitions
   type StateType is (IDLE_S,ARMED_S,HEADER_S,READ_FIFO_S,READ_FIFO_TEST_S,
                      ENV_DATA_S,TPS_DATA_S,FOOTER_S);

   -- Local Signals
   type RegType is record
      readDone       : sl;
      testPattern    : sl;
      streamMode     : sl;
      seqCountEn     : sl;
      fillCnt        : slv(CH_FIFO_ADDR_WIDTH_C-1 downto 0);
      overSmplCnt    : slv(log2(MAX_OVERSAMPLE)-1 downto 0);
      chCnt          : slv(3 downto 0);
      timeoutCnt     : slv(31 downto 0);
      clearFifos     : sl;
      error          : sl;
      wordCnt        : slv(31 downto 0);
      adcData        : word16_array(19 downto 0);
      frameTxIn      : VcUsBuff32InType;
      state          : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      '0',
      '0',
      (others => '0'),
      (others => (others => '0')),      
      VC_US_BUFF32_IN_INIT_C,
      IDLE_S
   );
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal memRst         : sl := '0';
   signal dataSendEdge   : sl;
   signal acqStartEdge   : sl;
   signal adcMemWrEn     : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemRdOrder  : std_logic_vector(15 downto 0);
   signal adcMemRdRdy    : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemRdValid  : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemOflow    : Slv16Array(MAX_OVERSAMPLE-1 downto 0);
   signal adcMemOflowAny : std_logic;
   signal adcMemRdData   : Slv16VectorArray(MAX_OVERSAMPLE-1 downto 0,15 downto 0);

   signal adcCntEn       : sl;
   signal adcCntRst      : sl;
   signal adcCnt         : slv(11 downto 0);
   
   signal adcFifoWrEn    : slv(15 downto 0);
   signal adcFifoEmpty   : slv(15 downto 0);
   signal adcFifoOflow   : slv(15 downto 0);
   signal adcFifoRdValid : slv(15 downto 0);
   signal adcFifoRdEn    : slv(15 downto 0);
   signal adcFifoRdData  : Slv32Array(15 downto 0);
   signal adcFifoWrData  : Slv16Array(15 downto 0);
   signal fifoOflowAny   : sl := '0';
   signal fifoEmptyAll   : sl := '0';
   signal intSeqCount    : slv(31 downto 0) := (others => '0');

   signal asicDoutPipeline : Slv128Array(3 downto 0);
   signal asicDoutDelayed  : slv(3 downto 0);

   signal adcDataToReorder : word16_array(19 downto 0);
   signal tpsData          : word16_array(3 downto 0);

   type chanMap is array(15 downto 0) of integer range 0 to 15;
   signal channelOrder   : chanMap;
   signal channelValid   : slv(15 downto 0);

   signal tpsAdcData     : Slv16Array(3 downto 0);

begin

   -- Counter output to register control
   seqCount <= intSeqCount;
   -- Channel Order for ASIC readout (last downto first)
   -- Readout order based on ePix100 ASIC numbering scheme (0 - forward, 1 - backward)
   -- Indexing for the memory readout order is linked to the raw ADC channel
   -- (i.e., if the channel reads out an ASIC from upper half of carrier,
   --  read it backward, otherwise, read it forward)
   G_EPIX100A_CARRIER : if (FpgaVersion(31 downto 24) = x"EA") generate
      channelOrder <= (0,3,1,2,8,11,9,10,6,4,5,7,14,12,13,15) when r.streamMode = '0' else
                      (15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0); 
      channelValid  <= (others => '1');
      adcMemRdOrder <= x"0F0F" when r.streamMode = '0' else
                       x"0000";
      tpsData(0) <= r.adcData(16+1);
      tpsData(1) <= r.adcData(16+3);
      tpsData(2) <= r.adcData(16+2);
      tpsData(3) <= r.adcData(16+0);
   end generate;
   G_EPIX100P_CARRIER : if (FpgaVersion(31 downto 24) = x"E0") generate
      channelOrder <= (4,5,6,7,8,9,10,11,3,2,1,0,15,14,13,12) when r.streamMode = '0' else
                      (15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0); 
      channelValid  <= (others => '1');
      adcMemRdOrder <= x"0FF0" when r.streamMode = '0' else
                       x"0000";
      tpsData(0) <= r.adcData(16+0);
      tpsData(1) <= r.adcData(16+1);
      tpsData(2) <= r.adcData(16+2);
      tpsData(3) <= r.adcData(16+3);
   end generate;
   G_EPIX10KP_CARRIER : if (FpgaVersion(31 downto 24) = x"E2") generate
      channelOrder <= (4,5,6,7,8,9,10,11,3,2,1,0,15,14,13,12) when r.streamMode = '0' else
                      (15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0); 
      channelValid  <= (others => '1');
      adcMemRdOrder <= x"0FF0" when r.streamMode = '0' else
                       x"0000";
      tpsData(0) <= r.adcData(16+0);
      tpsData(1) <= r.adcData(16+1);
      tpsData(2) <= r.adcData(16+2);
      tpsData(3) <= r.adcData(16+3);
   end generate;
   G_EPIXS_CARRIER : if (FpgaVersion(31 downto 24) = x"E3") generate
      channelOrder <= (4,5,6,7,8,9,10,11,3,2,1,0,15,14,13,12) when r.streamMode = '0' else
                      (15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0); 
      channelValid  <= "1000100000010001";
      adcMemRdOrder <= x"0FF0" when r.streamMode = '0' else
                       x"0000";
      tpsData(0) <= r.adcData(16+0);
      tpsData(1) <= r.adcData(16+1);
      tpsData(2) <= r.adcData(16+2);
      tpsData(3) <= r.adcData(16+3);
   end generate;

   -- Edge detection for signals that interface with other blocks
   U_DataSendEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => dataSend,
         risingEdge => dataSendEdge
      );
   U_ReadStartEdge : entity work.SynchronizerEdge
      port map (
         clk        => sysClk,
         rst        => sysClkRst,
         dataIn     => acqStart,
         risingEdge => acqStartEdge
      );

   process(adcFifoRdValid,channelOrder,frameTxOut,r) begin
      for i in 0 to 15 loop
         if (r.state = READ_FIFO_S and i = channelOrder(conv_integer(r.chCnt)) and 
             adcFifoRdValid(i) = '1' and frameTxOut.almostFull = '0') then
            adcFifoRdEn(i) <= '1';
         elsif (r.state = READ_FIFO_TEST_S and i = channelOrder(conv_integer(r.chCnt)) and 
                adcFifoRdValid(i) = '1' and frameTxOut.almostFull = '0' and acqBusy = '0') then
            adcFifoRdEn(i) <= '1';
         else
            adcFifoRdEn(i) <= '0';
         end if;
      end loop;
   end process;
   --------------------------------------------------
   -- Simple state machine to just send ADC values --
   --------------------------------------------------
   comb : process (r,epixConfig,acqCount,intSeqCount,adcFifoRdData,adcFifoRdValid,
                   channelOrder,fifoEmptyAll,acqBusy,adcMemOflowAny,fifoOflowAny,
                   slowAdcData,tpsAdcData,acqStartEdge,dataSendEdge,adcFifoEmpty,
                   sysClkRst,frameTxOut) 
      variable v : RegType;
   begin
      v := r;

      -- Reset pulsed signals
      v.frameTxIn.valid := '0';
      v.frameTxIn.sof   := '0';
      v.frameTxIn.eof   := '0';
      v.frameTxIn.eofe  := '0';
      v.seqCountEn      := '0';

      -- Always grab latest adc data
      for i in 0 to 19 loop
         v.adcData(i) := adcData(i);
      end loop;
      
      -- Latch overflows (this is reset in IDLE state)
      if (fifoOflowAny = '1' or adcMemOflowAny = '1') then
         v.error := '1';
      end if;
      
      -- State outputs
      if frameTxOut.almostFull = '0' then      
         case (r.state) is
            when IDLE_S =>
               v.wordCnt     := (others => '0');
               v.chCnt       := (others => '0');
               v.overSmplCnt := (others => '0');
               v.fillCnt     := (others => '0');
               v.timeoutCnt  := (others => '0');
               v.clearFifos  := '1';
               v.readDone    := '1';
               v.streamMode  := epixConfig.adcStreamMode;
               v.testPattern := epixConfig.testPattern;
               v.error       := '0';
               if (acqStartEdge = '1') then
                  v.state := ARMED_S;
               end if;
            when ARMED_S =>
               v.readDone   := '0';
               v.clearFifos := '0';
               v.timeoutCnt := r.timeoutCnt + 1;
               if (dataSendEdge = '1') then
                  v.seqCountEn := '1';
                  v.state      := HEADER_S;
               elsif (r.timeoutCnt >= DAQ_TIMEOUT_C) then
                  v.state := IDLE_S;
               end if;
            when HEADER_S =>
               v.wordCnt         := r.wordCnt + 1;
               v.frameTxIn.valid := '1';
               case conv_integer(r.wordCnt) is
                  when 0 => v.frameTxIn.data := x"000000" & "00" & LANE_C & "00" & VC_C;
                            v.frameTxIn.sof  := '1';
                  when 1 => v.frameTxIn.data := x"0" & "00" & QUAD_C & OPCODE_C & acqCount(15 downto 0);
                  when 2 => v.frameTxIn.data := intSeqCount;
                  when 3 => v.frameTxIn.data := ZEROWORD_C;
                  when 4 => v.frameTxIn.data := ZEROWORD_C;
                  when 5 => v.frameTxIn.data := ZEROWORD_C;
                  when 6 => v.frameTxIn.data := ZEROWORD_C;
                  when 7 => v.frameTxIn.data := ZEROWORD_C;
                  when others => v.frameTxIn.data := ZEROWORD_C;
               end case;
               if (r.wordCnt = 7) then
                  v.wordCnt := (others => '0');
                  if (r.streamMode = '0') then
                     v.state := READ_FIFO_S;
                  elsif (r.streamMode = '1') then
                     v.state := READ_FIFO_TEST_S;
                  end if;
               end if;
            when READ_FIFO_S => 
               v.frameTxIn.data := adcFifoRdData(channelOrder(conv_integer(r.chCnt)));
               if adcFifoRdValid(channelOrder(conv_integer(r.chCnt))) = '1' then
                  if (channelValid(conv_integer(r.chCnt)) = '1') then
                     v.frameTxIn.valid := '1';
                  end if;
                  v.fillCnt         := r.fillCnt + 1;
                  if (r.fillCnt = conv_std_logic_vector(NCOL_C/2-1,r.fillCnt'length)) then
                     v.chCnt   := r.chCnt + 1;
                     v.fillCnt := (others => '0');
                  end if;
               else
                  v.timeoutCnt := r.timeoutCnt + 1;
               end if;
               if acqBusy = '0' and fifoEmptyAll = '1' then
                  v.state := ENV_DATA_S;
               elsif r.error = '1' or r.timeoutCnt = STUCK_TIMEOUT_C then
                  v.state := FOOTER_S;
               end if;
            when READ_FIFO_TEST_S =>
               v.frameTxIn.data := adcFifoRdData(channelOrder(conv_integer(r.chCnt)));
               if adcFifoRdValid(channelOrder(conv_integer(r.chCnt))) = '1' and acqBusy = '0' then
                  v.frameTxIn.valid := '1';
                  v.fillCnt         := r.fillCnt + 1;
               else
                  v.timeoutCnt := r.timeoutCnt + 1;
               end if;
               if adcFifoEmpty(channelOrder(conv_integer(r.chCnt))) = '1' and acqBusy = '0' then
                  v.chCnt   := r.chCnt + 1;
                  v.fillCnt := (others => '0');
               end if;
               if acqBusy = '0' and fifoEmptyAll = '1' then
                  v.state := FOOTER_S;
               elsif r.error = '1' or r.timeoutCnt = STUCK_TIMEOUT_C then
                  v.state := FOOTER_S;
               end if;
            when ENV_DATA_S =>
               v.wordCnt         := r.wordCnt + 1;
               v.frameTxIn.valid := '1';
               if (r.wordCnt = conv_std_logic_vector(WORDS_PER_SUPER_ROW_C,r.wordCnt'length)) then
                  v.frameTxIn.data := slowAdcData(1) & slowAdcData(0);
               elsif (r.wordCnt = conv_std_logic_vector(WORDS_PER_SUPER_ROW_C+1,r.wordCnt'length)) then
                  v.frameTxIn.data := slowAdcData(3) & slowAdcData(2);
               elsif (r.wordCnt = conv_std_logic_vector(WORDS_PER_SUPER_ROW_C+2,r.wordCnt'length)) then
                  v.frameTxIn.data := slowAdcData(5) & slowAdcData(4);
               elsif (r.wordCnt = conv_std_logic_vector(WORDS_PER_SUPER_ROW_C+3,r.wordCnt'length)) then
                  v.frameTxIn.data := slowAdcData(7) & slowAdcData(6);
               else
                  v.frameTxIn.data := ZEROWORD_C;
               end if;
               if (r.wordCnt = conv_std_logic_vector(WORDS_PER_SUPER_ROW_C*2-1,r.wordCnt'length)) then
                  v.wordCnt := (others => '0');
                  v.state   := TPS_DATA_S;
               end if;
            when TPS_DATA_S =>
               v.wordCnt         := r.wordCnt + 1;
               v.frameTxIn.valid := '1';
               if (r.wordCnt = 0) then
                  v.frameTxIn.data := tpsAdcData(1) & tpsAdcData(0);
               elsif (r.wordCnt = 1) then
                  v.frameTxIn.data := tpsAdcData(3) & tpsAdcData(2);            
               end if;
               if (r.wordCnt = 1) then
                  v.state := FOOTER_S;
               end if;
            when FOOTER_S =>
               v.readDone        := '1';
               v.frameTxIn.data  := ZEROWORD_C;
               v.frameTxIn.valid := '1';
               v.frameTxIn.eof   := '1';
               v.frameTxIn.eofe  := r.error;
               v.state           := IDLE_S;
         end case;
      end if;
 
      -- Synchronous Reset
      if sysClkRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      -- Fine for most assignments but data needs to be endian reversed
      rin.frameTxIn.data <= v.frameTxIn.data(15 downto 0) & v.frameTxIn.data(31 downto 16);
      
      -- Outputs from block
      readDone  <= r.readDone;
      frameTxIn <= r.frameTxIn;
      mpsOut    <= '0';
      
   end process comb;
 
 
   seq : process (sysClk) is
   begin
      if rising_edge(sysClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
 

   --Count number of ADC writes
   adcCntEn  <= readValid(0) and adcPulse;
   adcCntRst <= memRst or sysClkRst;
   process(sysClk) begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1' or adcCntRst = '1') then
            adcCnt <= (others => '0') after TPD_G;
         elsif adcCntEn = '1' then
            adcCnt <= adcCnt + 1 after TPD_G;
         end if;
      end if;
   end process;
   --Register the TPS ADC data when readTps is high
   process(sysClk) 
   begin
      if rising_edge(sysClk) then
         for i in 0 to 3 loop
            if readTps = '1' then
               tpsAdcData(i) <= tpsData(i);
            end if;
         end loop;
      end if;
   end process;
   --Sequence/frame counter
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         intSeqCount <= (others => '0');
      elsif rising_edge(sysClk) then
         if epixConfig.seqCountReset = '1' then
            intSeqCount <= (others => '0') after TPD_G;
         elsif r.seqCountEn = '1' then
            intSeqCount <= intSeqCount + 1 after TPD_G;
          end if;
      end if;
   end process;

   --Simple logic to choose which memory to read from
   process(sysClk) begin
      if rising_edge(sysClk) then
         if r.streamMode = '0' then
            for i in 0 to 15 loop
               adcFifoWrEn(i)   <= adcMemRdValid(0)(i);
               if r.testPattern = '0' then
                  adcFifoWrData(i) <= adcMemRdData(0,i);
               else
                  adcFifoWrData(i) <= "0000" & conv_std_logic_vector(i,4) & adcMemRdData(0,i)(7 downto 0);
               end if;
            end loop;
         else
            for i in 0 to 15 loop
               adcFifoWrEn(i)   <= readValid(0) and adcPulse;
               if r.testPattern = '0' then
                  adcFifoWrData(i) <= adcDataToReorder(i);
               else
                  adcFifoWrData(i) <= conv_std_logic_vector(i,4) & std_logic_vector(adcCnt);
               end if;
            end loop;
         end if;
      end if;
   end process;

   --Blockrams to reorder data
   --Memory and fifos are reset on system reset or on IDLE state
   memRst <= r.clearFifos or sysClkRst;
   --Generate logic
   G_RowBuffers : for i in 0 to 15 generate
      --The following line will need to be modified when we go to full size 10k
      --since data will need to be synchronized with ASIC clock (x4).
      process(sysClk) begin
         if rising_edge(sysClk) then
            if (adcValid(i) = '1') then
               adcDataToReorder(i) <= '0' & asicDoutDelayed(i/4) & r.adcData(i)(13 downto 0);
            end if;
         end if;
      end process;
 
      G_OversampBuffers : for j in 0 to MAX_OVERSAMPLE-1 generate
         --Write when the ADC block says data is good AND when AcqControl agrees
         process(sysClk) begin
            if rising_edge(sysClk) then
               if r.streamMode = '0' then
                  adcMemWrEn(j)(i) <= readValid(j) and adcPulse;
               else
                  adcMemWrEn(j)(i) <= '0';
               end if;
            end if;
         end process;

         --Instantiate memory
         U_RowBuffer : entity work.EpixRowBlockRam
         port map (
            sysClk      => sysClk,
            sysClkRst   => sysClkRst,
            wrReset     => r.clearFifos,
            wrData      => adcDataToReorder(i),
            wrEn        => adcMemWrEn(j)(i),
            rdOrder     => adcMemRdOrder(i),
            rdReady     => adcMemRdRdy(j)(i),
            rdStart     => adcMemRdRdy(j)(i),
            overflow    => adcMemOflow(j)(i),
            rdData      => adcMemRdData(j,i),
            dataValid   => adcMemRdValid(j)(i),
            testPattern => r.testPattern
         );
      end generate;
   end generate;
   --Or of all memory overflow bits
   process(sysClk) 
      variable runningOr : std_logic := '0';
   begin
      if rising_edge(sysClk) then
         runningOr := '0';
         for i in 0 to 15 loop
            for j in 0 to MAX_OVERSAMPLE-1 loop
               runningOr := runningOr or adcMemOflow(j)(i);
            end loop;
         end loop;
         adcMemOflowAny <= runningOr;
      end if;
   end process;
   
   -- Instantiate FIFOs
   G_AdcFifos : for i in 0 to 15 generate
      --Instantiate the FIFOs
      U_AdcFifo : entity work.FifoMux
         generic map(
            WR_DATA_WIDTH_G => 16,
            RD_DATA_WIDTH_G => 32,
            GEN_SYNC_FIFO_G => true,
            ADDR_WIDTH_G    => CH_FIFO_ADDR_WIDTH_C,
            FWFT_EN_G       => true,
            USE_BUILT_IN_G  => false,
            XIL_DEVICE_G    => "VIRTEX5",
            EMPTY_THRES_G   => 1,
            LITTLE_ENDIAN_G => true
         )
         port map(
            rst           => memRst,
            --Write ports
            wr_clk        => sysClk,
            wr_en         => adcFifoWrEn(i),
            din           => adcFifoWrData(i),
            overflow      => adcFifoOflow(i),
            --Read ports
            rd_clk        => sysClk,
            rd_en         => adcFifoRdEn(i),
            dout          => adcFifoRdData(i),
            valid         => adcFifoRdValid(i),
            empty         => adcFifoEmpty(i)
         );
   end generate;
   --Or of all fifo overflow bits
   --And of all fifo empty bits
   PROC_FIFO_LOGIC : process(sysClk) 
      variable runningOr : std_logic := '0';
      variable runningAnd : std_logic := '0';
   begin
      if rising_edge(sysClk) then
         runningOr := '0';
         runningAnd := '1';
         for i in 0 to 15 loop
            runningOr := runningOr or adcFifoOflow(i);
            runningAnd := runningAnd and adcFifoEmpty(i);
         end loop;
         fifoOflowAny <= runningOr;
         fifoEmptyAll <= runningAnd;
      end if;
   end process;

   --Pipeline delay for the ASIC digital outputs
   PROC_DOUT_PIPELINE : process(sysClk) 
      variable delay : integer range 0 to 127; 
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            for n in 0 to 3 loop
               asicDoutPipeline(n) <= (others => '0');
            end loop;
         else
            for n in 0 to 3 loop
               for i in 1 to 127 loop
                  asicDoutPipeline(n)(i) <= asicDoutPipeline(n)(i-1);
               end loop;
               asicDoutPipeline(n)(0) <= asicDout(n);
            end loop;
         end if;

         delay := conv_integer(epixConfig.doutPipelineDelay(6 downto 0));
         for n in 0 to 3 loop
            if FpgaVersion(31 downto 24) = x"E2" then
               asicDoutDelayed(n) <= asicDoutPipeline(n)( delay );
            else
               asicDoutDelayed(n) <= '0';
            end if;
         end loop;

      end if;
   end process;

         

end ReadoutControl;

