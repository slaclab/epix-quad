//-----------------------------------------------------------------------------
// File          : EvrCntrl.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// EVR Control
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
#ifndef __EVR_CNTRL_H__
#define __EVR_CNTRL_H__

#include <Device.h>
using namespace std;

class MultDestPgpG3;

//! Class to contain APV25 
class EvrCntrl : public Device {
     
      MultDestPgpG3 * _mdp;


   public:

      EvrCntrl ( Device *parent, MultDestPgpG3 *mdp = NULL );

      ~EvrCntrl ( );

      void readStatus ( );

      void readConfig ( );

      void writeConfig ( bool force );

      void command ( string name, string arg );
};
#endif
