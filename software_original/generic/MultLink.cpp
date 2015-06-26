//-----------------------------------------------------------------------------
// File          : MultLink.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/18/2014
// Project       : General Purpose
//-----------------------------------------------------------------------------
// Description :
// RCE communications link
//-----------------------------------------------------------------------------
// Copyright (c) 2014 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 06/18/2014: created
//-----------------------------------------------------------------------------
#include <MultLink.h>
#include <PgpCardMod.h>
#include <PgpCardWrap.h>
#include <sstream>
#include "Register.h"
#include "Command.h"
#include "Data.h"
#include <fcntl.h>
#include <iostream>
#include <iomanip>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <stdarg.h>
using namespace std;

void MultLink::pgpTx(uint x, uint *data, uint size, uint laneVc) {
   uint lane;
   uint vc;

   lane = (laneVc >> 4) & 0xf;
   vc   = (laneVc     ) & 0xf;

   pgpcard_send(dests_[x]->fd_, data, size, lane, vc);
}

void MultLink::axisTx(uint x, uint *data, uint size, uint laneVc) {
   uint buffer[size+1];

   buffer[0]  = laneVc & 0xFF;
   buffer[0] += 0x0200; // First user SOF

   memcpy(buffer+1,data,size*4);

   ::write(dests_[x]->fd_, buffer, (size*4)+4);
}

void MultLink::udpTx(uint x, uint *data, uint size, uint laneVc) {
   uint  buffer[size+1];
   uint  header;
   uint  y;

   // Form header, continue bit and index are zero
   header  = (laneVc << 24) & 0xFF000000;

   // Copy payload integer by integer and convert
   buffer[0] = htonl(header);
   for ( y=0; y < size; y++ ) buffer[y+1] = htonl(data[y]);

   // Send
   sendto(dests_[x]->fd_,buffer,(size*4)+4,0,(struct sockaddr *)(&(dests_[x]->udpAddr_)),sizeof(struct sockaddr_in));
}

// Transmit thread
void MultLink::ioHandler() {
   uint           cmdBuff[4];
   uint           runBuff[4];
   uint           lastReqCnt;
   uint           lastCmdCnt;
   uint           lastRunCnt;
   uint           lastDataCnt;
   uint           regLaneSize;
   uint           idx;
   uint           laneVc;
   
   // Setup
   lastReqCnt  = regReqCnt_;
   lastCmdCnt  = cmdReqCnt_;
   lastRunCnt  = runReqCnt_;
   lastDataCnt = dataReqCnt_;

   // Init register buffer
   regBuff_ = (uint *) malloc(sizeof(uint)*maxRxTx_);

   // While enabled
   while ( runEnable_ ) {

      // Run Command TX is pending
      if ( lastRunCnt != runReqCnt_ ) {
         idx    = (runReqDest_      ) & 0xFF;
         laneVc = (runReqDest_ >> 16) & 0xFF;

         // Setup tx buffer
         runBuff[0]  = 0;
         runBuff[1]  = runReqEntry_->opCode() & 0xFF;
         runBuff[2]  = 0;
         runBuff[3]  = 0;
 
         // Send data
         if ( idx < destCount_ && dests_[idx] != NULL ) {
            switch(dests_[idx]->type_) {
               case MultDest::MultTypePgp  : pgpTx(idx,runBuff,4,laneVc); break;
               case MultDest::MultTypeUdp  : udpTx(idx,runBuff,4,laneVc); break;
               case MultDest::MultTypeAxis : axisTx(idx,runBuff,4,laneVc); break;
            }
         }
  
         // Match request count
         lastRunCnt = runReqCnt_;
      }

      // Register TX is pending
      else if ( lastReqCnt != regReqCnt_ ) {
         idx    = (regReqDest_     ) & 0xFF;
         laneVc = (regReqDest_ >> 8) & 0xFF;

         // Setup tx buffer
         regBuff_[0]  = regReqEntry_->address() & 0xFF000000;
         regBuff_[1]  = (regReqWrite_)?0x40000000:0x00000000;
         regBuff_[1] |= regReqEntry_->address() & 0x00FFFFFF;

         // Write has data
         if ( regReqWrite_ ) {
            memcpy(&(regBuff_[2]),regReqEntry_->data(),(regReqEntry_->size()*4));
            regBuff_[regReqEntry_->size()+2]  = 0;
         }

         // Read is always small
         else {
            regBuff_[2]  = (regReqEntry_->size()-1);
            regBuff_[3]  = 0;
         }

         regLaneSize = (regReqWrite_)?regReqEntry_->size()+3:4;

         // Send data
         if ( idx < destCount_ && dests_[idx] != NULL ) {
            switch(dests_[idx]->type_) {
               case MultDest::MultTypePgp  : pgpTx(idx,regBuff_,regLaneSize,laneVc); break;
               case MultDest::MultTypeUdp  : udpTx(idx,regBuff_,regLaneSize,laneVc); break;
               case MultDest::MultTypeAxis : axisTx(idx,regBuff_,regLaneSize,laneVc); break;
            }
         }
 
         // Match request count
         lastReqCnt = regReqCnt_;
      }

      // Command TX is pending
      else if ( lastCmdCnt != cmdReqCnt_ ) {
         idx    = (cmdReqDest_      ) & 0xFF;
         laneVc = (cmdReqDest_ >> 16) & 0xFF;

         // Setup tx buffer
         cmdBuff[0]  = 0;
         cmdBuff[1]  = cmdReqEntry_->opCode() & 0xFF;
         cmdBuff[2]  = 0;
         cmdBuff[3]  = 0;

         // Send data
         if ( idx < destCount_ && dests_[idx] != NULL ) {
            switch(dests_[idx]->type_) {
               case MultDest::MultTypePgp  : pgpTx(idx,cmdBuff,4,laneVc); break;
               case MultDest::MultTypeUdp  : udpTx(idx,cmdBuff,4,laneVc); break;
               case MultDest::MultTypeAxis : axisTx(idx,cmdBuff,4,laneVc); break;
            }
         }

         // Match request count
         lastCmdCnt = cmdReqCnt_;
         cmdRespCnt_++;
      }

      // Data TX is pending
      else if ( lastDataCnt != dataReqCnt_ ) {
         idx    = (dataReqDest_      ) & 0xFF;
         laneVc = (dataReqDest_ >> 24) & 0xFF;

         // Send data
         if ( idx < destCount_ && dests_[idx] != NULL ) {
            switch(dests_[idx]->type_) {
               case MultDest::MultTypePgp  : pgpTx(idx,dataReqEntry_,dataReqLength_,laneVc); break;
               case MultDest::MultTypeUdp  : udpTx(idx,dataReqEntry_,dataReqLength_,laneVc); break;
               case MultDest::MultTypeAxis : axisTx(idx,dataReqEntry_,dataReqLength_,laneVc); break;
            }
         }
         
         // Match request count
         lastDataCnt = dataReqCnt_;
         dataRespCnt_++;
      }

      else usleep(10);
   }

   free(regBuff_);
}

// PGP RX
int MultLink::pgpRx(uint x, uint **data, uint *laneVc, bool *err) {
   int  ret;
   uint lane;
   uint vc;
   uint eofe;
   uint fifoErr;
   uint lengthErr;

   *laneVc = 0;
   *err    = false;
   *data   = dests_[x]->rxBuff_;

   // Setup and attempt receive
   ret = pgpcard_recv(dests_[x]->fd_, dests_[x]->rxBuff_, maxRxTx_, &lane, &vc, &eofe, &fifoErr, &lengthErr);

   // No data
   if ( ret <= 0 ) return(0);

   // Bad size or error
   if ( ret < 4 || eofe || fifoErr || lengthErr ) {
      if ( debug_ ) {
         cout << "MultLink::pgpRx -> "
              << "Error in data receive. Rx=" << dec << ret
              << ", Lane=" << dec << lane << ", Vc=" << dec << vc
              << ", EOFE=" << dec << eofe << ", FifoErr=" << dec << fifoErr
              << ", LengthErr=" << dec << lengthErr << endl;
      }
      *err = true;
      errorCount_++;
      return(0);
   }

   *laneVc  = (lane <<  4) & 0xF0;
   *laneVc += (vc        ) & 0x0F;
   return(ret);
}

// Axis Rx
int MultLink::axisRx(uint x, uint **data, uint *laneVc, bool *err) {
   int   ret;
   uint  eofe;
   uint  lengthErr;

   *laneVc = 0;
   *err    = false;
   *data   = dests_[x]->rxBuff_+1;

   // Setup and attempt receive
   ret = ::read(dests_[x]->fd_, dests_[x]->rxBuff_, maxRxTx_*4);

   // No data
   if ( ret <= 0 ) return(0);

   // Extract status
   *laneVc   = (dests_[x]->rxBuff_[0]       ) & 0xFF;
   eofe      = (dests_[x]->rxBuff_[0] >> 16 ) & 0x1;
   lengthErr = (dests_[x]->rxBuff_[0] >> 25 ) & 0x1;

   // Bad size or error
   if ( (ret % 4) != 0 || (ret-4) < 5 || eofe || lengthErr ) {
      if ( debug_ ) {
         cout << "MultLink::axisRx -> "
              << "Error in data receive. Rx=" << dec << (ret-1)
              << ", LaneVc=" << dec << *laneVc
              << ", EOFE=" << dec << eofe 
              << ", LengthErr=" << dec << lengthErr << endl;
      }
      *err = true;
      errorCount_++;
      return(0);
   }

   return((ret/4)-1);
}

// UDP Rx
int MultLink::udpRx(uint x, uint **data, uint *laneVc, bool *err) {
   int   ret;
   uint  y;
   uint  header;
  
   *laneVc = 0;
   *err    = false;
   *data   = dests_[x]->rxBuff_+1;

   // Attempt receive
   ret = ::read(dests_[x]->fd_, dests_[x]->rxBuff_, maxRxTx_*4);

   // No data
   if ( ret <= 0 ) return(0);

   // Convert data
   for ( y=0; y < (uint)(ret/4); y++ ) dests_[x]->rxBuff_[y] = ntohl(dests_[x]->rxBuff_[y]);
   header = dests_[x]->rxBuff_[0];

   // Extract header
   *laneVc = (header >> 24) & 0xFF;

   // Continue bit and index must be zero
   if ( (header & 0x00FFFFFF) != 0 ) {
      if ( debug_ ) {
         cout << "MultLink::udpRx -> "
              << "Multi frame UDP message received." << endl;
      }
      *err = true;
      errorCount_++;
      return(0);
   }

   // Bad size or error
   if ( (ret % 4) != 0 || (ret-4) < 5 ) {
      if ( debug_ ) {
         cout << "MultLink::udpRx -> "
              << "Error in data receive. Rx=" << dec << ((ret/4)-1)
              << ", LaneVc=" << dec << *laneVc << endl;
      }
      *err = true;
      errorCount_++;
      return(0);
   }

   return((ret/4)-1);
}

// Receive Thread
void MultLink::rxHandler() {
   uint           x;
   int            maxFd;
   struct timeval timeout;
   uint         * buff;
   fd_set         fds;
   int            ret;
   Data         * data;
   bool           err;
   uint           laneVc;
   uint           dataMaskRx;
   uint           dest;

   // Init buffer
   for (x=0; x < destCount_; x++) {
      if ( dests_[x] != NULL ) dests_[x]->rxBuff_ = (uint *) malloc(sizeof(uint)*maxRxTx_);
   }

   // While enabled
   while ( runEnable_ ) {

      // Init fds
      FD_ZERO(&fds);
      maxFd = 0;

      // Process each dest
      for (x=0; x < destCount_; x++) {
         if ( dests_[x] != NULL ) {
            FD_SET(dests_[x]->fd_,&fds);
            if ( dests_[x]->fd_ > maxFd ) maxFd = dests_[x]->fd_;
         }
      }

      // Setup timeout
      timeout.tv_sec  = 0;
      timeout.tv_usec = 500;

      // Select
      if ( select(maxFd+1, &fds, NULL, NULL, &timeout) <= 0 ) continue;

      // Process each dest
      for (x=0; x < destCount_; x++) {
         if ( dests_[x] != NULL && FD_ISSET(dests_[x]->fd_,&fds) ) {

            // Receive
            switch(dests_[x]->type_) {
               case MultDest::MultTypePgp  : ret = pgpRx(x,&buff,&laneVc,&err); break;
               case MultDest::MultTypeUdp  : ret = udpRx(x,&buff,&laneVc,&err); break;
               case MultDest::MultTypeAxis : ret = axisRx(x,&buff,&laneVc,&err); break;
            }

            // Return
            if ( ret > 0 ) {

               // Check for data packet, use lower 4 laneVc bits to set rx mask bit
               dataMaskRx = (0x1 << (laneVc & 0xF));

               // Data is received
               if ( (dataMask_ && dataMaskRx) != 0 ) {
                  data = new Data(buff,ret);
                  dataQueue_.push(data);
               }

               // Reformat header for register rx
               else {
                  dest = x + ((laneVc << 8) & 0xFF00);

                  // Data matches outstanding register request
                  if ( (dest = regReqDest_) && (memcmp(buff,regBuff_,8) == 0) && ((uint)(ret-3) == regReqEntry_->size())) {
                     if ( regReqWrite_ == 0 ) {
                        if ( buff[ret-1] == 0 ) 
                           memcpy(regReqEntry_->data(),&(buff[2]),(regReqEntry_->size()*4));
                        else memset(regReqEntry_->data(),0xFF,(regReqEntry_->size()*4));
                     }
                     regReqEntry_->setStatus(buff[ret-1]);
                     regRespCnt_++;
                  }

                  // Unexpected frame
                  else {
                     unexpCount_++;
                     if ( debug_ ) {
                        cout << "PgpLink::rxHandler -> Unuexpected frame received"
                             << " Comp=" << dec << (memcmp(buff,regBuff_,8))
                             << " Word0_Exp=0x" << hex << regBuff_[0]
                             << " Word0_Got=0x" << hex << buff[0]
                             << " Word1_Exp=0x" << hex << regBuff_[1]
                             << " Word1_Got=0x" << hex << buff[1]
                             << " ExpSize=" << dec << regReqEntry_->size()
                             << " GotSize=" << dec << (ret-3) 
                             << " DataMaskRx=0x" << hex << dataMaskRx
                             << " DataMask=0x" << hex << dataMask_
                             << " RxDest=0x" << hex << dest
                             << " ExpDest=0x" << hex << regReqDest_ << endl;
                     }
                  }
               }
            }
         }
      }
   }

   // Free buffers
   for (x=0; x < destCount_; x++) {
      if ( dests_[x] != NULL ) free(dests_[x]->rxBuff_);
   }
}

// Constructor
MultLink::MultLink ( ) : CommLink() {
   dests_     = NULL;
   destCount_ = 0;
}

// Deconstructor
MultLink::~MultLink ( ) {
   close();
}


// Open link and start threads
void MultLink::open ( uint count, ... ) {
   va_list    a_list;
   uint       x;
   MultDest * idests[count];

   // Get list
   va_start(a_list,count);

   for (x=0; x < count; x++) idests[x] = va_arg(a_list,MultDest *);

   this->open(count,idests);
}

// Open link and start threads
void MultLink::open ( uint count, MultDest **dests ) {
   stringstream        tmp;
   struct addrinfo     aiHints;
   struct addrinfo*    aiList=0;
   const  sockaddr_in* addr;
   int                 error;
   uint                x;

   if ( dests_ != NULL || count == 0 || count > 255 ) return;

   // Allocate memory
   destCount_ = count;
   dests_     = (MultDest **) malloc(count * sizeof(MultDest *));

   // Set each destination
   for (x =0; x < count; x++) { 
      dests_[x] = dests[x];

      // Determine Type
      if ( dests_[x] != NULL ) {
         switch (dests_[x]->type_) {

            // PGP Type
            case MultDest::MultTypePgp :
               dests_[x]->fd_ = ::open(dests_[x]->meta_.c_str(),O_RDWR | O_NONBLOCK);
               if ( dests_[x]->fd_ == -1 ) {
                  tmp.str("");
                  tmp << "MultLink::open -> Could Not Open PGP For Dest " << dec << x;
                  throw tmp.str();
               }

               if ( debug_ ) 
                  cout << "MultLink::open -> Opened Dest " << dec << x << ", pgp device " << dests_[x]->meta_
                       << ", Fd=" << dec << dests_[x]->fd_ << endl;
               break;

            // Stream Type
            case MultDest::MultTypeAxis :
               dests_[x]->fd_ = ::open(dests_[x]->meta_.c_str(),O_RDWR | O_NONBLOCK);
               if ( dests_[x]->fd_ == -1 ) {
                  tmp.str("");
                  tmp << "MultLink::open -> Could Not Open Stream For Dest " << dec << x;
                  throw tmp.str();
               }

               if ( debug_ ) 
                  cout << "MultLink::open -> Opened Dest " << dec << x << ", stream device " << dests_[x]->meta_
                       << ", Fd=" << dec << dests_[x]->fd_ << endl;

               break;

            // UDP destination
            case MultDest::MultTypeUdp :

               // Create socket
               dests_[x]->fd_ = socket(AF_INET,SOCK_DGRAM,0);
               if ( dests_[x]->fd_ == -1 ) {
                  tmp.str("");
                  tmp << "MultLink::open -> Could Not Create Socket For Dest " << dec << x;
                  throw tmp.str();
               }

               // Lookup host address
               aiHints.ai_flags    = AI_CANONNAME;
               aiHints.ai_family   = AF_INET;
               aiHints.ai_socktype = SOCK_DGRAM;
               aiHints.ai_protocol = IPPROTO_UDP;
               error = ::getaddrinfo(dests_[x]->meta_.c_str(), 0, &aiHints, &aiList);
               if (error || !aiList) {
                  if ( debug_ ) 
                     cout << "MultLink::open -> Failed to open UDP host " 
                          << dests_[x]->meta_ << ":" << dests_[x]->udpPort_ << endl;
                  dests_[x]->fd_ = -1;
               }
               else {
                  addr = (const sockaddr_in*)(aiList->ai_addr);

                  // Setup Remote Address
                  memset(&(dests_[x]->udpAddr_),0,sizeof(struct sockaddr_in));
                  ((struct sockaddr_in *)(&(dests_[x]->udpAddr_)))->sin_family=AF_INET;
                  ((struct sockaddr_in *)(&(dests_[x]->udpAddr_)))->sin_addr.s_addr=addr->sin_addr.s_addr;
                  ((struct sockaddr_in *)(&(dests_[x]->udpAddr_)))->sin_port=htons(dests_[x]->udpPort_);

                  // Debug
                  if ( debug_ ) 
                     cout << "MultLink::open -> Opened Dest " << dec << x << ", UDP device " << dests_[x]->meta_ << ":" 
                          << dec << dests_[x]->udpPort_ << ", Fd=" << dec << dests_[x]->fd_
                          << ", Addr=0x" << hex << ((struct sockaddr_in *)(&(dests_[x]->udpAddr_)))->sin_addr.s_addr << endl;
               }
               break;
         }
      }
   }

   // Start threads
   CommLink::open();
}

// Stop threads and close link
void MultLink::close () {
   if ( dests_ != NULL ) {
      CommLink::close();
      usleep(100);
      for(uint x=0; x < destCount_; x++) { 
         if ( dests_[x]->fd_ >= 0 ) ::close(dests_[x]->fd_);
      }
      free(dests_);
   }
   dests_     = NULL;
   destCount_ = 0;
}

