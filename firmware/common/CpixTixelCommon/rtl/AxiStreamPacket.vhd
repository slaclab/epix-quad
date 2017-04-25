-------------------------------------------------------------------------------
-- Title      : Frame grabber module
-------------------------------------------------------------------------------
-- File       : AxiStreamPacket.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 01/19/2016
-- Last update: 01/19/2016
-- Platform   : Vivado 2014.4
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'CPIX Development Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'CPIX Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Change log:
-- [MK] 05/18/2016 - Added an option to force reading a frame if only a SOF was
--                   detected. When activated the pixels may be erroneous but
--                   less frames will be dropped. That mode is useful and should
--                   be used only with the prototype ASICs.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EpixPkgGen2.all;
use work.CpixPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiStreamPacket is
   generic (
      TPD_G                : time                  := 1 ns;
      SOF_D_G              : slv(15 downto 0)      := x"F7" & x"4A";
      SOF_K_G              : slv(1 downto 0)       := "10";
      EOF_D_G              : slv(15 downto 0)      := x"FD" & x"4A";
      EOF_K_G              : slv(1 downto 0)       := "10";
      FRAME_WORDS_G        : natural               := 2304;
      ASIC_NUMBER_G        : slv(3 downto 0)       := "0000"
   );
   port (
      -- deserializer data 
      clk            : in  sl;
      rst            : in  sl;
      rxData         : in  slv(19 downto 0);
      rxReady        : in  sl;
      
      -- acquisition number
      acqCnt         : in  slv(31 downto 0);
      
      -- axi lite for register
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      
      -- axi stream output
      axisClk        : in  sl;
      axisRst        : in  sl;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType
   );
end AxiStreamPacket;

architecture rtl of AxiStreamPacket is
   
   type StateType is (WAIT_SOF_S, WAIT_EOF_S);
   
   type RegType is record
      axilReadSlave     : AxiLiteReadSlaveType;
      axilWriteSlave    : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      axilReadSlave     => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave    => AXI_LITE_WRITE_SLAVE_INIT_C
   );
   
   type StrType is record
      state             : StateType;
      fifoRd            : sl;
      axisMaster        : AxiStreamMasterType;
   end record RegType;
   
   constant STR_INIT_C : RegType := (
      state             => WAIT_SOF_S,
      fifoRd            => '0',
      axisMaster        => AXI_STREAM_MASTER_INIT_C
   );
   
   signal rl   : RegType := REG_INIT_C;
   signal rlin : RegType;
   
   signal rs   : StrType := STR_INIT_C;
   signal rsin : StrType;
   
   signal fifoValid  : sl;
   signal fifoDout   : slv(19 downto 0);
   
   attribute keep : string;
   --attribute keep of fifoValid : signal is "true";
   
begin

   
   U_Decode8b10b: entity work.Decoder8b10b
   generic map (
      NUM_BYTES_G => 2,
      RST_POLARITY_G => '0'
   )
   port map (
      clk         => clk,
      clkEn       => rxReady,
      rst         => rst,
      dataIn      => rxData,
      dataOut     => fifoDin(15 downto 0),
      dataKOut    => framedDataK(i),
      codeErr     => codeErr(i),
      dispErr     => dispErr(i)
   );
   
   -----------------------------------------------
   -- async FIFO
   -----------------------------------------------   
   
   DinFifo_U: entity work.Fifo
   generic map (
      GEN_SYNC_FIFO_G => false,
      FWFT_EN_G       => true,
      DATA_WIDTH_G    => 20,
      ADDR_WIDTH_G    => 12
   )
   port map (
      --Write Ports (wr_clk domain)
      wr_clk        => clk,
      wr_en         => rxReady,
      din           => rxData,
      wr_data_count => open,
      wr_ack        => open,
      overflow      => open,
      prog_full     => open,
      almost_full   => open,
      full          => open,
      not_full      => open,
      --Read Ports (rd_clk domain)
      rd_clk        => axisClk,
      rd_en         => rs.fifoRd,
      dout          => fifoDout,
      rd_data_count => open,
      valid         => fifoValid,
      underflow     => open,
      prog_empty    => open,
      almost_empty  => open,
      empty         => open
   );
   
   -----------------------------------------------
   -- data transfer and register access
   -----------------------------------------------
   
   axilComb : process (rl, rs, axisRst, axilRst, axilReadMaster, axilWriteMaster, mAxisSlave, fifoValid, fifoDout) is
      variable vs     : StrType;
      variable vl     : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      
      vs := rs;   -- axisClk
      vl := rl;   -- axilClk
      
      -------------------------------------------------------------------------------------------------
      -- AXIL Interface
      -------------------------------------------------------------------------------------------------
      vl.axilReadSlave.rdata := (others => '0');

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, vl.axilWriteSlave, vl.axilReadSlave);
      
      axiSlaveRegisterR(axilEp, X"00", 0, delayCurr);
      axiSlaveRegister (axilEp, X"04", 0, vl.resync);
      axiSlaveRegisterR(axilEp, X"08", 0, serdR.locked);
      axiSlaveRegisterR(axilEp, X"0C", 0, std_logic_vector(to_unsigned(serdR.lockErrCnt,16)));

      axiSlaveDefault(axilEp, vl.axilWriteSlave, vl.axilReadSlave, AXI_RESP_DECERR_C);
      
      -------------------------------------------------------------------------------------------------
      -- AXIS data transfer
      -------------------------------------------------------------------------------------------------
      
      case (rs.state) is
         when WAIT_SOF_S =>
            if fifoValid = '1' and mAxisSlave.tReady = '1' then
               
               if 
               vs.state     := WAIT_EOF_S;
            end if;
         
         
         
         when others => null;
         
      end case;
      
      -------------------------------------------------------------------------------------------------
      -- reset and output regs
      -------------------------------------------------------------------------------------------------
      
      if (axisRst = '1') then
         vs := SER_INIT_C;
      end if;
      
      if (axilRst = '1') then
         vl := REG_INIT_C;
      end if;
      
      
      rsin        <= vs;
      rlin        <= vl;
      axilWriteSlave <= rl.axilWriteSlave;
      axilReadSlave  <= rl.axilReadSlave;
      mAxisMaster    <= rs.axisMaster;
      
      
   end process;

   axisSeq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         rs <= rsin after TPD_G;
      end if;
   end process axisSeq;
   
   axilSeq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         rl <= rlin after TPD_G;
      end if;
   end process axilSeq;
   
   
end rtl;
