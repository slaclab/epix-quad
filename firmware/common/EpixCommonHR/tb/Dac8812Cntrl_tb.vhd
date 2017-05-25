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

-------------------------------------------------------------------------------

entity Dac8812Cntrl_tb is

end Dac8812Cntrl_tb;

-------------------------------------------------------------------------------

architecture Dac8812Cntrl_arch of Dac8812Cntrl_tb is

  component Dac8812Cntrl
    generic (
      TPD_G : time);
    port (
      sysClk    : in  std_logic;
      sysClkRst : in  std_logic;
      dacData   : in  std_logic_vector(15 downto 0);
      dacCh     : in  std_logic_vector(1 downto 0);
      dacDin    : out std_logic;
      dacSclk   : out std_logic;
      dacCsL    : out std_logic;
      dacLdacL  : out std_logic;
      dacClrL   : out std_logic);
  end component;

  -- component generics
  constant TPD_G : time := 1 ns;

  -- component ports
  signal sysClk    : std_logic;
  signal sysClkRst : std_logic;
  signal dacData   : std_logic_vector(15 downto 0);
  signal dacCh     : std_logic_vector(1 downto 0);
  signal dacDin    : std_logic;
  signal dacSclk   : std_logic;
  signal dacCsL    : std_logic;
  signal dacLdacL  : std_logic;
  signal dacClrL   : std_logic;

  -- clock
  signal Clk : std_logic := '1';

begin  -- Dac8812Cntrl_arch

  -- component instantiation
  DUT: Dac8812Cntrl
    generic map (
      TPD_G => TPD_G)
    port map (
      sysClk    => sysClk,
      sysClkRst => sysClkRst,
      dacData   => dacData,
      dacCh     => dacCh,
      dacDin    => dacDin,
      dacSclk   => dacSclk,
      dacCsL    => dacCsL,
      dacLdacL  => dacLdacL,
      dacClrL   => dacClrL);

  -- clock generation
  Clk <= not Clk after 10 ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here

    wait until Clk = '1';
  end process WaveGen_Proc;

  

end Dac8812Cntrl_arch;

-------------------------------------------------------------------------------

configuration Dac8812Cntrl_tb_Dac8812Cntrl_arch_cfg of Dac8812Cntrl_tb is
  for Dac8812Cntrl_arch
  end for;
end Dac8812Cntrl_tb_Dac8812Cntrl_arch_cfg;

-------------------------------------------------------------------------------
