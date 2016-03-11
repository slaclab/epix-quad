//-----------------------------------------------------------------------------
// File          : EvrCntrl.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// EVR Control
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/07/2013: created
//-----------------------------------------------------------------------------
#ifndef __EVR_CNTRL_H__
#define __EVR_CNTRL_H__

#include <Device.h>
using namespace std;

//! Class to contain APV25 
class EvrCntrl : public Device {

   public:

      EvrCntrl ( Device *parent );

      ~EvrCntrl ( );

      void readStatus ( );

      void readConfig ( );

      void writeConfig ( bool force );

      void command ( string name, string arg );
};
#endif
