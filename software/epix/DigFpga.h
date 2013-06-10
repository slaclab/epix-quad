//-----------------------------------------------------------------------------
// File          : DigFpga.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// Digital FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/07/2013: created
//-----------------------------------------------------------------------------
#ifndef __DIG_FPGA_H__
#define __DIG_FPGA_H__

#include <Device.h>
using namespace std;

//! Class to contain APV25 
class DigFpga : public Device {

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param index       Device index
       * \param parent      Parent Device
      */
      DigFpga ( uint destination, uint index, Device *parent );

      //! Deconstructor
      ~DigFpga ( );

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
