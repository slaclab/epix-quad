-------------------------------------------------------------------------------
-- File       : TSDecoderMode.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2018-06-28
-------------------------------------------------------------------------------
-- Description: The test structure sends data in different way depending on the
-- selected mode (using SACI registers). This modules adapts the data from the
-- TS to the same format as the serial streaming used by the regular dataout.
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
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

use work.StdRtlPkg.all;

entity TSDecoderMode is

   generic (
      TPD_G          : time    := 1 ns;
      RST_POLARITY_G : sl      := '0';
      RST_ASYNC_G    : boolean := true);

   port (
      clk      : in  sl;
      rst      : in  sl := RST_POLARITY_G;
      dataIn   : in  slv(15 downto 0);
      validIn  : in  sl := '1';
      modeIn   : in  slv(1 downto 0) := "00";
      dataOut  : out slv(15 downto 0);
      validOut : out sl;
      sof      : out sl;
      eof      : out sl;
      eofe     : out sl);

end entity TSDecoderMode;

architecture rtl of TSDecoderMode is

  constant FRAME_1_2_SIZE_C : natural := 32;
  constant FRAME_3_4_SIZE_C : natural := 1024;
  constant TIMEOUT_C : slv(31 downto 0) := x"0006A120";  -- 4ms
  
  type StateType is (IDLE_S, SOF_S, VALID_DATA_S, EOF_S, EOFE_S);
  
  type StrType is record
    state          : StateType;
    data           : slv(15 downto 0);
    dataValid      : sl;
    frmSize        : slv(15 downto 0);
    timeoutCounter : slv(31 downto 0);
    sof            : sl;
    eof            : sl;
    eofe           : sl;
  end record;

  constant STR_INIT_C : StrType := (
    state          => IDLE_S,
    data           => (others=>'0'),
    dataValid      => '0',
    frmSize        => (others=>'0'),
    timeoutCounter => (others=>'1'),
    sof            => '0',
    eof            => '0',
    eofe           => '0'
    );
  
  signal s   : StrType := STR_INIT_C;
  signal sin : StrType;

  signal validInSync  : sl;
  signal dataInSync   : slv(15 downto 0);
  
  attribute keep : string;                    -- for chipscope
  attribute keep of s : signal is "true";     -- for chipscope

begin

  Sync1_U : entity wrk.Synchronizer
   port map (
      clk     => clk,
      rst     => rst,
      dataIn  => validIn,
      dataOut => validInSync
   );

  Sync2_U : entity wrk.SynchronizerVector
   port map (
      clk     => clk,
      rst     => rst,
      dataIn  => dataIn,
      dataOut => dataInSync
   );
  
  comb : process (s, dataInSync, validInSync, modeIn) is
    variable sv       : StrType;

  begin
    sv := s;

    --saves input signal in local varialble
    sv.data := dataInSync;
    sv.dataValid := validInSync;

    -- state machine that creates data packet and SOF, EOF flags
    case s.state is
      when IDLE_S =>
        -- flags
        sv.sof  := '0';
        sv.eof  := '0';
        sv.eofe := '0';
        sv.frmSize := (others=>'0');
        -- next state logic
        if (validInSync='1') and (s.dataValid='0') then
            sv.sof := '1';
            sv.state := SOF_S;
        end if;
      when SOF_S =>
        --sof flag
        sv.sof := '0';
        if ((modeIn = "00") or (modeIn = "01")) then
          --next state logic
          if (validInSync='0') and (s.dataValid='1') then
            sv.state := VALID_DATA_S;
          end if;
        else
          --keeps track of how much data has been saved
          if s.dataValid = '1' then
            sv.frmSize := s.frmSize + '1';
          end if;
          --next state logic
          sv.state := VALID_DATA_S;
        end if;
      when VALID_DATA_S =>
        --sof flag
        sv.sof := '0';
        --keeps track of how much data has been saved
        if s.dataValid = '1' then
          sv.frmSize := s.frmSize + '1';
        end if;
        --next state logic
        if ((modeIn = "00") or (modeIn = "01")) then
          if s.frmSize = FRAME_1_2_SIZE_C then
            sv.state := EOF_S;           
          end if;
        end if;
        if ((modeIn = "10") or (modeIn = "11")) then
          if s.frmSize = FRAME_3_4_SIZE_C then
            sv.state := EOF_S;           
          end if;
        end if;      
      when EOF_S =>
        sv.eof := '1';
        sv.state := IDLE_S;
      when EOFE_S =>
        sv.eofe := '1';
        sv.state := IDLE_S;
      when others =>     
        sv.state := IDLE_S;
    end case;

    --timeout counter
    if s.state = IDLE_S then
      sv.timeoutCounter := (others => '0');
    else
      sv.timeoutCounter := s.timeoutCounter + '1';
    end if;
    --timeout monitor
    if s.timeoutCounter = TIMEOUT_C then
          sv.state := EOFE_S;
    end if;
    --outputs
    sin <= sv;
    dataOut  <= s.data;
    -- overwrite signal due to inverted control logic in the asic
    if (s.state = VALID_DATA_S) then
      validOut <= s.dataValid;
    else
      validOut <= '0';
    end if;    
    sof      <= s.sof;
    eof      <= s.eof;
    eofe     <= s.eofe;
  end process comb;


  sseq : process (clk) is
  begin
    if (rising_edge(clk)) then
      s <= sin after TPD_G;
    end if;
  end process sseq;


end architecture rtl;
