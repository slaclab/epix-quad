//-----------------------------------------------------------------------------
// File          : cspadGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : CSPAD
//-----------------------------------------------------------------------------
// Description :
// Server application for GUI
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//----------------------------------------------------------------------------
#include <PgpLink.h>
#include <ControlServer.h>
#include <Device.h>
#include <iomanip>
#include <fstream>
#include <iostream>
#include <signal.h>
#include <pthread.h>
#include <Data.h>
#include <DataRead.h>

using namespace std;

#define HEADER_SIZE 14
#define FOOTER_SIZE 1
#define USE_MAJORITY_VOTE 1

// Run flag for sig catch
bool stop;

// Function to catch cntrl-c
void sigTerm (int) { 
   cout << "Got Signal!" << endl;
   stop = true; 
}

typedef uint pixelArray[48*48];


uint findMajorityElement(pixelArray *data, uint dataMask, uint dataLen, uint pixelNo);

int main (int argc, char **argv) {
   
   stop = false;
   
   // Catch signals
   signal (SIGINT,&sigTerm);

   try {

      DataRead  *dread_;
      Data      *event_;
      uint       dsize_;
      pixelArray pixelData[16];
      pixelArray pixelDataCorr;
      pixelArray *pixelDataPtr = pixelData;
      uint       acqNo;
      uint       rdOutNo;
      ofstream frameFile;
      //unsigned long int bytes = 0;

      dread_ = new DataRead;
      event_ = new Data;

      dread_->openShared("epix",1);
      
      printf("Waiting for data\n");
      
      acqNo = 0;
      
      while (!stop) {
         
         if ( dread_->next(event_)) {
            
            dsize_ = event_->size(); // 32 bit values
            
            if (dsize_==1168+1152) {
               
               
               // merge data frames after all are read out 
               // and print it
               if (acqNo != 0 && acqNo != event_->data()[1]) {
                  
                  if (USE_MAJORITY_VOTE) {
                     for (int x = 0; x < 48*48; x++)
                        pixelDataCorr[x] = findMajorityElement(pixelDataPtr, 0xff00, rdOutNo+1, x) | findMajorityElement(pixelDataPtr, 0x00ff, rdOutNo+1, x);
                  }
                  else {
                     for (uint i = 0; i <= rdOutNo; i++)
                        for (int x = 0; x < 48*48; x++) {
                           if (i == 0) {
                              pixelDataCorr[x] = pixelData[i][x];
                           }
                           else {
                              if ((pixelDataCorr[x]&0x000f0000) != 0) {
                                 pixelDataCorr[x] &= 0xfff0ff00;
                                 pixelDataCorr[x] |= (pixelData[i][x]&0x000f00ff);
                              }
                              else if ((pixelDataCorr[x]&0x0f000000) != 0) {
                                 pixelDataCorr[x] &= 0xf0ff00ff;
                                 pixelDataCorr[x] |= (pixelData[i][x]&0x0f00ff00);
                              }
                           }
                        }
                  }
                  
                  
                  
                  // print the content
                  for (int x = 0, i=1; x < 48*48; x++, i++) {
                     
                     printf("%4.4X", (pixelDataCorr[x]&0x0000ffff));
                     
                     if (!(i%48)) 
                        printf("\n");
                  }
                  
               }
               
               rdOutNo = (event_->data()[HEADER_SIZE]&0xf0)>>4;
               acqNo = event_->data()[1];
               
               //print packet size info
               printf("Payload size %d 32-bit words. Packet size %d 32-bit words. Acq %d, seq %d, ASIC %d, rdoutNo %d\n", dsize_-(HEADER_SIZE+FOOTER_SIZE+1), dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), rdOutNo);
               
               // save data frames
               for (int x = HEADER_SIZE+1, i=0; x < event_->size() - FOOTER_SIZE; x++, i++)
                  pixelData[rdOutNo][i] = event_->data()[x];
               
               
               
            }
            else if (dsize_ >= HEADER_SIZE) {
               printf("Wrong size packet %d 32-bit words. Acq %d, seq %d, ASIC %d, cnt%c\n", dsize_, event_->data()[1], event_->data()[2], (event_->data()[HEADER_SIZE]&0xf), (event_->data()[HEADER_SIZE]&0xf0)!=0?'A':'B');
            }
            else {
               printf("Wrong size packet %d 32-bit words.\n", dsize_);
            }

         }
      }
      
      exit(0);
      

   } catch ( string error ) {
      cout << "Caught Error: " << endl;
      cout << error << endl;
   }
}


uint findMajorityElement(pixelArray *data, uint dataMask, uint dataLen, uint pixelNo)
{
   uint candidate;
   uint counter = 0;
   
   for (uint i = 0; i < dataLen; i++) {
      if (counter == 0) {
         candidate = data[i][pixelNo]&dataMask;
         counter = 1;
      }
      else if (candidate == (data[i][pixelNo]&dataMask))
         counter++;
      else
         counter--;
   }
   
   //for (uint i = 0; i < dataLen; i++) {
   //   printf("e%d:%4.4X ", i, (data[i][pixelNo]&dataMask));
   //}
   //printf(" picked %4.4X\n", candidate);
   
   return candidate;
   
}


