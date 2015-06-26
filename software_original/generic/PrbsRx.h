//-----------------------------------------------------------------------------
// File          : PrbsRx.h
// Author        : Ben Reese <bareese@slac.stanford.edu>
// Created       : 11/12/2013
// Project       : Heavy Photon Search SVT DAQ
//-----------------------------------------------------------------------------
// Description :
// ADS1115 ADC
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//-----------------------------------------------------------------------------
#ifndef __PRBS_RX_H__
#define __PRBS_RX_H__

#include <Device.h>
using namespace std;

//! Class to contain AD9252
class PrbsRx : public Device {

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      PrbsRx ( uint destination, uint baseAddress, uint index, Device *parent );

      //! Deconstructor
      ~PrbsRx ( );

      //! Method to process a command
      /*!
       * \param name     Command name
       * \param arg      Optional arg
      */
      void command ( string name, string arg );

      //! Method to read status registers and update variables
      void readStatus ( );

      //! Method to read configuration registers and update variables
      /*!
       * Throws string error.
       */
      void readConfig ( );

      //! Method to write configuration registers
      /*! 
       * Throws string on error.
       * \param force Write all registers if true, only stale if false
      */
      void writeConfig ( bool force );

    private:
      void readStatusRegisterVariable(string name);
};

#endif
