-------------------------------------------------------------------------------
-- Title      : Wrapper of the DDR Controller IP core
-- Project    : EPIX Detector
-------------------------------------------------------------------------------
-- File       : AxiDdrControllerWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

entity AxiDdrControllerWrapper is 
   port (

      -- AXI Slave     
      axiReadMaster     : in    AxiReadMasterType;
      axiReadSlave      : out   AxiReadSlaveType;
      axiWriteMaster    : in    AxiWriteMasterType;
      axiWriteSlave     : out   AxiWriteSlaveType;
      
      -- DDR PHY Ref clk
      sysClk            : in    sl;
      dlyClk            : in    sl;
      
      -- DDR clock from the DDR controller core
      ddrClk            : out   sl;
      ddrRst            : out   sl;

      -- DRR Memory interface ports
      ddr3_dq           : inout slv(31 downto 0);
      ddr3_dqs_n        : inout slv(3 downto 0);
      ddr3_dqs_p        : inout slv(3 downto 0);
      ddr3_addr         : out   slv(14 downto 0);
      ddr3_ba           : out   slv(2 downto 0);
      ddr3_ras_n        : out   sl;
      ddr3_cas_n        : out   sl;
      ddr3_we_n         : out   sl;
      ddr3_reset_n      : out   sl;
      ddr3_ck_p         : out   slv(0 to 0);
      ddr3_ck_n         : out   slv(0 to 0);
      ddr3_cke          : out   slv(0 to 0);
      ddr3_cs_n         : out   slv(0 to 0);
      ddr3_dm           : out   slv(3 downto 0);
      ddr3_odt          : out   slv(0 to 0);
      calibComplete     : out   sl
   );
end AxiDdrControllerWrapper;


-- Define architecture
architecture RTL of AxiDdrControllerWrapper is


   component AxiDdrCtrl is
   Port ( 
      ddr3_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
      ddr3_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
      ddr3_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
      ddr3_addr : out STD_LOGIC_VECTOR ( 14 downto 0 );
      ddr3_ba : out STD_LOGIC_VECTOR ( 2 downto 0 );
      ddr3_ras_n : out STD_LOGIC;
      ddr3_cas_n : out STD_LOGIC;
      ddr3_we_n : out STD_LOGIC;
      ddr3_reset_n : out STD_LOGIC;
      ddr3_ck_p : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_ck_n : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_cke : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_cs_n : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr3_dm : out STD_LOGIC_VECTOR ( 3 downto 0 );
      ddr3_odt : out STD_LOGIC_VECTOR ( 0 to 0 );
      sys_clk_i : in STD_LOGIC;
      clk_ref_i : in STD_LOGIC;
      ui_clk : out STD_LOGIC;
      ui_clk_sync_rst : out STD_LOGIC;
      mmcm_locked : out STD_LOGIC;
      aresetn : in STD_LOGIC;
      app_sr_req : in STD_LOGIC;
      app_ref_req : in STD_LOGIC;
      app_zq_req : in STD_LOGIC;
      app_sr_active : out STD_LOGIC;
      app_ref_ack : out STD_LOGIC;
      app_zq_ack : out STD_LOGIC;
      s_axi_awid : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awaddr : in STD_LOGIC_VECTOR ( 29 downto 0 );
      s_axi_awlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
      s_axi_awsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_awburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_awlock : in STD_LOGIC_VECTOR ( 0 to 0 );
      s_axi_awcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_awqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awvalid : in STD_LOGIC;
      s_axi_awready : out STD_LOGIC;
      s_axi_wdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
      s_axi_wstrb : in STD_LOGIC_VECTOR ( 15 downto 0 );
      s_axi_wlast : in STD_LOGIC;
      s_axi_wvalid : in STD_LOGIC;
      s_axi_wready : out STD_LOGIC;
      s_axi_bready : in STD_LOGIC;
      s_axi_bid : out STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_bvalid : out STD_LOGIC;
      s_axi_arid : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_araddr : in STD_LOGIC_VECTOR ( 29 downto 0 );
      s_axi_arlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
      s_axi_arsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_arburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_arlock : in STD_LOGIC_VECTOR ( 0 to 0 );
      s_axi_arcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_arqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_arvalid : in STD_LOGIC;
      s_axi_arready : out STD_LOGIC;
      s_axi_rready : in STD_LOGIC;
      s_axi_rid : out STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_rdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
      s_axi_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_rlast : out STD_LOGIC;
      s_axi_rvalid : out STD_LOGIC;
      init_calib_complete : out STD_LOGIC;
      device_temp : out STD_LOGIC_VECTOR ( 11 downto 0 );
      sys_rst : in STD_LOGIC
   );
   end component;
   
   signal sysClkRst : sl;

begin


   U_AxiDdrCtrl : AxiDdrCtrl
   port map (
      ddr3_addr            => ddr3_addr   ,
      ddr3_ba              => ddr3_ba     ,
      ddr3_cas_n           => ddr3_cas_n  ,
      ddr3_ck_n            => ddr3_ck_n   ,
      ddr3_ck_p            => ddr3_ck_p   ,
      ddr3_cke             => ddr3_cke    ,
      ddr3_ras_n           => ddr3_ras_n  ,
      ddr3_reset_n         => ddr3_reset_n,
      ddr3_we_n            => ddr3_we_n   ,
      ddr3_dq              => ddr3_dq     ,
      ddr3_dqs_n           => ddr3_dqs_n  ,
      ddr3_dqs_p           => ddr3_dqs_p  ,
      ddr3_cs_n            => ddr3_cs_n   ,
      ddr3_dm              => ddr3_dm     ,
      ddr3_odt             => ddr3_odt    ,
      sys_clk_i            => sysClk,
      sys_rst              => sysClkRst,
      clk_ref_i            => dlyClk,
      ui_clk               => ddrClk,
      ui_clk_sync_rst      => ddrRst,
      mmcm_locked          => open,
      aresetn              => '1',
      app_sr_req           => '0',
      app_ref_req          => '0',
      app_zq_req           => '0',
      app_sr_active        => open,
      app_ref_ack          => open,
      app_zq_ack           => open,
      init_calib_complete  => calibComplete,
      device_temp          => open,
      -- Slave Interface Write Address Ports
      s_axi_awid           => axiWriteMaster.awid(3 downto 0),
      s_axi_awaddr         => axiWriteMaster.awaddr(29 downto 0),
      s_axi_awlen          => axiWriteMaster.awlen,
      s_axi_awsize         => axiWriteMaster.awsize,
      s_axi_awburst        => axiWriteMaster.awburst,
      s_axi_awlock         => axiWriteMaster.awlock(0 downto 0),
      s_axi_awcache        => axiWriteMaster.awcache,
      s_axi_awprot         => axiWriteMaster.awprot,
      s_axi_awqos          => axiWriteMaster.awqos,
      s_axi_awvalid        => axiWriteMaster.awvalid,
      s_axi_awready        => axiWriteSlave.awready,
      -- Slave Interface Write Data Ports
      s_axi_wdata          => axiWriteMaster.wdata(127 downto 0),
      s_axi_wstrb          => axiWriteMaster.wstrb(15 downto 0),
      s_axi_wlast          => axiWriteMaster.wlast,
      s_axi_wvalid         => axiWriteMaster.wvalid,
      s_axi_wready         => axiWriteSlave.wready,
      -- Slave Interface Write Response Ports
      s_axi_bid            => axiWriteSlave.bid(3 downto 0),
      s_axi_bresp          => axiWriteSlave.bresp,
      s_axi_bvalid         => axiWriteSlave.bvalid,
      s_axi_bready         => axiWriteMaster.bready,
      -- Slave Interface Read Address Ports
      s_axi_arid           => axiReadMaster.arid(3 downto 0),
      s_axi_araddr         => axiReadMaster.araddr(29 downto 0),
      s_axi_arlen          => axiReadMaster.arlen,
      s_axi_arsize         => axiReadMaster.arsize,
      s_axi_arburst        => axiReadMaster.arburst,
      s_axi_arlock         => axiReadMaster.arlock(0 downto 0),
      s_axi_arcache        => axiReadMaster.arcache,
      s_axi_arprot         => axiReadMaster.arprot,
      s_axi_arqos          => axiReadMaster.arqos,
      s_axi_arvalid        => axiReadMaster.arvalid,
      s_axi_arready        => axiReadSlave.arready,
      -- Slave Interface Read Data Ports
      s_axi_rid            => axiReadSlave.rid(3 downto 0),
      s_axi_rdata          => axiReadSlave.rdata(127 downto 0),
      s_axi_rresp          => axiReadSlave.rresp,
      s_axi_rlast          => axiReadSlave.rlast,
      s_axi_rvalid         => axiReadSlave.rvalid,
      s_axi_rready         => axiReadMaster.rready
   );
   
   
   U_PwrUpRst : entity surf.PwrUpRst
   port map (
      clk    => sysClk,
      rstOut => sysClkRst
   );
   
   

end RTL;

