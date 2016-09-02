//-----------------------------------------------------------------------------
// File          : EvrCntrl.cpp 
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// Evr Control
//-----------------------------------------------------------------------------
// This file is part of 'EPIX Development Softare'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'EPIX Development Softare', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
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
#include <Command.h>
#include <CommLink.h>
#include <PgpCardG3Link.h>
#include <MultDestPgpG3.h>
using namespace std;

// Constructor
EvrCntrl::EvrCntrl ( Device *parent, MultDestPgpG3 *mdp ) : Device(0,0,"evrCntrl",0,parent) {

   // Description
   desc_ = "EVR Control";
   _mdp = mdp;

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

   addVariable(new Variable("BeamDelay",       Variable::Configuration));
   addVariable(new Variable("DarkDelay",       Variable::Configuration));
   addVariable(new Variable("BeamCode",        Variable::Configuration));
   
   addCommand(new Command("SendOpCode"));
   getCommand("SendOpCode")->setDescription("Send zero opcode");

   getVariable("Enabled")->setHidden(true);
}

// Deconstructor
EvrCntrl::~EvrCntrl ( ) { }

// Method to read status registers and update variables
void EvrCntrl::readStatus ( ) {
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();


   if ( _mdp == NULL ) {
      getVariable("EvrStatus")->setInt(pgp->getEvrStatus());
      getVariable("EvrErrors")->setInt(pgp->getEvrErrors());
      getVariable("EvrCount")->setInt(pgp->getEvrCount(0));
      getVariable("EvrRawStat")->setInt(pgp->getEvrStatRaw());
   } else {
      getVariable("EvrStatus")->setInt(_mdp->getEvrStatus());
      getVariable("EvrErrors")->setInt(_mdp->getEvrErrors());
      getVariable("EvrCount")->setInt(_mdp->getEvrCount(0));
      getVariable("EvrRawStat")->setInt(_mdp->getEvrStatRaw());
   }
}

// Method to read configuration registers and update variables
void EvrCntrl::readConfig ( ) {
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();

   if ( _mdp == NULL ) {
      getVariable("EvrEnable")->setInt(pgp->getEvrEnable());
      getVariable("EvrEnableLane")->setInt(pgp->getEvrEnableLane());
      getVariable("EvrRunOpCode")->setInt(pgp->getEvrLaneRunOpCode(0));
      getVariable("EvrAcceptOpCode")->setInt(pgp->getEvrLaneAcceptOpCode(0));
      getVariable("EvrAcceptDelay")->setInt(pgp->getEvrLaneAcceptDelay(0));
      getVariable("EvrRunDelay")->setInt(pgp->getEvrLaneRunDelay(0));
   } else {
      getVariable("EvrEnable")->setInt(_mdp->getEvrEnable());
      getVariable("EvrEnableLane")->setInt(_mdp->getEvrEnableLane());
      getVariable("EvrRunOpCode")->setInt(_mdp->getEvrLaneRunOpCode(0));
      getVariable("EvrAcceptOpCode")->setInt(_mdp->getEvrLaneAcceptOpCode(0));
      getVariable("EvrAcceptDelay")->setInt(_mdp->getEvrLaneAcceptDelay(0));
      getVariable("EvrRunDelay")->setInt(_mdp->getEvrLaneRunDelay(0));
   }
}

// Method to write configuration registers
void EvrCntrl::writeConfig ( bool force ) {
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();

   if ( _mdp == NULL ) {
      pgp->setEvrEnable(getVariable("EvrEnable")->getInt());
      pgp->setEvrEnableLane(getVariable("EvrEnableLane")->getInt());
      pgp->setEvrLaneRunOpCode(0,getVariable("EvrRunOpCode")->getInt());
      pgp->setEvrLaneAcceptOpCode(0,getVariable("EvrAcceptOpCode")->getInt());
      pgp->setEvrLaneAcceptDelay(0,getVariable("EvrAcceptDelay")->getInt());
      pgp->setEvrLaneRunDelay(0,getVariable("EvrRunDelay")->getInt());
   } else {
      _mdp->setEvrEnable(getVariable("EvrEnable")->getInt());
      _mdp->setEvrEnableLane(getVariable("EvrEnableLane")->getInt());
      _mdp->setEvrLaneRunOpCode(0,getVariable("EvrRunOpCode")->getInt());
      _mdp->setEvrLaneAcceptOpCode(0,getVariable("EvrAcceptOpCode")->getInt());
      _mdp->setEvrLaneAcceptDelay(0,getVariable("EvrAcceptDelay")->getInt());
      _mdp->setEvrLaneRunDelay(0,getVariable("EvrRunDelay")->getInt());
   }
}


// Method to process a command
void EvrCntrl::command ( string name, string arg) {
   PgpCardG3Link *pgp = (PgpCardG3Link*)system_->commLink();

   if ( name == "SendOpCode" ) {
      if ( _mdp == NULL ) pgp->sendOpCode(0);
      else _mdp->sendOpCode(0);
   }
   else Device::command(name, arg);
}

