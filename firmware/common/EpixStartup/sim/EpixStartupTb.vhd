LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.VcPkg.all;
use work.EpixTypes.all;

entity EpixStartupTb is end EpixStartupTb;

architecture EpixStartupTb of EpixStartupTb is

   -- Internal signals
   signal sysClkRst      : std_logic;
   signal sysClk         : std_logic;
   signal startupReq     : std_logic;
   signal startupAck     : std_logic;
   signal startupFail    : std_logic;
   signal adcValid       : std_logic_vector(19 downto 0) := (others => '0');
   signal adcData        : word16_array(19 downto 0) := (others => (others => '0'));
   signal startupRegOut  : VcRegSlaveOutType := VC_REG_SLAVE_OUT_INIT_C;
   signal startupRegIn   : VcRegSlaveInType := VC_REG_SLAVE_IN_INIT_C;
   signal goodAlignment  : std_logic;
 
    constant ADC_TEST_PATTERN_C : slv(15 downto 0) := "0010100001100111"; --10343 decimal
 
begin

   -- Reset generation and initiate startup
   process 
   begin
      startupReq <= '0';
      sysClkRst  <= '1';
      wait for (20 us);
      sysClkRst  <= '0';
      wait for (10 us);
      startupReq <= '1';
      wait;
   end process;

   -- 100Mhz clock
   process 
   begin
      sysClk <= '0';
      wait for (5 ns);
      sysClk <= '1';
      wait for (5 ns);
   end process;

   -- Counter data on ADCs
   adc : process(sysClk) 
      variable toggle : std_logic := '0';
   begin
      if rising_edge(sysClk) then
         if (sysClkRst = '1') then
            adcData       <= (others => (others => '0'));
            adcValid      <= (others => '0');
            goodAlignment <= '0';
            toggle        := '0';
         else
            toggle := not(toggle);
            for i in 0 to 19 loop
               adcValid(i) <= toggle;
               if (goodAlignment = '1') then
                  adcData(i) <= ADC_TEST_PATTERN_C;
               else
                  adcData(i) <= (others => '1');
               end if;
            end loop;
            if (startupRegOut.req = '1') then
               if (startupRegOut.addr(23 downto 4) = x"00006" or startupRegOut.addr(23 downto 4) = x"00007") then
                  if (startupRegOut.wrData(5 downto 0) > 1 and startupRegOut.wrData(5 downto 0) < 3) then
--                     goodAlignment <= '1';
                     goodAlignment <= '0';
                  else
                     goodAlignment <= '0';
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;   
   
   reg : process(sysClk) 
      variable count : slv(3 downto 0) := (others => '0');
   begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            startupRegIn.ack    <= '0';
            startupRegIn.fail   <= '0';
            startupRegIn.rdData <= (others => '0');
            count               := (others => '0');
         else
            startupRegIn.ack <= startupRegOut.req;
            -- if startupRegOut.req = '1' then
               -- if (count = 15) then
                  -- startupRegIn.ack <= '0';
               -- else
                  -- count := count + 1;
               -- end if;
            -- else 
               -- startupRegIn.ack <= '0';
               -- count            := (others => '0');
            -- end if;
         end if;
      end if;
   end process;

   -- Startup processor
   U_EpixStartup : entity work.EpixStartup
      generic map (
         JTAG_LOADER_DISABLE_G => 0
      )
      port map (
         sysClk      => sysClk,
         sysClkRst   => sysClkRst,
         startupReq  => startupReq,
         startupAck  => startupAck,
         startupFail => startupFail,
         adcValid    => adcValid,
         adcData     => adcData,
         vcRegOut    => startupRegOut,
         vcRegIn     => startupRegIn
      );      

end EpixStartupTb;
