//-----------------------------------------------------------------------------
// File          : PseudoScope.h
// Author        : Kurtis Nishimura (adapted from Ryan Herbst's framework)
// Created       : 03/21/2014
// Project       : ePix
//-----------------------------------------------------------------------------
// Description :
// Pseudo-oscilloscope
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
// 03/21/2014: created
//-----------------------------------------------------------------------------
#ifndef __PSEUDOSCOPE_H__
#define __PSEUDOSCOPE_H__

#include <Device.h>
using namespace std;

//! Class to contain PseudoScope
class PseudoScope : public Device {

   public:

      //! Constructor
      /*! 
       * \param destination Device destination
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      PseudoScope ( uint destination, uint baseAddress, uint index, Device *parent, uint addrSize );

      //! Deconstructor
      ~PseudoScope ( );

      //! Handle commands
      void command ( string name, string arg );

      //! Method to read configuration registers and update variables
      void readConfig ( );

      //! Method to write configuration registers
      /*! 
       * Throws string on error.
       * \param force Write all registers if true, only stale if false
      */
      void writeConfig ( bool force );
};

#endif
