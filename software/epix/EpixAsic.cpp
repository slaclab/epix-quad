//-----------------------------------------------------------------------------
// File          : EpixAsic.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/06/2013
// Project       : Epix ASIC
//-----------------------------------------------------------------------------
// Description :
// Epix ASIC container
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/06/2013: created
//-----------------------------------------------------------------------------
#include <EpixAsic.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
EpixAsic::EpixAsic ( uint destination, uint baseAddress, uint index, Device *parent ) : 
                     Device(destination,baseAddress,"kpixAsic",index,parent) {

   // Description
   desc_    = "Epix ASIC Object.";

   // ASIC Address Space
   // Addr[11:0]  = Address
   // Addr[18:12] = CMD
   // Addr[21:20] = Chip

   // CMD = 0, Addr = 0  : Prepare for readout
   addRegister(new Register("CmdPrepForRead", baseAddress_ + 0x00000000));

   // CMD = 1, Addr = 1  : Pulser bits 2:0
   addRegister(new Register("MonostPulser", baseAddress_ + 0x00001001));

   addVariable(new Variable("MonostPulser", Variable::Configuration));
   getVariable("MonostPulser")->setDescription("MonoSt Pulser bits");
   getVariable("MonostPulser")->setRange(0,7);

   // CMD = 1, Addr = 2  : Pixel dummy, write data
   //                    : Bit 0 = Test
   //                    : Bit 1 = Test
   addRegister(new Register("PixelDummy", baseAddress_ + 0x00001002));

   addVariable(new Variable("DummyMask", Variable::Configuration));
   getVariable("DummyMask")->setDescription("Dummy Pixel Mask");
   getVariable("DummyMask")->setTrueFalse();

   addVariable(new Variable("DummyTest", Variable::Configuration));
   getVariable("DummyTest")->setDescription("Dummy Pixel Test");
   getVariable("DummyTest")->setTrueFalse();

   // CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
   //                    : Bit  10  = pbit
   //                    : Bit  11  = atest
   //                    : Bit  12  = test
   //                    : Bit  13  = sab_test
   //                    : Bit  14  = hrtest
   addRegister(new Register("Config3", baseAddress_ + 0x00001003));

   addVariable(new Variable("Pulser", Variable::Configuration));
   getVariable("Pulser")->setDescription("Pulser bits");
   getVariable("Pulser")->setRange(0,0x3FF);

   addVariable(new Variable("PBit", Variable::Configuration));
   getVariable("Pbit")->setDescription("PBit");
   getVariable("Pbit")->setTrueFalse();

   addVariable(new Variable("ATest", Variable::Configuration));
   getVariable("ATest")->setDescription("ATest");
   getVariable("ATest")->setTrueFalse();

   addVariable(new Variable("Test", Variable::Configuration));
   getVariable("Test")->setDescription("Test");
   getVariable("Test")->setTrueFalse();

   addVariable(new Variable("SabTest", Variable::Configuration));
   getVariable("SabTest")->setDescription("SabTest");
   getVariable("SabTest")->setTrueFalse();

   addVariable(new Variable("HrTest", Variable::Configuration));
   getVariable("HrTest")->setDescription("HrTest");
   getVariable("HrTest")->setTrueFalse();

   // CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
   //                    : Bits 7:4 = DM2[3:0]
   addRegister(new Register("Config4", baseAddress_ + 0x00001004));

   addVariable(new Variable("DigMon1", Variable::Configuration));
   getVariable("DigMon1")->setDescription("Digital Monitor 1 Select");
   vector<string> dm1;
   dm1.resize(16);
   dm1[0]  = "Clk";
   dm1[1]  = "Exec";
   dm1[2]  = "RoRst";
   dm1[3]  = "Ack";
   dm1[4]  = "IsEn";
   dm1[5]  = "RoWClk";
   dm1[6]  = "Addr0";
   dm1[7]  = "Addr1";
   dm1[8]  = "Addr2";
   dm1[9]  = "Addr3";
   dm1[10] = "Addr4";
   dm1[11] = "Cmd0";
   dm1[12] = "Cmd1";
   dm1[13] = "Cmd2";
   dm1[14] = "Cmd3";
   dm1[15] = "Config";
   getVariable("DigMon1")->setEnums(dm1);

   addVariable(new Variable("DigMon2", Variable::Configuration));
   getVariable("DigMon2")->setDescription("Digital Monitor 2 Select");
   vector<string> dm2;
   dm2.resize(16);
   dm2[0]  = "Clk";
   dm2[1]  = "Exec";
   dm2[2]  = "RoRst";
   dm2[3]  = "Ack";
   dm2[4]  = "IsEn";
   dm2[5]  = "RoWClk";
   dm2[6]  = "Db0";
   dm2[7]  = "Db1";
   dm2[8]  = "Db2";
   dm2[9]  = "Db3";
   dm2[10] = "Db4";
   dm2[11] = "Db5";
   dm2[12] = "Db6";
   dm2[13] = "Db7";
   dm2[14] = "AddrMot";
   dm2[15] = "Config";
   getVariable("DigMon2")->setEnums(dm2);

   // CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC[2:0]
   addRegister(new Register("PulserDac", baseAddress_ + 0x00001005));

   addVariable(new Variable("PulserDac", Variable::Configuration));
   getVariable("PulserDac")->setDescription("Pulser DAC");
   getVariable("PulserDac")->setRange(0,0x7);

   // CMD = 1, Addr = 6  : Bit  0   = DM1en
   //                    : Bit  1   = DM2en
   //                    : Bit  4   = SLVDSbit
   addRegister(new Register("Config6", baseAddress_ + 0x00001006));

   addVariable(new Variable("Dm1En", Variable::Configuration));
   getVariable("Dm1En")->setDescription("Digital Monitor 1 Enable");
   getVariable("Dm1En")->setTrueFalse();

   addVariable(new Variable("Dm2En", Variable::Configuration));
   getVariable("Dm2En")->setDescription("Digital Monitor 2 Enable");
   getVariable("Dm2En")->setTrueFalse();

   addVariable(new Variable("SlvdSBit", Variable::Configuration));
   getVariable("SlvdSBit")->setDescription("");
   getVariable("SlvdSBit")->setTrueFalse();

   // CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
   addRegister(new Register("VRef", baseAddress_ + 0x00001007));

   addVariable(new Variable("VRef", Variable::Configuration));
   getVariable("VRef")->setDescription("Voltage Ref");
   getVariable("VRef")->setRange(0,0x2F);

   // CMD = 1, Addr = 8  : Bit  0   = TPS_tcomp
   //                    : Bit  4:1 = TPS_MUX[3:0]
   //                    : Bit  7:5 = TO_Monost[2:0]
   addRegister(new Register("Config8", baseAddress_ + 0x00001008));

   addVariable(new Variable("TpsTComp", Variable::Configuration));
   getVariable("TpsTComp")->setDescription("");
   getVariable("TpsTComp")->setTrueFalse();

   addVariable(new Variable("TpsMux", Variable::Configuration));
   getVariable("TpsMux")->setDescription("");
   getVariable("TpsMux")->setRange(0,15);

   addVariable(new Variable("ToMonost", Variable::Configuration));
   getVariable("ToMonost")->setDescription("");
   getVariable("ToMonost")->setRange(0,7);

   // CMD = 1, Addr = 9  : Bit  3:0 = TPS_GR[3:0]
   //                    : Bit  7:4 = S2D_GR[3:0]
   addRegister(new Register("Config9", baseAddress_ + 0x00001009));

   addVariable(new Variable("TpsGr", Variable::Configuration));
   getVariable("TpsGr")->setDescription("");
   getVariable("TpsGr")->setRange(0,15);

   addVariable(new Variable("S2dGr", Variable::Configuration));
   getVariable("S2dGr")->setDescription("");
   getVariable("S2dGr")->setRange(0,15);

   // CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
   //                    : Bit  3:1 = OCB[2:0]
   //                    : Bit  6:4 = Monost[2:0]
   //                    : Bit  7   = fastpp_enable
   addRegister(new Register("Config10", baseAddress_ + 0x0000100A));

   addVariable(new Variable("PpOcbS2d", Variable::Configuration));
   getVariable("PpOcbS2d")->setDescription("");
   getVariable("PpOcbS2d")->setTrueFalse();

   addVariable(new Variable("Ocb", Variable::Configuration));
   getVariable("Ocb")->setDescription("");
   getVariable("Ocb")->setRange(0,7);

   addVariable(new Variable("Monst", Variable::Configuration));
   getVariable("Monost")->setDescription("");
   getVariable("Monost")->setRange(0,7);

   addVariable(new Variable("FastppEnable", Variable::Configuration));
   getVariable("FastppEnable")->setDescription("");
   getVariable("FastppEnable")->setTrueFalse();

   // CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
   //                    : Bit  6:4 = Pixel_CB[2:0]
   addRegister(new Register("Config11", baseAddress_ + 0x0000100B));

   addVariable(new Variable("Preamp", Variable::Configuration));
   getVariable("Preamp")->setDescription("");
   getVariable("Preamp")->setRange(0,7);

   addVariable(new Variable("PixelCb", Variable::Configuration));
   getVariable("PixelCb")->setDescription("");
   getVariable("PixelCb")->setRange(0,7);

   // CMD = 1, Addr = 12 : Bit  0   = S2D_tcomp
   //                    : Bit  6:1 = Filter_Dac[5:0]
   addRegister(new Register("Config12", baseAddress_ + 0x0000100C));

   addVariable(new Variable("S2dTComp", Variable::Configuration));
   getVariable("S2dTComp")->setDescription("");
   getVariable("S2dTComp")->setTrueFalse();

   addVariable(new Variable("FilterDac", Variable::Configuration));
   getVariable("FilterDac")->setDescription("");
   getVariable("FilterDac")->setRange(0,0x3F);

   // CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
   //                    : Bit  4:2 = S2D[2:0]
   //                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
   addRegister(new Register("Config13", baseAddress_ + 0x0000100D));

   addVariable(new Variable("TC", Variable::Configuration));
   getVariable("TC")->setDescription("");
   getVariable("TC")->setRange(0,3);

   addVariable(new Variable("S2d", Variable::Configuration));
   getVariable("S2d")->setDescription("");
   getVariable("S2d")->setRange(0,7);

   addVariable(new Variable("S2dDacBias", Variable::Configuration));
   getVariable("S2dDacBias")->setDescription("");
   getVariable("S2dDacBias")->setRange(0,7);

   // CMD = 1, Addr = 14 : Bit  1:0 = tps_tcDAC[1:0]
   //                    : Bit  7:2 = TPS_DAC[5:0]
   addRegister(new Register("Config14", baseAddress_ + 0x0000100E));

   addVariable(new Variable("TpsTcDac", Variable::Configuration));
   getVariable("TpsTcDac")->setDescription("");
   getVariable("TpsTcDac")->setRange(0,3);

   addVariable(new Variable("TpsDac", Variable::Configuration));
   getVariable("TpsDac")->setDescription("");
   getVariable("TpsDac")->setRange(0,0x3F);

   // CMD = 1, Addr = 15 : Bit  1:0 = S2D_tcDAC[1:0]
   //                    : Bit  7:2 = S2D_DAC[5:0]
   addRegister(new Register("Config15", baseAddress_ + 0x0000100F));

   addVariable(new Variable("S2dTcDac", Variable::Configuration));
   getVariable("S2dTcDac")->setDescription("");
   getVariable("S2dTcDac")->setRange(0,3);

   addVariable(new Variable("S2dDac", Variable::Configuration));
   getVariable("S2dDac")->setDescription("");
   getVariable("S2dDac")->setRange(0,0x3F);

   // CMD = 1, Addr = 16 : Bit  0   = test_BE
   //                    : Bit  1   = is_en
   //                    : Bit  2   = delEXEC
   //                    : Bit  3   = delCCkreg
   addRegister(new Register("Config15", baseAddress_ + 0x0000100F));

   addVariable(new Variable("TestBe", Variable::Configuration));
   getVariable("TestBe")->setDescription("");
   getVariable("TestBe")->setTrueFalse();

   addVariable(new Variable("IsEn", Variable::Configuration));
   getVariable("IsEn")->setDescription("");
   getVariable("IsEn")->setTrueFalse();

   addVariable(new Variable("DelExec", Variable::Configuration));
   getVariable("DelExec")->setDescription("");
   getVariable("DelExec")->setTrueFalse();

   addVariable(new Variable("DelCckRef", Variable::Configuration));
   getVariable("DelCckRef")->setDescription("");
   getVariable("DelCckRef")->setTrueFalse();

   // CMD = 1, Addr = 18 : Row stop  address[9:0]
   addRegister(new Register("RowStopAddr", baseAddress_ + 0x00001012));

   addVariable(new Variable("RowStopAddr", Variable::Configuration));
   getVariable("RowStopAddr")->setDescription("");
   getVariable("RowStopAddr")->setRange(0,0x2FF);

   // CMD = 1, Addr = 20 : Col stop  address[9:0]
   addRegister(new Register("ColStopAddr", baseAddress_ + 0x00001014));

   addVariable(new Variable("ColStopAddr", Variable::Configuration));
   getVariable("ColStopAddr")->setDescription("");
   getVariable("ColStopAddr")->setRange(0,0x2FF);

   // CMD = 1, Addr = 21 : Chip ID Read
   addRegister(new Register("ChipId", baseAddress_ + 0x00001015));

   addVariable(new Variable("ChipId", Variable::Status));
   getVariable("ChipId")->setDescription("");

   // CMD = 6, Addr = 17 : Row start address[9:0]
   addRegister(new Register("RowStartAddr", baseAddress_ + 0x00006011));

   addVariable(new Variable("RowStartAddr", Variable::Configuration));
   getVariable("RowStartAddr")->setDescription("");
   getVariable("RowStartAddr")->setRange(0,0x2FF);

   // CMD = 6, Addr = 19 : Col start address[9:0]
   addRegister(new Register("ColStartAddr", baseAddress_ + 0x00006011));

   addVariable(new Variable("ColStartAddr", Variable::Configuration));
   getVariable("ColStartAddr")->setDescription("");
   getVariable("ColStartAddr")->setRange(0,0x2FF);

   // CMD = 2, Addr = X  : Write Row with data
   addRegister(new Register("WriteRowData", baseAddress_ + 0x00002000));

   // CMD = 3, Addr = X  : Write Column with data
   addRegister(new Register("WriteColData", baseAddress_ + 0x00003000));

   // CMD = 4, Addr = X  : Write Matrix with data
   addRegister(new Register("WriteMatrixData", baseAddress_ + 0x00004000));

   // CMD = 5, Addr = X  : Read/Write Pixel with data
   addRegister(new Register("WritePixelData", baseAddress_ + 0x00005000));

   // CMD = 7, Addr = X  : Prepare to write chip ID
   addRegister(new Register("PrepareWriteChipId", baseAddress_ + 0x00007000));

   // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
   addRegister(new Register("PrepareMultiConfig", baseAddress_ + 0x00008000));

   // Pixel Configuration
   //                    : Bit 0 = Test
   //                    : Bit 1 = Test
   addVariable(new Variable("PixelMask", Variable::Configuration));
   getVariable("PixelMask")->setDescription("Dummy Pixel Mask");
   getVariable("PixelMask")->setTrueFalse();

   addVariable(new Variable("PixelTest", Variable::Configuration));
   getVariable("PixelTest")->setDescription("Dummy Pixel Test");
   getVariable("PixelTest")->setTrueFalse();

   // To Write a single pixel:
      // CMD = 6, Addr = 17 : Row start address[9:0]
      // CMD = 6, Addr = 19 : Col start address[9:0]
      // CMD = 5, Addr = X  : Read/Write Pixel

   // Configure entire matrix
      // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
      // CMD = 4, Addr = X  : Write Matrix With passed data

   // Configure row 
      // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
      // CMD = 6, Addr = 17 : Row start address[9:0]
      // CMD = 2, Addr = X  : Write Row with Data

   // Configure col 
      // CMD = 8, Addr = X  : Prepare for row/column/matrix configuration
      // CMD = 6, Addr = 19 : Col start address[9:0]
      // CMD = 3, Addr = X  : Write Col with Data

}

// Deconstructor
EpixAsic::~EpixAsic ( ) { }

// Method to read status registers and update variables
void EpixAsic::readStatus ( ) {
   REGISTER_LOCK

   // Read status register
   readRegister(getRegister("ChipId"));
   getVariable("ChipId")->setInt(getRegister("ChipId")->get());

   REGISTER_UNLOCK
}

// Method to read configuration registers and update variables
void EpixAsic::readConfig ( ) {

   REGISTER_LOCK

   // CMD = 1, Addr = 1  : Pulser bits 2:0
   readRegister(getRegister("MonostPulser"));
   getVariable("MonostPulser")->setInt(getRegister("MonostPulser")->get(0,0x7));

   // CMD = 1, Addr = 2  : Pixel dummy, write data
   //                    : Bit 0 = Test
   //                    : Bit 1 = Mask
   readRegister(getRegister("PixelDummy"));
   getVariable("DummlTest")->setInt(getRegister("PixelDummy")->get(0,0x1));
   getVariable("DummlMask")->setInt(getRegister("PixelDummy")->get(1,0x1));

   // CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
   //                    : Bit  10  = pbit
   //                    : Bit  11  = atest
   //                    : Bit  12  = test
   //                    : Bit  13  = sab_test
   //                    : Bit  14  = hrtest
   readRegister(getRegister("Config3"));
   getVariable("Pulser")->setInt(getRegister("Config3")->get(0,0x3FF));
   getVariable("PBit")->setInt(getRegister("Config3")->get(10,0x1));
   getVariable("ATest")->setInt(getRegister("Config3")->get(11,0x1));
   getVariable("Test")->setInt(getRegister("Config3")->get(12,0x1));
   getVariable("SabTest")->setInt(getRegister("Config3")->get(13,0x1));
   getVariable("HrTest")->setInt(getRegister("Config3")->get(14,0x1));

   // CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
   //                    : Bits 7:4 = DM2[3:0]
   readRegister(getRegister("Config4"));
   getVariable("DigMon1")->setInt(getRegister("Config4")->get(0,0xF));
   getVariable("DigMon2")->setInt(getRegister("Config4")->get(4,0xF));

   // CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC[2:0]
   readRegister(getRegister("PulserDac"));
   getVariable("PulserDac")->setInt(getRegister("PulserDac")->get(0,0x7));

   // CMD = 1, Addr = 6  : Bit  0   = DM1en
   //                    : Bit  1   = DM2en
   //                    : Bit  4   = SLVDSbit
   readRegister(getRegister("Config6"));
   getVariable("Dm1En")->setInt(getRegister("Config6")->get(0,0x1));
   getVariable("Dm2En")->setInt(getRegister("Config6")->get(1,0x1));
   getVariable("SlvdSBit")->setInt(getRegister("Config6")->get(4,0x1));

   // CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
   readRegister(getRegister("VRef"));
   getVariable("VRef")->setInt(getRegister("VRef")->get(0,0x3F));

   // CMD = 1, Addr = 8  : Bit  0   = TPS_tcomp
   //                    : Bit  4:1 = TPS_MUX[3:0]
   //                    : Bit  7:5 = TO_Monost[2:0]
   readRegister(getRegister("Config8"));
   getVariable("TpsTComp")->setInt(getRegister("Config8")->get(0,0x1));
   getVariable("TpsMux")->setInt(getRegister("Config8")->get(4,0xf));
   getVariable("ToMonost")->setInt(getRegister("Config8")->get(5,0x7));

   // CMD = 1, Addr = 9  : Bit  3:0 = TPS_GR[3:0]
   //                    : Bit  7:4 = S2D_GR[3:0]
   readRegister(getRegister("Config9"));
   getVariable("TpsGr")->setInt(getRegister("Config9")->get(0,0xf));
   getVariable("S2dGr")->setInt(getRegister("Config9")->get(4,0xf));

   // CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
   //                    : Bit  3:1 = OCB[2:0]
   //                    : Bit  6:4 = Monost[2:0]
   //                    : Bit  7   = fastpp_enable
   readRegister(getRegister("Config10"));
   getVariable("PpOcbS2d")->setInt(getRegister("Config10")->get(0,0x1));
   getVariable("Ocb")->setInt(getRegister("Config10")->get(1,0x7));
   getVariable("Monost")->setInt(getRegister("Config10")->get(4,0x7));
   getVariable("FastppEnable")->setInt(getRegister("Config10")->get(7,0x1));

   // CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
   //                    : Bit  6:4 = Pixel_CB[2:0]
   readRegister(getRegister("Config11"));
   getVariable("Preamp")->setInt(getRegister("Config11")->get(0,0x7));
   getVariable("PixelCb")->setInt(getRegister("Config11")->get(4,0x7));

   // CMD = 1, Addr = 12 : Bit  0   = S2D_tcomp
   //                    : Bit  6:1 = Filter_Dac[5:0]
   readRegister(getRegister("Config12"));
   getVariable("S2dTComp")->setInt(getRegister("Config12")->get(0,0x1));
   getVariable("FilterDac")->setInt(getRegister("Config12")->get(1,0x3F));

   // CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
   //                    : Bit  4:2 = S2D[2:0]
   //                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
   readRegister(getRegister("Config13"));
   getVariable("TC")->setInt(getRegister("Config13")->get(0,0x3));
   getVariable("S2d")->setInt(getRegister("Config13")->get(2,0x7));
   getVariable("S2dDacBias")->setInt(getRegister("Config13")->get(5,0x7));

   // CMD = 1, Addr = 14 : Bit  1:0 = tps_tcDAC[1:0]
   //                    : Bit  7:2 = TPS_DAC[5:0]
   readRegister(getRegister("Config14"));
   getVariable("TpsTcDac")->setInt(getRegister("Config14")->get(0,0x3));
   getVariable("TpsDac")->setInt(getRegister("Config14")->get(2,0x3F));

   // CMD = 1, Addr = 15 : Bit  1:0 = S2D_tcDAC[1:0]
   //                    : Bit  7:2 = S2D_DAC[5:0]
   readRegister(getRegister("Config15"));
   getVariable("S2dTcDac")->setInt(getRegister("Config15")->get(0,0x3));
   getVariable("S2dDac")->setInt(getRegister("Config15")->get(2,0x3F));

   // CMD = 1, Addr = 16 : Bit  0   = test_BE
   //                    : Bit  1   = is_en
   //                    : Bit  2   = delEXEC
   //                    : Bit  3   = delCCkreg
   readRegister(getRegister("Config16"));
   getVariable("TestBe")->setInt(getRegister("Config16")->get(0,0x1));
   getVariable("IsEn")->setInt(getRegister("Config16")->get(1,0x1));
   getVariable("DelExec")->setInt(getRegister("Config16")->get(2,0x1));
   getVariable("DelCckRef")->setInt(getRegister("Config16")->get(3,0x1));

   // CMD = 1, Addr = 18 : Row stop  address[9:0]
   readRegister(getRegister("RowStopAddr"));
   getVariable("RowStopAddr")->setInt(getRegister("RowStopAddr")->get(0,0x3FF));

   // CMD = 1, Addr = 20 : Col stop  address[9:0]
   readRegister(getRegister("ColStopAddr"));
   getVariable("ColStopAddr")->setInt(getRegister("ColStopAddr")->get(0,0x3FF));

   // CMD = 6, Addr = 17 : Row start address[9:0]
   readRegister(getRegister("RowStartAddr"));
   getVariable("RowStartAddr")->setInt(getRegister("RowStartAddr")->get(0,0x3FF));

   // CMD = 6, Addr = 19 : Col start address[9:0]
   readRegister(getRegister("ColStartAddr"));
   getVariable("ColStartAddr")->setInt(getRegister("ColStartAddr")->get(0,0x3FF));

   // CMD = 5, Addr = X  : Read/Write Pixel with data
   readRegister(getRegister("WritePixelData"));
   getVariable("PixelTest")->setInt(getRegister("WritePixelData")->get(0,0x1));
   getVariable("PixelMask")->setInt(getRegister("WritePixelData")->get(1,0x1));

   REGISTER_UNLOCK
}

// Method to write configuration registers
void EpixAsic::writeConfig ( bool force ) {

   REGISTER_LOCK

   // CMD = 1, Addr = 1  : Pulser bits 2:0
   getRegister("MonostPulser")->set(getVariable("MonostPulser")->getInt(),0,0x7);
   writeRegister(getRegister("MonostPulser"),force);

   // CMD = 1, Addr = 2  : Pixel dummy, write data
   //                    : Bit 0 = Test
   //                    : Bit 1 = Mask
   getRegister("PixelDummy")->set(getVariable("DummlTest")->getInt(),0,0x1);
   getRegister("PixelDummy")->set(getVariable("DummlMask")->getInt(),1,0x1);
   writeRegister(getRegister("PixelDummy"),force);

   // CMD = 1, Addr = 3  : Bits 9:0 = Pulser[9:0]
   //                    : Bit  10  = pbit
   //                    : Bit  11  = atest
   //                    : Bit  12  = test
   //                    : Bit  13  = sab_test
   //                    : Bit  14  = hrtest
   getRegister("Config3")->set(getVariable("Pulser")->getInt(),0,0x3FF);
   getRegister("Config3")->set(getVariable("PBit")->getInt(),10,0x1);
   getRegister("Config3")->set(getVariable("ATest")->getInt(),11,0x1);
   getRegister("Config3")->set(getVariable("Test")->getInt(),12,0x1);
   getRegister("Config3")->set(getVariable("SabTest")->getInt(),13,0x1);
   getRegister("Config3")->set(getVariable("HrTest")->getInt(),14,0x1);
   writeRegister(getRegister("Config3"),force);

   // CMD = 1, Addr = 4  : Bits 3:0 = DM1[3:0]
   //                    : Bits 7:4 = DM2[3:0]
   getRegister("Config4")->set(getVariable("DigMon1")->getInt(),0,0xF);
   getRegister("Config4")->set(getVariable("DigMon2")->getInt(),4,0xF);
   writeRegister(getRegister("Config4"),force);

   // CMD = 1, Addr = 5  : Bits 2:0 = Pulser DAC[2:0]
   getRegister("PulserDac")->set(getVariable("PulserDac")->getInt(),0,0x7);
   writeRegister(getRegister("PulserDac"),force);

   // CMD = 1, Addr = 6  : Bit  0   = DM1en
   //                    : Bit  1   = DM2en
   //                    : Bit  4   = SLVDSbit
   getRegister("Config6")->set(getVariable("Dm1En")->getInt(),0,0x1);
   getRegister("Config6")->set(getVariable("Dm2En")->getInt(),1,0x1);
   getRegister("Config6")->set(getVariable("SlvdSBit")->getInt(),4,0x1);
   writeRegister(getRegister("Config6"),force);

   // CMD = 1, Addr = 7  : Bit  5:0 = VREF[5:0]
   getRegister("VRef")->set(getVariable("VRef")->getInt(),0,0x3F);
   writeRegister(getRegister("VRef"),force);

   // CMD = 1, Addr = 8  : Bit  0   = TPS_tcomp
   //                    : Bit  4:1 = TPS_MUX[3:0]
   //                    : Bit  7:5 = TO_Monost[2:0]
   getRegister("Config8")->set(getVariable("TpsTComp")->getInt(),0,0x1);
   getRegister("Config8")->set(getVariable("TpsMux")->getInt(),4,0xf);
   getRegister("Config8")->set(getVariable("ToMonost")->getInt(),5,0x7);
   writeRegister(getRegister("Config8"),force);

   // CMD = 1, Addr = 9  : Bit  3:0 = TPS_GR[3:0]
   //                    : Bit  7:4 = S2D_GR[3:0]
   getRegister("Config9")->set(getVariable("TpsGr")->getInt(),0,0xf);
   getRegister("Config9")->set(getVariable("S2dGr")->getInt(),4,0xf);
   writeRegister(getRegister("Config9"),force);

   // CMD = 1, Addr = 10 : Bit  0   = PP_OCB_S2D
   //                    : Bit  3:1 = OCB[2:0]
   //                    : Bit  6:4 = Monost[2:0]
   //                    : Bit  7   = fastpp_enable
   getRegister("Config10")->set(getVariable("PpOcbS2d")->getInt(),0,0x1);
   getRegister("Config10")->set(getVariable("Ocb")->getInt(),1,0x7);
   getRegister("Config10")->set(getVariable("Monost")->getInt(),4,0x7);
   getRegister("Config10")->set(getVariable("FastppEnable")->getInt(),7,0x1);
   writeRegister(getRegister("Config10"),force);

   // CMD = 1, Addr = 11 : Bit  2:0 = Preamp[2:0]
   //                    : Bit  6:4 = Pixel_CB[2:0]
   getRegister("Config11")->set(getVariable("Preamp")->getInt(),0,0x7);
   getRegister("Config11")->set(getVariable("PixelCb")->getInt(),4,0x7);
   writeRegister(getRegister("Config11"),force);

   // CMD = 1, Addr = 12 : Bit  0   = S2D_tcomp
   //                    : Bit  6:1 = Filter_Dac[5:0]
   getRegister("Config12")->set(getVariable("S2dTComp")->getInt(),0,0x1);
   getRegister("Config12")->set(getVariable("FilterDac")->getInt(),1,0x3F);
   writeRegister(getRegister("Config12"),force);

   // CMD = 1, Addr = 13 : Bit  1:0 = tc[1:0]
   //                    : Bit  4:2 = S2D[2:0]
   //                    : Bit  7:5 = S2D_DAC_BIAS[2:0]
   getRegister("Config13")->set(getVariable("TC")->getInt(),0,0x3);
   getRegister("Config13")->set(getVariable("S2d")->getInt(),2,0x7);
   getRegister("Config13")->set(getVariable("S2dDacBias")->getInt(),5,0x7);
   writeRegister(getRegister("Config13"),force);

   // CMD = 1, Addr = 14 : Bit  1:0 = tps_tcDAC[1:0]
   //                    : Bit  7:2 = TPS_DAC[5:0]
   getRegister("Config14")->set(getVariable("TpsTcDac")->getInt(),0,0x3);
   getRegister("Config14")->set(getVariable("TpsDac")->getInt(),2,0x3F);
   writeRegister(getRegister("Config14"),force);

   // CMD = 1, Addr = 15 : Bit  1:0 = S2D_tcDAC[1:0]
   //                    : Bit  7:2 = S2D_DAC[5:0]
   getRegister("Config15")->set(getVariable("S2dTcDac")->getInt(),0,0x3);
   getRegister("Config15")->set(getVariable("S2dDac")->getInt(),2,0x3F);
   writeRegister(getRegister("Config15"),force);

   // CMD = 1, Addr = 16 : Bit  0   = test_BE
   //                    : Bit  1   = is_en
   //                    : Bit  2   = delEXEC
   //                    : Bit  3   = delCCkreg
   getRegister("Config16")->set(getVariable("TestBe")->getInt(),0,0x1);
   getRegister("Config16")->set(getVariable("IsEn")->getInt(),1,0x1);
   getRegister("Config16")->set(getVariable("DelExec")->getInt(),2,0x1);
   getRegister("Config16")->set(getVariable("DelCckRef")->getInt(),3,0x1);
   writeRegister(getRegister("Config16"),force);

   // CMD = 1, Addr = 18 : Row stop  address[9:0]
   getRegister("RowStopAddr")->set(getVariable("RowStopAddr")->getInt(),0,0x3FF);
   writeRegister(getRegister("RowStopAddr"),force);

   // CMD = 1, Addr = 20 : Col stop  address[9:0]
   getRegister("ColStopAddr")->set(getVariable("ColStopAddr")->getInt(),0,0x3FF);
   writeRegister(getRegister("ColStopAddr"),force);

   // CMD = 6, Addr = 17 : Row start address[9:0]
   getRegister("RowStartAddr")->set(getVariable("RowStartAddr")->getInt(),0,0x3FF);
   writeRegister(getRegister("RowStartAddr"),force);

   // CMD = 6, Addr = 19 : Col start address[9:0]
   getRegister("ColStartAddr")->set(getVariable("ColStartAddr")->getInt(),0,0x3FF);
   writeRegister(getRegister("ColStartAddr"),force);

   // CMD = 4, Addr = X  : Write Matrix With passed data
   getRegister("WriteMatrixData")->set(getVariable("PixelTest")->getInt(),0,0x1);
   getRegister("WriteMatrixData")->set(getVariable("PixelMask")->getInt(),1,0x1);

   if ( force || getRegister("WriteMatrixData")->isStale() ) {
      writeRegister(getRegister("PrepareMultiConfig",true);
      writeRegister(getRegister("WriteMatrixData"),true);
   }

   REGISTER_UNLOCK
}

// Verify hardware state of configuration
void EpixAsic::verifyConfig ( ) {

   REGISTER_LOCK

   verifyRegister(getRegister("MonostPulser"));
   verifyRegister(getRegister("PixelDummy"));
   verifyRegister(getRegister("Config3"));
   verifyRegister(getRegister("Config4"));
   verifyRegister(getRegister("PulserDac"));
   verifyRegister(getRegister("Config6"));
   verifyRegister(getRegister("VRef"));
   verifyRegister(getRegister("Config8"));
   verifyRegister(getRegister("Config9"));
   verifyRegister(getRegister("Config10"));
   verifyRegister(getRegister("Config11"));
   verifyRegister(getRegister("Config12"));
   verifyRegister(getRegister("Config13"));
   verifyRegister(getRegister("Config14"));
   verifyRegister(getRegister("Config15"));
   verifyRegister(getRegister("Config16"));
   verifyRegister(getRegister("RowStopAddr"));
   verifyRegister(getRegister("ColStopAddr"));
   verifyRegister(getRegister("RowStartAddr"));
   verifyRegister(getRegister("ColStartAddr"));

   REGISTER_UNLOCK
}

