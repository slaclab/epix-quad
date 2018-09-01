-------------------------------------------------------------------------------
-- File       : AsicCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-10
-------------------------------------------------------------------------------
-- Description: EPIX Quad Target's Top Level
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AsicCore is
   generic (
      TPD_G                : time             := 1 ns;
      AXI_BASE_ADDR_G      : slv(31 downto 0) := (others => '0')
   );
   port (
      -- Clock and Reset
      sysClk               : in    sl;
      sysRst               : in    sl;
      -- AXI-Lite Register Interface (sysClk domain)
      mAxilReadMaster      : in    AxiLiteReadMasterType;
      mAxilReadSlave       : out   AxiLiteReadSlaveType;
      mAxilWriteMaster     : in    AxiLiteWriteMasterType;
      mAxilWriteSlave      : out   AxiLiteWriteSlaveType;
      -- ASIC SACI signals
      asicSaciResp         : in    slv(3 downto 0);
      asicSaciClk          : out   slv(3 downto 0);
      asicSaciCmd          : out   slv(3 downto 0);
      asicSaciSelL         : out   slv(15 downto 0);
      -- ASIC ACQ signals
      asicAcq              : out   sl;
      asicR0               : out   sl;
      asicGr               : out   sl;
      asicSync             : out   sl;
      asicPpmat            : out   sl;
      asicRoClk            : out   sl;
      asicDout             : in    slv(15 downto 0)
   );
end AsicCore;

architecture rtl of AsicCore is
   
   constant SACI_CLK_PERIOD_C    : real := 1.00E-6;
   
   constant NUM_AXI_MASTERS_C    : natural := 4;

   constant ASIC_SACI0_INDEX_C   : natural := 0;
   constant ASIC_SACI1_INDEX_C   : natural := 1;
   constant ASIC_SACI2_INDEX_C   : natural := 2;
   constant ASIC_SACI3_INDEX_C   : natural := 3;

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

begin
   
   asicAcq              <= '0';
   asicR0               <= '0';
   asicGr               <= '0';
   asicSync             <= '0';
   asicPpmat            <= '0';
   asicRoClk            <= '0';
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C
      )
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => mAxilWriteMaster,
         sAxiWriteSlaves(0)  => mAxilWriteSlave,
         sAxiReadMasters(0)  => mAxilReadMaster,
         sAxiReadSlaves(0)   => mAxilReadSlave,

         mAxiWriteMasters => axilWriteMasters,
         mAxiWriteSlaves  => axilWriteSlaves,
         mAxiReadMasters  => axilReadMasters,
         mAxiReadSlaves   => axilReadSlaves
      );

   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   GEN_VEC4 : for i in 3 downto 0 generate
      U_AxiLiteSaciMaster : entity work.AxiLiteSaciMaster
         generic map (
            AXIL_CLK_PERIOD_G  => 10.0E-9, -- In units of seconds
            AXIL_TIMEOUT_G     => 1.0E-3,  -- In units of seconds
            SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_C, -- In units of seconds
            SACI_CLK_FREERUN_G => false,
            SACI_RSP_BUSSED_G  => true,
            SACI_NUM_CHIPS_G   => 4)
         port map (
            -- SACI interface
            saciClk           => asicSaciClk(i),
            saciCmd           => asicSaciCmd(i),
            saciSelL          => asicSaciSelL(i*4+3 downto i*4),
            saciRsp(0)        => asicSaciResp(i),
            -- AXI-Lite Register Interface
            axilClk           => sysClk,
            axilRst           => sysRst,
            axilReadMaster    => axilReadMasters(ASIC_SACI0_INDEX_C+i),
            axilReadSlave     => axilReadSlaves(ASIC_SACI0_INDEX_C+i),
            axilWriteMaster   => axilWriteMasters(ASIC_SACI0_INDEX_C+i),
            axilWriteSlave    => axilWriteSlaves(ASIC_SACI0_INDEX_C+i)
         );
   end generate GEN_VEC4;

end rtl;
