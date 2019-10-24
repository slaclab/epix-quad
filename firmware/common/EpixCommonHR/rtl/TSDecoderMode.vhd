-------------------------------------------------------------------------------
-- File       : TSDecoderMode.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-07-14
-- Last update: 2019-10-24
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
      asicSR0  : in  sl;
      modeIn   : in  slv( 3 downto 0) := "0100";
      frameSize: in  slv(15 downto 0) := x"0020";
      dataOut  : out slv(15 downto 0);
      validOut : out sl;
      sof      : out sl;
      eof      : out sl;
      eofe     : out sl);

end entity TSDecoderMode;

architecture rtl of TSDecoderMode is

  --constant FRAME_1_2_SIZE_C : natural := 32;
  --constant FRAME_3_4_SIZE_C : natural := 1024;
  constant TIMEOUT_C : slv(31 downto 0) := x"0006A120";  -- 4ms
  
  type StateType is (IDLE_S, SOF_S, VALID_DATA_S, EOF_S, EOFE_S);
  
  type StrType is record
    state          : StateType;
    edge           : sl;
    enabled        : sl;
    mode           : slv( 1 downto 0); 
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
    edge           => '0',
    enabled        => '0',
    mode           => (others=>'0'),
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

  signal validInSync      : sl;
  signal dataInSync       : slv(15 downto 0);
  signal validOutSig      : sl;
  signal validOutOneShot  : sl;     
  
  attribute keep : string;                    -- for chipscope
  attribute keep of s : signal is "true";     -- for chipscope

begin

  Sync1_U : entity work.Synchronizer
   port map (
      clk     => clk,
      rst     => rst,
      dataIn  => validIn,
      dataOut => validInSync
   );

  Sync2_U : entity work.SynchronizerVector
   port map (
      clk     => clk,
      rst     => rst,
      dataIn  => dataIn,
      dataOut => dataInSync
   );

--   Sync3_U : entity work.SynchronizerOneShot
--     generic map(
--       RELEASE_DELAY_G => 1
--    )    
--   port map (
--      clk     => clk,
--      rst     => rst,
--      dataIn  => validOutSig,
--      dataOut => validOutOneShot
--   );
  
  comb : process (s, dataInSync, validInSync, validOutOneShot, modeIn, asicSR0, frameSize) is
    variable sv       : StrType;

  begin
    sv := s;

    --saves input signal in local varialble
    sv.edge      := modeIn(3);
    sv.enabled   := modeIn(2);
    sv.mode      := modeIn(1 downto 0);
    sv.data      := dataInSync;
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
        if (validInSync='1') and (s.dataValid='0') and (s.enabled='1') and (asicSR0 = '1') then
            sv.sof := '1';
            sv.state := SOF_S;
        end if;
      when SOF_S =>
        --sof flag
        sv.sof := '0';
        if ((s.mode = "00") or (s.mode = "01")) then
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
        if s.enabled='0' then
          sv.state := IDLE_S;
        end if;
      when VALID_DATA_S =>
        --sof flag
        sv.sof := '0';
        --keeps track of how much data has been saved
        if validOutOneShot = '1' then
          sv.frmSize := s.frmSize + '1';
        end if;
        --next state logic
        if ((s.mode = "00") or (s.mode = "01")) then
          if s.frmSize >= frameSize + '1' then
            sv.state := EOF_S;           
          end if;
        else
          if s.frmSize > frameSize + '1' then
            sv.state := EOF_S;           
          end if;
        end if;
            
        if s.enabled='0' then
          sv.state := IDLE_S;
        end if;
      when EOF_S =>
        sv.eof := '1';
        sv.eofe := validOutOneShot;
        --waits for SR0 to go low to finish enable a new frame to be started.
        if asicSR0 = '0' then     
          sv.state := IDLE_S;
        end if;
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
    -- single shot logic
    if s.edge = '0' then                -- rising edge
      if validInSync = '1' and s.dataValid = '0' then
        validOutOneShot <= '1';
      else
        validOutOneShot <= '0';
      end if;
    else                                -- falling edge
      if validInSync = '0' and s.dataValid = '1' then
        validOutOneShot <= '1';
      else
        validOutOneShot <= '0';
      end if;
    end if;
    
    -- overwrite signal due to inverted control logic in the asic
    if (s.state = VALID_DATA_S) then
      validOutSig <= s.dataValid;
      validOut  <= validOutOneShot;
    else
      validOutSig <= '0';
      validOut    <= '0';
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
