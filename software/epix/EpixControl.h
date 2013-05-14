//-----------------------------------------------------------------------------
// File          : KpixControl.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 11/20/2011
// Project       : KPIX Asic
//-----------------------------------------------------------------------------
// Description :
// KpixControl Top Device
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 11/20/2011: created
//-----------------------------------------------------------------------------
#ifndef __KPIX_CONTROL_H__
#define __KPIX_CONTROL_H__

#include <System.h>
using namespace std;

class CommLink;

//! Class to contain APV25 
class KpixControl : public System {

      // setup calibration config
      void calibConfig ( uint channel, uint dac );

      // Software run thread
      void swRunThread();

   public:

      //! Constructor
      KpixControl ( CommLink *commLink_, string defFile, uint kpixCount );

      //! Deconstructor
      ~KpixControl ( );

      //! Method to set run state
      /*!
       * Set run state for the system. Default states are
       * Stopped & Running. Stopped must always be supported.
       * \param state    New run state
      */
      void setRunState ( string state );

      //! Method to process a command
      /*!
       * Returns status string if locally processed. Otherwise
       * an empty string is returned.
       * Throws string on error
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

};
#endif
