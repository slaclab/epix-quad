//-----------------------------------------------------------------------------
// File          : lutGenCpixData.cpp
// Author        : Maciej Kwiatkowski  <mkwiatko@slac.stanford.edu>
// Created       : 03/10/2016
// Project       : Cpix
//-----------------------------------------------------------------------------
// Description :
// Program to generate VHDL memory initialization constants from a white space
// delimited file. The memory is used in the cpix data decoding look-up table.
// Constants are to be used in the CpixLUTPkg.vhd file.
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
// 03/10/2016: created
//----------------------------------------------------------------------------


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>


int main(int argc, char* argv[])
{
   int data[32768];
   int i, j, k, lines;
   long int address;
   char * pEnd;
   char line[1024];
   unsigned char memory_bits[15][32];
   
   if (argc < 2) {
      printf("Usage: %s file_name.csv\n", argv[0]);
      printf("The file_name.csv must be space delimited\n");
      return 0;
   }
   
   char const* const fileName = argv[1];
   FILE* file = fopen(fileName, "r");
   
   if (file == NULL) {
      printf("Cannot read file\n");
      return 0;
   }
   
   //zero the data array
   for(i=0; i<32768; i++)
      data[i] = 0;
   
   //skip the header line
   fgets(line, 1024, file);
   
   //read line by line
   lines=0;
   while (fgets(line, 1024, file)) {
      
      address = strtol(line, &pEnd, 10);
      
      if (address < 0 || address > 32767 || address!=lines) {
         printf("Bad LUT address %ld or order in the file %s\n", address, argv[1]);
         return 0;
      }
      
      data[address] = strtol(pEnd, &pEnd, 10);
      lines++;
      
      //if (address == 32767)
      //   printf("Address 32767: %d\n", data[address]);
      
      //printf("1: %ld, 2:%ld\n", address, data);
   }
   
   fclose(file);
   
   
   // create VHDL simulation array
   printf("type NatArray is array (natural range <>) of natural;\n");
   printf("constant CPIX_NORMAL_SIM_ARRAY_C : NatArray(0 to 32767) := (\n");
   for (i=0; i<128; i++) {
      printf("   ");
      for (j=0; j<256; j++)
         if ((i+1)*(j+1)!=256*128)
            printf("%d ,", data[i*256+j]);
         else
            printf("%d ", data[i*256+j]);
      printf("\n");
   }
   printf(");\n");
   
   
   // create VHDL vectors
   for (i=0; i<128; i++) {
      
      //zero the memory_bits array
      for (j=0; j<15; j++)
         memset (memory_bits[j],0,32);
      
      // get 256 chunks of memory and split bits into individual vectors
      for (j=0; j<256; j++) {
         //256 bit vector is split into 32 chars
         memory_bits[ 0][j/8] |= ((data[i*256+j] & 0x0001)>> 0)<<(j%8);
         memory_bits[ 1][j/8] |= ((data[i*256+j] & 0x0002)>> 1)<<(j%8);
         memory_bits[ 2][j/8] |= ((data[i*256+j] & 0x0004)>> 2)<<(j%8);
         memory_bits[ 3][j/8] |= ((data[i*256+j] & 0x0008)>> 3)<<(j%8);
         memory_bits[ 4][j/8] |= ((data[i*256+j] & 0x0010)>> 4)<<(j%8);
         memory_bits[ 5][j/8] |= ((data[i*256+j] & 0x0020)>> 5)<<(j%8);
         memory_bits[ 6][j/8] |= ((data[i*256+j] & 0x0040)>> 6)<<(j%8);
         memory_bits[ 7][j/8] |= ((data[i*256+j] & 0x0080)>> 7)<<(j%8);
         memory_bits[ 8][j/8] |= ((data[i*256+j] & 0x0100)>> 8)<<(j%8);
         memory_bits[ 9][j/8] |= ((data[i*256+j] & 0x0200)>> 9)<<(j%8);
         memory_bits[10][j/8] |= ((data[i*256+j] & 0x0400)>>10)<<(j%8);
         memory_bits[11][j/8] |= ((data[i*256+j] & 0x0800)>>11)<<(j%8);
         memory_bits[12][j/8] |= ((data[i*256+j] & 0x1000)>>12)<<(j%8);
         memory_bits[13][j/8] |= ((data[i*256+j] & 0x2000)>>13)<<(j%8);
         memory_bits[14][j/8] |= ((data[i*256+j] & 0x4000)>>14)<<(j%8);
         if ((data[i*256+j] & 0x8000)!=0)
            printf("16th bit that is out of memory range is not zero at address %d!\n", i*256+j);
      }
      
      //print VHDL vectors
      for (j=0; j<15; j++) {
         printf("constant CPIX_NORMAL_INIT_%2.2X_BIT_%2.2d_C : bit_vector(255 downto 0) := x\"", i, j);
         for (k=31; k>=0; k--) 
            printf("%2.2X", memory_bits[j][k]);
         printf("\";\n");
      }
   }

   

   return 0;
}
