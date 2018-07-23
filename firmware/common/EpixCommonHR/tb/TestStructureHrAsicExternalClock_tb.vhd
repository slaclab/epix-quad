-------------------------------------------------------------------------------
-- Title      : Testbench for design "HR ASIC test structure with external clock"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : TestStructureHrAsicExternalClock_tb.vhd
-- Company    : 
-- Created    : 2017-05-22
-- Last update: 2018-07-23
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_arith.all;

library STD;
use STD.textio.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.EpixHRPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;


-------------------------------------------------------------------------------

entity TestStructureHrAsicExternalClock_tb is

end TestStructureHrAsicExternalClock_tb;

-------------------------------------------------------------------------------

architecture arch of TestStructureHrAsicExternalClock_tb is

  -- component generics
  constant TPD_G : time := 1 ns;

  -- clock
  signal sysClk    : std_logic := '1';
  signal sysClkRst : std_logic := '1';
  signal axiClk    : sl := '1';
  signal dSysClk   : sl := '1';


  -- axilite
  signal axilWriteMaster : AxiLiteWriteMasterType;
  signal axilWriteSlave  : AxiLiteWriteSlaveType;
  signal axilReadMaster  : AxiLiteReadMasterType;
  signal axilReadSlave   : AxiLiteReadSlaveType;
  signal registerValue   : slv(31 downto 0);    

  -- component ports
  signal asicSDCLk       : sl;
  signal asicSDRst       : sl;
  signal asicSHClk       : sl;

begin  --

  
  -- DUT is the deserializer using iserdes3 for ultrascale devices
  -- DUT enables data synchronization based on a channel data pattern or on frame clock.
  DUT0: entity work.TSWaveCtrlEpixHR 
   generic map(
      TPD_G             => TPD_G
   )
   port map(
      -- Global Signals
      axiClk         => axiClk,
      sysCLK         => sysCLK,
      dSysClk        => dSysClk,
      axiRst         => sysClkRst,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => axilReadMaster,
      axiReadSlave   => axilReadSlave,
      axiWriteMaster => axilWriteMaster,
      axiWriteSlave  => axilWriteSlave,
      -- ASICs acquisition signals
      asicSDCLk      => asicSDCLk,
      asicSDRst      => asicSDRst,
      asicSHClk      => asicSHClk
   );

    
  -- clock generation
  sysClk  <= not sysClk after 5 ns;  -- 100 MHz
  dSysClk <= sysClk after 2.5 ns;      --  this mimics the MMCM clock
                                       -- phase adjustment
  axiClk  <= not axiClk after 5 ns;    -- 100 MHz
  --

 
  -- waveform generation
  WaveGen_Proc: process
    variable registerData    : slv(31 downto 0);  
  begin

    ---------------------------------------------------------------------------
    -- reset
    ---------------------------------------------------------------------------
    wait until sysClk = '1';
    sysClkRst  <= '1';


    wait for 1 us;
    sysClkRst <= '0';

            
    ---------------------------------------------------------------------------
    -- load axilite registers
    ---------------------------------------------------------------------------
    --
    wait until sysClk = '1';
    -- change to axil register command
    wait until sysClk = '0';
    --loadDelay <= '0';
    axiLiteBusSimRead (sysClk, axilReadMaster, axilReadSlave, x"00000004", registerData, true);
    registerValue <= registerData;

    wait for 1 us;
    --axiLiteBusSimWrite (sysClk, axilWriteMaster, axilWriteSlave, x"00000024", x"00000020", true);
    wait for 1 us;
    --axiLiteBusSimWrite (sysClk, axilWriteMaster, axilWriteSlave, x"00000028", x"00000001", true);
    wait for 1 us;
    --axiLiteBusSimWrite (sysClk, axilWriteMaster, axilWriteSlave, x"00000034", x"00000020", true);
    wait for 1 us;
    --axiLiteBusSimWrite (sysClk, axilWriteMaster, axilWriteSlave, x"00000038", x"00000020", true);
    wait for 1 us;
    axiLiteBusSimWrite (sysClk, axilWriteMaster, axilWriteSlave, x"00000004", x"00000001", true);
    
    wait for 10 us;    
    
    axiLiteBusSimRead (sysClk, axilReadMaster, axilReadSlave, x"00000004", registerData, true);
    registerValue <= registerData;
    wait for 1 us;

    ---------------------------------------------------------------------------
    -- 
    ---------------------------------------------------------------------------
    wait for 10 us;
    

    
    wait;
  end process WaveGen_Proc;

  

end arch;

