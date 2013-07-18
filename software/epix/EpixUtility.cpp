#include <iostream>
#include <sstream>
#include <iomanip>
#include "EpixUtility.h"
using namespace std;

bool crc(unsigned int reg1, unsigned int reg2)
{
	int array[] = {0,0,0,0,0,0,0,0};
	int input, temp, CRC1, CRC2 = 0;
	unsigned long long int analog;
	stringstream concat;
	concat.str("");
	
	
	concat << hex << reg1 << reg2;	
	concat >> analog;
	CRC1 = analog >> 56;
	
	for (int i = 0; i < 56; i++)
	{
		if (analog % 2 == 0)
			input = 0;
		else
			input = 1;
		temp = array[7] ^ input;
		for (int i = 6; i >= 0; i--)
		{
			if(i == 3 || i == 4)
				array[i+1] = array[i] ^ temp;
			else
				array[i+1] = array [i];
		}
		array[0] = temp;

		analog = analog >> 1;
	}
	
	for (int i = 0; i < 8; i++)
	{
		CRC2 |= array[7-i] << i;
		
	}

	if (CRC1 == CRC2)
		return true;
	else 
		return false;
}
