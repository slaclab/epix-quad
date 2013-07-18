//-----------------------------------------------------------------------------
// File          : EpixUtility.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 06/07/2013
// Project       : Digital FPGA
//-----------------------------------------------------------------------------
// Description :
// List of utility funtions for the EpixAsic
//-----------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC. All rights reserved.
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
