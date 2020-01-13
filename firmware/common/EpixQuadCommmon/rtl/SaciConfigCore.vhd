-------------------------------------------------------------------------------
-- File       : SaciConfigCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: SaciConfigCore.
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

entity SaciConfigCore is
   generic (
      TPD_G             : time               := 1 ns;
      AXI_BASE_ADDR_G   : slv(31 downto 0)   := (others => '0');
      SACI_CLK_PERIOD_G : real               := 1.00E-6;
      AXI_CLK_FREQ_G    : real               := 100.00E+6;
      SIM_SPEEDUP_G     : boolean            := false
   );
   port (
      -- clock and reset
      sysClk            : in  sl;
      sysRst            : in  sl;
      -- SACI interface
      saciClk           : out slv(3 downto 0);
      saciCmd           : out slv(3 downto 0);
      saciSelL          : out slv(15 downto 0);
      saciRsp           : in  slv(3 downto 0);
      -- AXI-Lite Matrix Configuration Interface
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AXI-Lite Register Interfaces
      axilReadMasters   : in  AxiLiteReadMasterArray(3 downto 0);
      axilReadSlaves    : out AxiLiteReadSlaveArray(3 downto 0);
      axilWriteMasters  : in  AxiLiteWriteMasterArray(3 downto 0);
      axilWriteSlaves   : out AxiLiteWriteSlaveArray(3 downto 0)
   );
end SaciConfigCore;

architecture rtl of SaciConfigCore is
   
   constant DSP_CMP_NUM_C     : natural := 15;
   constant NUM_AXI_MASTERS_C : natural := 17;
   constant AXI_CONFIG_C      : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 19);

   signal axilCbWriteMasters  : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilCbWriteSlaves   : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilCbReadMasters   : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilCbReadSlaves    : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   type StateType is (
      REG_ACC_S,
      REG_WAIT_S,
      CON_ACC_S
   );
   
   type StateTypeArray is array (natural range <>) of StateType;
   
   type RegType is record
      state                : StateTypeArray(3 downto 0);
      maxFreqConf          : Slv4Array(15 downto 0);
      maxFreqHist          : Slv18VectorArray(15 downto 0, 15 downto 0);
      regSaciBusGr         : slv(3 downto 0);
      conSaciBusGr         : slv(3 downto 0);
      confWrReq            : sl;
      confRdReq            : sl;
      confSel              : slv(15 downto 0);
      axilWriteSlave       : AxiLiteWriteSlaveType;
      axilReadSlave        : AxiLiteReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state                => (others=>REG_ACC_S),
      maxFreqConf          => (others=>(others=>'0')),
      maxFreqHist          => (others=>(others=>(others=>'0'))),
      regSaciBusGr         => (others=>'0'),
      conSaciBusGr         => (others=>'0'),
      confWrReq            => '0',
      confRdReq            => '0',
      confSel              => (others=>'0'),
      axilWriteSlave       => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave        => AXI_LITE_READ_SLAVE_INIT_C
   );

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;
   
   signal confDone      : slv(3 downto 0);
   signal confDoneAll   : sl;
   signal confFail      : slv(15 downto 0);
   
   signal regSaciClk    : slv(3 downto 0);
   signal regSaciCmd    : slv(3 downto 0);
   signal regSaciSelL   : slv(15 downto 0);
   signal regSaciBusReq : slv(3 downto 0);
   
   signal conSaciClk    : slv(3 downto 0);
   signal conSaciCmd    : slv(3 downto 0);
   signal conSaciSelL   : slv(15 downto 0);
   signal conSaciBusReq : slv(3 downto 0);
   
   signal memAddr       : Slv13Array(15 downto 0);
   signal memDout       : Slv32Array(15 downto 0);
   signal memDin        : Slv32Array(15 downto 0);
   signal memWr         : slv(15 downto 0);
   
   signal cmpAin        : Slv18VectorArray(15 downto 0, DSP_CMP_NUM_C-1 downto 0);
   signal cmpBin        : Slv18VectorArray(15 downto 0, DSP_CMP_NUM_C-1 downto 0);
   signal cmpGtEq       : Slv1VectorArray (15 downto 0, DSP_CMP_NUM_C-1 downto 0);
   
begin
   
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVE_SLOTS_G    => 1,
         NUM_MASTER_SLOTS_G   => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G     => AXI_CONFIG_C
      )
      port map (
         axiClk               => sysClk,
         axiClkRst            => sysRst,
         sAxiWriteMasters(0)  => axilWriteMaster,
         sAxiWriteSlaves(0)   => axilWriteSlave,
         sAxiReadMasters(0)   => axilReadMaster,
         sAxiReadSlaves(0)    => axilReadSlave,

         mAxiWriteMasters     => axilCbWriteMasters,
         mAxiWriteSlaves      => axilCbWriteSlaves,
         mAxiReadMasters      => axilCbReadMasters,
         mAxiReadSlaves       => axilCbReadSlaves
      );
   

   comb : process (sysRst, r, axilCbReadMasters(16), axilCbWriteMasters, axilCbWriteSlaves, 
      confDone, confDoneAll, confFail, regSaciBusReq, conSaciBusReq, cmpGtEq) is
      variable v           : RegType;
      variable regCon      : AxiLiteEndPointType;
      variable countConf   : Slv4VectorArray(15 downto 0, 15 downto 0);
      variable cmpGtEqSel  : Slv18VectorArray(15 downto 0, 13 downto 0);
   begin
      v := r;
      
      v.confWrReq := '0';
      v.confRdReq := '0';
      
      --------------------------------------------------
      -- AXI Lite register logic
      --------------------------------------------------
      
      -- Determine the AXI-Lite transaction
      axiSlaveWaitTxn(regCon, axilCbWriteMasters(16), axilCbReadMasters(16), v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.confWrReq         );
      axiSlaveRegister (regCon, x"004", 0, v.confRdReq         );
      axiSlaveRegister (regCon, x"008", 0, v.confSel           );
      axiSlaveRegisterR(regCon, x"00C", 0, confDoneAll         );
      axiSlaveRegisterR(regCon, x"010", 0, confFail            );
      for asic in 15 downto 0 loop
         axiSlaveRegisterR(regCon, x"020"+toSlv(asic*4,12), 0, r.maxFreqConf(asic));
      end loop;
      
      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);
      
      --------------------------------------------------
      -- SACI arbiter FSMs
      --------------------------------------------------
      for i in 3 downto 0 loop
         case (r.state(i)) is
            
            when REG_ACC_S =>
               -- register acces at startup
               v.regSaciBusGr(i) := '1';
               v.conSaciBusGr(i) := '0';
               if conSaciBusReq(i) = '1' then
                  v.state(i) := REG_WAIT_S;
               end if;
            
            when REG_WAIT_S =>
               -- wait for register access to terminate
               if regSaciBusReq(i) = '0' then
                  v.regSaciBusGr(i) := '0';
                  v.conSaciBusGr(i) := '1';
                  v.state(i) := CON_ACC_S;
               end if;
               
            when CON_ACC_S =>
               -- return to register access mode when config done
               if confDone(i) = '1' then
                  v.state(i) := REG_ACC_S;
               end if;
            
            when others =>
               v.state(i) := REG_ACC_S;
            
         end case;
      end loop;
      
      --------------------------------------------------
      -- Find most frequent (commmon) pixel configuration in memories write transactions
      --------------------------------------------------
      for asic in 15 downto 0 loop
         
         for bins in 0 to 15 loop
            
            -- count bins in all 8 nibbles
            countConf(asic, bins) := (others=>'0');
            if axilCbWriteMasters(asic).wdata(3 downto 0) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(7 downto 4) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(11 downto 8) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(15 downto 12) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(19 downto 16) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(23 downto 20) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(27 downto 24) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            if axilCbWriteMasters(asic).wdata(31 downto 28) = bins then
               countConf(asic, bins) := countConf(asic, bins) + 1;
            end if;
            
            -- Register statistics
            if axilCbWriteSlaves(asic).wready = '1' then
               v.maxFreqHist(asic, bins) := r.maxFreqHist(asic, bins) + countConf(asic, bins);
            end if;
            
            -- Reset statistics on address 0
            if axilCbWriteMasters(asic).awaddr(18 downto 0) = 0 and axilCbWriteSlaves(asic).awready = '1' then
               v.maxFreqHist(asic, bins)  := "00000000000000" & countConf(asic, bins);
            end if;
            
         end loop;
         
         -- select the highest bin
         
         -- first stage of 8 DSP comparators
         for cmp in 0 to 7 loop
            cmpAin(asic, cmp) <= r.maxFreqHist(asic, cmp*2+0);
            cmpBin(asic, cmp) <= r.maxFreqHist(asic, cmp*2+1);
            if cmpGtEq(asic, cmp) = "1" then
               cmpGtEqSel(asic, cmp) := r.maxFreqHist(asic, cmp*2+0);
            else
               cmpGtEqSel(asic, cmp) := r.maxFreqHist(asic, cmp*2+1);
            end if;
         end loop;
         
         -- second stage of 4 DSP comparators
         for cmp in 0 to 3 loop
            cmpAin(asic, 8+cmp) <= cmpGtEqSel(asic, cmp*2+0);
            cmpBin(asic, 8+cmp) <= cmpGtEqSel(asic, cmp*2+1);
            if cmpGtEq(asic, 8+cmp) = "1" then
               cmpGtEqSel(asic, 8+cmp) := cmpGtEqSel(asic, cmp*2+0);
            else
               cmpGtEqSel(asic, 8+cmp) := cmpGtEqSel(asic, cmp*2+1);
            end if;
         end loop;
         
         -- third stage of 2 DSP comparators
         for cmp in 0 to 1 loop
            cmpAin(asic, 12+cmp) <= cmpGtEqSel(asic, 8+cmp*2+0);
            cmpBin(asic, 12+cmp) <= cmpGtEqSel(asic, 8+cmp*2+1);
            if cmpGtEq(asic, 12+cmp) = "1" then
               cmpGtEqSel(asic, 12+cmp) := cmpGtEqSel(asic, 8+cmp*2+0);
            else
               cmpGtEqSel(asic, 12+cmp) := cmpGtEqSel(asic, 8+cmp*2+1);
            end if;
         end loop;
         
         -- fourth stage of 1 DSP comparator
         cmpAin(asic, 14) <= cmpGtEqSel(asic, 12);
         cmpBin(asic, 14) <= cmpGtEqSel(asic, 13);
         
         -- decode highest bin
         if cmpGtEq(asic, 14) = "1" then
            -- comparator 12
            if cmpGtEq(asic, 12) = "1" then
               -- comparator 8
               if cmpGtEq(asic, 8) = "1" then 
                  -- comparator 0
                  if cmpGtEq(asic, 0) = "1" then 
                     -- bin 0
                     v.maxFreqConf(asic) := "0000";
                  else
                     -- bin 1
                     v.maxFreqConf(asic) := "0001";
                  end if;
               else
                  -- comparator 1
                  if cmpGtEq(asic, 1) = "1" then 
                     -- bin 2
                     v.maxFreqConf(asic) := "0010";
                  else
                     -- bin 3
                     v.maxFreqConf(asic) := "0011";
                  end if;
               end if;
            -- comparator 13
            else
               -- comparator 9
               if cmpGtEq(asic, 9) = "1" then 
                  -- comparator 2
                  if cmpGtEq(asic, 2) = "1" then 
                     -- bin 4
                     v.maxFreqConf(asic) := "0100";
                  else
                     -- bin 5
                     v.maxFreqConf(asic) := "0101";
                  end if;
               else
                  -- comparator 3
                  if cmpGtEq(asic, 3) = "1" then 
                     -- bin 6
                     v.maxFreqConf(asic) := "0110";
                  else
                     -- bin 7
                     v.maxFreqConf(asic) := "0111";
                  end if;
               end if;
            end if;
         else
            if cmpGtEq(asic, 13) = "1" then
               -- comparator 10
               if cmpGtEq(asic, 10) = "1" then 
                  -- comparator 4
                  if cmpGtEq(asic, 4) = "1" then 
                     -- bin 8
                     v.maxFreqConf(asic) := "1000";
                  else
                     -- bin 9
                     v.maxFreqConf(asic) := "1001";
                  end if;
               else
                  -- comparator 5
                  if cmpGtEq(asic, 5) = "1" then 
                     -- bin 10
                     v.maxFreqConf(asic) := "1010";
                  else
                     -- bin 11
                     v.maxFreqConf(asic) := "1011";
                  end if;
               end if;
            else
               -- comparator 11
               if cmpGtEq(asic, 11) = "1" then 
                  -- comparator 6
                  if cmpGtEq(asic, 6) = "1" then 
                     -- bin 12
                     v.maxFreqConf(asic) := "1100";
                  else
                     -- bin 13
                     v.maxFreqConf(asic) := "1101";
                  end if;
               else
                  -- comparator 7
                  if cmpGtEq(asic, 7) = "1" then 
                     -- bin 14
                     v.maxFreqConf(asic) := "1110";
                  else
                     -- bin 15
                     v.maxFreqConf(asic) := "1111";
                  end if;
               end if;
            end if;
         end if;
         
         
      end loop;
      
      
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      axilCbWriteSlaves(16) <= r.axilWriteSlave;
      axilCbReadSlaves(16)  <= r.axilReadSlave;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   
   GEN_SACI : for i in 3 downto 0 generate
      
      ----------------------------------------------------
      -- 4 x 4 ASICs SACI Registers Interfaces
      -- Wide address space (has to be at the top level)
      ----------------------------------------------------
      U_AxiLiteSaciMaster : entity surf.AxiLiteSaciMaster
         generic map (
            TPD_G              => TPD_G,
            AXIL_CLK_PERIOD_G  => (1.0/AXI_CLK_FREQ_G),
            AXIL_TIMEOUT_G     => 1.0E-3,
            SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
            SACI_CLK_FREERUN_G => false,
            SACI_RSP_BUSSED_G  => true,
            SACI_NUM_CHIPS_G   => 4
         )
         port map (
            -- SACI interface
            saciClk           => regSaciClk(i),
            saciCmd           => regSaciCmd(i),
            saciSelL          => regSaciSelL(i*4+3 downto i*4),
            saciRsp(0)        => saciRsp(i),
            -- bus arbitration
            saciBusReq        => regSaciBusReq(i),
            saciBusGr         => r.regSaciBusGr(i),
            -- AXI-Lite Register Interface
            axilClk           => sysClk,
            axilRst           => sysRst,
            axilReadMaster    => axilReadMasters(i),
            axilReadSlave     => axilReadSlaves(i),
            axilWriteMaster   => axilWriteMasters(i),
            axilWriteSlave    => axilWriteSlaves(i)
         );
   
      ----------------------------------------------------
      -- Matrix Configurators
      ----------------------------------------------------
      U_Epix10kMatrixConfig : entity work.Epix10kMatrixConfig
         generic map (
            TPD_G              => TPD_G,
            AXIL_CLK_PERIOD_G  => (1.0/AXI_CLK_FREQ_G),
            AXIL_TIMEOUT_G     => 1.0E-3,
            SACI_CLK_PERIOD_G  => SACI_CLK_PERIOD_G,
            SACI_CLK_FREERUN_G => false,
            SACI_RSP_BUSSED_G  => true,
            SACI_NUM_CHIPS_G   => 4,
            SIM_SPEEDUP_G      => SIM_SPEEDUP_G
         )
         port map (
            -- SACI interface
            saciClk        => conSaciClk(i),
            saciCmd        => conSaciCmd(i),
            saciSelL       => conSaciSelL(i*4+3 downto i*4),
            saciRsp(0)     => saciRsp(i),
            -- bus arbitration
            saciBusReq     => conSaciBusReq(i),
            saciBusGr      => r.conSaciBusGr(i),
            -- Matrix Config Interface
            clk            => sysClk,
            rst            => sysRst,
            confWrReq      => r.confWrReq,
            confRdReq      => r.confRdReq,
            confSel        => r.confSel(i*4+3 downto i*4),
            confDone       => confDone(i),
            confFail       => confFail(i*4+3 downto i*4),
            maxFreqConf    => r.maxFreqConf(i*4+3 downto i*4),
            memAddr        => memAddr(i*4+3 downto i*4),
            memDout        => memDout(i*4+3 downto i*4),
            memDin         => memDin(i*4+3 downto i*4),
            memWr          => memWr(i*4+3 downto i*4)
         );
      
      ----------------------------------------------------
      -- SACI bus mux
      ----------------------------------------------------
      saciClk(i)  <= 
         regSaciClk(i)                 when r.regSaciBusGr(i) = '1' else 
         conSaciClk(i);
      saciCmd(i)  <= 
         regSaciCmd(i)                 when r.regSaciBusGr(i) = '1' else 
         conSaciCmd(i);
      saciSelL(i*4+3 downto i*4) <= 
         regSaciSelL(i*4+3 downto i*4) when r.regSaciBusGr(i) = '1' else 
         conSaciSelL(i*4+3 downto i*4);
      
   end generate GEN_SACI;
   
   confDoneAll <= confDone(3) and confDone(2) and confDone(1) and confDone(0);
   
   ----------------------------------------------------
   -- Generate Configuration Memories
   ----------------------------------------------------
   GEN_MEM : for i in 15 downto 0 generate
      U_AxiDualPortRam : entity surf.AxiDualPortRam
         generic map (
            TPD_G            => TPD_G,
            MEMORY_TYPE_G    => "block",
--            REG_EN_G         => true,
--            MODE_G           => "read-first",
            AXI_WR_EN_G      => true,
            SYS_WR_EN_G      => true,
            SYS_BYTE_WR_EN_G => false,
            COMMON_CLK_G     => true,
            ADDR_WIDTH_G     => 13,
            DATA_WIDTH_G     => 32
         )
         port map (
            axiClk         => sysClk,
            axiRst         => sysRst,
            axiReadMaster  => axilCbReadMasters(i),
            axiReadSlave   => axilCbReadSlaves(i),
            axiWriteMaster => axilCbWriteMasters(i),
            axiWriteSlave  => axilCbWriteSlaves(i),
            clk            => sysClk,
            we             => memWr(i),
            rst            => sysRst,
            addr           => memAddr(i),
            din            => memDin(i),
            dout           => memDout(i)
         );
   
   end generate GEN_MEM;
   
   ----------------------------------------------------
   -- Generate DSP Comparators
   ----------------------------------------------------
   GEN_ASIC : for asic in 15 downto 0 generate
      GEN_CMP : for cmp in DSP_CMP_NUM_C-1 downto 0 generate
         U_DspCmp : entity surf.DspComparator
            generic map (
               WIDTH_G  => 18
            )
            port map (
               clk     => sysClk,
               rst     => sysRst,
               ain     => cmpAin(asic, cmp),
               bin     => cmpBin(asic, cmp),
               gtEq    => cmpGtEq(asic, cmp)(0)
            );
      end generate GEN_CMP;
   end generate GEN_ASIC;
   
end rtl;

