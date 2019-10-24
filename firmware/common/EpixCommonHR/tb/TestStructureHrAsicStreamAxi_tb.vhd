-------------------------------------------------------------------------------
-- Title      : Testbench for design "TestStructureHrAsicStreamAxi"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : TestStructureHrAsicStreamAxi_tb.vhd
-- Author     : Dionisio Doering  <ddoering@tid-pc94280.slac.stanford.edu>
-- Company    : 
-- Created    : 2017-05-22
-- Last update: 2019-10-24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-05-22  1.0      ddoering	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.EpixHRPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;

Library UNISIM;
use UNISIM.vcomponents.all;

-------------------------------------------------------------------------------

entity TestStructureHrAsicStreamAxi_tb is

end TestStructureHrAsicStreamAxi_tb;

-------------------------------------------------------------------------------

architecture sim_arch of TestStructureHrAsicStreamAxi_tb is


  component TestStructureHrAsicStreamAxi is 
    generic (
      TPD_G           	: time := 1 ns;
      VC_NO_G           : slv(3 downto 0)  := "0000";
      LANE_NO_G         : slv(3 downto 0)  := "0000";
      ASIC_NO_G         : slv(2 downto 0)  := "000";
      ASIC_DATA_G       : natural := (32*32)-1; --workds
      AXIL_ERR_RESP_G   : slv(1 downto 0)  := AXI_RESP_DECERR_C
      );
    port ( 
      -- Deserialized data port
      rxClk             : in  sl;
      rxRst             : in  sl;
      rxData            : in  slv(15 downto 0);
      rxValid           : in  sl;
      
      -- AXI lite slave port for register access
      axilClk           : in  sl;
      axilRst           : in  sl;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      
      -- AXI data stream output
      axisClk           : in  sl;
      axisRst           : in  sl;
      mAxisMaster       : out AxiStreamMasterType;
      mAxisSlave        : in  AxiStreamSlaveType;
      
      -- acquisition number input to the header
      acqNo             : in  slv(31 downto 0);
      
      -- optional readout trigger for test mode
      testTrig          : in  sl := '0';
      -- optional inhibit counting errors 
      -- workaround to tixel bug dropping link after R0
      -- affects only SOF error counter
      errInhibit        : in  sl := '0'
      );
  end component;

  -- component generics
  constant TPD_G : time := 1 ns;
  constant MASTER_AXI_STREAM_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);
  constant AXIL_ERR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;
  constant ADDR_WIDTH_G : integer := 10;
  constant DATA_WIDTH_G : integer := 16;
  constant MODE_C       : integer := 2;
  
  -- clock
  signal pgpClk        : sl := '1';
  signal asicRfClk     : sl;
  signal asicRfClkRst  : sl;
  signal asicRdClk     : sl;
  signal asicRdClkRst  : sl;
  signal bitClk        : sl;
  signal bitClkRst     : sl;
  signal byteClk       : sl;
  signal byteClkRst    : sl;
  signal sysRst        : sl;
  signal coreClk       : sl;
  signal iDelayCtrlClk : sl;
  signal tsClk0        : sl;
  signal tsClk1        : sl;
  signal coreClkRst    : sl;
  signal iDelayCtrlRst : sl;
  signal dummyRst      : slv(1 downto 0);

  -- component ports: axi lite
  signal sysClkRst          : std_logic;
  signal axilRst            : std_logic;
  signal sAxilWriteMaster   : AxiLiteWriteMasterType;
  signal sAxilWriteSlave    : AxiLiteWriteSlaveType;
  signal sAxilReadMaster    : AxiLiteReadMasterType;
  signal sAxilReadSlave     : AxiLiteReadSlaveType;
  -- component ports: axi stream
  signal userAxisMaster      : AxiStreamMasterType;
  signal userAxisSlave       : AxiStreamSlaveType;
  -- component ports: general IO
  signal iasicTsData : slv(15 downto 0) := (others => '0');
  signal iasicTsSync : sl := '1';
  signal iAsicSR0    : sl := '0';
  signal acqCnt      : slv(31 downto 0) := (others => '0');
  signal testTrig    : sl := '0';    
  signal errInhibit  : sl := '0';

begin  -- _arch

  -- component instantiation
  DUT: entity work.TestStructureHrAsicStreamAxi
      generic map (
         ASIC_NO_G   => std_logic_vector(to_unsigned(2, 3)) -- TS ID is the next after all
                                                            -- ASICs using 2
      )
      port map (
         rxClk             => bitClk,
         rxRst             => bitClkRst,
         rxData            => iasicTsData,
         rxValid           => iasicTsSync,
         asicSR0           => iAsicSR0, 
         axilClk           => coreClk,
         axilRst           => axilRst,
         sAxilWriteMaster  => sAxilWriteMaster,
         sAxilWriteSlave   => sAxilWriteSlave,
         sAxilReadMaster   => sAxilReadMaster,
         sAxilReadSlave    => sAxilReadSlave,
         axisClk           => coreClk,
         axisRst           => axilRst,
         mAxisMaster       => userAxisMaster,
         mAxisSlave        => userAxisSlave, 
         acqNo             => acqCnt,
         testTrig          => testTrig,
         errInhibit        => errInhibit
      );

  -- clock generation
  pgpClk <= not pgpClk after 3.2 ns;
  
   ------------------------------------------
   -- Generate clocks from 156.25 MHz PGP  --
   ------------------------------------------
   -- clkIn     : 156.25 MHz PGP
   -- clkOut(0) : 250 MHz serial data bit clock
   -- clkOut(1) : 100.00 MHz system clock
   -- clkOut(2) : 8 MHz ASIC readout clock
   -- clkOut(3) : 20 MHz ASIC reference clock
   -- clkOut(4) : 200 MHz Idelaye2 calibration clock
   -- clkOut(5) : 100.00 MHz system clock TS clocks
   -- clkOut(6) : 100.00 MHz system clock TS clocks
   U_CoreClockGen : entity work.ClockManager7
   generic map (
      INPUT_BUFG_G         => false,
      FB_BUFG_G            => true,
      NUM_CLOCKS_G         => 7,
      CLKIN_PERIOD_G       => 6.4,
      DIVCLK_DIVIDE_G      => 6,     --base clock 1000MHz
      CLKFBOUT_MULT_F_G    => 38.4,
      
      CLKOUT0_DIVIDE_F_G   => 4.0,
      CLKOUT0_PHASE_G      => 90.0,
      CLKOUT0_DUTY_CYCLE_G => 0.5,
      
      CLKOUT1_DIVIDE_G     => 10,
      CLKOUT1_PHASE_G      => 0.0,
      CLKOUT1_DUTY_CYCLE_G => 0.5,
      
      CLKOUT2_DIVIDE_G     => 4,
      CLKOUT2_PHASE_G      => 0.0,
      CLKOUT2_DUTY_CYCLE_G => 0.5,
      
      CLKOUT3_DIVIDE_G     => 20,
      CLKOUT3_PHASE_G      => 0.0,
      CLKOUT3_DUTY_CYCLE_G => 0.5,
      
      CLKOUT4_DIVIDE_G     => 5,
      CLKOUT4_PHASE_G      => 0.0,
      CLKOUT4_DUTY_CYCLE_G => 0.5,

      CLKOUT5_DIVIDE_G     => 10,
      CLKOUT5_PHASE_G      => 0.0,
      CLKOUT5_DUTY_CYCLE_G => 0.5,

      CLKOUT6_DIVIDE_G     => 10,
      CLKOUT6_PHASE_G      => 0.0,
      CLKOUT6_DUTY_CYCLE_G => 0.5
   )
   port map (
      clkIn     => pgpClk,
      rstIn     => sysRst,
      clkOut(0) => bitClk,
      clkOut(1) => coreClk,
      clkOut(2) => asicRdClk,
      clkOut(3) => asicRfClk,
      clkOut(4) => iDelayCtrlClk,
      clkOut(5) => tsClk0,
      clkOut(6) => tsClk1,
      rstOut(0) => bitClkRst,
      rstOut(1) => coreClkRst,
      rstOut(2) => asicRdClkRst,
      rstOut(3) => asicRfClkRst,
      rstOut(4) => iDelayCtrlRst,
      rstOut(5) => dummyRst(0),
      rstOut(6) => dummyRst(1),
      locked    => open
   );

  U_BUFR : BUFR
   generic map (
      SIM_DEVICE  => "7SERIES",
      BUFR_DIVIDE => "5"
   )
   port map (
      I   => bitClk,
      O   => byteClk,
      CE  => '1',
      CLR => '0'
   );
  
  -- reset
  axilRst <= sysClkRst;

-- waveform generation
  mode01: if MODE_C = 0 generate
      asicModel: process
      begin
        iasicTsSync <= '1';
        packetloop : for p in 0 to 3 loop
          wait for 100 us;
          --simulates asicSR0
          iAsicSR0 <= '1';
          wait for 1 us;
          --creates odd first pulse
          wait until rising_edge(byteClk);
          iasicTsSync <= '0';
          wait until rising_edge(byteClk);
          iasicTsSync <= '1';
          wait for 1 us;
          iasicTsSync <= '1';
          -- starts nomal pulses
          stimloop : for i in 0 to 31 loop    -- 31 "normal" pulses last pulse keeps TS_Sync high
            wait until rising_edge(byteClk);
            iasicTsSync <= '1';
            wait until rising_edge(byteClk);

            if i < 1023 then
              iasicTsSync <= '0';  
            end if;

            iasicTsData <= std_logic_vector(to_unsigned(i, 16));

            -- simulates the HR adc modes 0,1 where data rate is low
            delayloop : for j in 0 to 63 loop 
              wait until rising_edge(byteClk);
            end loop delayloop;

          end loop stimloop;
          iasicTsSync <= '1';                 -- last pulse keeps TS_Sync high
          --simulates asicSR0
          iAsicSR0 <= '0';
        end loop packetloop;
      end process;
  end generate mode01;


  mode23: if MODE_C = 2 generate
    asicModel: process
    begin
      iasicTsSync <= '0';
        packetloop : for p in 0 to 3 loop
          wait for 100 us;
          --simulates asicSR0
          iAsicSR0 <= '1';
          wait for 1 us;
          -- starts nomal pulses
          stimloop : for i in 0 to 4000 loop    -- 31 "normal" pulses last pulse keeps TS_Sync high
            wait until rising_edge(byteClk);
            iasicTsSync <= '1';
            iasicTsData <= std_logic_vector(to_unsigned(i, 16));
            wait until falling_edge(byteClk);
            iasicTsSync <= '0';
          end loop stimloop;
          iasicTsSync <= '0';                 -- last pulse keeps TS_Sync high
          --simulates asicSR0
          iAsicSR0 <= '0';
        end loop packetloop;
    end process;
  end generate mode23;
  
  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here

    wait until rising_edge(coreClk);
    sysClkRst <= '1';
    sAxilWriteMaster.awaddr  <= x"00000000";
    sAxilWriteMaster.awprot  <= "000";
    sAxilWriteMaster.awvalid <= '0';
    sAxilWriteMaster.wdata   <= x"00000000";
    sAxilWriteMaster.wstrb   <= x"0";
    sAxilWriteMaster.wvalid  <= '0';
    sAxilWriteMaster.bready  <= '1';    

    wait for 10 us;
    sysClkRst <= '0';

    sAxilWriteMaster.awaddr  <= std_logic_vector(to_unsigned(36, sAxilWriteMaster.awaddr'length)); --x"00000000";
    sAxilWriteMaster.awprot  <= "111";
    sAxilWriteMaster.awvalid <= '1';
    sAxilWriteMaster.wdata   <= std_logic_vector(to_unsigned(1023, sAxilWriteMaster.awaddr'length)); --x"0003A0F5";
    sAxilWriteMaster.wstrb   <= x"F";
    sAxilWriteMaster.wvalid  <= '1';
    sAxilWriteMaster.bready  <= '1';

        --wait for 1 us;
    wait until rising_edge(coreClk);    
    --sAxilWriteMaster.awaddr  <= x"00000000";
    sAxilWriteMaster.awprot  <= "000";
    sAxilWriteMaster.awvalid <= '0';
    --sAxilWriteMaster.wdata   <= x"00000000";
    sAxilWriteMaster.wstrb   <= x"0";
    sAxilWriteMaster.wvalid  <= '0';
    sAxilWriteMaster.bready  <= '1';
    wait for 5 us;
    --sets frame size
    axiLiteBusSimWrite (coreClk, sAxilWriteMaster, sAxilWriteSlave, x"00000024", x"0000001F", true);
    wait for 5 us;
    --select modes, use 4 for mode 0 and 6 for mode 2
    if MODE_C = 0 then
      --sets frame size
      axiLiteBusSimWrite (coreClk, sAxilWriteMaster, sAxilWriteSlave, x"00000024", x"0000001F", true);
      axiLiteBusSimWrite (coreClk, sAxilWriteMaster, sAxilWriteSlave, x"00000028", x"00000004", true);
    end if;
    if MODE_C = 2 then
      --sets frame size
      axiLiteBusSimWrite (coreClk, sAxilWriteMaster, sAxilWriteSlave, x"00000024", x"00000800", true);
      axiLiteBusSimWrite (coreClk, sAxilWriteMaster, sAxilWriteSlave, x"00000028", x"00000006", true);
    end if;
    
    wait for 10 us;
    
    wait for 7 ms;
    wait until rising_edge(coreClk);
    testTrig <= '1';
    wait until rising_edge(coreClk);
    testTrig <= '0';

    wait;
  end process WaveGen_Proc;
 
end sim_arch;

