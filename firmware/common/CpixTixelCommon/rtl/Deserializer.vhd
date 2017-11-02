-------------------------------------------------------------------------------
-- Title         : Tixel and cPix serial stream de-serializer
-- Project       : Tixel/cPix Detector
-------------------------------------------------------------------------------
-- File          : Deserializer.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 11/23/2015
-------------------------------------------------------------------------------
-- Description:
-- This block is responsible for deserialization of the 10b encoded
-- serial output data of the Tixel or Cpix ASIC.
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/23/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity Deserializer is 
   generic (
      TPD_G             : time      := 1 ns;
      IDELAYCTRL_FREQ_G : real      := 200.0;
      IODELAY_GROUP_G   : string    := "DEFAULT_GROUP";
      INVERT_SDATA_G    : boolean   := false;
      IDLE_WORDS_SYNC_G : natural   := 2048
   );
   port ( 
      -- global signals
      bitClk            : in  sl;   -- serial bit DDR clock
      byteClk           : in  sl;   -- serial bit clock div by 5
      byteRst           : in  sl;
      
      -- serial data in
      serDinP           : in  sl;
      serDinM           : in  sl;
            
      -- optional AXI Lite
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      
      -- Deserialized output (byteClk domain)
      rxData            : out slv(19 downto 0);
      rxValid           : out sl;   -- every 2nd rxData is valid
      
      -- optional feedback from decoder
      exReSync          : in  sl := '0';
      validWord         : in  sl := '1'
      
   );
end Deserializer;


-- Define architecture
architecture RTL of Deserializer is

   type StateType is (BIT_SLIP_S, SLIP_WAIT_S, PT0_CHECK_S, INSYNC_S);
   
   type SerType is record
      state          : StateType;
      resync         : sl;
      slip           : sl;
      locked         : sl;
--      tenbOrder      : sl;
      delay          : slv(4 downto 0);
      delayEn        : sl;
      waitCnt        : integer range 0 to 15;
      tryCnt         : integer range 0 to 31;
      idleCnt        : integer range 0 to IDLE_WORDS_SYNC_G;
      lockErrCnt     : integer range 0 to 2**16-1;
      iserdeseOutD   : Slv10Array(63 downto 0);
      --iserdeseOutD1  : slv(9 downto 0);
      --iserdeseOutD2  : slv(9 downto 0);
      --iserdeseOutD3  : slv(9 downto 0);
      twoWords       : slv(19 downto 0);
      valid          : sl;
      rxData         : slv(19 downto 0);
      rxValid        : sl;
   end record;

   constant SER_INIT_C : SerType := (
      state          => BIT_SLIP_S,
      resync         => '0',
      slip           => '0',
      locked         => '0',
--      tenbOrder      => '0',
      delay          => (others=>'0'),
      delayEn        => '0',
      waitCnt        => 0,
      tryCnt         => 0,
      idleCnt        => 0,
      lockErrCnt     => 0,
      iserdeseOutD   => (others=>(others=>'0')),
      --iserdeseOutD1  => (others=>'0'),
      --iserdeseOutD2  => (others=>'0'),
      --iserdeseOutD3  => (others=>'0'),
      twoWords       => (others=>'0'),
      valid          => '0',
      rxData         => (others=>'0'),
      rxValid        => '0'
   );
   
   type RegType is record
      resync         : slv(7 downto 0);
      iserdeseOutD   : Slv10Array(63 downto 0);
      delay          : slv(4 downto 0);
      delayEn        : sl;
--      tenbWordSwappEn : sl;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      resync         => (others=>'0'),
      iserdeseOutD   => (others=>(others=>'0')),
      delay          => (others=>'0'),
      delayEn        => '0',
--      tenbWordSwappEn => '0',
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C
   );


   signal serdR   : SerType := SER_INIT_C;
   signal serdRin : SerType;
   
   signal axilR   : RegType := REG_INIT_C;
   signal axilRin : RegType;
   
   signal bitClkInv     : sl;
   signal serDataBuf    : sl;
   signal serDin        : sl;
   signal serDinDly     : sl;
   signal idleWord      : sl;
   
   signal delayCurr     : slv(4 downto 0);
   signal iserdeseOut   : slv(9 downto 0);
   signal shift1        : sl;
   signal shift2        : sl;
   signal iLocked       : sl;
   signal twoWords      : slv(19 downto 0);
   
   attribute keep : string;                              -- for chipscope
   attribute keep of iserdeseOut : signal is "true";     -- for chipscope
   attribute keep of idleWord : signal is "true";        -- for chipscope
   attribute keep of twoWords : signal is "true";        -- for chipscope
   attribute keep of iLocked : signal is "true";         -- for chipscope
   
   attribute IODELAY_GROUP : string;
   attribute IODELAY_GROUP of U_IDELAYE2 : label is IODELAY_GROUP_G;
   
begin

   -- Input differential buffer
   U_IBUFDS : IBUFDS
   port map (
      I    => serDinP,
      IB   => serDinM,
      O    => serDataBuf
   );
   
   serDin <= not serDataBuf when INVERT_SDATA_G = true else serDataBuf;
   
   -- input delay taps
   U_IDELAYE2 : IDELAYE2
   generic map (
      DELAY_SRC             => "IDATAIN",
      HIGH_PERFORMANCE_MODE => "TRUE",
      IDELAY_TYPE           => "VAR_LOAD",
      IDELAY_VALUE          => 0,
      REFCLK_FREQUENCY      => IDELAYCTRL_FREQ_G,
      SIGNAL_PATTERN        => "DATA"
   )
   port map (
      C           => byteClk,
      REGRST      => '0',
      LD          => serdR.delayEn,
      CE          => '0',
      INC         => '1',
      CINVCTRL    => '0',
      CNTVALUEIN  => serdR.delay,
      IDATAIN     => serDin,
      DATAIN      => '0',
      LDPIPEEN    => '0',
      DATAOUT     => serDinDly,
      CNTVALUEOUT => delayCurr
   );
   
   bitClkInv <= not bitClk;
   
   U_MasterISERDESE2 : ISERDESE2
   generic map (
      DATA_RATE         => "DDR",
      DATA_WIDTH        => 10,
      INTERFACE_TYPE    => "NETWORKING",
      DYN_CLKDIV_INV_EN => "FALSE",
      DYN_CLK_INV_EN    => "FALSE",
      NUM_CE            => 1,
      OFB_USED          => "FALSE",
      IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
      SERDES_MODE       => "MASTER"
   )
   port map (
      Q1           => iserdeseOut(9),
      Q2           => iserdeseOut(8),
      Q3           => iserdeseOut(7),
      Q4           => iserdeseOut(6),
      Q5           => iserdeseOut(5),
      Q6           => iserdeseOut(4),
      Q7           => iserdeseOut(3),
      Q8           => iserdeseOut(2),
      SHIFTOUT1    => shift1,        -- Cascade connection to Slave ISERDES
      SHIFTOUT2    => shift2,        -- Cascade connection to Slave ISERDES
      BITSLIP      => serdR.slip,    -- 1-bit Invoke Bitslip. This can be used with any 
                                     -- DATA_WIDTH, cascaded or not.
      CE1          => '1',           -- 1-bit Clock enable input
      CE2          => '1',           -- 1-bit Clock enable input
      CLK          => bitClk,     -- Fast Source Synchronous SERDES clock from BUFIO
      CLKB         => bitClkInv,  -- Locally inverted clock
      CLKDIV       => byteClk,       -- Slow clock driven by BUFR
      CLKDIVP      => '0',
      D            => '0',
      DDLY         => serDinDly,   -- 1-bit Input signal from IODELAYE1.
      RST          => byteRst,         -- 1-bit Asynchronous reset only.
      SHIFTIN1     => '0',
      SHIFTIN2     => '0',
      -- unused connections
      DYNCLKDIVSEL => '0',
      DYNCLKSEL    => '0',
      OFB          => '0',
      OCLK         => '0',
      OCLKB        => '0',
      O            => open            -- unregistered output of ISERDESE1
   );         

   U_SlaveISERDESE2 : ISERDESE2
   generic map (
      DATA_RATE         => "DDR",
      DATA_WIDTH        => 10,
      INTERFACE_TYPE    => "NETWORKING",
      DYN_CLKDIV_INV_EN => "FALSE",
      DYN_CLK_INV_EN    => "FALSE",
      NUM_CE            => 1,
      OFB_USED          => "FALSE",
      IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
      SERDES_MODE       => "SLAVE"
   )
   port map (
      Q1           => open,
      Q2           => open,
      Q3           => iserdeseOut(1),
      Q4           => iserdeseOut(0),
      Q5           => open,
      Q6           => open,
      Q7           => open,
      Q8           => open,
      SHIFTOUT1    => open,
      SHIFTOUT2    => open,
      SHIFTIN1     => shift1,        -- Cascade connections from Master ISERDES
      SHIFTIN2     => shift2,        -- Cascade connections from Master ISERDES
      BITSLIP      => serdR.slip,    -- 1-bit Invoke Bitslip. This can be used with any 
                                     -- DATA_WIDTH, cascaded or not.
      CE1          => '1',           -- 1-bit Clock enable input
      CE2          => '1',           -- 1-bit Clock enable input
      CLK          => bitClk,     -- Fast Source Synchronous SERDES clock from BUFIO
      CLKB         => bitClkInv,  -- Locally inverted clock
      CLKDIV       => byteClk,       -- Slow clock driven by BUFR.
      CLKDIVP      => '0',
      D            => '0',           -- Slave ISERDES module. No need to connect D, DDLY
      DDLY         => '0',
      RST          => byteRst,         -- 1-bit Asynchronous reset only.
      -- unused connections
      DYNCLKDIVSEL => '0',
      DYNCLKSEL    => '0',
      OFB          => '0',
      OCLK         => '0',
      OCLKB        => '0',
      O            => open            -- unregistered output of ISERDESE1
   );
   
   -- look for idle data word
   idleWord <= '1' when
      serdR.twoWords = "0101111100" & "1010101010" or serdR.twoWords = "1010000011" & "1010101010"   --this is the cPix order
      --serdR.twoWords = "1010101010" & "0101111100" or serdR.twoWords = "1010101010" & "1010000011" -- this should be the IDLE correct order
      else '0';
   
   axilComb : process (serdR, axilR, axilReadMaster, byteRst, axilRst, axilWriteMaster, delayCurr, iserdeseOut, idleWord, validWord, exReSync) is
      variable v      : SerType;
      variable vr     : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      
      v  := serdR;   -- byteClk
      vr := axilR;   -- axilClk

      v.delay   :=  vr.delay;
      v.delayEn :=  vr.delayEn;

      v.slip    := '0';
      --vr.delayEn := '0';
      
      -------------------------------------------------------------------------------------------------
      -- AXIL Interface (axilClk)
      -------------------------------------------------------------------------------------------------
      vr.axilReadSlave.rdata := (others => '0');
      
      -- shift register
      vr.resync := axilR.resync(6 downto 0) & '0';

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, vr.axilWriteSlave, vr.axilReadSlave);
      
      -- override delay readout with the current value from the IDELAYE2
      axiSlaveRegisterR(axilEp, X"00", 0, delayCurr);
      axiSlaveRegister (axilEp, X"04", 0, vr.resync);
      axiSlaveRegisterR(axilEp, X"08", 0, serdR.locked);
      axiSlaveRegisterR(axilEp, X"0C", 0, std_logic_vector(to_unsigned(serdR.lockErrCnt,16)));
      axiSlaveRegister (axilEp, X"10", 0, vr.delay);
      axiSlaveRegister (axilEp, X"14", 0, vr.delayEn);
--      axiSlaveRegister (axilEp, X"14", 0, vr.tenbWordSwappEn);
      
      for i in 0 to 63 loop
         axiSlaveRegisterR(axilEp, std_logic_vector(to_unsigned(256+(i*4), 12)), 0, axilR.iserdeseOutD(i));
      end loop;

      axiSlaveDefault(axilEp, vr.axilWriteSlave, vr.axilReadSlave, AXI_RESP_DECERR_C);
      
      -- cross clock synchronization
      if ((vr.resync /= "00000000") or (exReSync = '1')) then
         v.resync := '1';
      else
         v.resync := '0';
      end if;
      for i in 0 to 63 loop
         vr.iserdeseOutD(i) := serdR.iserdeseOutD(i);
      end loop;
      
      -------------------------------------------------------------------------------------------------
      -- Bit slip state machine (byteClk)
      -------------------------------------------------------------------------------------------------
      
      
      case (serdR.state) is
         when BIT_SLIP_S =>
            v.slip      := '1';
            v.waitCnt   := 0;
            v.state     := SLIP_WAIT_S;

         when SLIP_WAIT_S =>
            v.idleCnt := 0;
            if serdR.waitCnt >= 15 then
               v.waitCnt   := 0;
               v.state := PT0_CHECK_S;
            else 
               v.waitCnt := serdR.waitCnt + 1;
            end if;

         when PT0_CHECK_S =>
            if serdR.valid = '1' then
               if idleWord = '1' then
                  v.idleCnt := serdR.idleCnt + 1;
                  if serdR.idleCnt >= IDLE_WORDS_SYNC_G then
                     v.tryCnt := 0;
                     v.idleCnt := 0;
                     v.state := INSYNC_S;
                  end if;
               else
                  if serdR.tryCnt /= 31 then
                     v.tryCnt := serdR.tryCnt + 1;
                  else
                     v.delay := std_logic_vector(unsigned(delayCurr));-- + to_unsigned(1, 5));
                     v.delayEn := '1';
                     v.tryCnt := 0;
                  end if;
                  v.state := BIT_SLIP_S;
               end if;
            end if;
         
         when INSYNC_S => 
            v.locked := '1';
            if serdR.valid = '1' and validWord = '0' then
               -- count errors - counter can be reset only via the reg access
               if serdR.lockErrCnt /= 65535 then 
                  v.lockErrCnt := serdR.lockErrCnt + 1;  
               end if;
               v.locked := '0';
               v.delay := std_logic_vector(unsigned(delayCurr));-- + to_unsigned(1, 5));
               v.delayEn := '1';
               v.state  := BIT_SLIP_S;
            end if;
         
         when others => null;
         
      end case;
      
      -- latch whole double word
      v.valid := not serdR.valid;
      if serdR.valid = '1' then
         v.twoWords  := serdR.iserdeseOutD(1) & serdR.iserdeseOutD(0);
      end if;
      
      -- reset state machine whenever resync requested 
      if serdR.resync = '1' then
         v.valid := '0';
         v.twoWords := (others=>'0');
         v.lockErrCnt := 0;
         v.locked := '0';
         v.idleCnt := 0;
         --v.state  := BIT_SLIP_S;
         v.state  := PT0_CHECK_S;
      end if;
      
      -------------------------------------------------------------------------------------------------
      -- output registers
      -------------------------------------------------------------------------------------------------
      
      -- 10 bit words pipeline
      v.iserdeseOutD(0) := iserdeseOut;
      for i in 1 to 63 loop
         v.iserdeseOutD(i) := serdR.iserdeseOutD(i-1);
      end loop;
          
      -- output register
      v.rxData    := serdR.twoWords(9 downto 0) & serdR.twoWords(19 downto 10);
      --v.rxData    := serdR.twoWords;
      if serdR.locked = '1' then
         v.rxValid := serdR.valid;
      else
         v.rxValid := '0';
      end if;
      
      
      if (byteRst = '1') then
         v := SER_INIT_C;
      end if;
      
      if (axilRst = '1') then
         vr := REG_INIT_C;
      end if;
      
      
      serdRin        <= v;
      axilRin        <= vr;
      axilWriteSlave <= axilR.axilWriteSlave;
      axilReadSlave  <= axilR.axilReadSlave;
      rxData         <= serdR.rxData;
      rxValid        <= serdR.rxValid;
      
   end process;

   serSeq : process (byteClk) is
   begin
      if (rising_edge(byteClk)) then
         serdR <= serdRin after TPD_G;
      end if;
   end process serSeq;
   
   axilSeq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         axilR <= axilRin after TPD_G;
      end if;
   end process axilSeq;
   
   iLocked <= serdR.locked;
   twoWords <= serdR.twoWords;
   
end RTL;

