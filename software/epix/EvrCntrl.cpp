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
#include <EvrCntrl.h>
#include <System.h>
#include <CommLink.h>
#include <PgpCardG3Link.h>
using namespace std;

// Constructor
EvrCntrl::EvrCntrl ( Device *parent ) : Device(0,0,"evrCntrl",0,parent) {

   // Description
   desc_ = "EVR Control";

   addVariable(new Variable("EvrStatus", Variable::Status));
   addVariable(new Variable("EvrErrors", Variable::Status));
   addVariable(new Variable("EvrCount",  Variable::Status));
   addVariable(new Variable("EvrRawStat",Variable::Status));

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
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();

   getVariable("EvrStatus")->setInt(pgp->getEvrStatus());
   getVariable("EvrErrors")->setInt(pgp->getEvrErrors());
   getVariable("EvrCount")->setInt(pgp->getEvrCount(0));
   getVariable("EvrRawStat")->setInt(pgp->getEvrStatRaw());
}

// Method to read configuration registers and update variables
void EvrCntrl::readConfig ( ) {
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();

   getVariable("EvrEnable")->setInt(pgp->getEvrEnable());
   getVariable("EvrEnableLane")->setInt(pgp->getEvrEnableLane());
   getVariable("EvrRunOpCode")->setInt(pgp->getEvrLaneRunOpCode(0));
   getVariable("EvrAcceptOpCode")->setInt(pgp->getEvrLaneAcceptOpCode(0));
   getVariable("EvrAcceptDelay")->setInt(pgp->getEvrLaneAcceptDelay(0));
   getVariable("EvrRunDelay")->setInt(pgp->getEvrLaneRunDelay(0));
}

// Method to write configuration registers
void EvrCntrl::writeConfig ( bool force ) {
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();

   pgp->setEvrEnable(getVariable("EvrEnable")->getInt());
   pgp->setEvrEnableLane(getVariable("EvrEnableLane")->getInt());
   pgp->setEvrLaneRunOpCode(0,getVariable("EvrRunOpCode")->getInt());
   pgp->setEvrLaneAcceptOpCode(0,getVariable("EvrAcceptOpCode")->getInt());
   pgp->setEvrLaneAcceptDelay(0,getVariable("EvrAcceptDelay")->getInt());
   pgp->setEvrLaneRunDelay(0,getVariable("EvrRunDelay")->getInt());
}

