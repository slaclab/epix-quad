//-----------------------------------------------------------------------------
// File          : EpixControl.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : EPXI Control
//-----------------------------------------------------------------------------
// Description :
// EpixControl Top Device
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
// 06/06/2013: created
//-----------------------------------------------------------------------------
#ifndef __EPIX_CONTROL_H__
#define __EPIX_CONTROL_H__

#include <System.h>
#include <EpixTypes.h>
using namespace std;

class CommLink;

class EpixControl : public System {

   EpixType epixType_;

   public:

      //! Constructor
      EpixControl ( CommLink *commLink_, string defFile, EpixType epixType, uint baseAddress, uint addrSize );

      //! Deconstructor
      ~EpixControl ( );

      //! Method to process a command
      /*!
       * Returns status string if locally processed. Otherwise
       * an empty string is returned.
       * \param name     Command name
       * \param arg      Optional arg
      */
      void command ( string name, string arg );

      //! Return local state, specific to each implementation
      string localState();

      //! Method to perform soft reset
      void softReset ( );

      //! Method to perform hard reset
      void hardReset ( );

      //! Method to set run state
      void setRunState ( string state );

};
#endif
