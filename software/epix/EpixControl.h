//-----------------------------------------------------------------------------
// File          : EpixControl.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : EPXI Control
//-----------------------------------------------------------------------------
// Description :
// EpixControl Top Device
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/06/2013: created
//-----------------------------------------------------------------------------
#ifndef __EPIX_CONTROL_H__
#define __EPIX_CONTROL_H__

#include <System.h>
using namespace std;

class CommLink;

class EpixControl : public System {

   public:

      //! Constructor
      EpixControl ( CommLink *commLink_, string defFile );

      //! Deconstructor
      ~EpixControl ( );

      //! Return local state, specific to each implementation
      string localState();

      //! Method to perform soft reset
      void softReset ( );

      //! Method to perform hard reset
      void hardReset ( );

};
#endif
