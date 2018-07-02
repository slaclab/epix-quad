-------------------------------------------------------------------------------
-- Title      : Testbench for design "TestStructureHrAsicStreamAxi"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : TestStructureHrAsicStreamAxi_tb.vhd
-- Author     : Dionisio Doering  <ddoering@tid-pc94280.slac.stanford.edu>
-- Company    : 
-- Created    : 2017-05-22
-- Last update: 2018-05-11
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
  
  -- clock
  signal sysClk    : std_logic := '1';
  signal axilClk   : std_logic := '1';
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
         rxClk             => sysClk,
         rxRst             => axilRst,
         rxData            => iasicTsData,
         rxValid           => iasicTsSync,
         axilClk           => sysClk,
         axilRst           => axilRst,
         sAxilWriteMaster  => sAxilWriteMaster,
         sAxilWriteSlave   => sAxilWriteSlave,
         sAxilReadMaster   => sAxilReadMaster,
         sAxilReadSlave    => sAxilReadSlave,
         axisClk           => sysClk,
         axisRst           => axilRst,
         mAxisMaster       => userAxisMaster,
         mAxisSlave        => userAxisSlave, 
         acqNo             => acqCnt,
         testTrig          => testTrig,
         errInhibit        => errInhibit
      );

  -- clock generation
  sysClk <= not sysClk after 6.4 ns;
  axilClk <= not axilClk after 6.4 ns;
  
  -- reset
  axilRst <= sysClkRst;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here

    wait until rising_edge(sysClk);
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
    wait until rising_edge(sysClk);    
    --sAxilWriteMaster.awaddr  <= x"00000000";
    sAxilWriteMaster.awprot  <= "000";
    sAxilWriteMaster.awvalid <= '0';
    --sAxilWriteMaster.wdata   <= x"00000000";
    sAxilWriteMaster.wstrb   <= x"0";
    sAxilWriteMaster.wvalid  <= '0';
    sAxilWriteMaster.bready  <= '1';
    wait for 10 us;

    axiLiteBusSimWrite (sysClk, sAxilWriteMaster, sAxilWriteSlave, x"00000020", x"00000001", true);
    wait for 10 us;
    
    wait for 7 ms;
    wait until rising_edge(sysClk);
    testTrig <= '1';
    wait until rising_edge(sysClk);
    testTrig <= '0';
    --creates odd first pulse
    wait until rising_edge(sysClk);
    iasicTsSync <= '0';
    wait until rising_edge(sysClk);
    iasicTsSync <= '1';
    wait for 1 us;
    iasicTsSync <= '0';
    -- starts nomal pulses
    stimloop : for i in 0 to 30 loop    -- 31 "normal" pulses last pulse keeps TS_Sync high
      wait until rising_edge(sysClk);
      iasicTsData <= std_logic_vector(to_unsigned(i, 16));
      iasicTsSync <= '1';
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      wait until rising_edge(sysClk);
      
      if i < 1023 then
        iasicTsSync <= '0';  
      end if;
      
      -- simulates the HR adc modes 0,1 where data rate is low
      delayloop : for i in 0 to 63 loop 
        wait until rising_edge(sysClk);
      end loop delayloop;
      
    end loop stimloop;
    iasicTsSync <= '1';                 -- last pulse keeps TS_Sync high

    wait;
  end process WaveGen_Proc;
 
end sim_arch;

