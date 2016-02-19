//-----------------------------------------------------------------------------
// File          : Epix10kpAsic.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/06/2013
// Project       : EPIX ASIC
//-----------------------------------------------------------------------------
// Description :
// EPIX ASIC container
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/06/2013: created
//-----------------------------------------------------------------------------
#ifndef __EPIX10KP_ASIC_H__
#define __EPIX10KP_ASIC_H__

#include <Device.h>
using namespace std;

//! Class to contain Kpix ASIC
class Epix10kpAsic : public Device {

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      Epix10kpAsic ( uint destination, uint baseAddress, uint index, Device *parent );

      //! Deconstructor
      ~Epix10kpAsic ( );

      //! Method to process a command
      /*!
       * Returns status string if locally processed. Otherwise
       * an empty string is returned.
       * \param name     Command name
       * \param arg      Optional arg
      */
      void command ( string name, string arg );

      //! Method to read status registers and update variables
      /*! 
       * Throws string on error.
      */
      void readStatus ( );

      //! Method to read configuration registers and update variables
      /*! 
       * Throws string on error.
      */
      void readConfig ( );

      //! Method to write configuration registers
      /*! 
       * Throws string on error.
       * \param force Write all registers if true, only stale if false
      */
      void writeConfig ( bool force );

      //! Verify hardware state of configuration
      void verifyConfig ( );

};
#endif
