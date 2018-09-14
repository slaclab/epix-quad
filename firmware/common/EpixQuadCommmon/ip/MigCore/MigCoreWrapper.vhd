-------------------------------------------------------------------------------
-- File       : MigCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-21
-- Last update: 2017-10-05
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity MigCoreWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI Slave
      axiClk           : out   sl;
      axiRst           : out   sl;
      axiReadMaster    : in    AxiReadMasterType;
      axiReadSlave     : out   AxiReadSlaveType;
      axiWriteMaster   : in    AxiWriteMasterType;
      axiWriteSlave    : out   AxiWriteSlaveType;
      -- DDR PHY Ref clk
      c0_sys_clk_p     : in    sl;
      c0_sys_clk_n     : in    sl;
      -- DRR Memory interface ports
      sys_rst          : in    sl := '0';
      c0_ddr4_aresetn  : in    sl := '1';
      c0_ddr4_dq       : inout slv(15 downto 0);
      c0_ddr4_dqs_c    : inout slv(1 downto 0);
      c0_ddr4_dqs_t    : inout slv(1 downto 0);
      c0_ddr4_adr      : out   slv(16 downto 0);
      c0_ddr4_ba       : out   slv(1 downto 0);
      c0_ddr4_bg       : out   slv(0 to 0);
      c0_ddr4_reset_n  : out   sl;
      c0_ddr4_act_n    : out   sl;
      c0_ddr4_ck_t     : out   slv(0 to 0);
      c0_ddr4_ck_c     : out   slv(0 to 0);
      c0_ddr4_cke      : out   slv(0 to 0);
      c0_ddr4_cs_n     : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n : inout slv(1 downto 0);
      c0_ddr4_odt      : out   slv(0 to 0);
      calibComplete    : out   sl);
end MigCoreWrapper;

architecture mapping of MigCoreWrapper is
   
   COMPONENT MigCore
      PORT (
         c0_init_calib_complete : OUT STD_LOGIC;
         dbg_clk : OUT STD_LOGIC;
         c0_sys_clk_p : IN STD_LOGIC;
         c0_sys_clk_n : IN STD_LOGIC;
         dbg_bus : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
         c0_ddr4_adr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
         c0_ddr4_ba : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_cke : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_cs_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_dm_dbi_n : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_dq : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
         c0_ddr4_dqs_c : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_dqs_t : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_odt : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_bg : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_reset_n : OUT STD_LOGIC;
         c0_ddr4_act_n : OUT STD_LOGIC;
         c0_ddr4_ck_c : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_ck_t : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_ui_clk : OUT STD_LOGIC;
         c0_ddr4_ui_clk_sync_rst : OUT STD_LOGIC;
         c0_ddr4_aresetn : IN STD_LOGIC;
         c0_ddr4_s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_awaddr : IN STD_LOGIC_VECTOR(28 DOWNTO 0);
         c0_ddr4_s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         c0_ddr4_s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         c0_ddr4_s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_s_axi_awlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         c0_ddr4_s_axi_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_awvalid : IN STD_LOGIC;
         c0_ddr4_s_axi_awready : OUT STD_LOGIC;
         c0_ddr4_s_axi_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         c0_ddr4_s_axi_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         c0_ddr4_s_axi_wlast : IN STD_LOGIC;
         c0_ddr4_s_axi_wvalid : IN STD_LOGIC;
         c0_ddr4_s_axi_wready : OUT STD_LOGIC;
         c0_ddr4_s_axi_bready : IN STD_LOGIC;
         c0_ddr4_s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_s_axi_bvalid : OUT STD_LOGIC;
         c0_ddr4_s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_araddr : IN STD_LOGIC_VECTOR(28 DOWNTO 0);
         c0_ddr4_s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         c0_ddr4_s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         c0_ddr4_s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_s_axi_arlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         c0_ddr4_s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         c0_ddr4_s_axi_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_arvalid : IN STD_LOGIC;
         c0_ddr4_s_axi_arready : OUT STD_LOGIC;
         c0_ddr4_s_axi_rready : IN STD_LOGIC;
         c0_ddr4_s_axi_rlast : OUT STD_LOGIC;
         c0_ddr4_s_axi_rvalid : OUT STD_LOGIC;
         c0_ddr4_s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         c0_ddr4_s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         c0_ddr4_s_axi_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         sys_rst : IN STD_LOGIC
      );
   END COMPONENT;

   signal ddrClk  : sl              := '0';
   signal ddrRst  : sl              := '1';
   signal coreRst : slv(1 downto 0) := "11";

   signal ddrWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal ddrWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal ddrReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal ddrReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

begin

   axiClk <= ddrClk;
   axiRst <= ddrRst;

   ddrWriteMaster <= axiWriteMaster;
   axiWriteSlave  <= ddrWriteSlave;

   ddrReadMaster <= axiReadMaster;
   axiReadSlave  <= ddrReadSlave;

   process(ddrClk)
   begin
      if rising_edge(ddrClk) then
         ddrRst     <= coreRst(1) after TPD_G;  -- Register to help with timing
         coreRst(1) <= coreRst(0) after TPD_G;  -- Register to help with timing
      end if;
   end process;

   U_MigCore : MigCore
      port map (
         -- general signals
         c0_init_calib_complete  => calibComplete,
         dbg_clk                 => open,
         c0_sys_clk_p            => c0_sys_clk_p,
         c0_sys_clk_n            => c0_sys_clk_n,
         dbg_bus                 => open,
         sys_rst                 => sys_rst,
         c0_ddr4_ui_clk          => ddrClk,
         c0_ddr4_ui_clk_sync_rst => coreRst(0),
         c0_ddr4_aresetn         => c0_ddr4_aresetn,
         -- DDR4 signals
         c0_ddr4_adr             => c0_ddr4_adr,
         c0_ddr4_ba              => c0_ddr4_ba,
         c0_ddr4_cke             => c0_ddr4_cke,
         c0_ddr4_cs_n            => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n        => c0_ddr4_dm_dbi_n,
         c0_ddr4_dq              => c0_ddr4_dq,
         c0_ddr4_dqs_c           => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t           => c0_ddr4_dqs_t,
         c0_ddr4_odt             => c0_ddr4_odt,
         c0_ddr4_bg              => c0_ddr4_bg,
         c0_ddr4_reset_n         => c0_ddr4_reset_n,
         c0_ddr4_act_n           => c0_ddr4_act_n,
         c0_ddr4_ck_c            => c0_ddr4_ck_c,
         c0_ddr4_ck_t            => c0_ddr4_ck_t,
         -- Slave Interface Write Address Ports
         c0_ddr4_s_axi_awid      => ddrWriteMaster.awid(3 downto 0),
         c0_ddr4_s_axi_awaddr    => ddrWriteMaster.awaddr(28 downto 0),
         c0_ddr4_s_axi_awlen     => ddrWriteMaster.awlen,
         c0_ddr4_s_axi_awsize    => ddrWriteMaster.awsize,
         c0_ddr4_s_axi_awburst   => ddrWriteMaster.awburst,
         c0_ddr4_s_axi_awlock    => ddrWriteMaster.awlock(0 downto 0),
         c0_ddr4_s_axi_awcache   => ddrWriteMaster.awcache,
         c0_ddr4_s_axi_awprot    => ddrWriteMaster.awprot,
         c0_ddr4_s_axi_awqos     => ddrWriteMaster.awqos,
         c0_ddr4_s_axi_awvalid   => ddrWriteMaster.awvalid,
         c0_ddr4_s_axi_awready   => ddrWriteSlave.awready,
         -- Slave Interface Write Data Ports
         c0_ddr4_s_axi_wdata     => ddrWriteMaster.wdata(127 downto 0),
         c0_ddr4_s_axi_wstrb     => ddrWriteMaster.wstrb(15 downto 0),
         c0_ddr4_s_axi_wlast     => ddrWriteMaster.wlast,
         c0_ddr4_s_axi_wvalid    => ddrWriteMaster.wvalid,
         c0_ddr4_s_axi_wready    => ddrWriteSlave.wready,
         -- Slave Interface Write Response Ports
         c0_ddr4_s_axi_bid       => ddrWriteSlave.bid(3 downto 0),
         c0_ddr4_s_axi_bresp     => ddrWriteSlave.bresp,
         c0_ddr4_s_axi_bvalid    => ddrWriteSlave.bvalid,
         c0_ddr4_s_axi_bready    => ddrWriteMaster.bready,
         -- Slave Interface Read Address Ports
         c0_ddr4_s_axi_arid      => ddrReadMaster.arid(3 downto 0),
         c0_ddr4_s_axi_araddr    => ddrReadMaster.araddr(28 downto 0),
         c0_ddr4_s_axi_arlen     => ddrReadMaster.arlen,
         c0_ddr4_s_axi_arsize    => ddrReadMaster.arsize,
         c0_ddr4_s_axi_arburst   => ddrReadMaster.arburst,
         c0_ddr4_s_axi_arlock    => ddrReadMaster.arlock(0 downto 0),
         c0_ddr4_s_axi_arcache   => ddrReadMaster.arcache,
         c0_ddr4_s_axi_arprot    => ddrReadMaster.arprot,
         c0_ddr4_s_axi_arqos     => ddrReadMaster.arqos,
         c0_ddr4_s_axi_arvalid   => ddrReadMaster.arvalid,
         c0_ddr4_s_axi_arready   => ddrReadSlave.arready,
         -- Slave Interface Read Data Ports
         c0_ddr4_s_axi_rid       => ddrReadSlave.rid(3 downto 0),
         c0_ddr4_s_axi_rdata     => ddrReadSlave.rdata(127 downto 0),
         c0_ddr4_s_axi_rresp     => ddrReadSlave.rresp,
         c0_ddr4_s_axi_rlast     => ddrReadSlave.rlast,
         c0_ddr4_s_axi_rvalid    => ddrReadSlave.rvalid,
         c0_ddr4_s_axi_rready    => ddrReadMaster.rready
      );

end mapping;
