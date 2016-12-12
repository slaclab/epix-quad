-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ELine100Config.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-16
-- Last update: 2016-12-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of Coulter. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of Coulter, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TextUtilPkg.all;

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
      asicEnaAMon : out sl;
      asicSclk    : out sl;
      asicSdi     : out sl;
      asicSdo     : in  sl;
      asicSen     : out sl;
      asicRw      : out sl);

end entity ELine100Config;

architecture rtl of ELine100Config is

   constant SHIFT_SIZE_BITS_C : integer                           := log2(ELINE_100_CFG_SHIFT_SIZE_C);
   constant SHIFT_SIZE_SLV_C  : slv(SHIFT_SIZE_BITS_C-1 downto 0) := toSlv(ELINE_100_CFG_SHIFT_SIZE_C-1, SHIFT_SIZE_BITS_C);

   type StateType is (WAIT_AXIL_S, ASIC_READ_S);

   type RegType is record
      state          : StateType;
      cfg            : ELine100CfgType;
      asicEnaAMon    : sl;
      asicSen        : sl;
      asicRw         : sl;
      spiWrEn        : sl;
      doneWr         : sl;
      dataSize       : slv(log2(ELINE_100_CFG_SHIFT_SIZE_C)-1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => WAIT_AXIL_S,
      cfg            => E_LINE_100_CFG_INIT_C,
      asicEnaAMon    => '0',
      asicSen        => '1',
      asicRw         => '1',
      spiWrEn        => '0',
      doneWr         => '0',
      dataSize       => SHIFT_SIZE_SLV_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal spiRdEn   : sl;
   signal spiWrData : slv(341 downto 0);
   signal spiRdData : slv(341 downto 0);

begin

   -- SPI sends data MSB first. Need to flip so that LSB sent first.
   spiWrData <= bitReverse(toSlv(r.cfg));

   U_SpiMaster_1 : entity work.SpiMaster
      generic map (
         TPD_G             => TPD_G,
         NUM_CHIPS_G       => 1,
         DATA_SIZE_G       => 342,
         CPHA_G            => '1',      -- Shift out on rising edge and
         CPOL_G            => '0',      -- sample on falling edge.
         CLK_PERIOD_G      => AXIL_CLK_PERIOD_G,
         SPI_SCLK_PERIOD_G => ASIC_SCLK_PERIOD_G)
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
      variable chCfg  : slv32Array(0 to 11);
   begin
      v := r;

      v.asicSen := '1';

      chCfg := (others => (others => '0'));

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      case r.state is
         when WAIT_AXIL_S =>
            -- Normal registers
            -- CFG write registers
--             for i in 0 to 95 loop
-- --                axiSlaveRegister(axilEp, toSlv(i/8*4, 8), ((i*4) mod 32) + 0, v.cfg.chCfg(i).somi);
-- --                axiSlaveRegister(axilEp, toSlv(i/8*4, 8), ((i*4) mod 32) + 1, v.cfg.chCfg(i).sm);
-- --                axiSlaveRegister(axilEp, toSlv(i/8*4, 8), ((i*4) mod 32) + 2, v.cfg.chCfg(i).st);
--                axiSlaveRegister(axilEp, X"00", (i*4) + 0, v.cfg.chCfg(i).somi, 'X', string("somi("&str(i)&")"));
--                axiSlaveRegister(axilEp, X"00", (i*4) + 1, v.cfg.chCfg(i).sm, 'X', string("sm("&str(i)&")"));
--                axiSlaveRegister(axilEp, X"00", (i*4) + 2, v.cfg.chCfg(i).st, 'X', string("st("&str(i)&")"));
--             end loop;

            for i in 0 to 11 loop
               for j in 0 to 7 loop
                  chCfg(i)(j*4)   := r.cfg.chCfg(i*8+j).somi;
                  chCfg(i)(j*4+1) := r.cfg.chCfg(i*8+j).sm;
                  chCfg(i)(j*4+2) := r.cfg.chCfg(i*8+j).st;
                  chCfg(i)(j*4+3) := '0';
               end loop;
               axiSlaveRegister(axilEp, toSlv(i*4, 8), 0, chCfg(i), "X", string("SomeSmSt("&str(i)&")"));
               for j in 0 to 7 loop
                  v.cfg.chCfg(i*8+j).somi := chCfg(i)(j*4);
                  v.cfg.chCfg(i*8+j).sm   := chCfg(i)(j*4+1);
                  v.cfg.chCfg(i*8+j).st   := chCfg(i)(j*4+2);
               end loop;
            end loop;

            axiSlaveRegister(axilEp, X"30", 0, v.cfg.pbitt);
            axiSlaveRegister(axilEp, X"30", 1, v.cfg.cs);
            axiSlaveRegister(axilEp, X"30", 2, v.cfg.atest);
            axiSlaveRegister(axilEp, X"30", 3, v.cfg.vdacm);
            axiSlaveRegister(axilEp, X"30", 4, v.cfg.hrtest);
            axiSlaveRegister(axilEp, X"30", 5, v.cfg.sbm);
            axiSlaveRegister(axilEp, X"30", 6, v.cfg.sb);
            axiSlaveRegister(axilEp, X"30", 7, v.cfg.test);
            axiSlaveRegister(axilEp, X"30", 8, v.cfg.saux);
            axiSlaveRegister(axilEp, X"30", 9, v.cfg.slrb);
            axiSlaveRegister(axilEp, X"30", 11, v.cfg.claen);
            axiSlaveRegister(axilEp, X"30", 12, v.cfg.pb);
            axiSlaveRegister(axilEp, X"30", 22, v.cfg.tr);
            axiSlaveRegister(axilEp, X"30", 25, v.cfg.sse);
            axiSlaveRegister(axilEp, X"30", 26, v.cfg.disen);
            axiSlaveRegister(axilEp, X"34", 0, v.cfg.pa);
            axiSlaveRegister(axilEp, X"34", 10, v.cfg.esm);
            axiSlaveRegister(axilEp, X"34", 11, v.cfg.t);
            axiSlaveRegister(axilEp, X"34", 14, v.cfg.dd);
            axiSlaveRegister(axilEp, X"34", 15, v.cfg.sabtest);
            axiSlaveRegister(axilEp, X"34", 16, v.cfg.clab);
            axiSlaveRegister(axilEp, X"34", 19, v.cfg.tres);

            axiSlaveRegister(axilEp, X"80", 0, v.asicEnaAMon);


            -- Special sequences to write and readback SPI config 
            if (axilEp.axiStatus.writeEnable = '1') then
               if (axilEp.axiWriteMaster.awaddr(7 downto 0) = X"40") then
                  -- Hold spiWrEn high until spiRdEn
                  v.doneWr  := '1';
                  v.spiWrEn := '1';
                  v.asicSen := '1';
                  if (spiRdEn = '0') then
                     -- Clear spiWrEn when spiRdEn goes low
                     v.spiWrEn := '0';
                  end if;
                  if (r.doneWr = '1' and spiRdEn = '1' and r.spiWrEn = '0') then
                     -- When spiRdEn goes back high, done with txn
                     v.doneWr  := '0';
                     v.spiWrEn := '0';
                     v.asicSen := '0';
                     axiSlaveWriteResponse(axilEp.axiWriteSlave);
                  end if;

               elsif (axilEp.axiWriteMaster.awaddr(7 downto 0) = X"44") then
                  -- Do a 1 bit SPI txn to get the asic in read mode
                  v.doneWr   := '1';
                  v.spiWrEn  := '1';
                  v.asicRw   := '0';
                  v.dataSize := toSlv(0, SHIFT_SIZE_BITS_C);

                  -- Wait for txn to finish
                  if (spiRdEn = '0') then
                     v.spiWrEn := '0';
                  end if;
                  if (r.doneWr = '1' and spiRdEn = '1' and r.spiWrEn = '0') then
                     v.doneWr := '0';
                     v.spiWrEn := '0';
                     v.asicRw := '1';
                     v.state  := ASIC_READ_S;
                  end if;
               end if;
            end if;

         when ASIC_READ_S =>
            -- Do a full shift operation
            v.doneWr   := '1';
            v.spiWrEn  := '1';
            v.dataSize := SHIFT_SIZE_SLV_C;
            -- Wait for txn to finish
            if (spiRdEn = '0') then
               v.spiWrEn := '0';
            end if;
            if (r.doneWr = '1' and spiRdEn = '1' and r.spiWrEn = '0') then
               -- Assign readback to r.readCfg registers
               v.doneWr := '0';
               v.spiWrEn := '0';
               v.state  := WAIT_AXIL_S;
               v.cfg    := toELine100Cfg(bitReverse(spiRdData));
               axiSlaveWriteResponse(axilEp.axiWriteSlave);
            end if;

      end case;

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXIL_ERR_RESP_G,
                      (v.doneWr or toSl(v.state=ASIC_READ_S)));

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      asicEnaAMon    <= r.asicEnaAMon;
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
