-------------------------------------------------------------------------------
-- Title         : Startup Controller
-- Project       : EPIX Readout
-------------------------------------------------------------------------------
-- File          : EpixStartupGen2.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Epix startup calibrations
-------------------------------------------------------------------------------
-- This file is part of 'EPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'EPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

use work.EpixPkgGen2.all;

entity EpixStartupGen2 is
   generic (
      TPD_G                : time := 1 ns;
      JTAG_LOADER_ENABLE_G : integer := 1
   );
   port (
      sysClk           : in  sl;
      sysClkRst        : in  sl;
      startupReq       : in  sl;
      startupAck       : out sl;
      startupFail      : out sl;
      adcValid         : in  slv(19 downto 0);
      adcData          : in  Slv16Array(19 downto 0);
      pbAxiReadMaster  : out AxiLiteReadMasterType;
      pbAxiReadSlave   : in  AxiLiteReadSlaveType;
      pbAxiWriteMaster : out AxiLiteWriteMasterType;
      pbAxiWriteSlave  : in  AxiLiteWriteSlaveType
   );
end EpixStartupGen2;

architecture EpixStartupGen2 of EpixStartupGen2 is 

   type StateType is (IDLE_S, WRITE_AXI_S, READ_AXI_S, ACK_S);
   type RegType is record
      req                 : sl;
      op                  : sl;
      ack                 : sl;
      fail                : sl;
      rdData              : slv(7 downto 0);
      state               : StateType;
      mAxiLiteWriteMaster : AxiLiteWriteMasterType;
      mAxiLiteReadMaster  : AxiLiteReadMasterType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      req                 => '0',
      op                  => '0',
      ack                 => '0',
      fail                => '0',
      rdData              => (others => '0'),
      state               => IDLE_S,
      mAxiLiteWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      mAxiLiteReadMaster  => AXI_LITE_READ_MASTER_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;   
   
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
   signal asicCmd     : slv(4 downto 0);
   signal addressByte : slv(7 downto 0);
   signal wrDataByte  : slv(7 downto 0);
   signal regReq      : sl;
   signal regOp       : sl;
   signal regAddr     : slv(23 downto 0);
   
   signal interrupt   : sl;
   
   signal resetCount       : slv(7 downto 0);
   signal adcValidCount    : slv(7 downto 0);
   signal adcMatchCount    : slv(7 downto 0);
   signal adcValidCountReg : slv(7 downto 0);
   signal adcMatchCountReg : slv(7 downto 0);
   
   signal muxedAdcData     : slv(15 downto 0);
   signal muxedAdcValid    : sl;
   
   signal pbReg            : Slv8Array(7 downto 0);
   
   constant ADC_TEST_PATTERN_C : slv(15 downto 0) := "0010100001100111"; --10343 decimal
   constant MAX_COUNT_C : slv(7 downto 0) := (others => '1');
   
   attribute keep : boolean;
   attribute keep of adcSelect : signal is true;
   attribute keep of adcChSelect : signal is true;
   attribute keep of muxedAdcData : signal is true;
   attribute keep of muxedAdcValid : signal is true;
   attribute keep of adcValidCountReg : signal is true;
   attribute keep of adcMatchCountReg : signal is true;
   
begin

   U_StartupPicoBlaze : entity work.kcpsm6_wrapper
      generic map (
         HW_BUILD_BYTE_G      => x"00",
         INTERRUPT_VECTOR_G   => x"3FF",
         SCRATCHPAD_SIZE_G    => 64,
         FPGA_FAMILY_G        => "7S",
         RAM_SIZE_KWORDS_G    => 2,
         JTAG_LOADER_ENABLE_G => 1
      )
      port map (
         port_id        => portId,
         write_strobe   => wrStrobe,
         k_write_strobe => open,
         read_strobe    => rdStrobe,
         out_port       => outPort,
         in_port        => inPort,
         interrupt      => interrupt,
         interrupt_ack  => interrupt,
         kcpsm6_sleep   => '0',
         reset          => sysClkRst,
         clk            => sysClk
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
   asicCmd     <= pbReg(3)(6 downto 2);
   regOp       <= pbReg(4)(0);
   regReq      <= pbReg(4)(1);
   startupAck  <= pbReg(5)(0);
   startupFail <= pbReg(5)(1);
   -- Output ports mapped to entity ports
   regAddr <= "10" & asicSelect & "000" & asicCmd & x"0" & addressByte when asicEnable = '1' else
              x"00" & '1' & adcSelect & '0' & x"0" & addressByte when adcEnable = '1' else
              x"0000" & addressByte; 
   
   -- Assignments of input registers
   process(sysClk) begin
      if rising_edge(sysClk) then
         if sysClkRst = '1' then
            inPort <= (others => '0');
         else
            case(portId(3 downto 0)) is
               when x"0" =>   inPort(0)          <= r.ack;
                              inPort(1)          <= r.fail;
                              inPort(7 downto 2) <= (others => '0');
               when x"1" =>   inPort    <= r.rdData;
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

   -- Simple state machine to interface via AXI-Lite
   comb : process (r, regReq, regOp, regAddr, wrDataByte, 
                   sysClkRst, pbAxiReadSlave, pbAxiWriteSlave) 
      variable v : RegType;
   begin
      v := r;
      
      case r.state is
         when IDLE_S =>
            v.mAxiLiteReadMaster  := AXI_LITE_READ_MASTER_INIT_C;
            v.mAxiLiteWriteMaster := AXI_LITE_WRITE_MASTER_INIT_C;
            v.ack                 := '0';
            -- Request is active
            if (regReq = '1') then
               -- Request is a write
               if (regOp = '1') then
                  v.mAxiLiteWriteMaster.awaddr(25 downto 2) := regAddr;
                  v.mAxiLiteWriteMaster.awprot              := (others => '0');
                  v.mAxiLiteWriteMaster.wstrb               := (others => '1');
                  v.mAxiLiteWriteMaster.wdata(7 downto 0)   := wrDataByte;
                  v.mAxiLiteWriteMaster.awvalid             := '1';
                  v.mAxiLiteWriteMaster.wvalid              := '1';
                  v.mAxiLiteWriteMaster.bready              := '1';
                  v.state := WRITE_AXI_S;
               -- Request is a read
               elsif (regOp = '1') then
                  v.mAxiLiteReadMaster.araddr(25 downto 2) := regAddr;
                  v.mAxiLiteReadMaster.arprot              := (others => '0');
                  v.mAxiLiteReadMaster.arvalid             := '1';
                  v.mAxiLiteReadMaster.rready              := '1';
                  v.state := READ_AXI_S;
               end if;
            end if;
         -- Perform AXI-lite write
         when WRITE_AXI_S =>
            -- Release signals as pieces are acknowledged
            if (pbAxiWriteSlave.awready = '1') then
               v.mAxiLiteWriteMaster.awvalid := '0';
            end if;
            if (pbAxiWriteSlave.wready = '1') then
               v.mAxiLiteWriteMaster.wvalid := '0';
            end if; 
            if (pbAxiWriteSlave.bvalid = '1') then
               v.mAxiLiteWriteMaster.bready := '0';
            end if;
            -- Everything is acknowledged, move on
            if (v.mAxiLiteWriteMaster.awvalid = '0' and
                v.mAxiLiteWriteMaster.wvalid  = '0' and
                v.mAxiLiteWriteMaster.bready  = '0') then
               v.state := ACK_S;
            end if;
         -- Perform AXI-lite read
         when READ_AXI_S =>
            -- Release signals as pieces are acknowledged
            if (pbAxiReadSlave.arready = '1') then
               v.mAxiLiteReadMaster.arvalid := '0';
            end if;
            if (pbAxiReadSlave.rvalid = '1') then
               v.mAxiLiteReadMaster.rready := '0';
            end if;
            -- Everything is acknowledged, move on
            if ( pbAxiReadSlave.arready = '1' and 
                 pbAxiReadSlave.rvalid = '1') then
               v.rdData := pbAxiReadSlave.rdata(7 downto 0);
               v.state  := ACK_S;
            end if;
         -- Hold ack high until request drops low
         when ACK_S =>
            v.ack := '1';
            if (regReq = '0') then
               v.ack   := '0';
               v.state := IDLE_S;
            end if;
         -- Default back to IDLE
         when others =>
            v.state := IDLE_S;
      end case;
      
      if (sysClkRst = '1') then
         v := REG_INIT_C;
      end if;
      
      rin <= v;
      
   end process;
      
   seq : process (sysClk) begin
      if rising_edge(sysClk) then
         r <= rin after TPD_G;
      end if;
   end process;
   
   pbAxiReadMaster  <= r.mAxiLiteReadMaster;
   pbAxiWriteMaster <= r.mAxiLiteWriteMaster;
   
end EpixStartupGen2;
