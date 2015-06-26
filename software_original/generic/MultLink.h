//-----------------------------------------------------------------------------
// File          : MultLink.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/18/2014
// Project       : General Purpose
//-----------------------------------------------------------------------------
// Description :
// Mult link
//-----------------------------------------------------------------------------
// Copyright (c) 2014 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/18/2014: created
//-----------------------------------------------------------------------------
#ifndef __MULT_LINK_H__
#define __MULT_LINK_H__

#include <sys/types.h>
#include <string>
#include <sstream>
#include <map>
#include <pthread.h>
#include <unistd.h>
#include <CommLink.h>
using namespace std;

class MultDest {
   public:

      static const uint MultTypeUdp  = 1;
      static const uint MultTypePgp  = 2;
      static const uint MultTypeAxis = 3;

      uint                 *rxBuff_;
      uint                 udpPort_;
      struct sockaddr_in   udpAddr_;
      int                  fd_;
      uint                 type_;
      string               meta_;

      MultDest(uint type, string meta, int port = 0) { 
         rxBuff_  = NULL;
         type_    = type;
         meta_    = meta;
         udpPort_ = port;
      }
};


//! Class to contain PGP communications link
class MultLink : public CommLink {
   protected:

      // Destinations
      uint        destCount_;
      MultDest ** dests_;

      // TX Routines
      void pgpTx(uint x, uint *data, uint size, uint laneVc);
      void axisTx(uint x, uint *data, uint size, uint laneVc);
      void udpTx(uint x, uint *data, uint size, uint laneVc);

      // RX Routines
      int pgpRx(uint x, uint **data, uint *laneVc, bool *err);
      int axisRx(uint x, uint **data, uint *laneVc, bool *err);
      int udpRx(uint x, uint **data, uint *laneVc, bool *err);

      //! IO handling thread
      void ioHandler();

      //! RX handling thread
      void rxHandler();

   public:

      //! Constructor
      MultLink ( );

      //! Deconstructor
      ~MultLink ( );

      //! Open link and start threads
      /*! 
       * Throw string on error.
       * \param count destination count
       * \param dest  destinations
      */
      void open ( uint count, ... );
      void open ( uint count, MultDest **dests );

      //! Stop threads and close link
      void close ();

};
#endif
