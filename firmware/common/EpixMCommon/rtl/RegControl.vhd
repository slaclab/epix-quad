-------------------------------------------------------------------------------
-- File       : RegControl.vhd
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity RegControl is
   generic (
      TPD_G             : time            := 1 ns;
      FPGA_BASE_CLOCK_G : slv(31 downto 0);
      AXI_ERROR_RESP_G  : slv(1 downto 0) := AXI_RESP_OK_C;
      MASTER_AXI_STREAM_CONFIG_G : AxiStreamConfigType   := ssiAxiStreamConfig(4, TKEEP_COMP_C)
   );
   port (
      -- Global Signals
      axiClk            : in  sl;
      axiRst            : in  sl;
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster     : in  AxiLiteReadMasterType;
      axiReadSlave      : out AxiLiteReadSlaveType;
      axiWriteMaster    : in  AxiLiteWriteMasterType;
      axiWriteSlave     : out AxiLiteWriteSlaveType;
      -- acquisition trigger
      acqStart          : in  sl;
      -- ASIC signals
      asicGR            : out sl;
      asicCk            : out sl;
      asicRst           : out sl;
      asicCdsBline      : out sl;
      asicRstComp       : out sl;
      asicSampleN       : out sl;
      asicDinjEn        : out sl;
      asicCKinjEn       : out sl;
      -- debug outputs
      dbgOut            : out slv(1 downto 0);
      -- power enables
      digPowerEn        : out sl;
      anaPowerEn        : out sl;
      fpgaOutEn         : out sl;
      ledEn             : out sl;
      -- Slow ADC env data
      envData           : in  Slv32Array(8 downto 0);
      -- ADC signals
      adcClk            : out sl;
      reqStartupCal     : out sl;
      adcCardPowerUp    : out sl;
      adcData           : in  Slv16Array(1 downto 0);
      adcValid          : in  slv(1 downto 0);
      -- AxiStream output
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisMaster        : out AxiStreamMasterType;
      axisSlave         : in  AxiStreamSlaveType
   );
end RegControl;

architecture rtl of RegControl is
   
   type StateType is (
      IDLE_S,
      HDR_S,
      DATA_S,
      FOOTER_S
   );
   
   type RegType is record
      axiReadSlave      : AxiLiteReadSlaveType;
      axiWriteSlave     : AxiLiteWriteSlaveType;
      txMaster          : AxiStreamMasterType;
      reqStartupD1      : sl;
      digPowerEn        : sl;
      anaPowerEn        : sl;
      fpgaOutEn         : sl;
      ledEn             : sl;
      asicGR            : sl;
      asicCk            : sl;
      asicRst           : sl;
      asicCdsBline      : sl;
      asicRstComp       : sl;
      asicSampleN       : sl;
      asicDinjEn        : sl;
      asicCKinjEn       : sl;
      asicCnt           : slv(31 downto 0);
      asicGRPol         : sl;
      asicGRDly         : slv(30 downto 0);
      asicGRWidth       : slv(30 downto 0);
      asicRstPol        : sl;
      asicRstDly        : slv(30 downto 0);
      asicRstWidth      : slv(30 downto 0);
      asicCdsBlinePol   : sl;
      asicCdsBlineDly   : slv(30 downto 0);
      asicCdsBlineWidth : slv(30 downto 0);
      asicRstCompPol    : sl;
      asicRstCompDly    : slv(30 downto 0);
      asicRstCompWidth  : slv(30 downto 0);
      asicSampleNPol    : sl;
      asicSampleNDly    : slv(30 downto 0);
      asicSampleNWidth  : slv(30 downto 0);
      asicRdStart       : sl;
      asicRdDly         : slv(30 downto 0);
      asicRdTicksCnt    : slv(15 downto 0);
      asicRdHalfPer     : slv(15 downto 0);
      asicRdHalfPerCnt  : slv(15 downto 0);
      adcClk            : sl;
      adcClkCnt         : slv(7 downto 0);
      adcClkHalfPer     : slv(7 downto 0);
      adcSample         : slv(255 downto 0);
      dbgMux            : Slv8Array(1 downto 0);
      dbgOut            : slv(1 downto 0);
      startupAck        : sl;
      startupFail       : sl;
      reqStartupCal     : sl;
      adcCardPowerUp    : sl;
      adcCardPowerUpDly : sl;
      adcData           : Slv14Array(1 downto 0);
      adcPipelineDly    : slv(7 downto 0);
      compOutThreshold  : slv(13 downto 0);
      compOut           : sl;
      state             : StateType;
      wordCnt           : slv(15 downto 0);
      iShCnt            : slv(5 downto 0);
      iRegCnt           : slv(6 downto 0);
      iRegClkCnt        : slv(15 downto 0);
      iRegEn            : sl;
      iRegTrig          : sl;
      iRegDly           : slv(30 downto 0);
      iRegClkHalfPer    : slv(15 downto 0);
      iRegDreg          : slv(47 downto 0);
      iRegDregLow       : slv(31 downto 0);
      iRegDregHigh      : slv(15 downto 0);
      overSampleEn      : sl;
      overSampleSize    : slv(2 downto 0);
      overSampleSizePwr : slv(6 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      axiReadSlave      => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave     => AXI_LITE_WRITE_SLAVE_INIT_C,
      txMaster          => AXI_STREAM_MASTER_INIT_C,
      reqStartupD1      => '0',
      digPowerEn        => '0',
      anaPowerEn        => '0',
      fpgaOutEn         => '0',
      ledEn             => '0',
      asicGR            => '0',
      asicCk            => '0',
      asicRst           => '0',
      asicCdsBline      => '0',
      asicRstComp       => '0',
      asicSampleN       => '0',
      asicDinjEn        => '0',
      asicCKinjEn       => '0',
      asicCnt           => (others=>'1'),
      asicGRPol         => '0',
      asicGRDly         => (others=>'0'),
      asicGRWidth       => (others=>'0'),
      asicRstPol        => '0',
      asicRstDly        => (others=>'0'),
      asicRstWidth      => (others=>'0'),
      asicCdsBlinePol   => '0',
      asicCdsBlineDly   => (others=>'0'),
      asicCdsBlineWidth => (others=>'0'),
      asicRstCompPol    => '0',
      asicRstCompDly    => (others=>'0'),
      asicRstCompWidth  => (others=>'0'),
      asicSampleNPol    => '0',
      asicSampleNDly    => (others=>'0'),
      asicSampleNWidth  => (others=>'0'),
      asicRdStart       => '0',
      asicRdDly         => (others=>'0'),
      asicRdTicksCnt    => (others=>'0'),
      asicRdHalfPer     => (others=>'0'),
      asicRdHalfPerCnt  => (others=>'0'),
      adcClk            => '0',
      adcClkCnt         => (others=>'0'),
      adcClkHalfPer     => x"01",
      adcSample         => (others=>'0'),
      dbgMux            => (others=>(others=>'0')),
      dbgOut            => (others=>'0'),
      startupAck        => '0',
      startupFail       => '0',
      reqStartupCal     => '0',
      adcCardPowerUp    => '0',
      adcCardPowerUpDly => '0',
      adcData           => (others=>(others=>'0')),
      adcPipelineDly    => (others=>'0'),
      compOutThreshold  => (others=>'0'),
      compOut           => '0',
      state             => IDLE_S,
      wordCnt           => (others=>'0'),
      iShCnt            => (others=>'0'),
      iRegCnt           => (others=>'0'),
      iRegClkCnt        => (others=>'0'),
      iRegEn            => '0',
      iRegTrig          => '0',
      iRegDly           => (others=>'0'),
      iRegClkHalfPer    => (others=>'0'),
      iRegDreg          => (others=>'0'),
      iRegDregLow       => (others=>'0'),
      iRegDregHigh      => (others=>'0'),
      overSampleEn      => '0',
      overSampleSize    => (others=>'0'),
      overSampleSizePwr => (others=>'0')
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- Stream settings
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := MASTER_AXI_STREAM_CONFIG_G;
   signal txSlave                : AxiStreamSlaveType;
   signal sAxisCtrl              : AxiStreamCtrlType;
   
   signal adcDataOvs             : Slv16Array(1 downto 0);
   signal adcValidOvs            : slv(1 downto 0);
   
   constant cLane     : slv( 1 downto 0) := "00";
   constant cVC       : slv( 1 downto 0) := "00";
   constant cQuad     : slv( 1 downto 0) := "00";
   constant cOpCode   : slv( 7 downto 0) := x"00";
   constant cZeroWord : slv(31 downto 0) := x"00000000";
   
begin
        
   
   --------------------------------------------------
   -- Instantiate Moving Average cores for oversampling
   --------------------------------------------------
   G_OVERSAMPLE_AVG : for i in 1 downto 0 generate
      signal avgDataTmp       : Slv21Array(1 downto 0);
      signal avgDataTmpValid  : slv(1 downto 0);
      signal avgDataMux       : Slv14Array(1 downto 0);
   begin
      
      U_MovingAvg : entity surf.BoxcarIntegrator
         generic map (
            TPD_G        => TPD_G,
            DATA_WIDTH_G => 14,
            ADDR_WIDTH_G => 7
         )
         port map (
            clk      => axiClk,
            rst      => axiRst,
            -- Configuration, intCount is 0 based, 0 = 1, 1 = 2, 1023 = 1024
            intCount => r.overSampleSizePwr,
            -- Inbound Interface
            ibValid  => adcValid(i),
            ibData   => adcData(i)(13 downto 0),
            -- Outbound Interface
            obValid  => avgDataTmpValid(i),
            obData   => avgDataTmp(i)
         );

      avgDataMux(i) <= 
         avgDataTmp(i)(20 downto 7) when r.overSampleSize = 7 else
         avgDataTmp(i)(19 downto 6) when r.overSampleSize = 6 else
         avgDataTmp(i)(18 downto 5) when r.overSampleSize = 5 else
         avgDataTmp(i)(17 downto 4) when r.overSampleSize = 4 else
         avgDataTmp(i)(16 downto 3) when r.overSampleSize = 3 else
         avgDataTmp(i)(15 downto 2) when r.overSampleSize = 2 else
         avgDataTmp(i)(14 downto 1) when r.overSampleSize = 1 else
         avgDataTmp(i)(13 downto 0);
      
      U_Reg : entity surf.RegisterVector
         generic map (
            TPD_G       => TPD_G,
            WIDTH_G     => 15
         )
         port map (
            clk         => axiClk,
            rst         => axiRst,
            sig_i(14)   => avgDataTmpValid(i),
            sig_i(13 downto 0) => avgDataMux(i),
            reg_o(14)   => adcValidOvs(i),
            reg_o(13 downto 0) => adcDataOvs(i)(13 downto 0)
         );
   
   end generate;
   

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, r, acqStart, envData, txSlave, adcValid, adcData, adcValidOvs, adcDataOvs) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;  
      
      if r.reqStartupCal = '1' then
         v.reqStartupCal   := '0';
         v.startupAck      := '0';
         v.startupFail     := '0';
      end if;
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave);

      -- map out registers    
      axiSlaveRegister (regCon, x"000",  0, v.digPowerEn);
      axiSlaveRegister (regCon, x"000",  1, v.anaPowerEn);
      axiSlaveRegister (regCon, x"000",  2, v.fpgaOutEn);
      axiSlaveRegister (regCon, x"000",  3, v.ledEn);
      axiSlaveRegister (regCon, x"004",  0, v.dbgMux(0));
      axiSlaveRegister (regCon, x"008",  0, v.dbgMux(1));
      axiSlaveRegister (regCon, x"00C",  0, v.adcClkHalfPer);
      axiSlaveRegister (regCon, x"010",  0, v.reqStartupCal);
      axiSlaveRegister (regCon, x"010",  1, v.startupAck);          -- set by Microblaze
      axiSlaveRegister (regCon, x"010",  2, v.startupFail);         -- set by Microblaze
      axiSlaveRegisterR(regCon, x"014",  0, FPGA_BASE_CLOCK_G);
      axiSlaveRegister (regCon, x"018",  0, v.compOutThreshold);
      axiSlaveRegister (regCon, x"01C",  0, v.adcPipelineDly);
      
      axiSlaveRegister (regCon, x"100",  0, v.asicRstPol);
      axiSlaveRegister (regCon, x"104",  0, v.asicRstDly);
      axiSlaveRegister (regCon, x"108",  0, v.asicRstWidth);
      axiSlaveRegister (regCon, x"10C",  0, v.asicCdsBlinePol);
      axiSlaveRegister (regCon, x"110",  0, v.asicCdsBlineDly);
      axiSlaveRegister (regCon, x"114",  0, v.asicCdsBlineWidth);
      axiSlaveRegister (regCon, x"118",  0, v.asicRstCompPol);
      axiSlaveRegister (regCon, x"11C",  0, v.asicRstCompDly);
      axiSlaveRegister (regCon, x"120",  0, v.asicRstCompWidth);
      axiSlaveRegister (regCon, x"124",  0, v.asicSampleNPol);
      axiSlaveRegister (regCon, x"128",  0, v.asicSampleNDly);
      axiSlaveRegister (regCon, x"12C",  0, v.asicSampleNWidth);
      axiSlaveRegister (regCon, x"130",  0, v.asicGRPol);
      axiSlaveRegister (regCon, x"134",  0, v.asicGRDly);
      axiSlaveRegister (regCon, x"138",  0, v.asicGRWidth);
      
      axiSlaveRegister (regCon, x"200",  0, v.asicRdDly);
      axiSlaveRegister (regCon, x"204",  0, v.asicRdHalfPer);
      
      axiSlaveRegister (regCon, x"210",  0, v.iRegEn);
      axiSlaveRegister (regCon, x"214",  0, v.iRegDly);
      axiSlaveRegister (regCon, x"218",  0, v.iRegClkHalfPer);
      axiSlaveRegister (regCon, x"21C",  0, v.iRegDregLow);
      axiSlaveRegister (regCon, x"220",  0, v.iRegDregHigh);
      
      axiSlaveRegister (regCon, x"300", 0, v.overSampleEn      );
      axiSlaveRegister (regCon, x"304", 0, v.overSampleSize    );
      
      if r.overSampleSize = 0 then
         v.overSampleSizePwr   := "0000000";
      elsif r.overSampleSize = 1 then
         v.overSampleSizePwr   := "0000001";
      elsif r.overSampleSize = 2 then
         v.overSampleSizePwr   := "0000011";
      elsif r.overSampleSize = 3 then
         v.overSampleSizePwr   := "0000111";
      elsif r.overSampleSize = 4 then
         v.overSampleSizePwr   := "0001111";
      elsif r.overSampleSize = 5 then
         v.overSampleSizePwr   := "0011111";
      elsif r.overSampleSize = 6 then
         v.overSampleSizePwr   := "0111111";
      else
         v.overSampleSizePwr   := "1111111";
      end if;
      
      for i in 0 to 8 loop
         axiSlaveRegisterR(regCon, x"300"+toSlv(i*4,12),  0, envData(i));
      end loop;
      
      axiSlaveDefault(regCon, v.axiWriteSlave, v.axiReadSlave, AXI_ERROR_RESP_G);
      
      -- ASIC waveforms
      -- programmable ASIC acquisition waveform
      
      v.asicRdStart := '0';
      v.iRegTrig    := '0';
      v.adcSample   := r.adcSample(254 downto 0) & '0';
      
      if acqStart = '1' then
         
         v.asicCnt      := (others=>'0');
         
         v.asicRst      := r.asicRstPol;
         v.asicGR       := r.asicGRPol;
         v.asicCdsBline := r.asicCdsBlinePol;
         v.asicRstComp  := r.asicRstCompPol;
         v.asicSampleN  := r.asicSampleNPol;
         
      elsif r.asicCnt /= x"FFFFFFFF" then
         
         v.asicCnt := r.asicCnt + 1;
         
         if r.asicCnt >= r.asicGRDly and r.asicGRDly /= 0 then
            v.asicGR := not r.asicGRPol;
            if r.asicCnt >= (r.asicGRDly + r.asicGRWidth) then
               v.asicGR := r.asicGRPol;
            end if;
         end if;
         
         if r.asicCnt >= r.asicRstDly and r.asicRstDly /= 0 then
            v.asicRst := not r.asicRstPol;
            if r.asicCnt >= (r.asicRstDly + r.asicRstWidth) then
               v.asicRst := r.asicRstPol;
            end if;
         end if;
         
         if r.asicCnt >= r.asicCdsBlineDly and r.asicCdsBlineDly /= 0 then
            v.asicCdsBline := not r.asicCdsBlinePol;
            if r.asicCnt >= (r.asicCdsBlineDly + r.asicCdsBlineWidth) then
               v.asicCdsBline := r.asicCdsBlinePol;
            end if;
         end if;
         
         if r.asicCnt >= r.asicRstCompDly and r.asicRstCompDly /= 0 then
            v.asicRstComp := not r.asicRstCompPol;
            if r.asicCnt >= (r.asicRstCompDly + r.asicRstCompWidth) then
               v.asicRstComp := r.asicRstCompPol;
            end if;
         end if;
         
         if r.asicCnt >= r.asicSampleNDly and r.asicSampleNDly /= 0 then
            v.asicSampleN := not r.asicSampleNPol;
            if r.asicCnt >= (r.asicSampleNDly + r.asicSampleNWidth) then
               v.asicSampleN := r.asicSampleNPol;
            end if;
         end if;
         
         -- start the readout
         if r.asicCnt = r.asicRdDly and r.asicRdDly /= 0 then
            v.asicRdStart := '1';
         end if;
         
         -- start the inj register shifting
         if r.iRegEn = '1' and r.asicCnt = r.iRegDly and r.iRegDly /= 0 then
            v.iRegTrig := '1';
         end if;
         
      end if;
      
      -- injection shift register
      v.iRegDreg := r.iRegDregHigh & r.iRegDregLow;
      v.asicDinjEn := r.iRegDreg(conv_integer(r.iShCnt));
      if r.iRegTrig = '1' then
        v.iRegCnt := toSlv(96, 7);
        v.iRegClkCnt := r.iRegClkHalfPer - 1;
        v.asicCKinjEn := '0';
        v.iShCnt := (others=>'0');
      end if;      
      if r.iRegCnt /= 0 then
         if r.iRegClkCnt /= 0 then
            v.iRegClkCnt := r.iRegClkCnt - 1;
         else
            v.iRegCnt := r.iRegCnt - 1;
            v.iRegClkCnt := r.iRegClkHalfPer - 1;
            v.asicCKinjEn := not r.asicCKinjEn;
            -- shift reg clock falling edge
            if v.asicCKinjEn = '0' and r.asicCKinjEn = '1' and r.iShCnt < 47 then
               v.iShCnt := r.iShCnt + 1;
            end if;
         end if;
      end if;

      
      -- readout clock generation
      if r.asicRdStart = '1' then
         v.asicRdTicksCnt := toSlv(4608, 16);
         v.asicRdHalfPerCnt := r.asicRdHalfPer - 1;
         v.asicCk := '0';
      end if;
      if r.asicRdTicksCnt /= 0 then
         if r.asicRdHalfPerCnt /= 0 then
            v.asicRdHalfPerCnt := r.asicRdHalfPerCnt - 1;
         else
            v.asicCk := not r.asicCk;
            v.asicRdHalfPerCnt := r.asicRdHalfPer - 1;
            v.asicRdTicksCnt := r.asicRdTicksCnt - 1;
            if r.asicCk = '0' then
               v.adcSample(0) := '1';
            end if;
         end if;
      end if;
      
      -- ADC clock generation
      if r.adcClkCnt >= r.adcClkHalfPer - 1 then
         v.adcClk := not r.adcClk;
         v.adcClkCnt := (others => '0');
      else
         v.adcClkCnt := r.adcClkCnt + 1;
      end if;
      
      -- ADC serdes reset      
      if r.digPowerEn = '1' and r.anaPowerEn = '1' and r.fpgaOutEn = '1' then
         v.adcCardPowerUp := '1';
      else
         v.adcCardPowerUp := '0';
      end if;
      v.adcCardPowerUpDly := r.adcCardPowerUp;
      
      -- debug signal selection
      for i in 0 to 1 loop
         if r.dbgMux(i) = 0 then
            v.dbgOut(i) := acqStart;
         elsif r.dbgMux(i) = 1 then
            v.dbgOut(i) := r.asicGR;
         elsif r.dbgMux(i) = 2 then
            v.dbgOut(i) := r.asicCk;
         elsif r.dbgMux(i) = 3 then
            v.dbgOut(i) := r.asicRst;
         elsif r.dbgMux(i) = 4 then
            v.dbgOut(i) := r.asicCdsBline;
         elsif r.dbgMux(i) = 5 then
            v.dbgOut(i) := r.asicRstComp;
         elsif r.dbgMux(i) = 6 then
            v.dbgOut(i) := r.asicSampleN;
         elsif r.dbgMux(i) = 7 then
            v.dbgOut(i) := r.asicDinjEn;
         elsif r.dbgMux(i) = 8 then
            v.dbgOut(i) := r.asicCKinjEn;
         elsif r.dbgMux(i) = 9 then
            v.dbgOut(i) := r.adcClk;
         else
            v.dbgOut(i) := r.adcSample(conv_integer(r.adcPipelineDly));
         end if;
      end loop;
      
      --------------------------------------------------
      -- Data stream FSM
      --------------------------------------------------
      
      for i in 0 to 1 loop
         if r.overSampleEn = '0' then
            if adcValid(i) = '1' then
               v.adcData(i) := adcData(i)(13 downto 0);
            end if;
         else
            if adcValidOvs(i) = '1' then
               v.adcData(i) := adcDataOvs(i)(13 downto 0);
            end if;
         end if;
      end loop;
      
      if r.adcData(1) >= r.compOutThreshold then
         v.compOut := '1';
      else
         v.compOut := '0';
      end if;
      
      -- Reset strobing Signals
      if (txSlave.tReady = '1') then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tKeep  := (others => '1');
         v.txMaster.tStrb  := (others => '1');
      end if;
      
      case r.state is
         
         -- wait trigger   
         when IDLE_S =>
            if acqStart = '1' then
               v.state := HDR_S;
            end if;
            v.wordCnt := (others=>'0');
         
         when HDR_S =>
            if v.txMaster.tValid = '0' then
               v.wordCnt := r.wordCnt + 1;
               v.txMaster.tValid := '1';
               if r.wordCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, v.txMaster, '1');
                  v.txMaster.tData(15 downto 0) := x"00" & "00" & cLane & "00" & cVC;
               elsif r.wordCnt = 1 then
                  v.txMaster.tData(15 downto 0) := x"0000";
               elsif r.wordCnt = 2 then
                  v.txMaster.tData(15 downto 0) := x"0000";
               elsif r.wordCnt = 3 then
                  v.txMaster.tData(15 downto 0) := x"0" & "00" & cQuad & cOpCode;
               else
                  v.txMaster.tData(15 downto 0) := (others=>'0');
                  if r.wordCnt = 15 then
                     v.state := DATA_S;
                     v.wordCnt := (others=>'0');
                  end if;
               end if;
            end if;
            
         when DATA_S =>
            if acqStart = '1' then
               -- another trigger during data acquisition (error)
               v.txMaster.tLast  := '1';
               ssiSetUserEofe(SLAVE_AXI_CONFIG_C, v.txMaster, '1');
               v.state := IDLE_S;
            elsif r.adcSample(conv_integer(r.adcPipelineDly)) = '1' then
               if v.txMaster.tValid = '1' then
                  -- axis not ready during data acquisition (error)
                  v.txMaster.tLast  := '1';
                  ssiSetUserEofe(SLAVE_AXI_CONFIG_C, v.txMaster, '1');
                  v.state := IDLE_S;
               end if;
               v.wordCnt := r.wordCnt + 1;
               v.txMaster.tValid := '1';
               v.txMaster.tData(15 downto 0) := '0' & v.compOut & r.adcData(0);
               if r.wordCnt >= 2303 then
                  v.state := FOOTER_S;
                  v.wordCnt := (others=>'0');
               end if;
            end if;
         
         when FOOTER_S =>
            if v.txMaster.tValid = '0' then
               v.wordCnt := r.wordCnt + 1;
               v.txMaster.tValid := '1';
               v.txMaster.tData(15 downto 0) := (others=>'0');
               if r.wordCnt >= 8 then
                  v.txMaster.tLast  := '1';
                  ssiSetUserEofe(SLAVE_AXI_CONFIG_C, v.txMaster, '0');
                  v.state := IDLE_S;
               end if;
            end if;
         
         when others =>
            v.state := IDLE_S;
            
      end case;
      
      
      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      --------------------------
      -- Outputs 
      --------------------------
      axiReadSlave   <= r.axiReadSlave;
      axiWriteSlave  <= r.axiWriteSlave;
      digPowerEn     <= r.digPowerEn;
      anaPowerEn     <= r.anaPowerEn;
      fpgaOutEn      <= r.fpgaOutEn;
      ledEn          <= r.ledEn;
      asicGR         <= r.asicGR;         -- add to waveform?
      asicCk         <= r.asicCk;
      asicRst        <= r.asicRst;
      asicCdsBline   <= r.asicCdsBline;
      asicRstComp    <= r.asicRstComp;
      asicSampleN    <= r.asicSampleN;
      asicDinjEn     <= r.asicDinjEn;     -- not yet implemented
      asicCKinjEn    <= r.asicCKinjEn;    -- not yet implemented
      dbgOut         <= r.dbgOut;
      adcClk         <= r.adcClk;
      adcCardPowerUp <= r.adcCardPowerUp and not r.adcCardPowerUpDly;
      reqStartupCal  <= r.reqStartupCal;
      
   end process comb;
   
   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
   ----------------------------------------------------------------------
   -- Output Axis FIFO
   ----------------------------------------------------------------------
   
   U_AxisBuf : entity surf.AxiStreamFifoV2
   generic map (
      -- General Configurations
      TPD_G                => TPD_G,
      PIPE_STAGES_G        => 1,
      SLAVE_READY_EN_G     => true,
      VALID_THOLD_G        => 1,     -- =0 = only when frame ready
      -- FIFO configurations
      GEN_SYNC_FIFO_G      => false,
      CASCADE_SIZE_G       => 1,
      FIFO_ADDR_WIDTH_G    => 5,
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G   => SLAVE_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G  => MASTER_AXI_CONFIG_C
   )
   port map (
      -- Slave Port
      sAxisClk          => axiClk,
      sAxisRst          => axiRst,
      sAxisMaster       => r.txMaster,
      sAxisSlave        => txSlave,
      sAxisCtrl         => sAxisCtrl,
      -- Master Port
      mAxisClk          => axisClk,
      mAxisRst          => axisRst,
      mAxisMaster       => axisMaster,
      mAxisSlave        => axisSlave
   );

   
end rtl;
