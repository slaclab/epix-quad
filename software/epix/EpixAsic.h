//-----------------------------------------------------------------------------
// File          : KpixAsic.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 11/17/2011
// Project       : Kpix ASIC
//-----------------------------------------------------------------------------
// Description :
// Kpix ASIC container
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 11/17/2011: created
//-----------------------------------------------------------------------------
#ifndef __KPIX_ASIC_H__
#define __KPIX_ASIC_H__

#include <Device.h>
using namespace std;

//! Class to contain Kpix ASIC
class KpixAsic : public Device {

      // Kpix is dummy
      bool dummy_;

      // Kpix version
      uint version_;

      // Time value to use for timing calculations
      static const uint KpixAcqPeriod = 50;

      // Function to convert dac value into a voltage
      static double dacToVolt(uint dac);

      // Function to convert dac value into a voltage
      static string dacToVoltString(uint dac);

      // Function to time value to string
      static string timeString(uint period, uint value);

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param baseAddress Device base address
       * \param index       Device index
       * \param dummy       Kpix is a dummy device
       * \param parent      Parent device
      */
      KpixAsic ( uint destination, uint baseAddress, uint index, bool dummy, Device *parent );

      //! Deconstructor
      ~KpixAsic ( );

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

      //! Channel count
      uint channels();

};
#endif
