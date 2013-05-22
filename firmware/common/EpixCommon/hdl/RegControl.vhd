-------------------------------------------------------------------------------
-- Title         : Register Control
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : RegControl.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/21/2013
-------------------------------------------------------------------------------
-- Description:
-- Register control block
-------------------------------------------------------------------------------
-- Copyright (c) 2011 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/08/2011: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.EpixTypes.all;
use work.Version.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity RegControl is
   port ( 

      -- Master system clock, 125Mhz
      sysClk          : in  std_logic;
      sysClkRst       : in  std_logic;

      -- Register Bus
      pgpRegOut       : in  RegSlaveOutType;
      pgpRegIn        : out RegSlaveInType;

      -- Configuration
      epixConfig      : out EpixConfigType;

      -- Status
      acqCount        : in  std_logic_vector(31 downto 0);

      -- Readout start command request
      saciReadoutReq  : in  std_logic;
      saciReadoutAck  : out std_logic;

      -- Serial interface
      saciClk         : out std_logic;
      saciSelL        : out std_logic_vector(3 downto 0);
      saciCmd         : out std_logic;
      saciRsp         : in  std_logic_vector(3 downto 0)
   );

end RegControl;

-- Define architecture
architecture RegControl of RegControl is

   -- Local Signals
   signal intConfig  : EpixConfigType;
   signal intRegIn   : RegSlaveInType;
   signal saciRegIn  : SaciMasterInType;
   signal saciRegOut : SaciMasterOutType;
   signal saciSelIn  : SaciMasterInType;
   signal saciSelOut : SaciMasterOutType;
   signal intSelL    : std_logic_vector(3 downto 0);
   signal intResp    : std_logic;
   signal saciCnt    : std_logic_vector(2 downto 0);
   signal intClk     : std_logic;

   -- States
   signal   curState   : std_logic_vector(2 downto 0);
   signal   nxtState   : std_logic_vector(2 downto 0);
   constant ST_IDLE    : std_logic_vector(2 downto 0) := "0000";
   constant ST_REG     : std_logic_vector(2 downto 0) := "0001";
   constant ST_CMD_0   : std_logic_vector(2 downto 0) := "0010";
   constant ST_PAUSE_0 : std_logic_vector(2 downto 0) := "0011";
   constant ST_CMD_1   : std_logic_vector(2 downto 0) := "0100";
   constant ST_PAUSE_1 : std_logic_vector(2 downto 0) := "0101";
   constant ST_CMD_2   : std_logic_vector(2 downto 0) := "0110";
   constant ST_PAUSE_2 : std_logic_vector(2 downto 0) := "0111";
   constant ST_CMD_3   : std_logic_vector(2 downto 0) := "1000";
   constant ST_DONE    : std_logic_vector(2 downto 0) := "1001";
 
   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   ------------------
   -- Outputs
   ------------------
   epixConfig <= intConfig;
   pgpRegIn   <= intRegIn;
   saciSelL   <= intSelL;

   --------------------------------
   -- Register control block
   --------------------------------
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         intConfig          <= EpixConfigInit after TPD_G;
         pgpRegIn.regAck    <= '0'            after TPD_G;
         pgpRegIn.regFail   <= '0'            after TPD_G;
         pgpRegIn.regDataIn <= (others=>'0')  after TPD_G;
         saciRegIn.req      <= '0'            after TPD_G;
      elsif rising_edge(sysClk) then

         -- Defaults
         pgpRegIn.regAck         <= pgpRegOut.regReq after TPD_G;
         pgpRegIn.regFail        <= '0'              after TPD_G;
         pgpRegIn.regDataIn      <= (others=>'0')    after TPD_G;
         intConfig.acqCountReset <= '0'              after TPD_G;
         saciRegIn.req           <= '0'              after TPD_G;

         -- Version register, 0x000000
         if pgpRegOut.regAddr = x"000000" then
            pgpRegIn.regDataIn <= FpgaVersion after TPD_G;

         -- Run Trigger Enable, 0x000001
         elsif pgpRegOut.regAddr = x"000001" then
            if pgpRegIn.regReq = '1' and pgpRegIn.regOp = '1' then
               intConfig.runTriggerEnable <= pgpRegIn.regDataOut(0) after TPD_G;
            end if;
            pgpRegIn.regDataIn(0) <= intConfig.runTriggerEnable after TPD_G;

         -- Run Trigger Delay, 0x000002
         elsif pgpRegOut.regAddr = x"000002" then
            if pgpRegIn.regReq = '1' and pgpRegIn.regOp = '1' then
               intConfig.runTriggerDelay <= pgpRegIn.regDataOut after TPD_G;
            end if;
            pgpRegIn.regDataIn <= intConfig.runTriggerDelay after TPD_G;

         -- DAQ Trigger Enable, 0x000003
         elsif pgpRegOut.regAddr = x"000003" then
            if pgpRegIn.regReq = '1' and pgpRegIn.regOp = '1' then
               intConfig.daqTriggerEnable <= pgpRegIn.regDataOut(0) after TPD_G;
            end if;
            pgpRegIn.regDataIn(0) <= intConfig.daqTriggerEnable after TPD_G;

         -- DAQ Trigger Delay, 0x000004
         elsif pgpRegOut.regAddr = x"000004" then
            if pgpRegIn.regReq = '1' and pgpRegIn.regOp = '1' then
               intConfig.daqTriggerDelay <= pgpRegIn.regDataOut after TPD_G;
            end if;
            pgpRegIn.regDataIn <= intConfig.daqTriggerDelay after TPD_G;

         -- ACQ Counter, 0x000005
         elsif pgpRegOut.regAddr = x"000005" then
            pgpRegIn.regDataIn <= acqCount after TPD_G;

         -- ACQ Count Reset, 0x000006
         elsif pgpRegOut.regAddr = x"000006" then
            if pgpRegIn.regReq = '1' and pgpRegIn.regOp = '1' then
               intConfig.acqCountReset <= '1' after TPD_G;
            end if;

         -- SACI Space, 0x800000
         elsif pgpRegOut.regAddr(23) = '1' then
            slacRegIn.req      <= pgpRegIn.regReq   after TPD_G;
            pgpRegIn.regDataIn <= saciRegOut.rdData after TPD_G;
            pgpRegIn.regAck    <= saciRegOut.ack    after TPD_G;
            pgpRegIn.regFail   <= saciRegOut.fail   after TPD_G;
         end if;

      end if;
   end process;

   -- SACI Constants
   saciRegIn.reset  <= sysClkRst;
   saciRegIn.chip   <= pgpRegIn.regAddr(21 downto 20);
   saciRegIn.op     <= pgpRegIn.regOp;
   saciRegIn.cmd    <= pgpRegIn.regAddr(18 downto 12);
   saciRegIn.addr   <= pgpRegIn.regAddr(11 downto 0);
   saciRegIn.wrData <= pgpRegIn.regDataOut;

   -----------------------------------------------
   -- Readout Init Request
   -----------------------------------------------

   -- Sync states
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         curState <= ST_IDLE after TPD_G;
      elsif rising_edge(sysClk) then
         curState <= nxtState after TPD_G;
      end if;  
   end process;

   -- Async states
   process ( curState, saciRegIn,  saciSelOut, saciReadoutReq ) begin
      saciRegOut.ack    <= '0';
      saciRegOut.fail   <= '0';
      saciRegOut.rdData <= (others=>'0');
      saciSelIn.req     <= '0';
      saciSelIn.chip    <= "00";
      saciSelIn.op      <= '1';
      saciSelIn.cmd     <= "0000000";
      saciSelIn.addr    <= x"000";
      saciSelIn.wrData  <= x"00000000";
      saciReadoutAck    <= '0';
      nxtState          <= curState;

      case curState is 

         when ST_IDLE =>
            if saciRegIn.req = '1' then
               nxtState <= ST_REG;
            elsif saciReadoutReq = '1' then
               nxtState <= ST_CMD_0;
            end if;

         when ST_REG =>
            saciSelIn  <= saciRegIn;
            saciRegOut <= saciSelOut;

            -- Request de-asserted
            if saciRegIn.req = '0' then
               nxtState <= ST_IDLE;
            end if;

         when ST_CMD_0 =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "00";

            -- Transaction acked
            if sacSelOut.ack = '1' then
               nxtState <= ST_PAUSE_0;
            end if;

         when ST_PAUSE_0 =>
            saciSelIn.req <= '0';
            nxtState      <= ST_CMD_1;

         when ST_CMD_1 =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "01";

            -- Transaction acked
            if sacSelOut.ack = '1' then
               nxtState <= ST_PAUSE_0;
            end if;

         when ST_PAUSE_1 =>
            saciSelIn.req <= '0';
            nxtState      <= ST_CMD_2;

         when ST_CMD_2 =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "10";

            -- Transaction acked
            if sacSelOut.ack = '1' then
               nxtState <= ST_PAUSE_2;
            end if;

         when ST_PAUSE_2 =>
            saciSelIn.req <= '0';
            nxtState      <= ST_CMD_3;

         when ST_CMD_3 =>
            saciSelIn.req    <= '1';
            saciSelIn.chip   <= "11";

            -- Transaction acked
            if sacSelOut.ack = '1' then
               nxtState <= ST_DONE;
            end if;

         when ST_DONE =>
            saciReadoutAck <= '1';
            if saciReadoutReq = '0' then
               nxtState <= ST_IDLE;
            end if;

         when others =>
      end case;
   end process;

   -----------------------------------------------
   -- SACI Controller
   -----------------------------------------------

   -- Generate SACI Clock
   process ( sysClk, sysClkRst ) begin
      if ( sysClkRst = '1' ) then
         saciCnt <= (others=>'0') after TPD_G;
      elsif rising_edge(sysClk) then
         saciCnt <= saciCnt + 1 after TPD_G;
      end if;  
   end process;

   --- ~16Mhz
   U_SaciClk: bufg port map ( I => saciCnt(3), O => intClk );

   -- Controller
   U_Saci : entity work.SaciMaster 
     port map (
       clk           => intClk,
       rst           => sysClkRst,
       saciClk       => saciClk,
       saciSelL      => intSelL,
       saciCmd       => saciCmd,
       saciRsp       => intResp,
       saciMasterIn  => saciSelIn,
       saciMasterOut => saciSelOut
   );

   -- Mask response
   intResp <= '0' when saciResp and (not intSelL) = 0 else '1';

end RegControl;

