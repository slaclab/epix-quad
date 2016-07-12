-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ELine100Config.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-16
-- Last update: 2016-06-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of <PROJECT_NAME>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <PROJECT_NAME>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

use work.ELine100Pkg.all;

entity ELine100Config is

   generic (
      TPD_G              : time            := 1 ns;
      AXIL_ERR_RESP_G    : slv(1 downto 0) := AXI_RESP_DECERR_C;
      AXIL_CLK_PERIOD_G  : real            := 8.0e-9;
      ASIC_SCLK_PERIOD_G : real            := 1.0e-6);

   port (
      -- Axi-Lite configuration interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;

      -- ELINE100 configuration interface
      asicSclk : out sl;
      asicSdi  : out sl;
      asicSdo  : in  sl;
      asicSen  : out sl;
      asicRw   : out sl);

end entity ELine100Config;

architecture rtl of ELine100Config is

   constant SHIFT_SIZE_BITS_C : integer                           := log2(ELINE_100_CFG_SHIFT_SIZE_G);
   constant SHIFT_SIZE_SLV_C  : slv(SHIFT_SIZE_BITS_C-1 downto 0) := toSlv(ELINE_100_CFG_SHIFT_SIZE_G-1, SHIFT_SIZE_BITS_C);

   type StateType is (WAIT_AXIL_S, ASIC_READ_S);

   type RegType is record
      state          : StateType;
      writeCfg       : ELine100CfgType;
      readCfg        : ELine100CfgType;
      asicSen        : sl;
      asicRw         : sl;
      spiWrEn        : sl;
      dataSize       : slv(log2(ELINE_100_CFG_SHIFT_SIZE_G)-1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => WAIT_AXIL_S,
      writeCfg       => E_LINE_100_CFG_INIT_C,
      readCfg        => E_LINE_100_CFG_INIT_C,
      asicSen        => '1',
      asicRw         => '1',
      spiWrEn        => '0',
      dataSize       => SHIFT_SIZE_SLV_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal spiRdEn   : sl;
   signal spiWrData : slv(341 downto 0);
   signal spiRdData : slv(341 downto 0);

begin

   spiWrData <= toSlv(r.writeCfg);

   U_SpiMaster_1 : entity work.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 342,
         CPHA_G            => '1',      -- Shift out on rising edge and
         CPOL_G            => '0',      -- sample on falling edge.
         CLK_PERIOD_G      => AXIL_CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => 1.0e-6)
      port map (
         clk      => axilClk,           -- [in]
         sRst     => axilRst,           -- [in]
         chipSel  => (others => '0'),   -- [in]
         wrEn     => r.spiWrEn,         -- [in]
         wrData   => spiWrData,         -- [in]
         dataSize => r.dataSize,        -- [in]
         rdEn     => spiRdEn,           -- [out]
         rdData   => spiRdData,         -- [out]
         spiCsL   => open,              -- [out]
         spiSclk  => asicSclk,          -- [out]
         spiSdi   => asicSdi,           -- [out]
         spiSdo   => asicSdo);          -- [in]

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, spiRdData, spiRdEn) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      v := r;

      v.asicSen := '1';

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);



      case r.state is                   -- Write the configuration to the asic
         when WAIT_AXIL_S =>
            -- Normal registers
            -- CFG write registers
            for i in 0 to 95 loop
               axiSlaveRegister(axilEp, toSlv(i/8, 8), ((i*4) mod 32) + 0, v.writeCfg.chCfg(i).somi);
               axiSlaveRegister(axilEp, toSlv(i/8, 8), ((i*4) mod 32) + 1, v.writeCfg.chCfg(i).sm);
               axiSlaveRegister(axilEp, toSlv(i/8, 8), ((i*4) mod 32) + 2, v.writeCfg.chCfg(i).st);
            end loop;
            axiSlaveRegister(axilEp, X"30", 0, v.writeCfg.pbitt);
            axiSlaveRegister(axilEp, X"30", 1, v.writeCfg.cs);
            axiSlaveRegister(axilEp, X"30", 2, v.writeCfg.atest);
            axiSlaveRegister(axilEp, X"30", 3, v.writeCfg.vdacm);
            axiSlaveRegister(axilEp, X"30", 4, v.writeCfg.hrtest);
            axiSlaveRegister(axilEp, X"30", 5, v.writeCfg.sbm);
            axiSlaveRegister(axilEp, X"30", 6, v.writeCfg.sb);
            axiSlaveRegister(axilEp, X"30", 7, v.writeCfg.test);
            axiSlaveRegister(axilEp, X"30", 8, v.writeCfg.saux);
            axiSlaveRegister(axilEp, X"30", 9, v.writeCfg.slrb);
            axiSlaveRegister(axilEp, X"30", 11, v.writeCfg.claen);
            axiSlaveRegister(axilEp, X"30", 12, v.writeCfg.pb);
            axiSlaveRegister(axilEp, X"30", 22, v.writeCfg.tr);
            axiSlaveRegister(axilEp, X"30", 25, v.writeCfg.sse);
            axiSlaveRegister(axilEp, X"30", 26, v.writeCfg.disen);
            axiSlaveRegister(axilEp, X"34", 0, v.writeCfg.pa);
            axiSlaveRegister(axilEp, X"34", 10, v.writeCfg.esm);
            axiSlaveRegister(axilEp, X"34", 11, v.writeCfg.t);
            axiSlaveRegister(axilEp, X"34", 14, v.writeCfg.dd);
            axiSlaveRegister(axilEp, X"34", 15, v.writeCfg.sabtest);
            axiSlaveRegister(axilEp, X"34", 16, v.writeCfg.clab);
            axiSlaveRegister(axilEp, X"34", 19, v.writeCfg.tres);

            -- Asic RD registers
            for i in 0 to 95 loop
               axiSlaveRegisterR(axilEp, toSlv(i/8, 8)+X"40", ((i*4) mod 32) + 0, r.readCfg.chCfg(i).somi);
               axiSlaveRegisterR(axilEp, toSlv(i/8, 8)+X"40", ((i*4) mod 32) + 1, r.readCfg.chCfg(i).sm);
               axiSlaveRegisterR(axilEp, toSlv(i/8, 8)+X"40", ((i*4) mod 32) + 2, r.readCfg.chCfg(i).st);
            end loop;
            axiSlaveRegisterR(axilEp, X"70", 0, r.readCfg.pbitt);
            axiSlaveRegisterR(axilEp, X"70", 1, r.readCfg.cs);
            axiSlaveRegisterR(axilEp, X"70", 2, r.readCfg.atest);
            axiSlaveRegisterR(axilEp, X"70", 3, r.readCfg.vdacm);
            axiSlaveRegisterR(axilEp, X"70", 4, r.readCfg.hrtest);
            axiSlaveRegisterR(axilEp, X"70", 5, r.readCfg.sbm);
            axiSlaveRegisterR(axilEp, X"70", 6, r.readCfg.sb);
            axiSlaveRegisterR(axilEp, X"70", 7, r.readCfg.test);
            axiSlaveRegisterR(axilEp, X"70", 8, r.readCfg.saux);
            axiSlaveRegisterR(axilEp, X"70", 9, r.readCfg.slrb);
            axiSlaveRegisterR(axilEp, X"70", 11, r.readCfg.claen);
            axiSlaveRegisterR(axilEp, X"70", 12, r.readCfg.pb);
            axiSlaveRegisterR(axilEp, X"70", 22, r.readCfg.tr);
            axiSlaveRegisterR(axilEp, X"70", 25, r.readCfg.sse);
            axiSlaveRegisterR(axilEp, X"70", 26, r.readCfg.disen);
            axiSlaveRegisterR(axilEp, X"74", 0, r.readCfg.pa);
            axiSlaveRegisterR(axilEp, X"74", 10, r.readCfg.esm);
            axiSlaveRegisterR(axilEp, X"74", 11, r.readCfg.t);
            axiSlaveRegisterR(axilEp, X"74", 14, r.readCfg.dd);
            axiSlaveRegisterR(axilEp, X"74", 15, r.readCfg.sabtest);
            axiSlaveRegisterR(axilEp, X"74", 16, r.readCfg.clab);
            axiSlaveRegisterR(axilEp, X"74", 19, r.readCfg.tres);

            -- Special sequences to write and readback SPI config 
            if (axilEp.axiStatus.writeEnable = '1') then
               if (axilEp.axiWriteMaster.awaddr(11 downto 0) = X"80") then
                  -- Hold spiWrEn high until spiRdEn
                  v.spiWrEn := '1';
                  v.asicSen := '1';
                  if (spiRdEn = '0') then
                     -- Clear spiWrEn when spiRdEn goes low
                     v.spiWrEn := '0';
                  end if;
                  if (v.spiWrEn = '0' and spiRdEn = '1') then
                     -- When spiRdEn goes back high, done with txn
                     v.asicSen := '0';
                     axiSlaveWriteResponse(axilEp.axiWriteSlave);
                  end if;
               end if;

               if (axilEp.axiWriteMaster.awaddr(11 downto 0) = X"84") then
                  -- Do a 1 bit SPI txn to get the asic in read mode
                  v.spiWrEn  := '1';
                  v.asicRw   := '0';
                  v.dataSize := toSlv(1, SHIFT_SIZE_BITS_C);

                  -- Wait for txn to finish
                  if (spiRdEn = '0') then
                     v.spiWrEn := '0';
                  end if;
                  if (v.spiWrEn = '0' and spiRdEn = '1') then
                     v.asicRw := '1';
                     v.state  := ASIC_READ_S;
                  end if;
               end if;
            end if;

         when ASIC_READ_S =>
            -- Do a full shift operation
            v.spiWrEn  := '1';
            v.dataSize := SHIFT_SIZE_SLV_C;
            -- Wait for txn to finish
            if (spiRdEn = '0') then
               v.spiWrEn := '0';
            end if;
            if (v.spiWrEn = '0' and spiRdEn = '1') then
               -- Assign readback to r.readCfg registers
               v.state   := WAIT_AXIL_S;
               v.readCfg := toELine100Cfg(spiRdData);
               axiSlaveWriteResponse(axilEp.axiWriteSlave);
            end if;

      end case;


      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXIL_ERR_RESP_G);

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      asicSen        <= r.asicSen;
      asicRw         <= r.asicRw;
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
