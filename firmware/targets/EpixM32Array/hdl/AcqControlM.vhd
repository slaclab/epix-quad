-------------------------------------------------------------------------------
-- File       : AcqControlM.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-14
-- Last update: 2017-07-14
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of ''Epix Test Stand Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AcqControlM is
   generic (
      TPD_G             : time                     := 1 ns;
      PGP_LANE_G        : slv(3 downto 0)          := "0000";
      PGP_VC_G          : slv(3 downto 0)          := "0000";
      ASIC_NO_G         : slv(3 downto 0)          := "0000"
   );
   port (
      clk               : in  sl;
      rst               : in  sl;
      adcData           : in  slv(15 downto 0);
      adcValid          : in  sl;
      asicStart         : in  sl;   -- from waveform gen
      asicSample        : in  sl;   -- from waveform gen
      asicReady         : out sl;   -- to waveform gen
      asicGlblRst       : in  sl;
      -- AxiStream output
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisMaster        : out AxiStreamMasterType;
      axisSlave         : in  AxiStreamSlaveType
   );
end AcqControlM;

architecture rtl of AcqControlM is
   
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   type StateType is (
      IDLE_S,
      HDR_S,
      MOVE_S
   );
   
   type RegType is record
      state          : StateType;
      asicReady      : sl;
      acqCnt         : slv(31 downto 0);
      adcData        : slv(15 downto 0);
      txMaster       : AxiStreamMasterType;
      hdrCnt         : integer;
      pixelCnt       : integer;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state          => IDLE_S,
      asicReady      => '0',
      acqCnt         => (others=>'0'),
      adcData        => (others=>'0'),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      hdrCnt         => 0,
      pixelCnt       => 0
   );
   
   signal fifoRst : sl;
   
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal txSlave : AxiStreamSlaveType;
   
begin
   
   
   comb : process (rst, reg, txSlave, asicStart, asicSample, adcData, adcValid, asicGlblRst) is
      variable vreg     : RegType;
   begin
      -- Latch the current value
      vreg := reg;
      
      -- reset strobes
      vreg.asicReady := '0';
      
      -- register valid ADC data
      if adcValid = '1' then
         vreg.adcData := adcData;
      end if;
      
      ------------------------------------------------
      -- AXI transactions
      ------------------------------------------------
      
      if (txSlave.tReady = '1') then
         vreg.txMaster.tValid := '0';
         vreg.txMaster.tLast  := '0';
         vreg.txMaster.tUser  := (others => '0');
         vreg.txMaster.tKeep  := (others => '1');
         vreg.txMaster.tStrb  := (others => '1');
      end if;
      
      ----------------------------------------------------------------------
      -- data stream read state machine
      ----------------------------------------------------------------------
      
      case reg.state is
      
         when IDLE_S =>
            vreg.pixelCnt := 0;
            vreg.hdrCnt := 0;
            vreg.asicReady := '1';
            if asicStart = '1' then
               vreg.state   := HDR_S;
            end if;            
         
         when HDR_S =>
            if vreg.txMaster.tValid = '0' then
               vreg.txMaster.tValid := '1';
               if reg.hdrCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, vreg.txMaster, '1');
                  vreg.txMaster.tData(15 downto 0) := x"00" & PGP_LANE_G & PGP_VC_G;   -- PGP lane and VC
               elsif reg.hdrCnt = 1 then
                  vreg.txMaster.tData(15 downto 0) := x"0000";                         -- PGP lane and VC
               elsif reg.hdrCnt = 2 then
                  vreg.txMaster.tData(15 downto 0) := reg.acqCnt(15 downto 0);         -- ACQ number
               elsif reg.hdrCnt = 3 then
                  vreg.txMaster.tData(15 downto 0) := reg.acqCnt(31 downto 16);        -- ACQ number
                  vreg.acqCnt                      := reg.acqCnt + 1;
               elsif reg.hdrCnt = 4 then
                  vreg.txMaster.tData(15 downto 0) := x"000" & ASIC_NO_G;              -- ASIC number
               else
                  vreg.txMaster.tData(15 downto 0) := x"0000";                         -- ASIC number
                  vreg.state   := MOVE_S;
               end if;
               vreg.hdrCnt := reg.hdrCnt + 1;
            end if;
         
         when MOVE_S =>
            
            -- Check if ready to move data
            if (vreg.txMaster.tValid = '0') and (asicSample = '1') then
               
               -- stream data samples
               vreg.txMaster.tValid := '1';
               vreg.txMaster.tData(15 downto 0) := reg.adcData;
               
               
               -- all samples done
               if reg.pixelCnt = 2047 then
                  -- last in axi stream
                  vreg.txMaster.tLast := '1';
                  vreg.state := IDLE_S;
               else
                  vreg.pixelCnt := reg.pixelCnt + 1;
               end if;
               
            end if;
         
         when others =>
            vreg.state := IDLE_S;
         
      end case;
      
      -- Reset      
      if (rst = '1' or asicGlblRst = '0') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn <= vreg;

      -- Outputs
      asicReady  <= reg.asicReady;
      
   end process comb;

   seqR : process (clk) is
   begin
      if (rising_edge(clk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seqR;
   
   ----------------------------------------------------------------------
   -- Streaming out FIFO
   ----------------------------------------------------------------------
   
   fifoRst <= '1' when rst = '1' or asicGlblRst = '0' else '0';
   
   U_AxisOut : entity work.AxiStreamFifoV2
   generic map (
      -- General Configurations
      TPD_G               => TPD_G,
      PIPE_STAGES_G       => 1,
      SLAVE_READY_EN_G    => true,
      VALID_THOLD_G       => 1,     -- =0 = only when frame ready
      -- FIFO configurations
      BRAM_EN_G           => true,
      USE_BUILT_IN_G      => false,
      GEN_SYNC_FIFO_G     => false,
      CASCADE_SIZE_G      => 1,
      FIFO_ADDR_WIDTH_G   => 12,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 128,
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C
   )
   port map (
      -- Slave Port
      sAxisClk    => clk,
      sAxisRst    => fifoRst,
      sAxisMaster => reg.txMaster,
      sAxisSlave  => txSlave,
      -- Master Port
      mAxisClk    => axisClk,
      mAxisRst    => axisRst,
      mAxisMaster => axisMaster,
      mAxisSlave  => axisSlave
   );
   
   

end rtl;
