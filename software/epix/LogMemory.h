//-----------------------------------------------------------------------------
// File          : LogMemory.h
// Author        : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
// Created       : 07/01/2016
// Project       : 
//-----------------------------------------------------------------------------
// Description :
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Generic DAQ Software'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC Generic DAQ Software', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 07/01/2016: created
//-----------------------------------------------------------------------------
#ifndef __LOG_MEMORY_H__
#define __LOG_MEMORY_H__

#include <Device.h>
#include <stdint.h>
using namespace std;

//! Class to contain LogMemory
class LogMemory : public Device {

   public:

      //! Constructor
      /*! 
       * \param linkConfig Device linkConfig
       * \param baseAddress Device base address
       * \param index       Device index
       * \param parent      Parent device
      */
      LogMemory ( uint32_t linkConfig, uint32_t baseAddress, uint32_t index, Device *parent, uint32_t addrSize=1 );

      //! Deconstructor
      ~LogMemory ( );

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
      //void readConfig ( );

      //! Method to write configuration registers
      /*! 
       * Throws string on error.
       * \param force Write all registers if true, only stale if false
      */
      //void writeConfig ( bool force );
      
      char* getBuffer();
      unsigned int getSize();

   private:
      
      char memory_[1023*4];
      unsigned int ptr_, len_;
   
   
};

#endif
