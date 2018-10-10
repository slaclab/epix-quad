-------------------------------------------------------------------------------
-- File       : SystemCore.vhd
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
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.I2cPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SystemCore is
   generic (
      TPD_G                : time             := 1 ns;
      BUILD_INFO_G         : BuildInfoType;
      AXI_CLK_FREQ_G       : real             := 100.00E+6;
      SIMULATION_G         : boolean          := false;
      SIM_SPEEDUP_G        : boolean          := false;
      AXI_BASE_ADDR_G      : slv(31 downto 0) := (others => '0');
      MIG_CORE_EN          : boolean          := true
   );
   port (
      -- Clock and Reset
      sysClk               : in    sl;
      sysRst               : in    sl;
      -- ADC ISERDESE reset
      adcClkRst            : out   slv(9 downto 0);
      -- ADC Startup Signals
      adcReqStart          : out   sl;
      adcReqTest           : out   sl;
      -- I2C busses
      dacScl               : inout sl;
      dacSda               : inout sl;
      monScl               : inout sl;
      monSda               : inout sl;
      humScl               : inout sl;
      humSda               : inout sl;
      humRstN              : out   sl;
      humAlert             : in    sl;
      -- DDR PHY Ref clk
      c0_sys_clk_p         : in    sl;
      c0_sys_clk_n         : in    sl;
      c0_ddr4_dq           : inout slv(15 downto 0);
      c0_ddr4_dqs_c        : inout slv(1 downto 0);
      c0_ddr4_dqs_t        : inout slv(1 downto 0);
      c0_ddr4_adr          : out   slv(16 downto 0);
      c0_ddr4_ba           : out   slv(1 downto 0);
      c0_ddr4_bg           : out   slv(0 to 0);
      c0_ddr4_reset_n      : out   sl;
      c0_ddr4_act_n        : out   sl;
      c0_ddr4_ck_t         : out   slv(0 to 0);
      c0_ddr4_ck_c         : out   slv(0 to 0);
      c0_ddr4_cke          : out   slv(0 to 0);
      c0_ddr4_cs_n         : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n     : inout slv(1 downto 0);
      c0_ddr4_odt          : out   slv(0 to 0);
      -- AXI DDR Buffer Interface (sysClk domain)
      axiWriteMasters      : in    AxiWriteMasterArray(3 downto 0);
      axiWriteSlaves       : out   AxiWriteSlaveArray(3 downto 0);
      axiReadMaster        : in    AxiReadMasterType;
      axiReadSlave         : out   AxiReadSlaveType;
      buffersRdy           : out   sl;
      -- AXI-Lite Register Interface (sysClk domain)
      mAxilReadMaster      : in    AxiLiteReadMasterType;
      mAxilReadSlave       : out   AxiLiteReadSlaveType;
      mAxilWriteMaster     : in    AxiLiteWriteMasterType;
      mAxilWriteSlave      : out   AxiLiteWriteSlaveType;
      -- SYSMON Ports
      vPIn                 : in    sl;
      vNIn                 : in    sl;
      -- Power Supply Cntrl Ports
      asicAnaEn            : out sl;
      asicDigEn            : out sl;
      dcdcSync             : out slv(10 downto 0);
      dcdcEn               : out slv(3 downto 0);
      ddrVttEn             : out sl;
      ddrVttPok            : in  sl;
      -- FPGA temperature alert
      tempAlertL           : in  sl;
      -- ASIC Carrier IDs
      asicDmSn             : inout slv(3 downto 0);
      -- ASIC Global Reset
      asicGr               : out   sl;
      -- trigger inputs
      trigPgp              : in  sl := '0';
      trigTtl              : in  sl := '0';
      trigCmd              : in  sl := '0';
      -- trigger output
      acqStart             : out sl
   );
end SystemCore;

architecture top_level of SystemCore is
   
   constant DDR_AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 29,
      DATA_BYTES_C => 16,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := ite(SIM_SPEEDUP_G, toSlv(32*4096, DDR_AXI_CONFIG_C.ADDR_WIDTH_C) ,toSlv(2**DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1, DDR_AXI_CONFIG_C.ADDR_WIDTH_C));
   
   constant I2C_MON_CONFIG_C : I2cAxiLiteDevArray(3 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("0110100", 8, 8, '0')),
      1 => (MakeI2cAxiLiteDevType("1100111", 8, 8, '0', '1')),
      2 => (MakeI2cAxiLiteDevType("1101111", 8, 8, '0', '1')),
      3 => (MakeI2cAxiLiteDevType("1010001", 8, 8, '0'))
   );
   
   constant I2C_HUM_CONFIG_C : I2cAxiLiteDevArray(1 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("1000100", 32, 16, '0')),
      1 => (MakeI2cAxiLiteDevType("1001100", 8, 8, '0'))
   );   
   
   constant I2C_DAC_CONFIG_C : I2cAxiLiteDevArray(0 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("1001110", 8, 8, '0'))
   );   

   constant NUM_AXI_MASTERS_C : natural := 8;

   constant VERSION_INDEX_C  : natural := 0;
   constant SYSREG_INDEX_C   : natural := 1;
   constant SYSMON_INDEX_C   : natural := 2;
   constant BOOT_MEM_INDEX_C : natural := 3;
   constant DDR_MEM_INDEX_C  : natural := 4;
   constant VDAC_INDEX_C     : natural := 5;
   constant MON_SNS_INDEX_C  : natural := 6;
   constant HUM_SNS_INDEX_C  : natural := 7;

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal axiClk              : sl;
   signal axiRst              : sl;
   signal axiDdrReadMaster    : AxiReadMasterType;
   signal axiDdrReadSlave     : AxiReadSlaveType;
   signal axiDdrWriteMaster   : AxiWriteMasterType;
   signal axiDdrWriteSlave    : AxiWriteSlaveType;

   signal axiBistReadMaster   : AxiReadMasterType;
   signal axiBistReadSlave    : AxiReadSlaveType;
   signal axiBistWriteMaster  : AxiWriteMasterType;
   signal axiBistWriteSlave   : AxiWriteSlaveType;

   signal bootCsL  : sl;
   signal bootSck  : sl;
   signal bootMosi : sl;
   signal bootMiso : sl;
   signal di       : slv(3 downto 0);
   signal do       : slv(3 downto 0);

   signal calibComplete    : sl;
   signal memReady         : sl;
   signal memFailed        : sl;
   signal userRst          : sl;
   signal memTestRst       : sl;
   signal memTestRstSync   : sl;
   signal iDdrVttEn        : sl;

begin
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
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
         mAxiReadSlaves   => axilReadSlaves);

   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
      generic map (
         TPD_G           => TPD_G,
         BUILD_INFO_G    => BUILD_INFO_G,
         XIL_DEVICE_G    => "ULTRASCALE",
         EN_ICAP_G       => true,
         EN_DEVICE_DNA_G => true,
         CLK_PERIOD_G    => (1.0/AXI_CLK_FREQ_G)
      )
      port map 
      (
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C),
         -- Clocks and Resets
         axiClk         => sysClk,
         axiRst         => sysRst,
         dnaValueOut    => open
      );
      
   --------------------------
   -- System Registers Module
   --------------------------    
   U_SystemRegs : entity work.SystemRegs
   generic map (
      TPD_G             => TPD_G,
      SIM_SPEEDUP_G     => SIM_SPEEDUP_G,
      CLK_PERIOD_G      => (1.0/AXI_CLK_FREQ_G)
   )
   port map (
      -- System Clock
      sysClk            => sysClk,
      sysRst            => sysRst,
      -- User reset output
      usrRst            => userRst,
      -- ADC ISERDESE reset
      adcClkRst         => adcClkRst,
      -- ADC Startup Signals
      adcReqStart       => adcReqStart,
      adcReqTest        => adcReqTest,
      -- AXI lite slave port for register access
      sAxilReadMaster   => axilReadMasters(SYSREG_INDEX_C),
      sAxilReadSlave    => axilReadSlaves(SYSREG_INDEX_C),
      sAxilWriteMaster  => axilWriteMasters(SYSREG_INDEX_C),
      sAxilWriteSlave   => axilWriteSlaves(SYSREG_INDEX_C),
      -- Power Supply Cntrl Ports
      asicAnaEn         => asicAnaEn,
      asicDigEn         => asicDigEn,
      dcdcSync          => dcdcSync,
      dcdcEn            => dcdcEn,
      ddrVttEn          => iDdrVttEn,
      ddrVttPok         => ddrVttPok,
      -- FPGA temperature alert
      tempAlertL        => tempAlertL,
      -- ASIC Carrier IDs
      asicDmSn          => asicDmSn,
      -- ASIC Global Reset
      asicGr            => asicGr,
      -- trigger inputs
      trigPgp           => trigPgp,
      trigTtl           => trigTtl,
      trigCmd           => trigCmd,
      -- trigger output
      acqStart          => acqStart
   );

   --------------------------
   -- AXI-Lite: SYSMON Module
   --------------------------
   G_SYSMON : if SIMULATION_G = false generate
      U_SysMon : entity work.EpixQuadSysMon
         generic map (
            TPD_G            => TPD_G)
         port map (
            -- SYSMON Ports
            vPIn            => vPIn,
            vNIn            => vNIn,
            -- AXI-Lite Register Interface
            axilReadMaster  => axilReadMasters(SYSMON_INDEX_C),
            axilReadSlave   => axilReadSlaves(SYSMON_INDEX_C),
            axilWriteMaster => axilWriteMasters(SYSMON_INDEX_C),
            axilWriteSlave  => axilWriteSlaves(SYSMON_INDEX_C),
            -- Clocks and Resets
            axilClk         => sysClk,
            axilRst         => sysRst);
   end generate G_SYSMON;
   
   G_NO_SYSMON : if SIMULATION_G = true generate
      axilReadSlaves(SYSMON_INDEX_C)   <= AXI_LITE_READ_SLAVE_INIT_C;
      axilWriteSlaves(SYSMON_INDEX_C)  <= AXI_LITE_WRITE_SLAVE_INIT_C;
   end generate G_NO_SYSMON;
   
   ------------------------------
   -- AXI-Lite: Boot Flash Module
   ------------------------------
   U_BootProm : entity work.AxiMicronN25QCore
      generic map (
         TPD_G            => TPD_G,
         MEM_ADDR_MASK_G  => x"00000000",  -- Using hardware write protection
         AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,   -- units of Hz
         SPI_CLK_FREQ_G   => (100.00E+6/4.0))  -- units of Hz
      port map (
         -- FLASH Memory Ports
         csL            => bootCsL,
         sck            => bootSck,
         mosi           => bootMosi,
         miso           => bootMiso,
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMasters(BOOT_MEM_INDEX_C),
         axiReadSlave   => axilReadSlaves(BOOT_MEM_INDEX_C),
         axiWriteMaster => axilWriteMasters(BOOT_MEM_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(BOOT_MEM_INDEX_C),
         -- Clocks and Resets
         axiClk         => sysClk,
         axiRst         => sysRst);

   U_STARTUPE3 : STARTUPE3
      generic map (
         PROG_USR      => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
         SIM_CCLK_FREQ => 0.0)  -- Set the Configuration Clock Frequency(ns) for simulation
      port map (
         CFGCLK    => open,  -- 1-bit output: Configuration main clock output
         CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
         DI        => di,  -- 4-bit output: Allow receiving on the D[3:0] input pins
         EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
         PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
         DO        => do,  -- 4-bit input: Allows control of the D[3:0] pin outputs
         DTS       => "1110",  -- 4-bit input: Allows tristate of the D[3:0] pins
         FCSBO     => bootCsL,  -- 1-bit input: Contols the FCS_B pin for flash access
         FCSBTS    => '0',              -- 1-bit input: Tristate the FCS_B pin
         GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
         GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
         KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
         PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
         USRCCLKO  => bootSck,          -- 1-bit input: User CCLK input
         USRCCLKTS => '0',  -- 1-bit input: User CCLK 3-state enable input
         USRDONEO  => '1',  -- 1-bit input: User DONE pin output control
         USRDONETS => '0'  -- 1-bit input: User DONE 3-state enable output
         );

   do       <= "111" & bootMosi;
   bootMiso <= di(1);

   ----------------------------------------
   -- DDR memory tester
   ----------------------------------------
   U_AxiMemTester : entity work.AxiMemTester
      generic map (
         TPD_G        => TPD_G,
         START_ADDR_G => START_ADDR_C,
         STOP_ADDR_G  => STOP_ADDR_C,
         AXI_CONFIG_G => DDR_AXI_CONFIG_C)
      port map (
         -- AXI-Lite Interface
         axilClk         => sysClk,
         axilRst         => sysRst,
         axilReadMaster  => axilReadMasters(DDR_MEM_INDEX_C),
         axilReadSlave   => axilReadSlaves(DDR_MEM_INDEX_C),
         axilWriteMaster => axilWriteMasters(DDR_MEM_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(DDR_MEM_INDEX_C),
         memReady        => memReady,
         memError        => memFailed,
         -- DDR Memory Interface
         axiClk          => axiClk,
         axiRst          => memTestRst,
         start           => calibComplete,
         axiWriteMaster  => axiBistWriteMaster,
         axiWriteSlave   => axiBistWriteSlave,
         axiReadMaster   => axiBistReadMaster,
         axiReadSlave    => axiBistReadSlave);
   
   G_MIG_CORE : if MIG_CORE_EN = true generate
   
      Sync_0 : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => axiClk,
            dataIn  => userRst,
            dataOut => memTestRstSync);
      
      memTestRst <= axiRst or memTestRstSync;
      
      ------------------------------------------------
      -- DDR memory controller
      ------------------------------------------------
      U_DDR : entity work.MigCoreWrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- AXI Slave
            axiClk           => axiClk,
            axiRst           => axiRst,
            axiReadMaster    => axiDdrReadMaster,
            axiReadSlave     => axiDdrReadSlave,
            axiWriteMaster   => axiDdrWriteMaster,
            axiWriteSlave    => axiDdrWriteSlave,
            -- DDR PHY Ref clk
            c0_sys_clk_p     => c0_sys_clk_p,
            c0_sys_clk_n     => c0_sys_clk_n,
            -- DRR Memory interface ports
            c0_ddr4_adr      => c0_ddr4_adr,
            c0_ddr4_ba       => c0_ddr4_ba,
            c0_ddr4_cke      => c0_ddr4_cke,
            c0_ddr4_cs_n     => c0_ddr4_cs_n,
            c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n,
            c0_ddr4_dq       => c0_ddr4_dq,
            c0_ddr4_dqs_c    => c0_ddr4_dqs_c,
            c0_ddr4_dqs_t    => c0_ddr4_dqs_t,
            c0_ddr4_odt      => c0_ddr4_odt,
            c0_ddr4_bg       => c0_ddr4_bg,
            c0_ddr4_reset_n  => c0_ddr4_reset_n,
            c0_ddr4_act_n    => c0_ddr4_act_n,
            c0_ddr4_ck_c     => c0_ddr4_ck_c,
            c0_ddr4_ck_t     => c0_ddr4_ck_t,
            calibComplete    => calibComplete,
            c0_ddr4_aresetn  => '1'
         );
      
      ------------------------------------------------
      -- DDR memory AXI interconnect
      ------------------------------------------------
      U_AxiIcWrapper : entity work.AxiIcWrapper
         generic map (
            TPD_G => TPD_G)
         port map (
            -- AXI Slaves for ADC channels
            -- 128 Bit Data Bus
            -- 1 burst packet FIFOs
            axiImgClk          => sysClk,
            axiImgWriteMasters => axiWriteMasters,
            axiImgWriteSlaves  => axiWriteSlaves,
            -- AXI Slave for data readout
            -- 128 Bit Data Bus
            axiDoutClk         => sysClk,
            axiDoutReadMaster  => axiReadMaster,
            axiDoutReadSlave   => axiReadSlave,
            -- AXI Slave for memory tester (aximClk domain)
            -- 128 Bit Data Bus
            axiBistReadMaster  => axiBistReadMaster,
            axiBistReadSlave   => axiBistReadSlave,
            axiBistWriteMaster => axiBistWriteMaster,
            axiBistWriteSlave  => axiBistWriteSlave,
            -- AXI Master
            -- 128 Bit Data Bus
            aximClk            => axiClk,
            aximRst            => axiRst,
            aximReadMaster     => axiDdrReadMaster,
            aximReadSlave      => axiDdrReadSlave,
            aximWriteMaster    => axiDdrWriteMaster,
            aximWriteSlave     => axiDdrWriteSlave
         );

      -- keep memory writers in reset during memory test
      memRst : process (sysClk) is
      begin
         if rising_edge(sysClk) then
            if memReady = '1' and memFailed = '0' then
               buffersRdy <= '1' after TPD_G;
            else
               buffersRdy <= '0' after TPD_G;
            end if;
         end if;
      end process memRst;
      
      ddrVttEn <= iDdrVttEn;
      
   end generate;
   
   G_NO_MIG_CORE : if MIG_CORE_EN = false generate
      memTestRst        <= '1';
      c0_ddr4_reset_n   <= '0';
      ddrVttEn          <= '0';
      axiBistWriteSlave <= AXI_WRITE_SLAVE_INIT_C;
      axiBistReadSlave  <= AXI_READ_SLAVE_INIT_C;
      axiWriteSlaves    <= (others=>AXI_WRITE_SLAVE_INIT_C);
      axiReadSlave      <= AXI_READ_SLAVE_INIT_C;
      calibComplete     <= '0';
      buffersRdy        <= '0';
   end generate;
   
   ------------------------------------------------
   -- Power nad temperature monitoring sensors readout
   ------------------------------------------------
   U_MonI2C : entity work.AxiI2cRegMaster
   generic map (
      DEVICE_MAP_G     => I2C_MON_CONFIG_C,
      AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
      I2C_SCL_FREQ_G   => 50.0E+3
   )
   port map (
      scl            => monScl,
      sda            => monSda,
      axiReadMaster  => axilReadMasters(MON_SNS_INDEX_C),
      axiReadSlave   => axilReadSlaves(MON_SNS_INDEX_C),
      axiWriteMaster => axilWriteMasters(MON_SNS_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(MON_SNS_INDEX_C),
      axiClk         => sysClk,
      axiRst         => sysRst
   );
   
   ------------------------------------------------
   -- Humidity and temp sensors readout
   ------------------------------------------------
   U_HumI2C : entity work.AxiI2cRegMaster
   generic map (
      DEVICE_MAP_G     => I2C_HUM_CONFIG_C,
      AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
      I2C_SCL_FREQ_G   => 50.0E+3
   )
   port map (
      scl            => humScl,
      sda            => humSda,
      axiReadMaster  => axilReadMasters(HUM_SNS_INDEX_C),
      axiReadSlave   => axilReadSlaves(HUM_SNS_INDEX_C),
      axiWriteMaster => axilWriteMasters(HUM_SNS_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(HUM_SNS_INDEX_C),
      axiClk         => sysClk,
      axiRst         => sysRst
   );   
   
   -- humRstN and humAlert are currently not supported
   humRstN <= '1';
   
   ------------------------------------------------
   -- Vguard DAC interface
   ------------------------------------------------
   U_VdacI2C : entity work.AxiI2cRegMaster
   generic map (
      DEVICE_MAP_G     => I2C_DAC_CONFIG_C,
      AXI_CLK_FREQ_G   => AXI_CLK_FREQ_G,
      I2C_SCL_FREQ_G   => 50.0E+3
   )
   port map (
      scl            => dacScl,
      sda            => dacSda,
      axiReadMaster  => axilReadMasters(VDAC_INDEX_C),
      axiReadSlave   => axilReadSlaves(VDAC_INDEX_C),
      axiWriteMaster => axilWriteMasters(VDAC_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(VDAC_INDEX_C),
      axiClk         => sysClk,
      axiRst         => sysRst
   );   
   

end top_level;
