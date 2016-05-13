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
#ifndef __EPIX_ESA_CONTROL_H__
#define __EPIX_ESA_CONTROL_H__

#include <System.h>
#include <EpixTypes.h>
using namespace std;

class CommLink;

class EpixEsaControl : public System {

   EpixType epixType_;

   public:

      //! Constructor
      EpixEsaControl ( CommLink *commLink_, string defFile, EpixType epixType, uint baseAddress, uint addrSize );

      //! Deconstructor
      ~EpixEsaControl ( );

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
