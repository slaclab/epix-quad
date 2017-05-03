-------------------------------------------------------------------------------
-- File       : AsicStreamAxiTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-08-27
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Testbench for design "AsicStreamAxi"
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

----------------------------------------------------------------------------------------------------

entity AsicStreamAxiTb is

end entity AsicStreamAxiTb;

----------------------------------------------------------------------------------------------------

architecture sim of AsicStreamAxiTb is
   
   procedure tixelSerialData ( 
         constant clkPeriod   : time;
         signal sroReq        : in  std_logic;
         signal sroAck        : out std_logic;
         signal dOutP         : out std_logic;
         signal dOutM         : out std_logic
      ) is
      variable t1             : time;
      
      constant idleK          : std_logic_vector(7 downto 0) := x"BC";
      constant idleD          : std_logic_vector(7 downto 0) := x"4A";
      constant sofK           : std_logic_vector(7 downto 0) := x"F7";
      constant sofD           : std_logic_vector(7 downto 0) := x"4A";
      constant eofK           : std_logic_vector(7 downto 0) := x"FD";
      constant eofD           : std_logic_vector(7 downto 0) := x"4A";
      variable dataIn         : std_logic_vector(15 downto 0) := x"0000";
      variable dataOut        : std_logic_vector(9 downto 0);
      variable disparity      : std_logic := '0';
      variable dispOut        : std_logic;
   begin
   
      dOutP <= '0';
      dOutM <= '1';
      sroAck <= '0';
      disparity := '0';
      
      loop
         
         -- idle pattern
         encode8b10b (idleK, '1', disparity, dataOut, dispOut);
         disparity := dispOut;
         for i in 0 to 9 loop
            dOutP <= dataOut(i);
            dOutM <= not dataOut(i);
            wait for clkPeriod;
         end loop;
         encode8b10b (idleD, '0', disparity, dataOut, dispOut);
         disparity := dispOut;
         for i in 0 to 9 loop
            dOutP <= dataOut(i);
            dOutM <= not dataOut(i);
            wait for clkPeriod;
         end loop;
         
         -- data frame if requested
         if sroReq = '1' then
            sroAck <= '1';
            dataIn := x"0000";
            -- SOF
            encode8b10b (sofK, '1', disparity, dataOut, dispOut);
            disparity := dispOut;
            for i in 0 to 9 loop
               dOutP <= dataOut(i);
               dOutM <= not dataOut(i);
               wait for clkPeriod;
            end loop;
            encode8b10b (sofD, '0', disparity, dataOut, dispOut);
            disparity := dispOut;
            for i in 0 to 9 loop
               dOutP <= dataOut(i);
               dOutM <= not dataOut(i);
               wait for clkPeriod;
            end loop;
            -- DATA LOOP
            for i in 0 to 2303 loop
               encode8b10b (dataIn(7 downto 0), '0', disparity, dataOut, dispOut);
               disparity := dispOut;
               for i in 0 to 9 loop
                  dOutP <= dataOut(i);
                  dOutM <= not dataOut(i);
                  wait for clkPeriod;
               end loop;
               encode8b10b (dataIn(15 downto 8), '0', disparity, dataOut, dispOut);
               disparity := dispOut;
               for i in 0 to 9 loop
                  dOutP <= dataOut(i);
                  dOutM <= not dataOut(i);
                  wait for clkPeriod;
               end loop;
               dataIn := std_logic_vector(unsigned(dataIn) + 1);
            end loop;
            sroAck <= '0';
            -- EOF
            encode8b10b (eofK, '1', disparity, dataOut, dispOut);
            disparity := dispOut;
            for i in 0 to 9 loop
               dOutP <= dataOut(i);
               dOutM <= not dataOut(i);
               wait for clkPeriod;
            end loop;
            encode8b10b (eofD, '0', disparity, dataOut, dispOut);
            disparity := dispOut;
            for i in 0 to 9 loop
               dOutP <= dataOut(i);
               dOutM <= not dataOut(i);
               wait for clkPeriod;
            end loop;
         end if;
      
      end loop;
      
   end procedure tixelSerialData ;
   
   
   
   signal asicDoutP  : sl;
   signal asicDoutM  : sl;
   signal sroAck     : sl;
   signal sroReq     : sl;
   signal rxData     : slv(19 downto 0);
   signal rxValid    : sl;
   signal axilClk    : sl := '0';
   signal axisClk    : sl := '0';
   signal bitClk     : sl := '0';
   signal byteClk    : sl := '0';
   signal axilRst    : sl := '1';
   signal axisRst    : sl := '1';
   signal byteRst    : sl := '1';
   signal mAxisMaster   : AxiStreamMasterType;
   signal mAxisSlave    : AxiStreamSlaveType;
   signal acqNo         : slv(31 downto 0);
   signal asicAcq       : sl;

begin

   -- component instantiation

   UUT2 : entity work.Deserializer
   generic map (
      IDLE_WORDS_SYNC_G => 12
   )
   port map ( 
      -- global signals
      bitClk            => bitClk,
      byteClk           => byteClk,
      byteRst           => byteRst,
      
      -- serial data in
      serDinP           => asicDoutP,
      serDinM           => asicDoutM,
      
      -- optional AXI Lite
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => AXI_LITE_READ_MASTER_INIT_C,
      axilReadSlave     => open,
      axilWriteMaster   => AXI_LITE_WRITE_MASTER_INIT_C,
      axilWriteSlave    => open,
      
      -- Deserialized output (byteClk domain)
      rxData            => rxData,
      rxValid           => rxValid,
      
      -- optional feedback from decoder
      validWord         => '1'
      
   );
   
   -- unit under test
   UUT1 : entity work.AsicStreamAxi
   generic map (
      ASIC_NO_G   => "111",
      VC_NO_G     => "0001"
   )
   port map (
      rxClk             => byteClk,
      rxRst             => byteRst,
      rxData            => rxData,
      rxValid           => rxValid,
      axilClk           => axilClk,
      axilRst           => axilRst,
      sAxilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
      sAxilWriteSlave   => open,
      sAxilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
      sAxilReadSlave    => open,
      axisClk           => axisClk,
      axisRst           => axisRst,
      mAxisMaster       => mAxisMaster,
      mAxisSlave        => mAxisSlave,
      acqNo             => acqNo,
      asicAcq           => asicAcq
   );

   -- clock generation
   axilClk <= not axilClk after 10 ns;
   axisClk <= not axisClk after 10 ns;
   bitClk <= not bitClk after 2.5 ns;
   byteClk <= not byteClk after 12.5 ns;
   -- reset generation
   axilRst <= '0' after 80 ns;
   axisRst <= '0' after 80 ns;
   byteRst <= '0' after 100 ns;  
   
   
   -- process emulating tixel data out
   
   process
   begin
   
      tixelSerialData ( 
         clkPeriod   => 2.5 ns,
         sroReq      => sroReq,
         sroAck      => sroAck,
         dOutP       => asicDoutP,
         dOutM       => asicDoutM
      );
      
   end process;
   

   -- waveform generation
   WaveGen_Proc : process
   begin
      
      asicAcq <= '0';
      sroReq <= '0';
      mAxisSlave.tReady <= '1';
      acqNo <= (others=>'0');
      
      loop
      
         wait for 100 us;
         
         sroReq <= '1';
         
         wait until falling_edge(sroAck);
         
         sroReq <= '0';
         
         acqNo <= std_logic_vector(unsigned(acqNo) + 1);
      
      end loop;
      
      
      wait;
   end process WaveGen_Proc;

   

end architecture sim;

