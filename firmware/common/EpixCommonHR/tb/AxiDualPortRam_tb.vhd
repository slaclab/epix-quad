-------------------------------------------------------------------------------
-- File       : Dac8812Cntrl_tb.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Testbench for design "Dac8812Cntrl"
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

use work.EpixHRPkg.all;

-------------------------------------------------------------------------------

entity AxiDualPortRam_tb is

end AxiDualPortRam_tb;

-------------------------------------------------------------------------------

architecture sim_arch of AxiDualPortRam_tb is


   component AxiDualPortRam is

   generic (
      TPD_G            : time                       := 1 ns;
      MEMORY_TYPE_G    : string                     := "distributed";
      REG_EN_G         : boolean                    := true;
      MODE_G           : string                     := "read-first";
      AXI_WR_EN_G      : boolean                    := true;
      SYS_WR_EN_G      : boolean                    := false;
      SYS_BYTE_WR_EN_G : boolean                    := false;
      COMMON_CLK_G     : boolean                    := false;
      ADDR_WIDTH_G     : integer range 1 to (2**24) := 5;
      DATA_WIDTH_G     : integer                    := 32;
      INIT_G           : slv                        := "0";
      AXI_ERROR_RESP_G : slv(1 downto 0)            := AXI_RESP_DECERR_C);

   port (
      -- Axi Port
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Standard Port
      clk         : in  sl                                         := '0';
      en          : in  sl                                         := '1';
      we          : in  sl                                         := '0';
      weByte      : in  slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0) := (others => '0');
      rst         : in  sl                                         := '0';
      addr        : in  slv(ADDR_WIDTH_G-1 downto 0)               := (others => '0');
      din         : in  slv(DATA_WIDTH_G-1 downto 0)               := (others => '0');
      dout        : out slv(DATA_WIDTH_G-1 downto 0);
      axiWrValid  : out sl;
      axiWrStrobe : out slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0);
      axiWrAddr   : out slv(ADDR_WIDTH_G-1 downto 0);
      axiWrData   : out slv(DATA_WIDTH_G-1 downto 0));
  end component;

  -- component generics
  constant TPD_G : time := 1 ns;
  constant MASTER_AXI_STREAM_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);
  constant AXIL_ERR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;
  constant ADDR_WIDTH_G : integer := 10;
  constant DATA_WIDTH_G : integer := 16;
  
  -- component ports
  signal sysClkRst          : std_logic;
  signal axilRst            : std_logic;
  signal en                 : sl := '1';
  signal we                 : sl := '0';
  signal weByte             : slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0) := (others => '0');
  signal addr               : slv(ADDR_WIDTH_G-1 downto 0)               := (others => '0');
  signal din                : slv(DATA_WIDTH_G-1 downto 0)               := (others => '0');
  signal dout               : slv(DATA_WIDTH_G-1 downto 0);
  signal axiWrValid         : sl;
  signal axiWrStrobe        : slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0);
  signal axiWrAddr          : slv(ADDR_WIDTH_G-1 downto 0);
  signal axiWrData          : slv(DATA_WIDTH_G-1 downto 0);
  signal sAxilWriteMaster   : AxiLiteWriteMasterType;
  signal sAxilWriteSlave    : AxiLiteWriteSlaveType;
  signal sAxilReadMaster    : AxiLiteReadMasterType;
  signal sAxilReadSlave     : AxiLiteReadSlaveType;

  -- clock
  signal sysClk    : std_logic := '1';
  signal axilClk   : std_logic := '1';

begin  -- Dac8812Cntrl_arch

  -- component instantiation
  DUT: entity surf.AxiDualPortRam 
   generic map(
      TPD_G            => 1 ns,
      MEMORY_TYPE_G    => "block",
      REG_EN_G         => true,
      MODE_G           => "read-first",
      AXI_WR_EN_G      => true,
      SYS_WR_EN_G      => false,
      SYS_BYTE_WR_EN_G => false,
      COMMON_CLK_G     => false,
      ADDR_WIDTH_G     => ADDR_WIDTH_G,
      DATA_WIDTH_G     => DATA_WIDTH_G,
      INIT_G           => "0")
   port map (
      -- Axi Port
      axiClk         => sysClk,
      axiRst         => axilRst,
      axiReadMaster  => sAxilReadMaster,
      axiReadSlave   => sAxilReadSlave,
      axiWriteMaster => sAxilWriteMaster,
      axiWriteSlave  => sAxilWriteSlave,

      -- Standard Port
      clk           => sysClk,
      en            => en,
      we            => we,
      weByte        => weByte,
      rst           => axilRst,
      addr          => addr,
      din           => din,
      dout          => dout,
      axiWrValid    => axiWrValid,
      axiWrStrobe   => axiWrStrobe,
      axiWrAddr     => axiWrAddr,
      axiWrData     => axiWrData);

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
    sAxilWriteMaster.awaddr  <= x"00000000";
    sAxilWriteMaster.awprot  <= "000";
    sAxilWriteMaster.awvalid <= '0';
    sAxilWriteMaster.wdata   <= x"00000000";
    sAxilWriteMaster.wstrb   <= x"0";
    sAxilWriteMaster.wvalid  <= '0';
    sAxilWriteMaster.bready  <= '1';    

    wait for 1 us;
    sysClkRst <= '0';
    stimloop : for i in 0 to 255 loop 
        wait for 4 us;
        wait until sysClk = '1';
        sAxilWriteMaster.awaddr  <= std_logic_vector(to_unsigned(i*4, sAxilWriteMaster.awaddr'length)); --x"00000000";
        sAxilWriteMaster.awprot  <= "111";
        sAxilWriteMaster.awvalid <= '1';
        sAxilWriteMaster.wdata   <= std_logic_vector(to_unsigned(i, sAxilWriteMaster.awaddr'length)); --x"0003A0F5";
        sAxilWriteMaster.wstrb   <= x"F";
        sAxilWriteMaster.wvalid  <= '1';
        sAxilWriteMaster.bready  <= '1';

        --wait for 1 us;
        wait until sysClk = '1';    
        --sAxilWriteMaster.awaddr  <= x"00000000";
        sAxilWriteMaster.awprot  <= "000";
        sAxilWriteMaster.awvalid <= '0';
        --sAxilWriteMaster.wdata   <= x"00000000";
        sAxilWriteMaster.wstrb   <= x"0";
        sAxilWriteMaster.wvalid  <= '0';
        sAxilWriteMaster.bready  <= '1';
        
    end loop stimloop;

   stimloop1 : for j in 0 to 1023 loop
        stimloop2 : for i in 0 to 1023 loop 
        
            wait until sysClk = '1';
            en <= '1';
            addr <= std_logic_vector(to_unsigned(i, addr'length));        
        
        end loop stimloop2;
    end loop stimloop1;
    wait for 1 us;

    wait;
  end process WaveGen_Proc;

  

end sim_arch;

-------------------------------------------------------------------------------

--configuration Dac8812Cntrl_tb_Dac8812Cntrl_arch_cfg of Dac8812Cntrl_tb is
--  for Dac8812Cntrl_arch
--  end for;
--end Dac8812Cntrl_tb_Dac8812Cntrl_arch_cfg;

-------------------------------------------------------------------------------
