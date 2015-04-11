-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AdcDeserializer.vhd
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-12
-- Last update: 2015-03-12
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 14 bit DDR deserializer using 7 series IDELAYE2 and ISERDESE2.
--              Initial version taken from Ben Reese's HPS AdcDeserializer.vhd
--              Expecting to migrate to allow for oversampling next.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity AdcDeserializer is
   
   generic (
      TPD_G             : time := 1 ns;
      IDELAYCTRL_FREQ_G : real := 200.0
   );
   port (
      clkIo    : in sl;
      clkIoInv : in sl;
      clkR     : in sl;
      rst      : in sl;
      slip     : in sl;

      sysClk   : in sl;
      setDelay : in slv(4 downto 0);
      curDelay : out slv(4 downto 0);

      iData    : in  sl;
      oData    : out slv(13 downto 0)
   );

end entity AdcDeserializer;

architecture rtl of AdcDeserializer is

   signal dlyData   : sl;
   signal shift1    : sl;
   signal shift2    : sl;
   signal ldDelay   : sl;
   signal iCurDelay : slv(4 downto 0);

begin

   -- Map internal signals to ports where necessary
   curDelay <= iCurDelay;

   -- Check for difference in set delay vs. current delay,
   -- if you see one set LD high until they match.
   process (sysClk) begin
      if rising_edge(sysClk) then
         if (iCurDelay /= setDelay) then
            ldDelay <= '1';
         else 
            ldDelay <= '0';
         end if;
      end if;
   end process;

   U_DELAY : IDELAYE2
      generic map (
         DELAY_SRC             => "IDATAIN",
         HIGH_PERFORMANCE_MODE => "TRUE",
         IDELAY_TYPE           => "VAR_LOAD",
         IDELAY_VALUE          => 0,    -- Here
         REFCLK_FREQUENCY      => IDELAYCTRL_FREQ_G,
         SIGNAL_PATTERN        => "DATA"
         )
      port map (
         C           => sysClk,
         REGRST      => '0',
         LD          => ldDelay,
         CE          => '0',
         INC         => '1',
         CINVCTRL    => '0',
         CNTVALUEIN  => setDelay,
         IDATAIN     => iData,
         DATAIN      => '0',
         LDPIPEEN    => '0',
         DATAOUT     => dlyData,
         CNTVALUEOUT => iCurDelay);

   U_ISERDES_MASTER : ISERDESE2
      generic map (
         DATA_RATE         => "DDR",
         DATA_WIDTH        => 14,
         INTERFACE_TYPE    => "NETWORKING",
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         NUM_CE            => 1,
         OFB_USED          => "FALSE",
         IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
         SERDES_MODE       => "MASTER")
      port map (
         Q1           => oData(0),
         Q2           => oData(1),
         Q3           => oData(2),
         Q4           => oData(3),
         Q5           => oData(4),
         Q6           => oData(5),
         Q7           => oData(6),
         Q8           => oData(7),
         SHIFTOUT1    => shift1,        -- Cascade connection to Slave ISERDES
         SHIFTOUT2    => shift2,        -- Cascade connection to Slave ISERDES
         BITSLIP      => slip,          -- 1-bit Invoke Bitslip. This can be used with any 
                                        -- DATA_WIDTH, cascaded or not.
         CE1          => '1',           -- 1-bit Clock enable input
         CE2          => '1',           -- 1-bit Clock enable input
         CLK          => clkIo,         -- Fast Source Synchronous SERDES clock from BUFIO
         CLKB         => clkIoInv,      -- Locally inverted clock
         CLKDIV       => clkR,          -- Slow clock driven by BUFR
         CLKDIVP      => '0',
         D            => '0',
         DDLY         => dlyData,       -- 1-bit Input signal from IODELAYE1.
         RST          => rst,           -- 1-bit Asynchronous reset only.
         SHIFTIN1     => '0',
         SHIFTIN2     => '0',
         -- unused connections
         DYNCLKDIVSEL => '0',
         DYNCLKSEL    => '0',
         OFB          => '0',
         OCLK         => '0',
         OCLKB        => '0',
         O            => open);         -- unregistered output of ISERDESE1

   U_ISERDES_SLAVE : ISERDESE2
      generic map (
         DATA_RATE         => "DDR",
         DATA_WIDTH        => 14,
         INTERFACE_TYPE    => "NETWORKING",
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         NUM_CE            => 1,
         OFB_USED          => "FALSE",
         IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
         SERDES_MODE       => "SLAVE")
      port map (
         Q1           => open,
         Q2           => open,
         Q3           => oData(8),
         Q4           => oData(9),
         Q5           => oData(10),
         Q6           => oData(11),
         Q7           => oData(12),
         Q8           => oData(13),
         SHIFTOUT1    => open,
         SHIFTOUT2    => open,
         SHIFTIN1     => shift1,        -- Cascade connections from Master ISERDES
         SHIFTIN2     => shift2,        -- Cascade connections from Master ISERDES
         BITSLIP      => slip,          -- 1-bit Invoke Bitslip. This can be used with any 
                                        -- DATA_WIDTH, cascaded or not.
         CE1          => '1',           -- 1-bit Clock enable input
         CE2          => '1',           -- 1-bit Clock enable input
         CLK          => clkIo,         -- Fast source synchronous serdes clock
         CLKB         => clkIoInv,      -- locally inverted clock
         CLKDIV       => clkR,          -- Slow clock driven by BUFR.
         CLKDIVP      => '0',
         D            => '0',           -- Slave ISERDES module. No need to connect D, DDLY
         DDLY         => '0',
         RST          => rst,           -- 1-bit Asynchronous reset only.
         -- unused connections
         DYNCLKDIVSEL => '0',
         DYNCLKSEL    => '0',
         OFB          => '0',
         OCLK         => '0',
         OCLKB        => '0',
         O            => open);         -- unregistered output of ISERDESE1

end architecture rtl;
