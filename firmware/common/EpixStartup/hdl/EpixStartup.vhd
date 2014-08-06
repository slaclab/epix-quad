-------------------------------------------------------------------------------
-- Title         : Startup Controller
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : EpixStartup.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 07/29/2014
-------------------------------------------------------------------------------
-- Description:
-- Epix startup calibrations
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by SLAC. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 07/29/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.VcPkg.all;
use work.EpixTypes.all;

entity EpixStartup is
   generic (
      JTAG_LOADER_DISABLE_G : integer := 0
   );
   port (
      sysClk      : in  sl;
      sysClkRst   : in  sl;
      startupReq  : in  sl;
      startupAck  : out sl;
      startupFail : out sl;
      adcValid    : in  slv(19 downto 0);
      adcData     : in  word16_array(19 downto 0);
      vcRegOut    : out VcRegSlaveOutType;
      vcRegIn     : in  VcRegSlaveInType
   );
end EpixStartup;

architecture EpixStartup of EpixStartup is 
   signal portId   : slv(7 downto 0);
   signal outPort  : slv(7 downto 0);
   signal inPort   : slv(7 downto 0);
   signal wrStrobe : sl;
   signal rdStrobe : sl;

   signal adcEnable   : sl;
   signal asicEnable  : sl;
   signal adcSelect   : slv(1 downto 0);
   signal adcChSelect : slv(2 downto 0);
   signal asicSelect  : slv(1 downto 0);
   signal addressByte : slv(7 downto 0);
   signal wrDataByte  : slv(7 downto 0);
   signal regReq      : sl;
   signal regOp       : sl;
   
   signal resetCount       : slv(7 downto 0);
   signal adcValidCount    : slv(7 downto 0);
   signal adcMatchCount    : slv(7 downto 0);
   signal adcValidCountReg : slv(7 downto 0);
   signal adcMatchCountReg : slv(7 downto 0);
   
   signal muxedAdcData   : slv(15 downto 0);
   signal muxedAdcValid  : sl;
   
   signal pbReg : word8_array(7 downto 0);
   
   constant ADC_TEST_PATTERN_C : slv(15 downto 0) := "0010100001100111"; --10343 decimal
   constant MAX_COUNT_C : slv(7 downto 0) := (others => '1');
   
begin

   U_StartupPicoBlaze : entity work.embedded_kcpsm3
      generic map (
         JTAG_LOADER_DISABLE_G => JTAG_LOADER_DISABLE_G
      )
      port map (
         port_id       => portId,
         write_strobe  => wrStrobe,
         read_strobe   => rdStrobe,
         out_port      => outPort,
         in_port       => inPort,
         interrupt     => '0',
         interrupt_ack => open,
         reset         => sysClkRst,
         clk           => sysClk
      );

   -- Multiplexing of outputs, one-hot encoding
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            pbReg <= (others => (others => '0'));
         else
            if wrStrobe = '1' then
               case portId is
                  when x"01" => pbReg(0) <= outPort;
                  when x"02" => pbReg(1) <= outPort;
                  when x"04" => pbReg(2) <= outPort;
                  when x"08" => pbReg(3) <= outPort;
                  when x"10" => pbReg(4) <= outPort;
                  when x"20" => pbReg(5) <= outPort;
                  when x"40" => pbReg(6) <= outPort;
                  when x"80" => pbReg(7) <= outPort;
                  when others => 
               end case;
            end if;
         end if;
      end if;
   end process;
   -- Assignments of output registers
   addressByte <= pbReg(0);
   wrDataByte  <= pbReg(1);
   adcEnable   <= pbReg(2)(7);
   adcSelect   <= pbReg(2)(4 downto 3);
   adcChSelect <= pbReg(2)(2 downto 0);
   asicEnable  <= pbReg(3)(7);
   asicSelect  <= pbReg(3)(1 downto 0);
   regOp       <= pbReg(4)(0);
   regReq      <= pbReg(4)(1);
   startupAck  <= pbReg(5)(0);
   startupFail <= pbReg(5)(1);
   -- Output ports mapped to entity ports
   vcRegOut.addr <= "10" & asicSelect & x"000" & addressByte when asicEnable = '1' else
                    x"00" & '1' & adcSelect & '0' & x"0" & addressByte when adcEnable = '1' else
                    x"0000" & addressByte; 
   vcRegOut.wrData <= x"000000" & wrDataByte;
   vcRegOut.op     <= regOp;
   vcRegOut.req    <= regReq;
   vcRegOut.inp    <= regReq;
   
   -- Assignments of input registers
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            inPort <= (others => '0');
         else
            case(portId(3 downto 0)) is
               when x"0" =>   inPort(0)          <= vcRegIn.ack;
                              inPort(1)          <= vcRegIn.fail;
                              inPort(7 downto 2) <= (others => '0');
               when x"1" =>   inPort    <= vcRegIn.rdData(7 downto 0);
               when x"2" =>   inPort    <= adcValidCountReg;
               when x"3" =>   inPort    <= adcMatchCountReg;
               when x"4" =>   inPort(0) <= startupReq;
                              inPort(7 downto 1) <= (others => '0');
               when others => inPort <= (others => '0'); 
            end case;
         end if; 
      end if;
   end process;

   -- Select ADC data and valid based on output ports
   process(sysClk) begin
      if rising_edge(sysClk) then
         case adcSelect is
            when   "00" => muxedAdcData  <= adcData(  0 + conv_integer(adcChSelect));
                           muxedAdcValid <= adcValid( 0 + conv_integer(adcChSelect));
            when   "01" => muxedAdcData  <= adcData(  8 + conv_integer(adcChSelect));
                           muxedAdcValid <= adcValid( 8 + conv_integer(adcChSelect));
            when   "10" => muxedAdcData  <= adcData( 16 + conv_integer(adcChSelect));
                           muxedAdcValid <= adcValid(16 + conv_integer(adcChSelect));
            when others => muxedAdcData  <= (others => '0');
                           muxedAdcValid <= '0';
         end case;
      end if;
   end process;
   -- process(adcSelect,adcChSelect,adcData,adcValid) begin
      -- case adcSelect is
         -- when   "00" => muxedAdcData  <= adcData(  0 + conv_integer(adcChSelect));
                        -- muxedAdcValid <= adcValid( 0 + conv_integer(adcChSelect));
         -- when   "01" => muxedAdcData  <= adcData(  8 + conv_integer(adcChSelect));
                        -- muxedAdcValid <= adcValid( 8 + conv_integer(adcChSelect));
         -- when   "10" => muxedAdcData  <= adcData( 16 + conv_integer(adcChSelect));
                        -- muxedAdcValid <= adcValid(16 + conv_integer(adcChSelect));
         -- when others => muxedAdcData  <= (others => '0');
                        -- muxedAdcValid <= '0';
      -- end case;
   -- end process;
   -- Monitor rate of valid signals and ADC mismatch signals
   adc_mon : process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            resetCount    <= (others => '0');
            adcValidCount <= (others => '0');
            adcMatchCount <= (others => '0');
            adcValidCount <= (others => '0');
            adcMatchCount <= (others => '0');
            adcMatchCountReg <= (others => '0');
            adcValidCountReg <= (others => '0');
         else
            if (resetCount = 255) then
               adcValidCountReg <= adcValidCount;
               adcMatchCountReg <= adcMatchCount;            
               adcValidCount    <= (others => '0');
               adcMatchCount    <= (others => '0');
            else
               if muxedAdcValid = '1' then
                  adcValidCount <= adcValidCount + 1;
               end if;
               if muxedAdcValid = '1' and muxedAdcData /= ADC_TEST_PATTERN_C then
                  adcMatchCount <= adcMatchCount + 1;
               end if;
            end if;
            resetCount <= resetCount + 1;
         end if;
      end if;
   end process;
   

end EpixStartup;
