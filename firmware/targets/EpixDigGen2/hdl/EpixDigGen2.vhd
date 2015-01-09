-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EpixDigGen2.vhd
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-12-11
-- Last update: 2014-12-11
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.CommonPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EpixDigGen2 is
   port (
      -- Debugging IOs
      led        : out slv(3 downto 0);
      -- GT CLK Pins
      gtRefClk0P : in  sl;
      gtRefClk0N : in  sl;
      -- pgp fiber link
      gtDataRxP  : in  sl;
      gtDataRxN  : in  sl;
      gtDataTxP  : out sl;
      gtDataTxN  : out sl;
      -- SFP signals
      sfpDisable : out sl
   );
end EpixDigGen2;

architecture top_level of EpixDigGen2 is

   signal coreClk     : sl;
   signal axiRst      : sl;
   signal heartBeat   : sl;
   signal txLinkReady : sl;
   signal rxLinkReady : sl;

   -- AXI-Lite Signals
   signal sAxiReadMaster  : AxiLiteReadMasterType;
   signal sAxiReadSlave   : AxiLiteReadSlaveType;
   signal sAxiWriteMaster : AxiLiteWriteMasterType;
   signal sAxiWriteSlave  : AxiLiteWriteSlaveType;
   -- AXI-Lite Signals
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0); 
   
begin

   -- Fixed state logic signals
   sfpDisable <= '0';

   ---------------------
   -- Diagnostic LEDs --
   ---------------------
   led(3) <= coreClk;
   led(2) <= rxLinkReady;
   led(1) <= txLinkReady;
   led(0) <= heartBeat;
   ---------------------
   -- Heart beat LED  --
   ---------------------
   U_Heartbeat : entity work.Heartbeat
      generic map(
         PERIOD_IN_G => 6.4E-9
      )   
      port map (
         clk => coreClk,
         o   => heartBeat
      );    

   ---------------------
   -- PGP Front end   --
   ---------------------
   U_PgpFrontEnd : entity work.PgpFrontEnd
      port map (
         -- GTX 7 Ports
         gtClkP      => gtRefClk0P,
         gtClkN      => gtRefClk0N,
         gtRxP       => gtDataRxP,
         gtRxN       => gtDataRxN,
         gtTxP       => gtDataTxP,
         gtTxN       => gtDataTxN,
         -- Output reset
         pgpRst      => open,
         -- Output status
         rxLinkReady => rxLinkReady,
         txLinkReady => txLinkReady,
         -- Output clocking
         pgpClk      => coreClk,
         stableClk   => open,
         -- AXI clocking
         axiClk     => coreClk,--: in  sl;
         axiRst     => axiRst,--: in  sl
         -- Axi Master Interface - Registers (axiClk domain)
         mAxiLiteReadMaster  => sAxiReadMaster,--: out AxiLiteReadMasterType;
         mAxiLiteReadSlave   => sAxiReadSlave,--: in  AxiLiteReadSlaveType;
         mAxiLiteWriteMaster => sAxiWriteMaster,--: out AxiLiteWriteMasterType;
         mAxiLiteWriteSlave  => sAxiWriteSlave--: in  AxiLiteWriteSlaveType;
         -- -- Streaming data Links (axiClk domain)      
         -- userAxisMaster : in  AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
         -- userAxisSlave  : out AxiStreamSlaveType;
         -- -- Command interface
         -- ssiCmd         : out SsiCmdMasterType
      );

   --------------------------------------------
   -- AXI Lite Crossbar for register control --
   --------------------------------------------
   U_AxiLiteCrossbar : entity work.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         sAxiWriteMasters(0) => sAxiWriteMaster,
         sAxiWriteSlaves(0)  => sAxiWriteSlave,
         sAxiReadMasters(0)  => sAxiReadMaster,
         sAxiReadSlaves(0)   => sAxiReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves,
         axiClk              => coreClk,
         axiClkRst           => axiRst);
   
   --------------------------------------------
   --     AXI Lite Version Register          --
   --------------------------------------------   
   U_AxiVersion : entity work.AxiVersion
      generic map (
         EN_DEVICE_DNA_G => true
      )
      port map (
         axiReadMaster  => mAxiReadMasters(VERSION_AXI_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(VERSION_AXI_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(VERSION_AXI_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(VERSION_AXI_INDEX_C),
         axiClk         => coreClk,
         axiRst         => axiRst
      );    

   
end top_level;
