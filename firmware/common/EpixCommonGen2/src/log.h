#include <stdio.h>
#include <string.h>
#include "xil_types.h"
#include "xil_io.h"
#include "microblaze_sleep.h"
#include "xil_printf.h"

#define BUS_OFFSET         (0x80000000)
#define LOG_MEM_OFFSET     (BUS_OFFSET+0x24000000)

#define MAX_ADDRESS (4095)

void logInit(void);
void logPush(char *string);
