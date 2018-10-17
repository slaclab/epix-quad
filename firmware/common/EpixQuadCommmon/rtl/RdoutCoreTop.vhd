-------------------------------------------------------------------------------
-- File       : RdoutCoreTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-07
-- Last update: 2017-07-14
-------------------------------------------------------------------------------
-- Description:
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPkg.all;
use work.SsiPkg.all;

entity RdoutCoreTop is
   generic (
      TPD_G             : time            := 1 ns;
      BANK_COLS_G       : natural         := 48;
      BANK_ROWS_G       : natural         := 178;
      LINE_REVERSE_G    : slv(3 downto 0) := "1010";
      USE_DDR_BUFF_G    : boolean         := false
   );
   port (
      -- ADC interface
      sysClk               : in  sl;
      sysRst               : in  sl;
      -- AXI-Lite Interface for local registers 
      sAxilReadMaster      : in  AxiLiteReadMasterType;
      sAxilReadSlave       : out AxiLiteReadSlaveType;
      sAxilWriteMaster     : in  AxiLiteWriteMasterType;
      sAxilWriteSlave      : out AxiLiteWriteSlaveType;
      -- AXI DDR Buffer Interface (sysClk domain)
      axiWriteMasters      : out AxiWriteMasterArray(3 downto 0);
      axiWriteSlaves       : in  AxiWriteSlaveArray(3 downto 0);
      axiReadMaster        : out AxiReadMasterType;
      axiReadSlave         : in  AxiReadSlaveType;
      buffersRdy           : in  sl;
      -- Opcode to insert into frame
      opCode               : in  slv(7 downto 0);
      -- Run control
      acqBusy              : in  sl;
      acqCount             : in  slv(31 downto 0);
      acqSmplEn            : in  sl;
      readDone             : out sl;
      -- Monitor data for the image stream
      monData              : in  Slv16Array(37 downto 0);
      -- ADC stream input
      adcStream            : in  AxiStreamMasterArray(63 downto 0);
      tpsStream            : in  AxiStreamMasterArray(15 downto 0);
      -- Test stream input
      testStream           : in  AxiStreamMasterArray(63 downto 0);
      -- ASIC digital data signals to/from deserializer
      asicDout             : in  slv(15 downto 0);
      asicDoutTest         : in  slv(15 downto 0);
      asicRoClk            : in  sl;
      roClkTail            : out slv(7 downto 0);
      -- Frame stream output (axisClk domain)
      axisClk              : in  sl;
      axisRst              : in  sl;
      axisMaster           : out AxiStreamMasterType;
      axisSlave            : in  AxiStreamSlaveType
   );
end RdoutCoreTop;

architecture rtl of RdoutCoreTop is
   
begin
   
   G_RdoutBram : if USE_DDR_BUFF_G = false generate
      U_RdoutCore : entity work.RdoutCoreBram
         generic map (
            TPD_G             => TPD_G,
            BANK_COLS_G       => BANK_COLS_G,
            BANK_ROWS_G       => BANK_ROWS_G,
            LINE_REVERSE_G    => LINE_REVERSE_G
         )
         port map (
            -- ADC interface
            sysClk               => sysClk,
            sysRst               => sysRst,
            -- AXI-Lite Interface for local registers 
            sAxilReadMaster      => sAxilReadMaster ,
            sAxilReadSlave       => sAxilReadSlave  ,
            sAxilWriteMaster     => sAxilWriteMaster,
            sAxilWriteSlave      => sAxilWriteSlave ,
            -- Opcode to insert into frame
            opCode               => opCode,
            -- Run control
            acqBusy              => acqBusy,
            acqCount             => acqCount,
            acqSmplEn            => acqSmplEn,
            readDone             => readDone,
            -- Monitor data for the image stream
            monData              => monData,
            -- ADC stream input
            adcStream            => adcStream,
            tpsStream            => tpsStream,
            -- Test stream input
            testStream           => testStream,
            -- ASIC digital data signals to/from deserializer
            asicDout             => asicDout,
            asicDoutTest         => asicDoutTest,
            asicRoClk            => asicRoClk,
            roClkTail            => roClkTail,
            -- Frame stream output (axisClk domain)
            axisClk              => axisClk   ,
            axisRst              => axisRst   ,
            axisMaster           => axisMaster,
            axisSlave            => axisSlave 
         );
         axiWriteMasters      <= (others=>AXI_WRITE_MASTER_INIT_C);
         axiReadMaster        <= AXI_READ_MASTER_INIT_C;
   end generate G_RdoutBram;
   
   G_RdoutDdr : if USE_DDR_BUFF_G = true generate
      U_RdoutCore : entity work.RdoutCoreDdr
         generic map (
            TPD_G             => TPD_G,
            BANK_COLS_G       => BANK_COLS_G,
            BANK_ROWS_G       => BANK_ROWS_G,
            LINE_REVERSE_G    => LINE_REVERSE_G
         )
         port map (
            -- ADC interface
            sysClk               => sysClk,
            sysRst               => sysRst,
            -- AXI-Lite Interface for local registers 
            sAxilReadMaster      => sAxilReadMaster ,
            sAxilReadSlave       => sAxilReadSlave  ,
            sAxilWriteMaster     => sAxilWriteMaster,
            sAxilWriteSlave      => sAxilWriteSlave ,
            -- AXI DDR Buffer Interface (sysClk domain)
            axiWriteMasters      => axiWriteMasters ,
            axiWriteSlaves       => axiWriteSlaves  ,
            axiReadMaster        => axiReadMaster   ,
            axiReadSlave         => axiReadSlave    ,
            buffersRdy           => buffersRdy,
            -- Opcode to insert into frame
            opCode               => opCode,
            -- Run control
            acqBusy              => acqBusy,
            acqCount             => acqCount,
            acqSmplEn            => acqSmplEn,
            readDone             => readDone,
            -- Monitor data for the image stream
            monData              => monData,
            -- ADC stream input
            adcStream            => adcStream,
            tpsStream            => tpsStream,
            -- Test stream input
            testStream           => testStream,
            -- ASIC digital data signals to/from deserializer
            asicDout             => asicDout,
            asicDoutTest         => asicDoutTest,
            asicRoClk            => asicRoClk,
            roClkTail            => roClkTail,
            -- Frame stream output (axisClk domain)
            axisClk              => axisClk   ,
            axisRst              => axisRst   ,
            axisMaster           => axisMaster,
            axisSlave            => axisSlave 
         );
   end generate G_RdoutDdr;
   
end rtl;
