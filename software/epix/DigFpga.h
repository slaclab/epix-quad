//-----------------------------------------------------------------------------
// File          : ConFpga.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 05/24/2012
// Project       : Kpix ASIC
//-----------------------------------------------------------------------------
// Description :
// Con FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 05/24/2012: created
//-----------------------------------------------------------------------------
#ifndef __CON_FPGA_H__
#define __CON_FPGA_H__

#include <Device.h>
using namespace std;

//! Class to contain APV25 
class ConFpga : public Device {

      // Number of kpix devices
      unsigned int kpixCount;

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param index       Device index
       * \param parent      Parent Device
      */
      ConFpga ( uint destination, uint index, uint kpixCount, Device *parent );

      //! Deconstructor
      ~ConFpga ( );

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
