#include "log.h"

unsigned int memPtr;
unsigned int memLen;

void logInit(void) {
   
   //zero the memory
   memset((void*)LOG_MEM_OFFSET, 0, 1024*4);
   
   //inital buffer length
   memLen = 0;
   
   //initial buffer pointer
   memPtr = 4;
   
   //the pointer and length are stored in the memory at address 0
   Xil_Out32( LOG_MEM_OFFSET, (memLen<<16) | memPtr);
}


void logPush(char *string) {
   
   //read the pointer
   unsigned int len = strlen(string);
   
   if (memPtr+len-1 <= MAX_ADDRESS) {
      memcpy((char*)(LOG_MEM_OFFSET + memPtr), string, len);
      memPtr += len;
   }
   else {
      memcpy((char*)(LOG_MEM_OFFSET + memPtr), string, MAX_ADDRESS-memPtr+1);
      memcpy((char*)(LOG_MEM_OFFSET + 4), string+(MAX_ADDRESS-memPtr+1), len-(MAX_ADDRESS-memPtr+1));
      memPtr = 4+len-(MAX_ADDRESS-memPtr+1);
   }
   
   if (memLen+len <= 1023*4)
      memLen += len;
   else
      memLen = 1023*4;
   
   //update pointer and length
   Xil_Out32( LOG_MEM_OFFSET, (memLen<<16) | memPtr);
   
}
