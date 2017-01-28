-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Kc705Epix100Emu.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-01-25
-- Last update: 2017-01-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'Example Project Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Example Project Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;
use work.EpixPkgGen2.all;

library unisim;
use unisim.vcomponents.all;

entity Kc705Epix100Emu is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_OK_C);
   port (
      -- LEDs and Reset button
      fmcLed          : out   slv(3 downto 0);
      fmcSfpLossL     : in    slv(3 downto 0);
      fmcTxFault      : in    slv(3 downto 0);
      fmcSfpTxDisable : out   slv(3 downto 0);
      fmcSfpRateSel   : out   slv(3 downto 0);
      fmcSfpModDef0   : out   slv(3 downto 0);
      extRst          : in    sl;
      led             : out   slv(7 downto 0);
      -- 1-wire board ID interfaces
      serialIdIo      : inout slv(9 downto 0);
      -- GT Pins
      gtClkP          : in    sl;
      gtClkN          : in    sl;
      gtRxP           : in    slv(4 downto 0);
      gtRxN           : in    slv(4 downto 0);
      gtTxP           : out   slv(4 downto 0);
      gtTxN           : out   slv(4 downto 0));
end Kc705Epix100Emu;

architecture top_level of Kc705Epix100Emu is

   signal txMasters : AxiStreamMasterArray(4 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(4 downto 0);

   signal pgpTxIn  : Pgp2bTxInArray(4 downto 0) := (others => PGP2B_TX_IN_INIT_C);
   signal pgpRxIn  : Pgp2bRxInArray(4 downto 0) := (others => PGP2B_RX_IN_INIT_C);
   signal pgpTxOut : Pgp2bTxOutArray(4 downto 0);
   signal pgpRxOut : Pgp2bRxOutArray(4 downto 0);

   signal epixStatus : EpixStatusArray(4 downto 0);
   signal epixConfig : EpixConfigArray(4 downto 0);

   signal refClk     : sl;
   signal refClkDiv2 : sl;
   signal clkIn      : sl;
   signal rstIn      : sl;
   signal clk        : sl;
   signal rst        : sl;

begin

   ----------------
   -- Misc. Signals
   ----------------
   led(7) <= pgpTxOut(3).linkReady and not(rst);
   led(6) <= pgpRxOut(3).linkReady and not(rst);
   led(5) <= pgpTxOut(2).linkReady and not(rst);
   led(4) <= pgpRxOut(2).linkReady and not(rst);
   led(3) <= pgpTxOut(1).linkReady and not(rst);
   led(2) <= pgpRxOut(1).linkReady and not(rst);
   led(1) <= pgpTxOut(0).linkReady and not(rst);
   led(0) <= pgpRxOut(0).linkReady and not(rst);

   fmcLed          <= not(fmcSfpLossL);
   fmcSfpTxDisable <= (others => '0');
   fmcSfpRateSel   <= (others => '1');
   fmcSfpModDef0   <= (others => '0');

   ------------------
   -- Clock and Reset
   ------------------
   U_IBUFDS : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => refClkDiv2,
         O     => refClk);

   U_BUFG : BUFG
      port map (
         I => refClkDiv2,
         O => clkIn);

   U_RstSync : entity work.RstSync
      generic map(
         TPD_G => TPD_G)
      port map (
         clk      => clkIn,
         asyncRst => extRst,
         syncRst  => rstIn);

   U_MMCM : entity work.ClockManager7
      generic map(
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => false,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 1,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 16.0,
         DIVCLK_DIVIDE_G    => 2,
         CLKFBOUT_MULT_F_G  => 31.875,
         CLKOUT0_DIVIDE_F_G => 6.375)
      port map(
         clkIn     => clkIn,
         rstIn     => rstIn,
         clkOut(0) => clk,
         rstOut(0) => rst);

   GEN_VEC :
   for i in 4 downto 0 generate

      ------------------------
      -- PGP Core for KINTEX-7
      ------------------------
      U_PGP : entity work.PgpWrapper
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
         port map (
            -- Clock and Reset
            refClk     => refClk,
            clk        => clk,
            rst        => rst,
            -- Non VC TX Signals
            pgpTxIn    => pgpTxIn(i),
            pgpTxOut   => pgpTxOut(i),
            -- Non VC RX Signals
            pgpRxIn    => pgpRxIn(i),
            pgpRxOut   => pgpRxOut(i),
            -- Streaming Interface
            txMaster   => txMasters(i),
            txSlave    => txSlaves(i),
            -- Register Inputs/Outputs
            epixStatus => epixStatus(i),
            epixConfig => epixConfig(i),
            -- 1-wire board ID interfaces
            serialIdIo => serialIdIo((2*i)+1 downto (2*i)),
            -- GT Pins
            gtTxP      => gtTxP(i),
            gtTxN      => gtTxN(i),
            gtRxP      => gtRxP(i),
            gtRxN      => gtRxN(i));

      ------------------------
      -- Data Packet Generator
      ------------------------
      U_EmuDataGen : entity work.EmuDataGen
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clock and Reset
            clk        => clk,
            rst        => rst,
            -- Trigger Interface
            opCodeEn   => pgpRxOut(i).opCodeEn,
            opCode     => pgpRxOut(i).opCode,
            -- Streaming Interface
            txMaster   => txMasters(i),
            txSlave    => txSlaves(i),
            -- Register Inputs/Outputs
            epixStatus => epixStatus(i),
            epixConfig => epixConfig(i));

   end generate GEN_VEC;

end top_level;
