-------------------------------------------------------------------------------
-- File       : Epix10kMatrixConfig.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Epix10kMatrixConfig.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.SaciMasterPkg.all;

entity Epix10kMatrixConfig is
   generic (
      TPD_G                : time                  := 1 ns;
      AXIL_CLK_PERIOD_G    : real                  := 8.0e-9;  -- In units of seconds
      AXIL_TIMEOUT_G       : real                  := 1.0E-3;  -- In units of seconds
      SACI_CLK_PERIOD_G    : real                  := 1.0e-6;  -- In units of seconds
      SACI_CLK_FREERUN_G   : boolean               := false;
      SACI_NUM_CHIPS_G     : positive range 1 to 4 := 1;
      SACI_RSP_BUSSED_G    : boolean               := false;
      SIM_SPEEDUP_G        : boolean               := false
   );
   port (
      -- SACI interface
      saciClk        : out sl;
      saciCmd        : out sl;
      saciSelL       : out slv(SACI_NUM_CHIPS_G-1 downto 0);
      saciRsp        : in  slv(ite(SACI_RSP_BUSSED_G, 0, SACI_NUM_CHIPS_G-1) downto 0);
      -- bus arbitration
      saciBusReq     : out sl;
      saciBusGr      : in  sl := '1';
      -- Matrix Config Interface
      clk            : in  sl;
      rst            : in  sl;
      confWrReq      : in  sl;
      confRdReq      : in  sl;
      confSel        : in  slv(SACI_NUM_CHIPS_G-1 downto 0);
      confDone       : out sl;
      confFail       : out slv(SACI_NUM_CHIPS_G-1 downto 0);
      maxFreqConf    : in  Slv4Array(SACI_NUM_CHIPS_G-1 downto 0) := (others=>(others=>'0'));
      memAddr        : out Slv13Array(SACI_NUM_CHIPS_G-1 downto 0);
      memDout        : in  Slv32Array(SACI_NUM_CHIPS_G-1 downto 0);
      memDin         : out Slv32Array(SACI_NUM_CHIPS_G-1 downto 0);
      memWr          : out slv(SACI_NUM_CHIPS_G-1 downto 0)
   );
end Epix10kMatrixConfig;

architecture rtl of Epix10kMatrixConfig is

   constant CHIP_BITS_C : integer := log2(SACI_NUM_CHIPS_G);
   constant TIMEOUT_C   : integer := integer(AXIL_TIMEOUT_G/AXIL_CLK_PERIOD_G)-1;

   constant COLCNT_C    : integer := ite(SIM_SPEEDUP_G, 1,  47);
   constant ROWCNT_C    : integer := ite(SIM_SPEEDUP_G, 3, 176);

   constant SACI_ROWCNT_CMD_C : slv( 6 downto 0) := "0000110";
   constant SACI_ROWCNT_ADR_C : slv(11 downto 0) := "000000010001";
   constant SACI_COLCNT_CMD_C : slv( 6 downto 0) := "0000110";
   constant SACI_COLCNT_ADR_C : slv(11 downto 0) := "000000010011";
   constant SACI_PIXDAT_CMD_C : slv( 6 downto 0) := "0000101";
   constant SACI_PIXDAT_ADR_C : slv(11 downto 0) := "000000000000";
   constant SACI_PREPMC_CMD_C : slv( 6 downto 0) := "0001000";
   constant SACI_PREPMC_ADR_C : slv(11 downto 0) := "000000000000";
   constant SACI_MATDAT_CMD_C : slv( 6 downto 0) := "0000100";
   constant SACI_MATDAT_ADR_C : slv(11 downto 0) := "000000000000";


   type SaciStateType is (
      IDLE_S,
      SACI_REQ_S,
      SACI_ACK_S
   );

   type ConfStateType is (
      IDLE_S,
      WAIT_BUS_S,
      NEXT_ASIC_S,
      PREPMC_CMD_S,
      PREPMC_CMD_WAIT_S,
      MATDAT_CMD_S,
      MATDAT_CMD_WAIT_S,
      ROWCNT_CMD_S,
      ROWCNT_CMD_WAIT_S,
      COLCNT_CMD_S,
      COLCNT_CMD_WAIT_S,
      PIXDAT_CMD_S,
      PIXDAT_CMD_WAIT_S,
      ASIC_DONE_S
   );

   type RegType is record
      saciState      : SaciStateType;
      confState      : ConfStateType;
      maxFreqConf    : Slv4Array(SACI_NUM_CHIPS_G-1 downto 0);
      saciBusReq     : sl;
      saciReq        : sl;
      saciSkip       : sl;
      saciDone       : sl;
      saciErr        : sl;
      confWrReq      : sl;
      confDone       : sl;
      confFail       : slv(SACI_NUM_CHIPS_G-1 downto 0);
      dlyCnt         : integer range 0 to 3;
      asicCnt        : integer range 0 to SACI_NUM_CHIPS_G-1;
      bankCnt        : integer range 0 to 3;
      colCnt         : integer range 0 to COLCNT_C;
      rowCnt         : integer range 0 to ROWCNT_C;
      confAddr       : slv(15 downto 0);
      memAddr        : slv(12 downto 0);
      memDin         : slv(31 downto 0);
      memWr          : sl;
      rdData         : slv(31 downto 0);
      saciRst        : sl;
      req            : sl;
      chip           : slv(log2(SACI_NUM_CHIPS_G)-1 downto 0);
      op             : sl;
      cmd            : slv(6 downto 0);
      addr           : slv(11 downto 0);
      wrData         : slv(31 downto 0);
      timer          : integer range 0 to TIMEOUT_C;
   end record RegType;

   constant REG_INIT_C : RegType := (
      saciState      => IDLE_S,
      confState      => IDLE_S,
      maxFreqConf    => (others=>(others=>'0')),
      saciBusReq     => '0',
      saciReq        => '0',
      saciSkip       => '0',
      saciDone       => '0',
      saciErr        => '0',
      confWrReq      => '0',
      confDone       => '0',
      confFail       => (others => '0'),
      dlyCnt         => 0,
      asicCnt        => 0,
      bankCnt        => 0,
      colCnt         => 0,
      rowCnt         => 0,
      confAddr       => (others => '0'),
      memAddr        => (others => '0'),
      memDin         => (others => '0'),
      memWr          => '0',
      rdData         => (others => '0'),
      saciRst        => '1',
      req            => '0',
      chip           => (others => '0'),
      op             => '0',
      cmd            => (others => '0'),
      addr           => (others => '0'),
      wrData         => (others => '0'),
      timer          => 0
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack    : sl;
   signal fail   : sl;
   signal rdData : slv(31 downto 0);

begin

   assert (AXIL_CLK_PERIOD_G < 1.0)
      report "AXIL_CLK_PERIOD_G must be < 1.0 seconds" severity failure;
   assert (AXIL_TIMEOUT_G < 1.0)
      report "AXIL_TIMEOUT_G must be < 1.0 seconds" severity failure;
   assert (SACI_CLK_PERIOD_G < 1.0)
      report "SACI_CLK_PERIOD_G must be < 1.0 seconds" severity failure;
   assert (AXIL_CLK_PERIOD_G < AXIL_TIMEOUT_G)
      report "AXIL_CLK_PERIOD_G must be < AXIL_TIMEOUT_G" severity failure;
   assert (AXIL_CLK_PERIOD_G < SACI_CLK_PERIOD_G)
      report "AXIL_CLK_PERIOD_G must be < SACI_CLK_PERIOD_G" severity failure;
   assert (SACI_CLK_PERIOD_G < AXIL_TIMEOUT_G)
      report "SACI_CLK_PERIOD_G must be < AXIL_TIMEOUT_G" severity failure;

   U_SaciMaster2_1 : entity surf.SaciMaster2
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_PERIOD_G   => AXIL_CLK_PERIOD_G,
         SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
         SACI_CLK_FREERUN_G => SACI_CLK_FREERUN_G,
         SACI_NUM_CHIPS_G   => SACI_NUM_CHIPS_G,
         SACI_RSP_BUSSED_G  => SACI_RSP_BUSSED_G)
      port map (
         sysClk   => clk,           -- [in]
         sysRst   => r.saciRst,         -- [in]
         req      => r.req,             -- [in]
         ack      => ack,               -- [out]
         fail     => fail,              -- [out]
         chip     => r.chip,            -- [in]
         op       => r.op,              -- [in]
         cmd      => r.cmd,             -- [in]
         addr     => r.addr,            -- [in]
         wrData   => r.wrData,          -- [in]
         rdData   => rdData,            -- [out]
         saciClk  => saciClk,           -- [out]
         saciSelL => saciSelL,          -- [out]
         saciCmd  => saciCmd,           -- [out]
         saciRsp  => saciRsp);          -- [in]

   comb : process (ack, rst, fail, r, rdData, memDout, confWrReq, confRdReq, confSel, saciBusGr, maxFreqConf) is
      variable v           : RegType;
      variable maxFreq     : sl;
      variable memDoutSel  : slv(3 downto 0);
   begin
      -- Latch the current value
      v := r;

      v.saciReq   := '0';
      v.memWr     := '0';
      -- move memory address
      -- 4 bits per pixel / 32 bit memory
      v.memAddr   := r.confAddr(15 downto 3);

      -- Check the timer
      if r.timer /= TIMEOUT_C then
         -- Increment the counter
         v.timer := r.timer + 1;
      end if;

      -- select memory output bits of current ASIC
      if r.confAddr(2 downto 0) = "000" then
         memDoutSel := memDout(r.asicCnt)( 3 downto  0);
      elsif r.confAddr(2 downto 0) = "001" then
         memDoutSel := memDout(r.asicCnt)( 7 downto  4);
      elsif r.confAddr(2 downto 0) = "010" then
         memDoutSel := memDout(r.asicCnt)(11 downto  8);
      elsif r.confAddr(2 downto 0) = "011" then
         memDoutSel := memDout(r.asicCnt)(15 downto 12);
      elsif r.confAddr(2 downto 0) = "100" then
         memDoutSel := memDout(r.asicCnt)(19 downto 16);
      elsif r.confAddr(2 downto 0) = "101" then
         memDoutSel := memDout(r.asicCnt)(23 downto 20);
      elsif r.confAddr(2 downto 0) = "110" then
         memDoutSel := memDout(r.asicCnt)(27 downto 24);
      else
         memDoutSel := memDout(r.asicCnt)(31 downto 28);
      end if;

      -- check if current pixel config of current ASIC is equal to most frequent element
      if memDoutSel = maxFreqConf(r.asicCnt) then
         maxFreq := '1';
      else
         maxFreq := '0';
      end if;

      -- Matrix Set/Get Configuration State Machine
      case (r.confState) is

         when IDLE_S =>
            v.bankCnt := 0;
            v.colCnt := 0;
            v.rowCnt := 0;
            v.asicCnt := 0;
            v.confDone := '1';
            v.confAddr := (others=>'0');
            v.saciBusReq := '0';
            -- write configuration request has higher priority
            if confWrReq = '1' or confRdReq = '1' then
               v.confDone := '0';
               v.confFail := (others=>'0');
               v.confWrReq := confWrReq;
               v.maxFreqConf := maxFreqConf;
               v.confState := WAIT_BUS_S;
            end if;

         -- wait for SACI bus
         when WAIT_BUS_S =>
            v.saciBusReq := '1';
            if saciBusGr = '1' then
               v.confState := NEXT_ASIC_S;
            end if;

         -- select next enabled ASIC
         when NEXT_ASIC_S =>
            v.bankCnt := 0;
            v.colCnt := 0;
            v.rowCnt := 0;
            v.confAddr := (others=>'0');
            if confSel(r.asicCnt) = '1' then
               if r.confWrReq = '1' then
                  v.confState := PREPMC_CMD_S;
               else
                  -- do not set entire matrix when reading
                  v.confState := ROWCNT_CMD_S;
               end if;
            elsif r.asicCnt < SACI_NUM_CHIPS_G-1 then
               v.asicCnt := r.asicCnt + 1;
            else
               v.confState := IDLE_S;
            end if;

         ----------------------------------------------------------
         -- the following SACI commands set entire matrix to selected
         -- most frequent (common) configration component
         ----------------------------------------------------------

         when PREPMC_CMD_S =>
            -- Prepare Multi-config SACI Command
            v.req       := '1';
            v.op        := '1';
            v.chip      := toSlv(r.asicCnt, CHIP_BITS_C);
            v.cmd       := SACI_PREPMC_CMD_C;
            v.addr      := SACI_PREPMC_ADR_C;
            v.wrData    := (others=>'0');
            v.saciReq   := '1';
            v.confState := PREPMC_CMD_WAIT_S;

         when PREPMC_CMD_WAIT_S =>
            if r.saciDone = '1' then
               if r.saciErr = '0' then
                  v.confState := MATDAT_CMD_S;
               else
                  v.confFail(r.asicCnt) := '1';
                  v.confState := ASIC_DONE_S;
               end if;
            end if;

         when MATDAT_CMD_S =>
            -- Set Matrix Data SACI Command
            v.req       := '1';
            v.op        := '1';
            v.chip      := toSlv(r.asicCnt, CHIP_BITS_C);
            v.cmd       := SACI_MATDAT_CMD_C;
            v.addr      := SACI_MATDAT_ADR_C;
            v.wrData    := x"0000000" & maxFreqConf(r.asicCnt);
            v.saciReq   := '1';
            v.confState := MATDAT_CMD_WAIT_S;

         when MATDAT_CMD_WAIT_S =>
            if r.saciDone = '1' then
               if r.saciErr = '0' then
                  v.confState := ROWCNT_CMD_S;
               else
                  v.confFail(r.asicCnt) := '1';
                  v.confState := ASIC_DONE_S;
               end if;
            end if;

         ----------------------------------------------------------
         -- the following SACI commands loop through all non common
         -- configuration components
         ----------------------------------------------------------

         when ROWCNT_CMD_S =>
            -- wait for the read address
            if r.dlyCnt >= 3 then
               if maxFreq = '0' or r.confWrReq = '0' then
                  -- Set Row SACI Command
                  v.req       := '1';
                  v.op        := '1';
                  v.chip      := toSlv(r.asicCnt, CHIP_BITS_C);
                  v.cmd       := SACI_ROWCNT_CMD_C;
                  v.addr      := SACI_ROWCNT_ADR_C;
                  v.wrData    := toSlv(r.rowCnt, 32);
                  v.saciReq   := '1';
                  v.confState := ROWCNT_CMD_WAIT_S;
               else
                  -- skip all 3 SACI commands for the most frequent config
                  -- only when writing configuration to ASIC
                  v.confState := PIXDAT_CMD_WAIT_S;
                  v.saciSkip := '1';
               end if;
               v.dlyCnt := 0;
            else
               v.dlyCnt := r.dlyCnt + 1;
            end if;


         when ROWCNT_CMD_WAIT_S =>
            if r.saciDone = '1' then
               if r.saciErr = '0' then
                  v.confState := COLCNT_CMD_S;
               else
                  v.confFail(r.asicCnt) := '1';
                  v.confState := ASIC_DONE_S;
               end if;
            end if;

         when COLCNT_CMD_S =>
            -- Set Column and Bank SACI Command
            v.req       := '1';
            v.op        := '1';
            v.chip      := toSlv(r.asicCnt, CHIP_BITS_C);
            v.cmd       := SACI_COLCNT_CMD_C;
            v.addr      := SACI_COLCNT_ADR_C;
            v.wrData    := (others=>'0');
            if r.bankCnt = 0 then
               v.wrData(10 downto 0) := "1110" & toSlv(r.colCnt, 7);
            elsif r.bankCnt = 1 then
               v.wrData(10 downto 0) := "1101" & toSlv(r.colCnt, 7);
            elsif r.bankCnt = 2 then
               v.wrData(10 downto 0) := "1011" & toSlv(r.colCnt, 7);
            else
               v.wrData(10 downto 0) := "0111" & toSlv(r.colCnt, 7);
            end if;
            v.saciReq   := '1';
            v.confState := COLCNT_CMD_WAIT_S;

         when COLCNT_CMD_WAIT_S =>
            if r.saciDone = '1' then
               if r.saciErr = '0' then
                  v.confState := PIXDAT_CMD_S;
               else
                  v.confFail(r.asicCnt) := '1';
                  v.confState := ASIC_DONE_S;
               end if;
            end if;

         when PIXDAT_CMD_S =>
            -- Set Pixel Data SACI Command
            v.req       := '1';
            v.op        := r.confWrReq;
            v.chip      := toSlv(r.asicCnt, CHIP_BITS_C);
            v.cmd       := SACI_PIXDAT_CMD_C;
            v.addr      := SACI_PIXDAT_ADR_C;
            v.wrData    := x"0000000" & memDoutSel;
            v.saciReq   := '1';
            v.confState := PIXDAT_CMD_WAIT_S;

         when PIXDAT_CMD_WAIT_S =>
            if r.saciDone = '1' or r.saciSkip = '1' then

               v.saciSkip := '0';

               -- if no error
               -- select next column/row/ASIC
               if r.saciErr = '1' then
                  v.confFail(r.asicCnt) := '1';
                  v.confState := ASIC_DONE_S;
               elsif r.colCnt < COLCNT_C then
                  v.colCnt := r.colCnt + 1;
                  v.confState := ROWCNT_CMD_S;
               elsif r.bankCnt < 3 then
                  v.colCnt := 0;
                  v.bankCnt := r.bankCnt + 1;
                  v.confState := ROWCNT_CMD_S;
               elsif v.rowCnt < ROWCNT_C then
                  v.bankCnt := 0;
                  v.colCnt := 0;
                  v.rowCnt := r.rowCnt + 1;
                  v.confState := ROWCNT_CMD_S;
               else
                  -- all pixels done
                  if r.confWrReq = '0' then
                     -- this will ensure that last pixels
                     -- configuration is stored with unaligned address
                     v.memWr := '1';
                  end if;
                  v.confState := ASIC_DONE_S;
               end if;

               -- move memory address
               -- 4 bits per pixel / 32 bit memory
               v.confAddr := r.confAddr + 1;

               -- overwrite memory if matrix read request
               if r.confWrReq = '0' then
                  if r.confAddr(2 downto 0) = "000" then
                     v.memDin               := (others=>'0');
                     v.memDin( 3 downto  0) := r.rdData(3 downto 0);
                  elsif r.confAddr(2 downto 0) = "001" then
                     v.memDin( 7 downto  4) := r.rdData(3 downto 0);
                  elsif r.confAddr(2 downto 0) = "010" then
                     v.memDin(11 downto  8) := r.rdData(3 downto 0);
                  elsif r.confAddr(2 downto 0) = "011" then
                     v.memDin(15 downto 12) := r.rdData(3 downto 0);
                  elsif r.confAddr(2 downto 0) = "100" then
                     v.memDin(19 downto 16) := r.rdData(3 downto 0);
                  elsif r.confAddr(2 downto 0) = "101" then
                     v.memDin(23 downto 20) := r.rdData(3 downto 0);
                  elsif r.confAddr(2 downto 0) = "110" then
                     v.memDin(27 downto 24) := r.rdData(3 downto 0);
                  else
                     v.memDin(31 downto 28) := r.rdData(3 downto 0);
                     v.memWr := '1';
                  end if;
               end if;

            end if;

         when ASIC_DONE_S =>
            if r.asicCnt < SACI_NUM_CHIPS_G-1 then
               v.asicCnt := r.asicCnt + 1;
               v.confState := NEXT_ASIC_S;
            else
               v.confState := IDLE_S;
            end if;

         when others =>
            v.confState  := IDLE_S;

      end case;

      -- SACI Access State Machine
      case (r.saciState) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the timer
            v.saciRst   := '0';
            v.timer     := 0;
            v.saciDone  := '0';
            v.saciErr   := '0';
            -- Check for a write or read request
            if (r.saciReq = '1') then
               -- Next state
               v.saciState  := SACI_REQ_S;
            end if;
         ----------------------------------------------------------------------
         when SACI_REQ_S =>
            if (ack = '1' and fail = '1') or (r.timer = TIMEOUT_C) then
               v.req     := '0';
               v.saciRst := '1';
               v.saciErr := '1';
            elsif (ack = '1') then
               -- Reset the flag
               v.req := '0';
            end if;


            if (v.req = '0') then
               -- Check for Write operation
               if (r.op = '0') then
                  -- Return the read data bus
                  v.rdData := rdData;
               end if;
               -- Next state
               v.saciState := SACI_ACK_S;
            end if;
         ----------------------------------------------------------------------
         when SACI_ACK_S =>
            -- Check status of ACK flag
            if (ack = '0') then
               -- Next state
               v.saciState := IDLE_S;
               v.saciDone  := '1';
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if rst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      confDone             <= r.confDone;
      confFail             <= r.confFail;
      memAddr              <= (others=>(others=>'0'));
      memDin               <= (others=>(others=>'0'));
      memWr                <= (others=>'0');
      memAddr(r.asicCnt)   <= r.memAddr;
      memDin(r.asicCnt)    <= r.memDin;
      memWr(r.asicCnt)     <= r.memWr;
      saciBusReq           <= r.saciBusReq;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
