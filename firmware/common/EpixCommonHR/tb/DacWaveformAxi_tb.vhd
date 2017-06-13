-------------------------------------------------------------------------------
-- Title      : Testbench for design "Dac8812Cntrl"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Dac8812Cntrl_tb.vhd
-- Author     : Dionisio Doering  <ddoering@tid-pc94280.slac.stanford.edu>
-- Company    : 
-- Created    : 2017-05-22
-- Last update: 2017-05-22
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

entity DacWaveformAxi_tb is

end DacWaveformAxi_tb;

-------------------------------------------------------------------------------

architecture arch of DacWaveformAxi_tb is

  -- component generics
  constant TPD_G : time := 1 ns;
  constant MASTER_AXI_STREAM_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);
  constant AXIL_ERR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;
  
  -- component ports
  signal sysClkRst : std_logic;
  signal dacDin    : std_logic;
  signal dacSclk   : std_logic;
  signal dacCsL    : std_logic;
  signal dacLdacL  : std_logic;
  signal dacClrL   : std_logic;
  signal axilRst           : std_logic;
  signal sAxilWriteMaster  : AxiLiteWriteMasterArray(EPIXHR_NUM_AXI_MASTER_SLOTS_C-1 downto 0);
  signal sAxilWriteSlave   : AxiLiteWriteSlaveArray(EPIXHR_NUM_AXI_MASTER_SLOTS_C-1 downto 0);
  signal sAxilReadMaster   : AxiLiteReadMasterArray(EPIXHR_NUM_AXI_MASTER_SLOTS_C-1 downto 0);
  signal sAxilReadSlave    : AxiLiteReadSlaveArray(EPIXHR_NUM_AXI_MASTER_SLOTS_C-1 downto 0);


  -- clock
  signal sysClk    : std_logic := '1';
  signal axilClk   : std_logic := '1';

begin  -- arch

  -- component instantiation
  DUT: entity work.DacWaveformGenAxi
    generic map (
      TPD_G => TPD_G,
      NUM_SLAVE_SLOTS_G  => EPIXHR_NUM_AXI_SLAVE_SLOTS_C,
      NUM_MASTER_SLOTS_G => EPIXHR_NUM_AXI_MASTER_SLOTS_C,
      MASTERS_CONFIG_G   => ssiAxiStreamConfig(4, TKEEP_COMP_C)
    )
    port map (
      sysClk    => sysClk,
      sysClkRst => sysClkRst,
      dacDin    => dacDin,
      dacSclk   => dacSclk,
      dacCsL    => dacCsL,
      dacLdacL  => dacLdacL,
      dacClrL   => dacClrL,
      axilClk           => axilClk,
      axilRst           => axilRst,
      sAxilWriteMaster  => sAxilWriteMaster,
      sAxilWriteSlave   => sAxilWriteSlave,
      sAxilReadMaster   => sAxilReadMaster,
      sAxilReadSlave    => sAxilReadSlave);

  -- clock generation
  sysClk <= not sysClk after 6.4 ns;
  axilClk <= not axilClk after 6.4 ns;
  
  -- reset
  axilRst <= sysClkRst;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here

    wait until sysClk = '1';
    sysClkRst <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"0";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';    

    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awaddr  <= x"00000000";
    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awprot  <= "000";
    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awvalid <= '0';
    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wdata   <= x"00000000";
    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wstrb   <= x"0";
    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wvalid  <= '0';
    sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).bready  <= '1';    

    wait for 1 us;
    sysClkRst <= '0';
    
    wait for 4 us;
    wait until sysClk = '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "111";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000001";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"F";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';

    wait until sysClk = '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"0";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';




    stimloop : for i in 0 to 255 loop 
        wait for 4 us;
        wait until sysClk = '1';
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awaddr  <= std_logic_vector(to_unsigned(i*4, sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awaddr'length)); --x"00000000";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awprot  <= "111";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awvalid <= '1';
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wdata   <= std_logic_vector(to_unsigned(i, sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awaddr'length)); --x"0003A0F5";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wstrb   <= x"F";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wvalid  <= '1';
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).bready  <= '1';

        --wait for 1 us;
        wait until sysClk = '1';    
        --sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awaddr  <= x"00000000";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awprot  <= "000";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).awvalid <= '0';
        --sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wdata   <= x"00000000";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wstrb   <= x"0";
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).wvalid  <= '0';
        sAxilWriteMaster(DACWFMEM_REG_AXI_INDEX_C).bready  <= '1';
        
    end loop stimloop;
       
    wait for 1 us;

    wait until sysClk = '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "111";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000003";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"F";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';

    wait until sysClk = '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"0";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';

    wait for 3000 us;

    wait until sysClk = '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000004";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "111";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000400";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"F";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';

    wait until sysClk = '1';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awaddr  <= x"00000004";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awprot  <= "000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).awvalid <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wdata   <= x"00000000";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wstrb   <= x"0";
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).wvalid  <= '0';
    sAxilWriteMaster(DAC8812_REG_AXI_INDEX_C).bready  <= '1';


    wait;
  end process WaveGen_Proc;

  

end arch;

-------------------------------------------------------------------------------

--configuration Dac8812Cntrl_tb_Dac8812Cntrl_arch_cfg of Dac8812Cntrl_tb is
--  for Dac8812Cntrl_arch
--  end for;
--end Dac8812Cntrl_tb_Dac8812Cntrl_arch_cfg;

-------------------------------------------------------------------------------
