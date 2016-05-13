-------------------------------------------------------------------------------
-- Title         : Test-bench of CpixCore
-- Project       : Cpix Detector
-------------------------------------------------------------------------------
-- File          : TB_CpixCore.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 01/19/2016
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Maciej Kwiatkowski. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/19/2016: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.Code8b10bPkg.all;
use work.EpixPkgGen2.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.Pgp2bPkg.all;
use work.CpixPkg.all;

entity TB_CpixCore is 

end TB_CpixCore;


-- Define architecture
architecture beh of TB_CpixCore is
   
   constant TPD_G             : time := 1 ns;
   
   signal coreClk      : std_logic;
   signal axiRst       : std_logic;
   
   signal asicRdClk     : sl;
   signal asicRdClkRst  : sl;
   signal bitClk        : sl;
   signal bitClkRst     : sl;
   signal byteClk       : sl;
   signal byteClkRst    : sl;
   signal iAsicRoClk : sl;

   signal asicDoutP           : slv(1 downto 0);
   signal asicDoutM           : slv(1 downto 0);
   
   signal dataOut    : Slv8Array(1 downto 0);
   signal dataKOut   : slv(1 downto 0);
   signal codeErr    : slv(1 downto 0);
   signal dispErr    : slv(1 downto 0);
   signal inSync     : slv(1 downto 0);
   signal sroAck     : slv(1 downto 0);
   signal sroReq     : slv(1 downto 0);
   
   
   signal asicEnA      : std_logic;
   signal asicEnB      : std_logic;
   signal asicVid      : std_logic;
   signal iAsicPpbe    : std_logic;
   signal iAsicPpmat   : std_logic;
   signal iAsicR0      : std_logic;
   signal asicSRO      : std_logic;
   signal iAsicGrst    : std_logic;
   signal iAsicSync    : std_logic;   
   signal iAsicAcq     : std_logic;   
   signal saciPrepReadoutReq     : std_logic;   
   signal saciPrepReadoutAck     : std_logic;     
   signal acqStart     : std_logic;     
   
   signal epixStatus       : EpixStatusType;
   signal epixConfig       : EpixConfigType;
   signal cpixConfig       : CpixConfigType := CPIX_CONFIG_INIT_C;
   
   constant NUMBER_OF_ASICS   : natural := 2;
   
   signal cntAcquisition  : std_logic_vector(31 downto 0);
   signal cntSequence     : std_logic_vector(31 downto 0);
   signal cntAReadout     : std_logic;
   signal frameReq        : std_logic;
   signal frameAck        : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal frameErr        : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal headerAck       : std_logic_vector(NUMBER_OF_ASICS-1 downto 0);
   signal timeoutReq      : std_logic;
   
   signal cntFrameDone     : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
   signal cntFrameError    : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
   signal cntCodeError     : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
   signal cntToutError     : Slv32Array(NUMBER_OF_ASICS-1 downto 0);
   signal framerAxisMaster : AxiStreamMasterArray(NUMBER_OF_ASICS-1 downto 0);
   signal framerAxisSlave  : AxiStreamSlaveArray(NUMBER_OF_ASICS-1 downto 0);
   signal pgpAxisMaster    : AxiStreamMasterType;
   signal pgpAxisSlave     : AxiStreamSlaveType;
   

   procedure cpixSerialData ( 
         signal roClk         : in  std_logic;
         signal sroReq        : in  std_logic;
         signal sroAck        : out std_logic;
         signal dOutP         : out std_logic;
         signal dOutM         : out std_logic
      ) is
      variable t1             : time;
      variable dataClkPeriod  : time;
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
      
      -- wait for stable clock
      wait for 10 us;
   
      --wait until rising_edge(roClk);
      t1 := now;
      
      wait until rising_edge(roClk);
      dataClkPeriod := (now - t1)/40;
      
      -- the above does not work due to accumulating error
      -- fixed period
      dataClkPeriod := 2.5 ns;
      
      loop
         
         -- idle pattern
         encode8b10b (idleK, '1', disparity, dataOut, dispOut);
         disparity := dispOut;
         for i in 0 to 9 loop
            dOutP <= dataOut(i);
            dOutM <= not dataOut(i);
            wait for dataClkPeriod;
         end loop;
         encode8b10b (idleD, '0', disparity, dataOut, dispOut);
         disparity := dispOut;
         for i in 0 to 9 loop
            dOutP <= dataOut(i);
            dOutM <= not dataOut(i);
            wait for dataClkPeriod;
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
               wait for dataClkPeriod;
            end loop;
            encode8b10b (sofD, '0', disparity, dataOut, dispOut);
            disparity := dispOut;
            for i in 0 to 9 loop
               dOutP <= dataOut(i);
               dOutM <= not dataOut(i);
               wait for dataClkPeriod;
            end loop;
            -- DATA LOOP
            for i in 0 to 2303 loop
               encode8b10b (dataIn(7 downto 0), '0', disparity, dataOut, dispOut);
               disparity := dispOut;
               for i in 0 to 9 loop
                  dOutP <= dataOut(i);
                  dOutM <= not dataOut(i);
                  wait for dataClkPeriod;
               end loop;
               encode8b10b (dataIn(15 downto 8), '0', disparity, dataOut, dispOut);
               disparity := dispOut;
               for i in 0 to 9 loop
                  dOutP <= dataOut(i);
                  dOutM <= not dataOut(i);
                  wait for dataClkPeriod;
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
               wait for dataClkPeriod;
            end loop;
            encode8b10b (eofD, '0', disparity, dataOut, dispOut);
            disparity := dispOut;
            for i in 0 to 9 loop
               dOutP <= dataOut(i);
               dOutM <= not dataOut(i);
               wait for dataClkPeriod;
            end loop;
         end if;
      
      end loop;
      
   end procedure cpixSerialData ;
   

begin
   
   -- clocks and resets
   
   process
   begin
      coreClk <= '0';
      wait for 5 ns;
      coreClk <= '1';
      wait for 5 ns;
   end process;
   
   process
   begin
      asicRdClk <= '0';
      wait for 100 ns;
      asicRdClk <= '1';
      wait for 100 ns;
   end process;
   
   process
   begin
      wait for 1.8 ns;
      loop
         bitClk <= '0';
         wait for 2.5 ns;
         bitClk <= '1';
         wait for 2.5 ns;
      end loop;
   end process;
   
   process
   begin
      axiRst <= '1';
      wait for 10 ns;
      axiRst <= '0';
      wait;
   end process;
   
   process
   begin
      bitClkRst <= '1';
      wait for 5 ns;
      bitClkRst <= '0';
      wait;
   end process;
   
   process
   begin
      asicRdClkRst <= '1';
      wait for 200 ns;
      asicRdClkRst <= '0';
      wait;
   end process;
   
   
   -- process emulating cPix data out
   
   process
   begin
   
      cpixSerialData ( 
         roClk       => iAsicRoClk,
         sroReq      => sroReq(0),
         sroAck      => sroAck(0),
         dOutP       => asicDoutM(0),
         dOutM       => asicDoutP(0)
      );
      
   end process;
   
   process
   begin
   
      cpixSerialData ( 
         roClk       => iAsicRoClk,
         sroReq      => sroReq(1),
         sroAck      => sroAck(1),
         dOutP       => asicDoutM(1),
         dOutM       => asicDoutP(1)
      );
      
   end process;

   -- triggers
   
   process
   begin

      acqStart <= '0';
   
      wait for 100 us;
      
      acqStart <= '1';
      
      wait for 10 ns;
      
   end process;
   
   epixConfig.totalPixelsToRead <= std_logic_vector(to_unsigned(2304, 32));
   epixConfig.asicMask <= "0011";
   epixConfig.daqTriggerEnable <= '1';
   epixConfig.manualPinControl <= (others=>'0');
   epixStatus.acqCount <= (others=>'0');
   
   cpixConfig.cpixRunToAcq         <= std_logic_vector(to_unsigned(100, 32));
   cpixConfig.cpixR0ToAcq          <= std_logic_vector(to_unsigned(50, 32));
   cpixConfig.cpixAcqWidth         <= std_logic_vector(to_unsigned(50, 32));
   cpixConfig.cpixAcqToCnt         <= std_logic_vector(to_unsigned(100, 32));
   cpixConfig.cpixSyncWidth        <= std_logic_vector(to_unsigned(5, 32));
   cpixConfig.cpixSROWidth         <= std_logic_vector(to_unsigned(5, 32));
   cpixConfig.cpixNRuns            <= std_logic_vector(to_unsigned(4, 32));
   cpixConfig.cpixCntAnotB         <= x"5A5A5A5A";
   cpixConfig.syncMode             <= "00";
   saciPrepReadoutAck              <= '1';
   --epixConfig.manualPinControl(1)  <= '1';
   --epixConfig.manualPinControl(2)  <= '1';
   --epixConfig.asicPins(1)          <= '1';
   --epixConfig.asicPins(2)          <= '1';
   
   --DUTs

   U_BUFR : BUFR
   generic map (
      SIM_DEVICE  => "7SERIES",
      BUFR_DIVIDE => "5"
   )
   port map (
      I   => bitClk,
      O   => byteClk,
      CE  => '1',
      CLR => '0'
   );
   
   U_RdPwrUpRst : entity work.PwrUpRst
   generic map (
      DURATION_G => 20000000,
      SIM_SPEEDUP_G => true
   )
   port map (
      clk      => byteClk,
      rstOut   => byteClkRst
   );
   
   roClkDdr_i : ODDR 
   port map ( 
      Q  => iAsicRoClk,
      C  => asicRdClk,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => '0',
      S  => '0'
   );
   
   ------------------------------------------
   -- Common ASIC acquisition control            --
   ------------------------------------------      
   U_ASIC_Acquisition : entity work.CpixAcquisition
   generic map(
      NUMBER_OF_ASICS   => NUMBER_OF_ASICS
   )
   port map(
   
      -- global signals
      sysClk            => coreClk,
      sysClkRst         => axiRst,
   
      -- trigger
      acqStart          => acqStart,
      
      -- control/status signals (byteClk)
      cntAcquisition    => cntAcquisition,
      cntSequence       => cntSequence,
      cntAReadout       => cntAReadout,
      frameReq          => frameReq,
      frameAck          => frameAck,
      frameErr          => frameErr,
      headerAck         => headerAck,
      timeoutReq        => timeoutReq,
      
      epixConfig        => epixConfig,
      cpixConfig        => cpixConfig,
      saciReadoutReq    => saciPrepReadoutReq,
      saciReadoutAck    => saciPrepReadoutAck,
      
      -- ASICs signals
      asicEnA           => asicEnA,
      asicEnB           => asicEnB,
      asicVid           => asicVid,
      asicPPbe          => iAsicPpbe,
      asicPpmat         => iAsicPpmat,
      asicR0            => iAsicR0,
      asicSRO           => asicSRO,
      asicGlblRst       => iAsicGrst,
      asicSync          => iAsicSync,
      asicAcq           => iAsicAcq
      
   );
   
   
   G_ASIC : for i in 0 to NUMBER_OF_ASICS-1 generate  
      
      -------------------------------------------------------
      -- ASIC deserializers
      -------------------------------------------------------
      U_AsicDeser : entity work.Deserializer
      port map ( 
         bitClk         => bitClk,
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         
         -- serial data in
         asicDoutP      => asicDoutP(i),
         asicDoutM      => asicDoutM(i),
         
         -- status
         patternCnt     => open,
         testDone       => open,
         inSync         => inSync(i),
         
         -- decoded data out
         dataOut        => dataOut(i),
         dataKOut       => dataKOut(i),
         codeErr        => codeErr(i),
         dispErr        => dispErr(i),
         
         -- control
         resync         => '0',
         delay          => "00000"
      );
      
      -------------------------------------------------------
      -- ASIC AXI stream framers
      -------------------------------------------------------
      U_ASIC_Framer : entity work.Framer
      generic map(
         ASIC_NUMBER_G  => std_logic_vector(to_unsigned(i, 4))
      )
      port map(
         -- global signals
         sysClk         => coreClk,
         sysRst         => axiRst,
         byteClk        => byteClk,
         byteClkRst     => byteClkRst,
         
         -- decoded data signals (byteClk)
         inSync         => inSync(0),
         dataOut        => dataOut(0),
         dataKOut       => dataKOut(0),
         codeErr        => codeErr(0),
         dispErr        => dispErr(0),
         
         -- control/status signals (byteClk)
         cntAcquisition => cntAcquisition,
         cntSequence    => cntSequence,
         cntAReadout    => cntAReadout,
         frameReq       => frameReq     ,
         frameAck       => frameAck(i)     ,
         frameErr       => frameErr(i)     ,
         headerAck      => headerAck(i)    ,
         timeoutReq     => timeoutReq   ,
         cntFrameDone   => cntFrameDone(i) ,
         cntFrameError  => cntFrameError(i),
         cntCodeError   => cntCodeError(i) ,
         cntToutError   => cntToutError(i) ,
         cntReset       => '0'     ,
         epixConfig     => epixConfig,
         
         -- AXI Stream Master Port (sysClk)
         mAxisMaster    => framerAxisMaster(i),
         mAxisSlave     => framerAxisSlave(i)
      );
      
      -- start of readout handshake
      -- only for simulation procedure
      process
      begin
      
         sroReq(i) <= '0';
      
         wait until rising_edge(asicSRO);
         
         sroReq(i) <= '1';
         
         wait until rising_edge(sroAck(i));
         
      end process;
   
   end generate;
   
   -------------------------------------------------------
   -- AXI stream mux
   -------------------------------------------------------
   U_AxiStreamMux : entity work.AxiStreamMux
   generic map(
      NUM_SLAVES_G   => NUMBER_OF_ASICS
   )
   port map(
      -- Clock and reset
      axisClk        => coreClk,
      axisRst        => axiRst,
      -- Slaves
      sAxisMasters   => framerAxisMaster,
      sAxisSlaves    => framerAxisSlave,
      -- Master
      mAxisMaster    => pgpAxisMaster,
      mAxisSlave     => pgpAxisSlave
      
   );
   
   -- only for the simulation
   pgpAxisSlave.tReady <= '1';
   
   --process
   --begin
   --   
   --   timeoutReq <= '0';
   --   
   --   wait for 101589 ns;
   --   
   --   timeoutReq <= '1';
   --   
   --   wait for 200 ns;
   --   
   --   timeoutReq <= '0';
   --   
   --   wait;
   --   
   --end process;

end beh;







-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 
-- LIBRARY ieee;
-- use work.all;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;
-- 
-- library unisim;
-- use unisim.vcomponents.all;
-- 
-- use work.StdRtlPkg.all;
-- use work.Code8b10bPkg.all;
-- use work.EpixPkgGen2.all;
-- use work.AxiLitePkg.all;
-- use work.AxiStreamPkg.all;
-- use work.SsiPkg.all;
-- use work.SsiCmdMasterPkg.all;
-- use work.Pgp2bPkg.all;
-- use work.CpixPkg.all;
-- 
-- entity TB_CpixCore is 
-- 
-- end TB_CpixCore;
-- 
-- 
-- -- Define architecture
-- architecture beh of TB_CpixCore is
--    
--    constant TPD_G             : time := 1 ns;
--    
--    signal coreClk      : std_logic;
--    signal axiRst      : std_logic;
--    
--    signal asicRdClk     : sl;
--    signal asicRdClkRst  : sl;
--    signal bitClk        : sl;
--    signal bitClkRst     : sl;
--    signal byteClk       : sl;
--    signal byteClkRst    : sl;
--    signal iAsicRoClk : sl;
-- 
--    signal asicDoutP           : slv(1 downto 0);
--    signal asicDoutM           : slv(1 downto 0);
--    
--    signal dataOut    : Slv8Array(1 downto 0);
--    signal dataKOut   : slv(1 downto 0);
--    signal codeErr    : slv(1 downto 0);
--    signal dispErr    : slv(1 downto 0);
--    signal inSync     : slv(1 downto 0);
--    signal sroAck     : slv(1 downto 0);
--    signal sroReq     : slv(1 downto 0);
--    
--    
--    signal asicEnA      : std_logic;
--    signal asicEnB      : std_logic;
--    signal asicVid      : std_logic;
--    signal iAsicPpbe    : std_logic;
--    signal iAsicPpmat   : std_logic;
--    signal iAsicR0      : std_logic;
--    signal asicSRO      : std_logic;
--    signal iAsicGrst    : std_logic;
--    signal iAsicSync    : std_logic;   
--    signal iAsicAcq     : std_logic;   
--    signal saciPrepReadoutReq     : std_logic;   
--    signal saciPrepReadoutAck     : std_logic;   
--    signal readPend     : std_logic;   
--    signal acqDone     : std_logic;   
--    signal readCntA     : std_logic;   
--    signal acqStart     : std_logic;     
--    
--    signal epixStatus       : EpixStatusType;
--    signal epixConfig       : EpixConfigType;
--    signal cpixConfig       : CpixConfigType := CPIX_CONFIG_INIT_C;
--    
--    signal userAxisMaster   : AxiStreamMasterType;
--    signal userAxisSlave    : AxiStreamSlaveType;
--    
-- 
--    procedure cpixSerialData ( 
--          signal roClk         : in  std_logic;
--          signal sroReq        : in  std_logic;
--          signal sroAck        : out std_logic;
--          signal dOutP         : out std_logic;
--          signal dOutM         : out std_logic
--       ) is
--       variable t1             : time;
--       variable dataClkPeriod  : time;
--       constant idleK          : std_logic_vector(7 downto 0) := x"BC";
--       constant idleD          : std_logic_vector(7 downto 0) := x"4A";
--       constant sofK           : std_logic_vector(7 downto 0) := x"F7";
--       constant sofD           : std_logic_vector(7 downto 0) := x"4A";
--       constant eofK           : std_logic_vector(7 downto 0) := x"FD";
--       constant eofD           : std_logic_vector(7 downto 0) := x"4A";
--       variable dataIn         : std_logic_vector(15 downto 0) := x"0000";
--       variable dataOut        : std_logic_vector(9 downto 0);
--       variable disparity      : std_logic := '0';
--       variable dispOut        : std_logic;
--    begin
--    
--       dOutP <= '0';
--       dOutM <= '1';
--       sroAck <= '0';
--       disparity := '0';
--       
--       -- wait for stable clock
--       wait for 10 us;
--    
--       --wait until rising_edge(roClk);
--       t1 := now;
--       
--       wait until rising_edge(roClk);
--       dataClkPeriod := (now - t1)/40;
--       
--       -- the above does not work due to accumulating error
--       -- fixed period
--       dataClkPeriod := 2.5 ns;
--       
--       loop
--          
--          -- idle pattern
--          encode8b10b (idleK, '1', disparity, dataOut, dispOut);
--          disparity := dispOut;
--          for i in 0 to 9 loop
--             dOutP <= dataOut(i);
--             dOutM <= not dataOut(i);
--             wait for dataClkPeriod;
--          end loop;
--          encode8b10b (idleD, '0', disparity, dataOut, dispOut);
--          disparity := dispOut;
--          for i in 0 to 9 loop
--             dOutP <= dataOut(i);
--             dOutM <= not dataOut(i);
--             wait for dataClkPeriod;
--          end loop;
--          
--          -- data frame if requested
--          if sroReq = '1' then
--             sroAck <= '1';
--             dataIn := x"0000";
--             -- SOF
--             encode8b10b (sofK, '1', disparity, dataOut, dispOut);
--             disparity := dispOut;
--             for i in 0 to 9 loop
--                dOutP <= dataOut(i);
--                dOutM <= not dataOut(i);
--                wait for dataClkPeriod;
--             end loop;
--             encode8b10b (sofD, '0', disparity, dataOut, dispOut);
--             disparity := dispOut;
--             for i in 0 to 9 loop
--                dOutP <= dataOut(i);
--                dOutM <= not dataOut(i);
--                wait for dataClkPeriod;
--             end loop;
--             -- DATA LOOP
--             for i in 0 to 2303 loop
--                encode8b10b (dataIn(7 downto 0), '0', disparity, dataOut, dispOut);
--                disparity := dispOut;
--                for i in 0 to 9 loop
--                   dOutP <= dataOut(i);
--                   dOutM <= not dataOut(i);
--                   wait for dataClkPeriod;
--                end loop;
--                encode8b10b (dataIn(15 downto 8), '0', disparity, dataOut, dispOut);
--                disparity := dispOut;
--                for i in 0 to 9 loop
--                   dOutP <= dataOut(i);
--                   dOutM <= not dataOut(i);
--                   wait for dataClkPeriod;
--                end loop;
--                dataIn := std_logic_vector(unsigned(dataIn) + 1);
--             end loop;
--             sroAck <= '0';
--             -- EOF
--             encode8b10b (eofK, '1', disparity, dataOut, dispOut);
--             disparity := dispOut;
--             for i in 0 to 9 loop
--                dOutP <= dataOut(i);
--                dOutM <= not dataOut(i);
--                wait for dataClkPeriod;
--             end loop;
--             encode8b10b (eofD, '0', disparity, dataOut, dispOut);
--             disparity := dispOut;
--             for i in 0 to 9 loop
--                dOutP <= dataOut(i);
--                dOutM <= not dataOut(i);
--                wait for dataClkPeriod;
--             end loop;
--          end if;
--       
--       end loop;
--       
--    end procedure cpixSerialData ;
--    
-- 
-- begin
--    
--    -- clocks and resets
--    
--    process
--    begin
--       coreClk <= '0';
--       wait for 5 ns;
--       coreClk <= '1';
--       wait for 5 ns;
--    end process;
--    
--    process
--    begin
--       asicRdClk <= '0';
--       wait for 100 ns;
--       asicRdClk <= '1';
--       wait for 100 ns;
--    end process;
--    
--    process
--    begin
--       wait for 1.8 ns;
--       loop
--          bitClk <= '0';
--          wait for 2.5 ns;
--          bitClk <= '1';
--          wait for 2.5 ns;
--       end loop;
--    end process;
--    
--    process
--    begin
--       axiRst <= '1';
--       wait for 10 ns;
--       axiRst <= '0';
--       wait;
--    end process;
--    
--    process
--    begin
--       bitClkRst <= '1';
--       wait for 5 ns;
--       bitClkRst <= '0';
--       wait;
--    end process;
--    
--    process
--    begin
--       asicRdClkRst <= '1';
--       wait for 200 ns;
--       asicRdClkRst <= '0';
--       wait;
--    end process;
--    
--    
--    -- process emulating cPix data out
--    
--    process
--    begin
--    
--       cpixSerialData ( 
--          roClk       => iAsicRoClk,
--          sroReq      => sroReq(0),
--          sroAck      => sroAck(0),
--          dOutP       => asicDoutM(0),
--          dOutM       => asicDoutP(0)
--       );
--       
--    end process;
--    
--    process
--    begin
--    
--       cpixSerialData ( 
--          roClk       => iAsicRoClk,
--          sroReq      => sroReq(1),
--          sroAck      => sroAck(1),
--          dOutP       => asicDoutM(1),
--          dOutM       => asicDoutP(1)
--       );
--       
--    end process;
--    
--    
--    -- start of readout handshake
--    
--    process
--    begin
--    
--       sroReq(0) <= '0';
--    
--       wait until rising_edge(asicSRO);
--       
--       sroReq(0) <= '1';
--       
--       wait until rising_edge(sroAck(0));
--       
--    end process;
--    
--    process
--    begin
-- 
--       sroReq(1) <= '0';
--    
--       wait until rising_edge(asicSRO);
--       
--       sroReq(1) <= '1';
--       
--       wait until rising_edge(sroAck(1));
--       
--    end process;
--    
--    -- triggers
--    
--    process
--    begin
-- 
--       acqStart <= '0';
--    
--       wait for 100 us;
--       
--       acqStart <= '1';
--       
--       wait for 10 ns;
--       
--    end process;
--    
--    epixConfig.totalPixelsToRead <= std_logic_vector(to_unsigned(2304, 32));
--    epixConfig.asicMask <= "0011";
--    epixConfig.daqTriggerEnable <= '1';
--    epixConfig.manualPinControl <= (others=>'0');
--    epixStatus.acqCount <= (others=>'0');
--    
--    cpixConfig.cpixRunToAcq         <= std_logic_vector(to_unsigned(100, 32));
--    cpixConfig.cpixR0ToAcq          <= std_logic_vector(to_unsigned(50, 32));
--    cpixConfig.cpixAcqWidth         <= std_logic_vector(to_unsigned(50, 32));
--    cpixConfig.cpixAcqToCnt         <= std_logic_vector(to_unsigned(100, 32));
--    cpixConfig.cpixSyncWidth        <= std_logic_vector(to_unsigned(5, 32));
--    cpixConfig.cpixSROWidth         <= std_logic_vector(to_unsigned(5, 32));
--    cpixConfig.cpixNRuns            <= std_logic_vector(to_unsigned(4, 32));
--    cpixConfig.cpixCntAnotB         <= x"ffffffff";
--    cpixConfig.syncMode             <= "10";
--    saciPrepReadoutAck              <= '1';
--    --epixConfig.manualPinControl(1)  <= '1';
--    --epixConfig.manualPinControl(2)  <= '1';
--    --epixConfig.asicPins(1)          <= '1';
--    --epixConfig.asicPins(2)          <= '1';
--    
--    --DUTs
-- 
--    U_BUFR : BUFR
--    generic map (
--       SIM_DEVICE  => "7SERIES",
--       BUFR_DIVIDE => "5"
--    )
--    port map (
--       I   => bitClk,
--       O   => byteClk,
--       CE  => '1',
--       CLR => '0'
--    );
--    
--    U_RdPwrUpRst : entity work.PwrUpRst
--    generic map (
--       DURATION_G => 20000000,
--       SIM_SPEEDUP_G => true
--    )
--    port map (
--       clk      => byteClk,
--       rstOut   => byteClkRst
--    );
--    
--    roClkDdr_i : ODDR 
--    port map ( 
--       Q  => iAsicRoClk,
--       C  => asicRdClk,
--       CE => '1',
--       D1 => '1',
--       D2 => '0',
--       R  => '0',
--       S  => '0'
--    );
--    
--    
--    -------------------------------------------------------
--    -- ASIC deserializers
--    -------------------------------------------------------
--    G_ASIC : for i in 0 to 1 generate 
--       
--       U_AsicDeser : entity work.Deserializer
--       port map ( 
--          bitClk         => bitClk,
--          byteClk        => byteClk,
--          byteClkRst     => byteClkRst,
--          
--          -- serial data in
--          asicDoutP      => asicDoutP(i),
--          asicDoutM      => asicDoutM(i),
--          
--          -- status
--          patternCnt     => open,
--          testDone       => open,
--          inSync         => inSync(i),
--          
--          -- decoded data out
--          dataOut        => dataOut(i),
--          dataKOut       => dataKOut(i),
--          codeErr        => codeErr(i),
--          dispErr        => dispErr(i),
--          
--          -- control
--          resync         => '0',
--          delay          => "00000"
--       );
--    
--    end generate;
--    
--    
--    ---------------------
--    -- Acq control     --
--    ---------------------      
--    U_AcqControl : entity work.CpixAcqControl
--       port map (
--          sysClk          => coreClk,
--          sysClkRst       => axiRst,
--          
--          acqStart        => acqStart,
--          acqDone         => acqDone,
--          readPend        => readPend,
--          readCntA        => readCntA,
--          
--          epixConfig      => epixConfig,
--          cpixConfig      => cpixConfig,
--          
--          saciReadoutReq  => saciPrepReadoutReq,
--          saciReadoutAck  => saciPrepReadoutAck,
--          
--          asicEnA         => asicEnA,
--          asicEnB         => asicEnB,
--          asicVid         => asicVid,
--          asicPPbe        => iAsicPpbe,
--          asicPpmat       => iAsicPpmat,
--          asicR0          => iAsicR0,
--          asicSRO         => asicSRO,
--          asicGlblRst     => iAsicGrst,
--          asicSync        => iAsicSync,
--          asicAcq         => iAsicAcq
--    );
--  
--    ---------------------
--    -- Readout control --
--    ---------------------      
--    U_ReadoutControl : entity work.CpixReadoutControl
--       generic map (
--         TPD_G                      => TPD_G,
--         MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)
--       )
--       port map (
--          sysClk         => coreClk,
--          sysClkRst      => axiRst,
--          byteClk        => byteClk,
--          byteClkRst     => byteClkRst,
--          
--          acqStart       => acqStart,   -- acq trigger
--          acqDone        => acqDone,    -- signal from CpixAcqControl to CpixReadoutControl to request the readout on next acq trigger
--          readPend       => readPend,   -- signal to CpixAcqControl from CpixReadoutControl to stop he acquisition when the readout is pending
--          readCntA       => readCntA,
--          
--          inSync         => inSync,
--          dataOut        => dataOut,
--          dataKOut       => dataKOut,
--          codeErr        => codeErr,
--          dispErr        => dispErr,
--          
--          epixConfig     => epixConfig,   -- total pixels to read
--          cpixConfig     => cpixConfig,
--          acqCount       => epixStatus.acqCount,
--          seqCount       => epixStatus.seqCount,
--          envData        => epixStatus.envData,
--          errorFrame     => open,
--          errorCode      => open,
--          
--          mAxisMaster    => userAxisMaster,
--          mAxisSlave     => userAxisSlave
--       );
--       
--       userAxisSlave.tReady <= '1';
--    
--    
-- 
-- end beh;

