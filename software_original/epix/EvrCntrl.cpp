//-----------------------------------------------------------------------------
// File          : EvrCntrl.cpp 
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// Evr Control
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/07/2013: created
//-----------------------------------------------------------------------------
#include <Variable.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
EvrCntrl::EvrCntrl ( Device *parent ) : Device(0,0,"evrCntrl",0,parent) {

   // Description
   desc_ = "EVR Control";

   addVariable(new Variable("EvrStatus", Variable::Status));
   addVariable(new Variable("EvrErrors", Variable::Status));

   addVariable(new Variable("EvrEnable",       Variable::Configuration));
   addVariable(new Variable("EvrEnableLane",   Variable::Configuration));
   addVariable(new Variable("EvrRunOpCode",    Variable::Configuration));
   addVariable(new Variable("EvrAcceptOpCode", Variable::Configuration));
   addVariable(new Variable("EvrAcceptDelay",  Variable::Configuration));
   addVariable(new Variable("EvrRunDelay",     Variable::Configuration));

   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
EvrCntrl::~EvrCntrl ( ) { }

// Method to read status registers and update variables
void EvrCntrl::readStatus ( ) {
   getVariable("EvrStatus")->setInt(getEvrStatus());
   getVariable("EvrErrors")->setInt(getEvrErrors());
}

// Method to read configuration registers and update variables
void EvrCntrl::readConfig ( ) {
   getVariable("EvrEnable")->setInt(getEvrEnable());
   getVariable("EvrEnableLane")->setInt(getEvrEnableLane(0));
   getVariable("EvrRunOpCode")->setInt(getEvrRunOpCode(0));
   getVariable("EvrAcceptOpCode")->setInt(getEvrAcceptOpCode(0));
   getVariable("EvrAcceptDelay")->setInt(getEvrAcceptDelay(0));
   getVariable("EvrRunDelay")->setInt(getEvrRunDelay(0));
   Device::readConfig();
}

// Method to write configuration registers
void EvrCntrl::writeConfig ( bool force ) {
   setEvrEnable(getVariable("EvrEnable")->getInt());
   setEvrEnableLane(getVariable("EvrEnableLane")->getInt());
   setEvrLaneRunOpCode(getVariable("EvrRunOpCode")->getInt());
   setEvrLaneAcceptOpCode(getVariable("EvrAcceptOpCode")->getInt());
   setEvrLaneAcceptDelay(getVariable("EvrAcceptDelay")->getInt());
   setEvrLaneRunDelay(getVariable("EvrRunDelay")->getInt());
}

