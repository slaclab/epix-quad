-------------------------------------------------------------------------------
-- File       : AxiIcWrapper.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-21
-- Last update: 2017-07-05
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

entity AxiIcWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI Slaves for image writers
      -- 128 Bit Data Bus
      -- 1 burst packet FIFOs
      axiImgClk            : in  sl;
      axiImgWriteMasters   : in  AxiWriteMasterArray(3 downto 0);
      axiImgWriteSlaves    : out AxiWriteSlaveArray(3 downto 0);
      
      -- AXI Slave for data readout
      -- 32 Bit Data Bus
      axiDoutClk           : in  sl;
      axiDoutReadMaster    : in  AxiReadMasterType;
      axiDoutReadSlave     : out AxiReadSlaveType;
      
      -- AXI Slave for memory tester (aximClk domain)
      -- 512 Bit Data Bus
      axiBistReadMaster    : in  AxiReadMasterType;
      axiBistReadSlave     : out AxiReadSlaveType;
      axiBistWriteMaster   : in  AxiWriteMasterType;
      axiBistWriteSlave    : out AxiWriteSlaveType;
      
      -- AXI Master
      -- 512 Bit Data Bus
      aximClk              : in  sl;
      aximRst              : in  sl;
      aximReadMaster       : out AxiReadMasterType;
      aximReadSlave        : in  AxiReadSlaveType;
      aximWriteMaster      : out AxiWriteMasterType;
      aximWriteSlave       : in  AxiWriteSlaveType
   );
end AxiIcWrapper;

architecture mapping of AxiIcWrapper is
   
   COMPONENT AxiInterconnect
      PORT (
         INTERCONNECT_ACLK : IN STD_LOGIC;
         INTERCONNECT_ARESETN : IN STD_LOGIC;
         S00_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S00_AXI_ACLK : IN STD_LOGIC;
         S00_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S00_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S00_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_AWLOCK : IN STD_LOGIC;
         S00_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_AWVALID : IN STD_LOGIC;
         S00_AXI_AWREADY : OUT STD_LOGIC;
         S00_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S00_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S00_AXI_WLAST : IN STD_LOGIC;
         S00_AXI_WVALID : IN STD_LOGIC;
         S00_AXI_WREADY : OUT STD_LOGIC;
         S00_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_BVALID : OUT STD_LOGIC;
         S00_AXI_BREADY : IN STD_LOGIC;
         S00_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S00_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S00_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_ARLOCK : IN STD_LOGIC;
         S00_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_ARVALID : IN STD_LOGIC;
         S00_AXI_ARREADY : OUT STD_LOGIC;
         S00_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S00_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_RLAST : OUT STD_LOGIC;
         S00_AXI_RVALID : OUT STD_LOGIC;
         S00_AXI_RREADY : IN STD_LOGIC;
         S01_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S01_AXI_ACLK : IN STD_LOGIC;
         S01_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S01_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S01_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_AWLOCK : IN STD_LOGIC;
         S01_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_AWVALID : IN STD_LOGIC;
         S01_AXI_AWREADY : OUT STD_LOGIC;
         S01_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S01_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S01_AXI_WLAST : IN STD_LOGIC;
         S01_AXI_WVALID : IN STD_LOGIC;
         S01_AXI_WREADY : OUT STD_LOGIC;
         S01_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_BVALID : OUT STD_LOGIC;
         S01_AXI_BREADY : IN STD_LOGIC;
         S01_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S01_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S01_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_ARLOCK : IN STD_LOGIC;
         S01_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_ARVALID : IN STD_LOGIC;
         S01_AXI_ARREADY : OUT STD_LOGIC;
         S01_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S01_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_RLAST : OUT STD_LOGIC;
         S01_AXI_RVALID : OUT STD_LOGIC;
         S01_AXI_RREADY : IN STD_LOGIC;
         S02_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S02_AXI_ACLK : IN STD_LOGIC;
         S02_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S02_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S02_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_AWLOCK : IN STD_LOGIC;
         S02_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_AWVALID : IN STD_LOGIC;
         S02_AXI_AWREADY : OUT STD_LOGIC;
         S02_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S02_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S02_AXI_WLAST : IN STD_LOGIC;
         S02_AXI_WVALID : IN STD_LOGIC;
         S02_AXI_WREADY : OUT STD_LOGIC;
         S02_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_BVALID : OUT STD_LOGIC;
         S02_AXI_BREADY : IN STD_LOGIC;
         S02_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S02_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S02_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_ARLOCK : IN STD_LOGIC;
         S02_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_ARVALID : IN STD_LOGIC;
         S02_AXI_ARREADY : OUT STD_LOGIC;
         S02_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S02_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_RLAST : OUT STD_LOGIC;
         S02_AXI_RVALID : OUT STD_LOGIC;
         S02_AXI_RREADY : IN STD_LOGIC;
         S03_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S03_AXI_ACLK : IN STD_LOGIC;
         S03_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S03_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S03_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_AWLOCK : IN STD_LOGIC;
         S03_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_AWVALID : IN STD_LOGIC;
         S03_AXI_AWREADY : OUT STD_LOGIC;
         S03_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S03_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S03_AXI_WLAST : IN STD_LOGIC;
         S03_AXI_WVALID : IN STD_LOGIC;
         S03_AXI_WREADY : OUT STD_LOGIC;
         S03_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_BVALID : OUT STD_LOGIC;
         S03_AXI_BREADY : IN STD_LOGIC;
         S03_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S03_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S03_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_ARLOCK : IN STD_LOGIC;
         S03_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_ARVALID : IN STD_LOGIC;
         S03_AXI_ARREADY : OUT STD_LOGIC;
         S03_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S03_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_RLAST : OUT STD_LOGIC;
         S03_AXI_RVALID : OUT STD_LOGIC;
         S03_AXI_RREADY : IN STD_LOGIC;
         S04_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S04_AXI_ACLK : IN STD_LOGIC;
         S04_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S04_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S04_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_AWLOCK : IN STD_LOGIC;
         S04_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_AWVALID : IN STD_LOGIC;
         S04_AXI_AWREADY : OUT STD_LOGIC;
         S04_AXI_WDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
         S04_AXI_WSTRB : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_WLAST : IN STD_LOGIC;
         S04_AXI_WVALID : IN STD_LOGIC;
         S04_AXI_WREADY : OUT STD_LOGIC;
         S04_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_BVALID : OUT STD_LOGIC;
         S04_AXI_BREADY : IN STD_LOGIC;
         S04_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S04_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S04_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_ARLOCK : IN STD_LOGIC;
         S04_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_ARVALID : IN STD_LOGIC;
         S04_AXI_ARREADY : OUT STD_LOGIC;
         S04_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_RDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
         S04_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_RLAST : OUT STD_LOGIC;
         S04_AXI_RVALID : OUT STD_LOGIC;
         S04_AXI_RREADY : IN STD_LOGIC;
         S05_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S05_AXI_ACLK : IN STD_LOGIC;
         S05_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S05_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S05_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_AWLOCK : IN STD_LOGIC;
         S05_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_AWVALID : IN STD_LOGIC;
         S05_AXI_AWREADY : OUT STD_LOGIC;
         S05_AXI_WDATA : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
         S05_AXI_WSTRB : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
         S05_AXI_WLAST : IN STD_LOGIC;
         S05_AXI_WVALID : IN STD_LOGIC;
         S05_AXI_WREADY : OUT STD_LOGIC;
         S05_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_BVALID : OUT STD_LOGIC;
         S05_AXI_BREADY : IN STD_LOGIC;
         S05_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S05_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S05_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_ARLOCK : IN STD_LOGIC;
         S05_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_ARVALID : IN STD_LOGIC;
         S05_AXI_ARREADY : OUT STD_LOGIC;
         S05_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_RDATA : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
         S05_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_RLAST : OUT STD_LOGIC;
         S05_AXI_RVALID : OUT STD_LOGIC;
         S05_AXI_RREADY : IN STD_LOGIC;
         M00_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         M00_AXI_ACLK : IN STD_LOGIC;
         M00_AXI_AWID : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_AWADDR : OUT STD_LOGIC_VECTOR(29 DOWNTO 0);
         M00_AXI_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
         M00_AXI_AWSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_AWBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_AWLOCK : OUT STD_LOGIC;
         M00_AXI_AWCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_AWQOS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_AWVALID : OUT STD_LOGIC;
         M00_AXI_AWREADY : IN STD_LOGIC;
         M00_AXI_WDATA : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
         M00_AXI_WSTRB : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
         M00_AXI_WLAST : OUT STD_LOGIC;
         M00_AXI_WVALID : OUT STD_LOGIC;
         M00_AXI_WREADY : IN STD_LOGIC;
         M00_AXI_BID : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_BVALID : IN STD_LOGIC;
         M00_AXI_BREADY : OUT STD_LOGIC;
         M00_AXI_ARID : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_ARADDR : OUT STD_LOGIC_VECTOR(29 DOWNTO 0);
         M00_AXI_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
         M00_AXI_ARSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_ARLOCK : OUT STD_LOGIC;
         M00_AXI_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_ARQOS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_ARVALID : OUT STD_LOGIC;
         M00_AXI_ARREADY : IN STD_LOGIC;
         M00_AXI_RID : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_RDATA : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
         M00_AXI_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_RLAST : IN STD_LOGIC;
         M00_AXI_RVALID : IN STD_LOGIC;
         M00_AXI_RREADY : OUT STD_LOGIC
      );
   END COMPONENT;
   
   
   
   signal aximRstN            : sl;
   
   -- AXI Interconnect RTL 1.7 generates ports for unused channels
   -- unused channels
   signal axiImgReadMasters   : AxiReadMasterArray(3 downto 0);
   signal axiImgReadSlaves    : AxiReadSlaveArray(3 downto 0);
   signal axiDoutWriteMaster  : AxiWriteMasterType;
   signal axiDoutWriteSlave   : AxiWriteSlaveType;

begin
   
   aximRstN <= not aximRst;
   
   -- AXI Interconnect RTL 1.7 generates ports for unused channels
   -- unused channels
   axiImgReadMasters    <= (others=>AXI_READ_MASTER_INIT_C);
   axiDoutWriteMaster   <= AXI_WRITE_MASTER_INIT_C;

   U_AxiInterconnect : AxiInterconnect
   PORT MAP (
      INTERCONNECT_ACLK       => aximClk,
      INTERCONNECT_ARESETN    => aximRstN,
      
      S00_AXI_ARESET_OUT_N    => open,
      S00_AXI_ACLK            => axiImgClk,
      S00_AXI_AWID            => axiImgWriteMasters(0).awid(0 downto 0),
      S00_AXI_AWADDR          => axiImgWriteMasters(0).awaddr(29 downto 0),
      S00_AXI_AWLEN           => axiImgWriteMasters(0).awlen,
      S00_AXI_AWSIZE          => axiImgWriteMasters(0).awsize,
      S00_AXI_AWBURST         => axiImgWriteMasters(0).awburst,
      S00_AXI_AWLOCK          => axiImgWriteMasters(0).awlock(0),
      S00_AXI_AWCACHE         => axiImgWriteMasters(0).awcache,
      S00_AXI_AWPROT          => axiImgWriteMasters(0).awprot,
      S00_AXI_AWQOS           => axiImgWriteMasters(0).awqos,
      S00_AXI_AWVALID         => axiImgWriteMasters(0).awvalid,
      S00_AXI_AWREADY         => axiImgWriteSlaves(0).awready,
      S00_AXI_WDATA           => axiImgWriteMasters(0).wdata(127 downto 0),
      S00_AXI_WSTRB           => axiImgWriteMasters(0).wstrb(15 downto 0),
      S00_AXI_WLAST           => axiImgWriteMasters(0).wlast,
      S00_AXI_WVALID          => axiImgWriteMasters(0).wvalid,
      S00_AXI_WREADY          => axiImgWriteSlaves(0).wready,
      S00_AXI_BID             => axiImgWriteSlaves(0).bid(0 downto 0),
      S00_AXI_BRESP           => axiImgWriteSlaves(0).bresp,
      S00_AXI_BVALID          => axiImgWriteSlaves(0).bvalid,
      S00_AXI_BREADY          => axiImgWriteMasters(0).bready,
      S00_AXI_ARID            => axiImgReadMasters(0).arid(0 downto 0),
      S00_AXI_ARADDR          => axiImgReadMasters(0).araddr(29 downto 0),
      S00_AXI_ARLEN           => axiImgReadMasters(0).arlen,
      S00_AXI_ARSIZE          => axiImgReadMasters(0).arsize,
      S00_AXI_ARBURST         => axiImgReadMasters(0).arburst,
      S00_AXI_ARLOCK          => axiImgReadMasters(0).arlock(0),
      S00_AXI_ARCACHE         => axiImgReadMasters(0).arcache,
      S00_AXI_ARPROT          => axiImgReadMasters(0).arprot,
      S00_AXI_ARQOS           => axiImgReadMasters(0).arqos,
      S00_AXI_ARVALID         => axiImgReadMasters(0).arvalid,
      S00_AXI_ARREADY         => axiImgReadSlaves(0).arready,
      S00_AXI_RID             => axiImgReadSlaves(0).rid(0 downto 0),
      S00_AXI_RDATA           => axiImgReadSlaves(0).rdata(127 downto 0),
      S00_AXI_RRESP           => axiImgReadSlaves(0).rresp,
      S00_AXI_RLAST           => axiImgReadSlaves(0).rlast,
      S00_AXI_RVALID          => axiImgReadSlaves(0).rvalid,
      S00_AXI_RREADY          => axiImgReadMasters(0).rready,
      
      S01_AXI_ARESET_OUT_N    => open,
      S01_AXI_ACLK            => axiImgClk,
      S01_AXI_AWID            => axiImgWriteMasters(1).awid(0 downto 0),
      S01_AXI_AWADDR          => axiImgWriteMasters(1).awaddr(29 downto 0),
      S01_AXI_AWLEN           => axiImgWriteMasters(1).awlen,
      S01_AXI_AWSIZE          => axiImgWriteMasters(1).awsize,
      S01_AXI_AWBURST         => axiImgWriteMasters(1).awburst,
      S01_AXI_AWLOCK          => axiImgWriteMasters(1).awlock(0),
      S01_AXI_AWCACHE         => axiImgWriteMasters(1).awcache,
      S01_AXI_AWPROT          => axiImgWriteMasters(1).awprot,
      S01_AXI_AWQOS           => axiImgWriteMasters(1).awqos,
      S01_AXI_AWVALID         => axiImgWriteMasters(1).awvalid,
      S01_AXI_AWREADY         => axiImgWriteSlaves(1).awready,
      S01_AXI_WDATA           => axiImgWriteMasters(1).wdata(127 downto 0),
      S01_AXI_WSTRB           => axiImgWriteMasters(1).wstrb(15 downto 0),
      S01_AXI_WLAST           => axiImgWriteMasters(1).wlast,
      S01_AXI_WVALID          => axiImgWriteMasters(1).wvalid,
      S01_AXI_WREADY          => axiImgWriteSlaves(1).wready,
      S01_AXI_BID             => axiImgWriteSlaves(1).bid(0 downto 0),
      S01_AXI_BRESP           => axiImgWriteSlaves(1).bresp,
      S01_AXI_BVALID          => axiImgWriteSlaves(1).bvalid,
      S01_AXI_BREADY          => axiImgWriteMasters(1).bready,
      S01_AXI_ARID            => axiImgReadMasters(1).arid(0 downto 0),
      S01_AXI_ARADDR          => axiImgReadMasters(1).araddr(29 downto 0),
      S01_AXI_ARLEN           => axiImgReadMasters(1).arlen,
      S01_AXI_ARSIZE          => axiImgReadMasters(1).arsize,
      S01_AXI_ARBURST         => axiImgReadMasters(1).arburst,
      S01_AXI_ARLOCK          => axiImgReadMasters(1).arlock(0),
      S01_AXI_ARCACHE         => axiImgReadMasters(1).arcache,
      S01_AXI_ARPROT          => axiImgReadMasters(1).arprot,
      S01_AXI_ARQOS           => axiImgReadMasters(1).arqos,
      S01_AXI_ARVALID         => axiImgReadMasters(1).arvalid,
      S01_AXI_ARREADY         => axiImgReadSlaves(1).arready,
      S01_AXI_RID             => axiImgReadSlaves(1).rid(0 downto 0),
      S01_AXI_RDATA           => axiImgReadSlaves(1).rdata(127 downto 0),
      S01_AXI_RRESP           => axiImgReadSlaves(1).rresp,
      S01_AXI_RLAST           => axiImgReadSlaves(1).rlast,
      S01_AXI_RVALID          => axiImgReadSlaves(1).rvalid,
      S01_AXI_RREADY          => axiImgReadMasters(1).rready,
      
      S02_AXI_ARESET_OUT_N    => open,
      S02_AXI_ACLK            => axiImgClk,
      S02_AXI_AWID            => axiImgWriteMasters(2).awid(0 downto 0),
      S02_AXI_AWADDR          => axiImgWriteMasters(2).awaddr(29 downto 0),
      S02_AXI_AWLEN           => axiImgWriteMasters(2).awlen,
      S02_AXI_AWSIZE          => axiImgWriteMasters(2).awsize,
      S02_AXI_AWBURST         => axiImgWriteMasters(2).awburst,
      S02_AXI_AWLOCK          => axiImgWriteMasters(2).awlock(0),
      S02_AXI_AWCACHE         => axiImgWriteMasters(2).awcache,
      S02_AXI_AWPROT          => axiImgWriteMasters(2).awprot,
      S02_AXI_AWQOS           => axiImgWriteMasters(2).awqos,
      S02_AXI_AWVALID         => axiImgWriteMasters(2).awvalid,
      S02_AXI_AWREADY         => axiImgWriteSlaves(2).awready,
      S02_AXI_WDATA           => axiImgWriteMasters(2).wdata(127 downto 0),
      S02_AXI_WSTRB           => axiImgWriteMasters(2).wstrb(15 downto 0),
      S02_AXI_WLAST           => axiImgWriteMasters(2).wlast,
      S02_AXI_WVALID          => axiImgWriteMasters(2).wvalid,
      S02_AXI_WREADY          => axiImgWriteSlaves(2).wready,
      S02_AXI_BID             => axiImgWriteSlaves(2).bid(0 downto 0),
      S02_AXI_BRESP           => axiImgWriteSlaves(2).bresp,
      S02_AXI_BVALID          => axiImgWriteSlaves(2).bvalid,
      S02_AXI_BREADY          => axiImgWriteMasters(2).bready,
      S02_AXI_ARID            => axiImgReadMasters(2).arid(0 downto 0),
      S02_AXI_ARADDR          => axiImgReadMasters(2).araddr(29 downto 0),
      S02_AXI_ARLEN           => axiImgReadMasters(2).arlen,
      S02_AXI_ARSIZE          => axiImgReadMasters(2).arsize,
      S02_AXI_ARBURST         => axiImgReadMasters(2).arburst,
      S02_AXI_ARLOCK          => axiImgReadMasters(2).arlock(0),
      S02_AXI_ARCACHE         => axiImgReadMasters(2).arcache,
      S02_AXI_ARPROT          => axiImgReadMasters(2).arprot,
      S02_AXI_ARQOS           => axiImgReadMasters(2).arqos,
      S02_AXI_ARVALID         => axiImgReadMasters(2).arvalid,
      S02_AXI_ARREADY         => axiImgReadSlaves(2).arready,
      S02_AXI_RID             => axiImgReadSlaves(2).rid(0 downto 0),
      S02_AXI_RDATA           => axiImgReadSlaves(2).rdata(127 downto 0),
      S02_AXI_RRESP           => axiImgReadSlaves(2).rresp,
      S02_AXI_RLAST           => axiImgReadSlaves(2).rlast,
      S02_AXI_RVALID          => axiImgReadSlaves(2).rvalid,
      S02_AXI_RREADY          => axiImgReadMasters(2).rready,
      
      S03_AXI_ARESET_OUT_N    => open,
      S03_AXI_ACLK            => axiImgClk,
      S03_AXI_AWID            => axiImgWriteMasters(3).awid(0 downto 0),
      S03_AXI_AWADDR          => axiImgWriteMasters(3).awaddr(29 downto 0),
      S03_AXI_AWLEN           => axiImgWriteMasters(3).awlen,
      S03_AXI_AWSIZE          => axiImgWriteMasters(3).awsize,
      S03_AXI_AWBURST         => axiImgWriteMasters(3).awburst,
      S03_AXI_AWLOCK          => axiImgWriteMasters(3).awlock(0),
      S03_AXI_AWCACHE         => axiImgWriteMasters(3).awcache,
      S03_AXI_AWPROT          => axiImgWriteMasters(3).awprot,
      S03_AXI_AWQOS           => axiImgWriteMasters(3).awqos,
      S03_AXI_AWVALID         => axiImgWriteMasters(3).awvalid,
      S03_AXI_AWREADY         => axiImgWriteSlaves(3).awready,
      S03_AXI_WDATA           => axiImgWriteMasters(3).wdata(127 downto 0),
      S03_AXI_WSTRB           => axiImgWriteMasters(3).wstrb(15 downto 0),
      S03_AXI_WLAST           => axiImgWriteMasters(3).wlast,
      S03_AXI_WVALID          => axiImgWriteMasters(3).wvalid,
      S03_AXI_WREADY          => axiImgWriteSlaves(3).wready,
      S03_AXI_BID             => axiImgWriteSlaves(3).bid(0 downto 0),
      S03_AXI_BRESP           => axiImgWriteSlaves(3).bresp,
      S03_AXI_BVALID          => axiImgWriteSlaves(3).bvalid,
      S03_AXI_BREADY          => axiImgWriteMasters(3).bready,
      S03_AXI_ARID            => axiImgReadMasters(3).arid(0 downto 0),
      S03_AXI_ARADDR          => axiImgReadMasters(3).araddr(29 downto 0),
      S03_AXI_ARLEN           => axiImgReadMasters(3).arlen,
      S03_AXI_ARSIZE          => axiImgReadMasters(3).arsize,
      S03_AXI_ARBURST         => axiImgReadMasters(3).arburst,
      S03_AXI_ARLOCK          => axiImgReadMasters(3).arlock(0),
      S03_AXI_ARCACHE         => axiImgReadMasters(3).arcache,
      S03_AXI_ARPROT          => axiImgReadMasters(3).arprot,
      S03_AXI_ARQOS           => axiImgReadMasters(3).arqos,
      S03_AXI_ARVALID         => axiImgReadMasters(3).arvalid,
      S03_AXI_ARREADY         => axiImgReadSlaves(3).arready,
      S03_AXI_RID             => axiImgReadSlaves(3).rid(0 downto 0),
      S03_AXI_RDATA           => axiImgReadSlaves(3).rdata(127 downto 0),
      S03_AXI_RRESP           => axiImgReadSlaves(3).rresp,
      S03_AXI_RLAST           => axiImgReadSlaves(3).rlast,
      S03_AXI_RVALID          => axiImgReadSlaves(3).rvalid,
      S03_AXI_RREADY          => axiImgReadMasters(3).rready,
      
      S04_AXI_ARESET_OUT_N    => open,
      S04_AXI_ACLK            => axiDoutClk,
      S04_AXI_AWID            => axiDoutWriteMaster.awid(0 downto 0),
      S04_AXI_AWADDR          => axiDoutWriteMaster.awaddr(29 downto 0),
      S04_AXI_AWLEN           => axiDoutWriteMaster.awlen,
      S04_AXI_AWSIZE          => axiDoutWriteMaster.awsize,
      S04_AXI_AWBURST         => axiDoutWriteMaster.awburst,
      S04_AXI_AWLOCK          => axiDoutWriteMaster.awlock(0),
      S04_AXI_AWCACHE         => axiDoutWriteMaster.awcache,
      S04_AXI_AWPROT          => axiDoutWriteMaster.awprot,
      S04_AXI_AWQOS           => axiDoutWriteMaster.awqos,
      S04_AXI_AWVALID         => axiDoutWriteMaster.awvalid,
      S04_AXI_AWREADY         => axiDoutWriteSlave.awready,
      S04_AXI_WDATA           => axiDoutWriteMaster.wdata(31 downto 0),
      S04_AXI_WSTRB           => axiDoutWriteMaster.wstrb(3 downto 0),
      S04_AXI_WLAST           => axiDoutWriteMaster.wlast,
      S04_AXI_WVALID          => axiDoutWriteMaster.wvalid,
      S04_AXI_WREADY          => axiDoutWriteSlave.wready,
      S04_AXI_BID             => axiDoutWriteSlave.bid(0 downto 0),
      S04_AXI_BRESP           => axiDoutWriteSlave.bresp,
      S04_AXI_BVALID          => axiDoutWriteSlave.bvalid,
      S04_AXI_BREADY          => axiDoutWriteMaster.bready,
      S04_AXI_ARID            => axiDoutReadMaster.arid(0 downto 0),
      S04_AXI_ARADDR          => axiDoutReadMaster.araddr(29 downto 0),
      S04_AXI_ARLEN           => axiDoutReadMaster.arlen,
      S04_AXI_ARSIZE          => axiDoutReadMaster.arsize,
      S04_AXI_ARBURST         => axiDoutReadMaster.arburst,
      S04_AXI_ARLOCK          => axiDoutReadMaster.arlock(0),
      S04_AXI_ARCACHE         => axiDoutReadMaster.arcache,
      S04_AXI_ARPROT          => axiDoutReadMaster.arprot,
      S04_AXI_ARQOS           => axiDoutReadMaster.arqos,
      S04_AXI_ARVALID         => axiDoutReadMaster.arvalid,
      S04_AXI_ARREADY         => axiDoutReadSlave.arready,
      S04_AXI_RID             => axiDoutReadSlave.rid(0 downto 0),
      S04_AXI_RDATA           => axiDoutReadSlave.rdata(31 downto 0),
      S04_AXI_RRESP           => axiDoutReadSlave.rresp,
      S04_AXI_RLAST           => axiDoutReadSlave.rlast,
      S04_AXI_RVALID          => axiDoutReadSlave.rvalid,
      S04_AXI_RREADY          => axiDoutReadMaster.rready,
      
      S05_AXI_ARESET_OUT_N    => open,
      S05_AXI_ACLK            => aximClk,
      S05_AXI_AWID            => axiBistWriteMaster.awid(0 downto 0),
      S05_AXI_AWADDR          => axiBistWriteMaster.awaddr(29 downto 0),
      S05_AXI_AWLEN           => axiBistWriteMaster.awlen,
      S05_AXI_AWSIZE          => axiBistWriteMaster.awsize,
      S05_AXI_AWBURST         => axiBistWriteMaster.awburst,
      S05_AXI_AWLOCK          => axiBistWriteMaster.awlock(0),
      S05_AXI_AWCACHE         => axiBistWriteMaster.awcache,
      S05_AXI_AWPROT          => axiBistWriteMaster.awprot,
      S05_AXI_AWQOS           => axiBistWriteMaster.awqos,
      S05_AXI_AWVALID         => axiBistWriteMaster.awvalid,
      S05_AXI_AWREADY         => axiBistWriteSlave.awready,
      S05_AXI_WDATA           => axiBistWriteMaster.wdata(255 downto 0),
      S05_AXI_WSTRB           => axiBistWriteMaster.wstrb(31 downto 0),
      S05_AXI_WLAST           => axiBistWriteMaster.wlast,
      S05_AXI_WVALID          => axiBistWriteMaster.wvalid,
      S05_AXI_WREADY          => axiBistWriteSlave.wready,
      S05_AXI_BID             => axiBistWriteSlave.bid(0 downto 0),
      S05_AXI_BRESP           => axiBistWriteSlave.bresp,
      S05_AXI_BVALID          => axiBistWriteSlave.bvalid,
      S05_AXI_BREADY          => axiBistWriteMaster.bready,
      S05_AXI_ARID            => axiBistReadMaster.arid(0 downto 0),
      S05_AXI_ARADDR          => axiBistReadMaster.araddr(29 downto 0),
      S05_AXI_ARLEN           => axiBistReadMaster.arlen,
      S05_AXI_ARSIZE          => axiBistReadMaster.arsize,
      S05_AXI_ARBURST         => axiBistReadMaster.arburst,
      S05_AXI_ARLOCK          => axiBistReadMaster.arlock(0),
      S05_AXI_ARCACHE         => axiBistReadMaster.arcache,
      S05_AXI_ARPROT          => axiBistReadMaster.arprot,
      S05_AXI_ARQOS           => axiBistReadMaster.arqos,
      S05_AXI_ARVALID         => axiBistReadMaster.arvalid,
      S05_AXI_ARREADY         => axiBistReadSlave.arready,
      S05_AXI_RID             => axiBistReadSlave.rid(0 downto 0),
      S05_AXI_RDATA           => axiBistReadSlave.rdata(255 downto 0),
      S05_AXI_RRESP           => axiBistReadSlave.rresp,
      S05_AXI_RLAST           => axiBistReadSlave.rlast,
      S05_AXI_RVALID          => axiBistReadSlave.rvalid,
      S05_AXI_RREADY          => axiBistReadMaster.rready,
      
      M00_AXI_ARESET_OUT_N    => open,
      M00_AXI_ACLK            => aximClk,
      M00_AXI_AWID            => aximWriteMaster.awid(3 downto 0),
      M00_AXI_AWADDR          => aximWriteMaster.awaddr(29 downto 0),
      M00_AXI_AWLEN           => aximWriteMaster.awlen,
      M00_AXI_AWSIZE          => aximWriteMaster.awsize,
      M00_AXI_AWBURST         => aximWriteMaster.awburst,
      M00_AXI_AWLOCK          => aximWriteMaster.awlock(0),
      M00_AXI_AWCACHE         => aximWriteMaster.awcache,
      M00_AXI_AWPROT          => aximWriteMaster.awprot,
      M00_AXI_AWQOS           => aximWriteMaster.awqos,
      M00_AXI_AWVALID         => aximWriteMaster.awvalid,
      M00_AXI_AWREADY         => aximWriteSlave.awready,
      M00_AXI_WDATA           => aximWriteMaster.wdata(255 downto 0),
      M00_AXI_WSTRB           => aximWriteMaster.wstrb(31 downto 0),
      M00_AXI_WLAST           => aximWriteMaster.wlast,
      M00_AXI_WVALID          => aximWriteMaster.wvalid,
      M00_AXI_WREADY          => aximWriteSlave.wready,
      M00_AXI_BID             => aximWriteSlave.bid(3 downto 0),
      M00_AXI_BRESP           => aximWriteSlave.bresp,
      M00_AXI_BVALID          => aximWriteSlave.bvalid,
      M00_AXI_BREADY          => aximWriteMaster.bready,
      M00_AXI_ARID            => aximReadMaster.arid(3 downto 0),
      M00_AXI_ARADDR          => aximReadMaster.araddr(29 downto 0),
      M00_AXI_ARLEN           => aximReadMaster.arlen,
      M00_AXI_ARSIZE          => aximReadMaster.arsize,
      M00_AXI_ARBURST         => aximReadMaster.arburst,
      M00_AXI_ARLOCK          => aximReadMaster.arlock(0),
      M00_AXI_ARCACHE         => aximReadMaster.arcache,
      M00_AXI_ARPROT          => aximReadMaster.arprot,
      M00_AXI_ARQOS           => aximReadMaster.arqos,
      M00_AXI_ARVALID         => aximReadMaster.arvalid,
      M00_AXI_ARREADY         => aximReadSlave.arready,
      M00_AXI_RID             => aximReadSlave.rid(3 downto 0),
      M00_AXI_RDATA           => aximReadSlave.rdata(255 downto 0),
      M00_AXI_RRESP           => aximReadSlave.rresp,
      M00_AXI_RLAST           => aximReadSlave.rlast,
      M00_AXI_RVALID          => aximReadSlave.rvalid,
      M00_AXI_RREADY          => aximReadMaster.rready
   );

end mapping;
