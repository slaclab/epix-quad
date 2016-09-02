//-----------------------------------------------------------------------------
// File          : EpixUtility.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// List of utility funtions for the EpixAsic
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
// 07/18/2013: created
//-----------------------------------------------------------------------------
#ifndef __EPIX_UTILITY_h__
#define __EPIX_UTILITY_h__
using namespace std;

// returns true or false depending on if the serial number matches the CRC
bool crc(unsigned int reg1, unsigned int reg2);
#endif
