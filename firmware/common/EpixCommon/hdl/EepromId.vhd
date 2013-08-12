------------------------------------------------------------------------------
-- Title         : Petacache SliceCore FPGA, FMC Dimm ID Prom Block
-- Project       : Petacache RCE Board
-------------------------------------------------------------------------------
-- File          : EeproId.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 12/19/2007
-------------------------------------------------------------------------------
-- Description:
-- Contains controller for DS2411 serial ID Prom On Flash DIMM.
-- SerClkIn is asserted for one clock every 6.55us.
-------------------------------------------------------------------------------
-- Copyright (c) 2007 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 12/19/2007: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity EepromId is 
	port ( 

		-- PGP Clock & Reset Signals
		pgpClk    : in  std_logic;
		pgpRst    : in  std_logic;
		serClkEn  : in  std_logic;

		-- FMC DIMM ID Prom Signals
		fdSerDin  : in  std_logic;
		fdSerDout : out std_logic;
		fdSerDenL : out std_logic;

		-- Serial Number
		fdSerial  : out std_logic_vector(63 downto 0);
		fdValid   : out std_logic;

		-- Eeprom Access
		address   : in std_logic_vector(15 downto 0);
		dataIn	: in std_logic_vector(63 downto 0);
		dataOut   : out std_logic_vector(63 downto 0);
		dataValid : out std_logic;
		readReq   : in std_logic;
		writeReq  : in std_logic
);
end EepromId;


-- Define architecture
architecture EepromId of EepromId is

	-- Local Signals
	signal setOutLow    		: std_logic;
	signal fdValidSet   		: std_logic;
	signal dataValidSet 		: std_logic;
	signal dataValidRst     : std_logic;
	signal bitSetS      		: std_logic;
	signal bitSetD      		: std_logic;
	signal bitCntRst    		: std_logic;
	signal bitCntEn     		: std_logic;
	signal byteCntRst   		: std_logic;
	signal byteCntEn    		: std_logic;
	signal timeCntRst   		: std_logic;
	signal timeCnt      		: std_logic_vector(13  downto 0);
	signal bitCnt       		: std_logic_vector(5  downto 0);
	signal byteCnt      		: std_logic_vector(4  downto 0);
	signal copyScratch  		: std_logic;
	signal copyScratchSet	: std_logic;
	signal copyScratchRst	: std_logic;
	signal readSer      		: std_logic;
	signal readSerSet			: std_logic;
	signal readSerRst			: std_logic;
	signal write        		: std_logic;
	signal writeSet			: std_logic;
	signal writeRst			: std_logic;
	signal oneWire      		: std_logic;

	-- States
	constant ST_START        : std_logic_vector(4 downto 0) := "00000";
	constant ST_RESET        : std_logic_vector(4 downto 0) := "00001";
	constant ST_WAIT         : std_logic_vector(4 downto 0) := "00010";
	constant ST_WRITE_R      : std_logic_vector(4 downto 0) := "00011";
	constant ST_WRITE_S      : std_logic_vector(4 downto 0) := "00100";
	constant ST_PAUSE        : std_logic_vector(4 downto 0) := "00101";
	constant ST_READ         : std_logic_vector(4 downto 0) := "00110";
	constant ST_IDLE         : std_logic_vector(4 downto 0) := "00111";
	constant ST_W_SCRATCH    : std_logic_vector(4 downto 0) := "01000";
	constant ST_W_TARGET	    : std_logic_vector(4 downto 0) := "01001";
	constant ST_W_DATA       : std_logic_vector(4 downto 0) := "01010";
	constant ST_C_SCRATCH    : std_logic_vector(4 downto 0) := "01011";
	constant ST_W_ZEROS      : std_logic_vector(4 downto 0) := "01100";
	constant ST_WAIT_WRITE   : std_logic_vector(4 downto 0) := "01101";
	constant ST_READ_DATA    : std_logic_vector(4 downto 0) := "01110";
	constant ST_R_DATA       : std_logic_vector(4 downto 0) := "01111";
	constant ST_RECEIVE_CRC  : std_logic_vector(4 downto 0) := "10000";
	constant ST_WAIT_SCRATCH : std_logic_vector(4 downto 0) := "10001";
	signal   curState        : std_logic_vector(4 downto 0);
	signal   nxtState        : std_logic_vector(4 downto 0);

	attribute keep : string;
	attribute keep of curState : signal is "true";
	attribute keep of oneWire  : signal is "true";

	-- Register delay for simulation
	constant tpd:time := 0.5 ns;

begin

	-- Dout is always zero
	fdSerDout <= '0';
	fdSerDenL <= not setOutLow;

	-- Save input for ChipScope
	process(pgpClk) begin
		if rising_edge(pgpClk) then
			oneWire   <= fdSerDin;
		end if;
	end process;

	-- Sync state logic
	process ( pgpClk, pgpRst ) begin
		if pgpRst = '1' then
			fdSerial    <= (others=>'0') after tpd;
			fdValid     <= '0'           after tpd;
			dataValid   <= '0'	        after tpd;
			timeCnt     <= (others=>'0') after tpd;
			bitCnt      <= (others=>'0') after tpd;
			byteCnt     <= (others=>'0') after tpd;
			copyScratch <= '0'           after tpd;
			write       <= '0'           after tpd;
			readSer     <= '0'           after tpd;
			curState    <= ST_START      after tpd;
		elsif rising_edge(pgpClk) then

			-- Shift new serial data
			if fdValidSet = '1' then
				fdValid <= '1' after tpd;
			end if;

			-- Shift new EEPROM data
			if dataValidSet = '1' then
				dataValid <= '1' after tpd;
			elsif dataValidRst = '1' then
				dataValid <= '0' after tpd;
			end if;

			-- Bit Set Of Received Serial Data
			if bitSetS = '1' then
				fdSerial(conv_integer(bitCnt)) <= fdSerDin after tpd;
			end if;

			-- Bit Set Of Received EEPROM Data
			if bitSetD = '1' then
				dataOut(conv_integer((byteCnt * "00001000") + bitCnt)) <= fdSerDin after tpd;
			end if;

			-- Bit Counter
			if bitCntRst = '1' then
				bitCnt <= (others=>'0') after tpd;
			elsif bitCntEn = '1' then
				bitCnt <= bitCnt + 1 after tpd;
			end if;

			-- Byte Counter
			if byteCntRst = '1' then
				byteCnt <= (others=>'0') after tpd;
			elsif byteCntEn = '1' then
				byteCnt <= byteCnt + 1 after tpd;
			end if;

			-- Time Counter
			if timeCntRst = '1' then
				timeCnt <= (others=>'0') after tpd;
			elsif serClkEn = '1' then
				timeCnt <= timeCnt + 1 after tpd;
			end if;

			-- Set and Reset copyScratch signal
			if pgpRst = '1' or copyScratchRst = '1' then
				copyScratch <= '0';
			elsif copyScratchSet = '1' then
				copyScratch <= '1';
			end if;

			-- Set and Reset write signal
			if pgpRst = '1' or writeRst = '1' then
				write <= '0';
			elsif writeSet = '1' then
				write <= '1';
			end if;

			-- Set and Reset readSer signal
			if pgpRst = '1' or readSerRst = '1' then
				readSer <= '0';
			elsif readSerSet = '1' then
				readSer <= '1';
			end if;

			-- State
				curState <= nxtState after tpd;

		end if;
	end process;


	-- State Machine
	process ( curState, timeCnt, bitCnt, serClkEn, writeReq, readReq, copyScratch, write, bytecnt, readSer, address, dataIn  ) begin

		-- State machine
		case curState is

			-- Start State
			when ST_START =>
				setOutLow      <= '0';
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '1';
				bitSetS        <= '0';
				bitSetD        <= '0';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				readSerSet     <= '1';
				readSerRst     <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
	 			copyScratchSet <= '0';
				copyScratchRst <= '1';
	
				-- Wait 830us
				if timeCnt = 127 then
					nxtState   <= ST_RESET;
					timeCntRst <= '1';
				else
					nxtState   <= curState;
					timeCntRst <= '0';
				end if;

			-- Reset Link
			when ST_RESET =>
				setOutLow      <= '1';
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				copyScratchSet <= '0';
				copyScratchRst <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Continue for 500us
				if timeCnt = 77 then
					nxtState   <= ST_WAIT;
					timeCntRst <= '1';
				else
					nxtState   <= curState;
					timeCntRst <= '0';
				end if;

			-- Wait after reset
			when ST_WAIT =>
				setOutLow      <= '0';
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
            bitSetD        <= '0';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst	   <= '1';
				byteCntEn      <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				copyScratchSet <= '0';
				copyScratchRst <= '0';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Wait 500us
				if timeCnt = 77 then
					if readSer = '1' then
						nxtState   <= ST_WRITE_R;
						timeCntRst <= '1';
					else
						nxtState   <= ST_WRITE_S;
						timeCntRst <= '1';
					end if;
				else
					nxtState   <= curState;
					timeCntRst <= '0';
				end if;

			-- Write Command Bits To PROM (0x33)
			when ST_WRITE_R =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if bitCnt = 2 or bitCnt = 3 or bitCnt = 6 or bitCnt = 7 then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					byteCntRst <= '1';
					byteCntEn  <= '0';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 7  then
						bitCntRst <= '1';
						nxtState  <= ST_PAUSE;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

			-- Write Command Bits To PROM (0xCC)
			when ST_WRITE_S =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				copyScratchSet <= '0';
				copyScratchRst <= '0';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if bitCnt = 0 or bitCnt = 1 or bitCnt = 4 or bitCnt = 5 then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 7  then
						bitCntRst <= '1';
						nxtState  <= ST_IDLE;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

			-- Delay after write
			when ST_PAUSE =>
				setOutLow      <= '0';
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Wait 60us
				if timeCnt = 10 then
					nxtState   <= ST_READ;
					timeCntRst <= '1';
				else
					nxtState   <= curState;
					timeCntRst <= '0';
				end if;

			-- Read Data Bits From Prom
			when ST_READ =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					bitSetS    <= '0';
					nxtState   <= curState;

				-- Sample data at 13.1uS
				elsif timeCnt = 2 and serClkEn = '1' then
					setOutLow  <= '0';
					bitCntEn   <= '0';
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitSetS    <= '1';
					nxtState   <= curState;

				-- Recovery
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitSetS    <= '0';
					bitCntRst  <= '0';
					nxtState   <= curState;

				-- Done with bit
				else
					setOutLow  <= '0';
					timeCntRst <= '1';
					bitCntEn   <= '1';
					bitSetS    <= '0';

					-- Done with write
					if bitCnt = 63 then
						fdValidSet <= '1';
						bitCntRst <= '1';
						nxtState  <= ST_IDLE;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

			-- Done with read
			when ST_IDLE =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				timeCntRst     <= '1';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				setOutLow      <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				readSerSet     <= '0';
				readSerRst     <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				copyScratchSet <= '0';
				copyScratchRst <= '0';

				if copyScratch = '1' and serClkEn = '1' then
					nxtState <= ST_WAIT_SCRATCH;
				elsif writeReq = '1' and serClkEn = '1' then
					nxtState <= ST_W_SCRATCH;
				elsif readReq = '1' and serClkEn = '1' then
					nxtState <= ST_READ_DATA;
				else
					nxtState <= curState;
	    		end if; 

			-- Write command bits to EEPROM (0x0F)
			when ST_W_SCRATCH =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '1';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				writeSet       <= '1';
				writeRst       <= '0';
				copyScratchSet <= '0';
				copyScratchRst <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					bitCntEn   <= '0';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if bitCnt = 4 or bitCnt = 5 or bitCnt = 6 or bitCnt = 7 then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 7  then
						bitCntRst <= '1';
						nxtState  <= ST_W_TARGET;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;
	
			-- Writes target address    
			when ST_W_TARGET =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				writeSet       <= '0';
				writeRst       <= '0';
				copyScratchSet <= '0';
				copyScratchRst <= '0';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					bitCntEn   <= '0';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if address(conv_integer(bitCnt)) = '0' then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
						nxtState   <= curState;
						timeCntRst <= '0';
						bitCntRst  <= '0';
						bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 15  then
						if write = '1' then
							bitCntRst <= '1';
							nxtState  <= ST_W_DATA;
						elsif copyScratch = '1' then
							bitCntRst <= '1';
							nxtState  <= ST_W_ZEROS;
						else
							bitCntRst <= '1';
							nxtState  <= ST_R_DATA;
						end if;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

			-- Write data to scratchpad
			when ST_W_DATA =>
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				fdValidSet     <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
			 	copyScratchSet <= '1';
				copyScratchRst <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					byteCntEn  <= '0';
					byteCntRst <= '0';
					setOutLow  <= '1';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if dataIn(conv_integer((byteCnt * "00001000") + bitCnt)) = '0' then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';
					byteCntEn  <= '0';
					byteCntRst <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';
					byteCntRst <= '0';
					byteCntEn  <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					setOutLow  <= '0';

					-- Done with write
					if byteCnt = 7 then   
						if bitCnt = 7  then
							bitCntRst      <= '1';
							bitCntEn       <= '0';
							byteCntRst     <= '1';
							byteCntEn      <= '0';
							copyScratchRst <= '0';
							copyScratchSet <= '1';
							readSerSet     <= '0';
							readSerRst     <= '1';
							writeSet       <= '0';
							writeRst       <= '1';
							nxtState       <= ST_RECEIVE_CRC;
							--nxtState       <= ST_RESET;
						else
							bitCntRst  <= '0';
							byteCntEn  <= '0';
							byteCntRst <= '0';
							bitCntEn   <= '1';
							nxtState   <= curState;
						end if;
					else
						if bitCnt = 7  then
							bitCntRst  <= '1';
							bitCntEn   <= '0';
							byteCntRst <= '0';
							byteCntEn  <= '1';
							nxtState   <= curState;
						else
							bitCntRst <= '0';
							byteCntEn <= '0';
							byteCntRst <= '0';
							bitCntEn   <= '1';
							nxtState   <= curState;
						end if;
					end if;
				end if;        

			-- Receives CRC from DS 2431
			when ST_RECEIVE_CRC =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					byteCntEn  <= '0';
					byteCntRst <= '0';
					setOutLow  <= '1';
					nxtState   <= curState;

				-- Sample data at 13.1uS
				elsif timeCnt = 2 and serClkEn = '1' then
					setOutLow  <= '0';
					bitCntEn   <= '0';
					timeCntRst <= '0';
					bitCntRst  <= '0';
					byteCntRst <= '0';
					byteCntEn  <= '0';
					nxtState   <= curState;

				-- Recovery
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					byteCntRst <= '0';
					byteCntEn  <= '0';
					nxtState   <= curState;

				-- Done with bit
				else
					setOutLow  <= '0';
					timeCntRst <= '1';

					-- Done with write
					if byteCnt = 2 then
						if bitCnt = 7  then
							bitCntRst  <= '1';
							bitCntEn   <= '0';
							byteCntRst <= '1';
							byteCntEn  <= '0';
							nxtState  <= ST_RESET;
						else
							bitCntRst <= '0';
							byteCntRst<= '0';
							byteCntEn <= '0';
							bitCntEn  <= '1';
							nxtState  <= curState;
						end if;
					else
						if bitCnt = 7  then
							bitCntRst  <= '1';
							bitCntEn	 <= '0';
							byteCntRst <= '0';
							byteCntEn  <= '1';
							nxtState   <= curState;
						else
							bitCntRst <= '0';
							bitCntEn	<= '1';
							byteCntRst<= '0';
							byteCntEn <= '0';
							nxtState  <= curState;
						end if;
					end if;
				end if;        

			-- Delay after write
			when ST_WAIT_SCRATCH =>
				setOutLow      <= '0';
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '0';

				-- Wait 60us
				if timeCnt = 10 then
					nxtState   <= ST_C_SCRATCH;
					timeCntRst <= '1';
				else
					nxtState   <= curState;
					timeCntRst <= '0';
				end if;

	 		-- Write command bits to EEPROM (0x55)
         when ST_C_SCRATCH =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '1';
				copyScratchRst <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					bitCntEn   <= '0';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if bitCnt = 1 or bitCnt = 3 or bitCnt = 5 or bitCnt = 7 then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 7  then
						bitCntRst <= '1';
						nxtState  <= ST_W_TARGET;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

			-- Write 8 zeros
			when ST_W_ZEROS =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '1';
				copyScratchRst <= '0';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					setOutLow  <= '1';
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if bitCnt = 7 or bitCnt = 6 or bitCnt = 5 or bitCnt = 4 or bitCnt = 3 then
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 7  then
						bitCntRst <= '1';
						nxtState  <= ST_WAIT_WRITE;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

			-- Wait while the EEPROM writes the data to the target address
			when ST_WAIT_WRITE =>
				setOutLow      <= '0';
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Wait 10ms
				if timeCnt = 1530 then
					copyScratchRst <= '1';
					copyScratchSet <= '0';
					dataValidSet   <= '1';
					timeCntRst     <= '1';
					--nxtState       <= ST_RESET;
					nxtState       <= ST_RECEIVE_CRC;
				else
					nxtState   <= curState;
					timeCntRst <= '0';
				end if;

			-- Write command bits to EEPROM (0xF0)
			when ST_READ_DATA =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '1';
				bitSetS        <= '0';
				bitSetD        <= '0';
				byteCntRst     <= '1';
				byteCntEn	   <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					setOutLow  <= '1';
					bitCntEn   <= '0';
					nxtState   <= curState;

				-- Output write value for 52uS
				elsif timeCnt < 10 then
					if bitCnt = 0 or bitCnt = 1 or bitCnt = 2 or bitCnt = 3 then 
						setOutLow <= '1';
					else
						setOutLow <= '0';
					end if;
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';
					bitCntEn   <= '0';

				-- Recovery Time
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					nxtState   <= curState;
					timeCntRst <= '0';
					bitCntRst  <= '0';	
					bitCntEn   <= '0';

				-- Done with bit
				else
					timeCntRst <= '1';
					bitCntEn   <= '1';
					setOutLow  <= '0';

					-- Done with write
					if bitCnt = 7  then
						bitCntRst      <= '1';
						copyScratchRst <= '1';
						copyScratchSet <= '0';
						nxtState       <= ST_W_TARGET;
					else
						bitCntRst <= '0';
						nxtState  <= curState;
					end if;
				end if;

	 		-- Reads back data from memory	    
 	 		when ST_R_DATA =>
				fdValidSet     <= '0';
				dataValidSet   <= '0';
				dataValidRst   <= '0';
				bitSetS        <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';

				-- Assert start pulse for 12us
				if timeCnt < 2 then
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitCntRst  <= '0';
					byteCntEn  <= '0';
					byteCntRst <= '0';
					setOutLow  <= '1';
					bitSetD    <= '0';
					nxtState   <= curState;

				-- Sample data at 13.1uS
				elsif timeCnt = 2 and serClkEn = '1' then
					setOutLow  <= '0';
					bitCntEn   <= '0';
					timeCntRst <= '0';
					bitCntRst  <= '0';
					byteCntRst <= '0';
					byteCntEn  <= '0';
					bitSetD    <= '1';
					nxtState   <= curState;

				-- Recovery
				elsif timeCnt < 12 then
					setOutLow  <= '0';
					timeCntRst <= '0';
					bitCntEn   <= '0';
					bitSetD    <= '0';
					bitCntRst  <= '0';
					byteCntRst <= '0';
					byteCntEn  <= '0';
					nxtState   <= curState;

				-- Done with bit
				else
					setOutLow  <= '0';
					timeCntRst <= '1';
					bitSetD    <= '0';

					-- Done with write
					if byteCnt = 7 then
						if bitCnt = 7  then
							bitCntRst    <= '1';
							bitCntEn     <= '0';
							byteCntRst   <= '1';
							byteCntEn    <= '0';
							dataValidSet <= '1';
							nxtState     <= ST_RESET;
						else
							bitCntRst <= '0';
							byteCntRst<= '0';
							byteCntEn <= '0';
							bitCntEn  <= '1';
							nxtState  <= curState;
						end if;
					else
						if bitCnt = 7  then
							bitCntRst  <= '1';
							bitCntEn	 <= '0';
							byteCntRst <= '0';
							byteCntEn  <= '1';
							nxtState   <= curState;
						else
							bitCntRst <= '0';
							bitCntEn	<= '1';
							byteCntRst<= '0';
							byteCntEn <= '0';
							nxtState  <= curState;
						end if;
					end if;
				end if;        

			when others =>
				fdValidSet     <= '0';
				timeCntRst     <= '1';
				bitCntRst      <= '1';
				bitCntEn       <= '0';
				byteCntRst     <= '1';
				byteCntEn      <= '0';
				setOutLow      <= '0';
				bitSetS        <= '0';
				bitSetD        <= '0';
			 	copyScratchSet <= '0';
				copyScratchRst <= '1';
				writeSet       <= '0';
				writeRst       <= '1';
				readSerSet     <= '0';
				readSerRst     <= '1';
				nxtState       <= ST_RESET;
		end case;
	end process;

end EepromId;
