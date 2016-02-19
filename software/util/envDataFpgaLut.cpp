#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#define TEMP_LOW     -50.0
#define TEMP_HIGH    100.0
#define TEMP_STEP    0.01

#define TH_R25       10000.0
#define TH_I_DAC     0.000026
#define TH_SCALE     100.0
#define TH_VREF      2.5

#define TH_A1        -14.122478
#define TH_A2        -14.141963
#define TH_A3        -14.202172

#define TH_B1        4413.6033
#define TH_B2        4430.783
#define TH_B3        4497.5256

#define TH_C1        -29034.189
#define TH_C2        -34078.983
#define TH_C3        -58421.357

#define TH_D1        -9387503.5
#define TH_D2        -8894192.9
#define TH_D3        -5965879.6

#define HUM_COMP     0.03199688  // 2.5V / 2^12 / 3V / 0.00636
#define HUM_SHIFT    (-23.8)     // constant
#define HUM_SCALE    100.0       // (%RH * 100)

#define IANA_COMP    2.597875    // 2.5V / 2^12 / 470ohm * 1000 ( * 1000 for mA) * 2
#define IANA_SHIFT   0.0
#define IANA_SCALE   1.0

#define IDIG_COMP    1.298937    // 2.5V / 2^12 / 470ohm * 1000 ( * 1000 for mA)
#define IDIG_SHIFT   0.0
#define IDIG_SCALE   1.0

#define IGUA_COMP    0.0006105   // 2.5V / 2^12 (mA)                       
#define IGUA_SHIFT   0.0
#define IGUA_SCALE   1000.0      // (mA * 1000)

#define IBIA_COMP    0.0030525   // 2.5V * 5 / 2^12 (mA)                  
#define IBIA_SHIFT   0.0
#define IBIA_SCALE   1000.0      // (mA * 1000)

#define AVIN_COMP    0.001831502 // 2.5V / 2^12 * 3       
#define AVIN_SHIFT   0.0
#define AVIN_SCALE   1000.0      // (Vin * 1000)

#define DVIN_COMP    0.001831502 // 2.5V / 2^12 * 3      
#define DVIN_SHIFT   0.0
#define DVIN_SCALE   1000.0      // (Vin * 1000)


int main ()
{
   FILE *outF;
   FILE *csvF;
   FILE *tempF;
   double adc_d;   
   int adc_i, last_addr;   
   int first_address_index, first_address, lut_address;   
   
   double *thermistor_curve_x;
   double *thermistor_curve_y;
   double *thermistor_voltage;
   long *th_lut_addr;
   long *th_lut_value;
   int temp_steps = (abs(TEMP_LOW) + TEMP_HIGH)/TEMP_STEP;
   
   // Allocate buffers for the thermistor curve
   thermistor_curve_x = (double*)malloc(temp_steps*sizeof(double));
   thermistor_curve_y = (double*)malloc(temp_steps*sizeof(double));
   thermistor_voltage = (double*)malloc(temp_steps*sizeof(double));
   th_lut_addr = (long*)malloc(temp_steps*sizeof(long));
   th_lut_value = (long*)malloc(4096*sizeof(long));
   
   if (thermistor_curve_x == NULL || thermistor_curve_y == NULL || thermistor_voltage == NULL || th_lut_addr == NULL) {
      printf("Can't allocate buffers\n");
      exit(1);
   }
   
   //calculate thermistor curve
   for(int i=0; i<temp_steps; i++) {
      thermistor_curve_x[i] = TEMP_LOW + TEMP_STEP * i;
      thermistor_curve_y[i] = exp(TH_A1 + TH_B1/(thermistor_curve_x[i]+273.15) + TH_C1/pow(thermistor_curve_x[i]+273.15, 2.0) + TH_D1/pow(thermistor_curve_x[i]+273.15, 3.0));
      thermistor_voltage[i] = thermistor_curve_y[i] * TH_R25 * TH_I_DAC;
      th_lut_addr[i] = lround(thermistor_voltage[i]/TH_VREF*4095.0);
   }
   
   //create thermistor LUT
   first_address_index = 0;
   lut_address = 4095;
   do {
      //find first LUT address in the table
      for(int i=first_address_index; i<temp_steps; i++) {
         if (th_lut_addr[i] <= lut_address) {
            first_address = th_lut_addr[i];
            first_address_index = i;
            th_lut_value[first_address] = lround(thermistor_curve_x[first_address_index] * TH_SCALE);
            printf("First address %d found in table at index %d\n", first_address, first_address_index);
            break;
         }
         //if LUT addres was not found in the table
         if(i==temp_steps-1) {
            first_address_index = i+1;
            last_addr = first_address;
         }
      }
      
      if(first_address<lut_address) {
         for(int i=0; i<lut_address-first_address; i++) {
            th_lut_value[lut_address-i] = lround(thermistor_curve_x[first_address_index] * TH_SCALE);
            printf("Higher address %d set to first found\n", lut_address-i);
         }
      }
      
      if(first_address-1>0)
         lut_address=first_address-1;
      
      
   } while(first_address_index < temp_steps);
   
   printf("%d is the last LUT address found in the table\n", last_addr);
      

   if (last_addr>0) {
      for (int i=0; i<last_addr; i++)
         th_lut_value[i] = th_lut_value[last_addr];
   }
   
   // get local time
   struct tm *tm;
   time_t t;
   char str_date[100];
   
   t = time(NULL);
   tm = localtime(&t);
   strftime(str_date, sizeof(str_date), "%m/%d/%Y", tm);
   
   // open files for writing
   outF = fopen("SlowAdcPkg.vhd", "w");
   csvF = fopen("SlowAdcPkg.csv", "w");
   tempF = fopen("TempCurve.csv", "w");
   
   if (outF == NULL || csvF == NULL || tempF == NULL) {
      printf("Can't open file for write\n");
      exit(1);
   }
   
   //Write thermistor curve to the CSV file
   fprintf(tempF, "Temp,");
   for (int i=0; i<temp_steps; i++) {
      if (i < temp_steps - 1)
         fprintf(tempF, "%f,", thermistor_curve_x[i]); 
      else
         fprintf(tempF, "%f", thermistor_curve_x[i]);
   }
   fprintf(tempF, "\n");
   fprintf(tempF, "Temp100,");
   for (int i=0; i<temp_steps; i++) {
      if (i < temp_steps - 1)
         fprintf(tempF, "%f,", thermistor_curve_x[i]*100.00); 
      else
         fprintf(tempF, "%f", thermistor_curve_x[i]*100.00);
   }
   fprintf(tempF, "\n");
   fprintf(tempF, "RtR25,");
   for (int i=0; i<temp_steps; i++) {
      if (i < temp_steps - 1)
         fprintf(tempF, "%f,", thermistor_curve_y[i]); 
      else
         fprintf(tempF, "%f", thermistor_curve_y[i]);
   }
   fprintf(tempF, "\n");
   fprintf(tempF, "ThVolt,");
   for (int i=0; i<temp_steps; i++) {
      if (i < temp_steps - 1)
         fprintf(tempF, "%f,", thermistor_voltage[i]); 
      else
         fprintf(tempF, "%f", thermistor_voltage[i]);
   }
   fprintf(tempF, "\n");
   fprintf(tempF, "LuaAddrAll,");
   for (int i=0; i<temp_steps; i++) {
      if (i < temp_steps - 1)
         fprintf(tempF, "%ld,", th_lut_addr[i]); 
      else
         fprintf(tempF, "%ld", th_lut_addr[i]);
   }
   fprintf(tempF, "\n");
   fprintf(tempF, "LutAddr,");
   for (int i=4095; i>=0; i--) {
      if (i == 0)
         fprintf(tempF, "%d", i); 
      else
         fprintf(tempF, "%d,", i);
   }
   fprintf(tempF, "\n");
   fprintf(tempF, "LutValue,");
   for (int i=4095; i>=0; i--) {
      if (i == 0)
         fprintf(tempF, "%ld", th_lut_value[i]); 
      else
         fprintf(tempF, "%ld,", th_lut_value[i]);
   }
   fprintf(tempF, "\n");
   fclose(tempF);
   
   
   // Generate the VHDL package file
   fprintf(outF, "-- Auto-generated package containing LUT initialization data\n"); 
   fprintf(outF, "-- for conversion of the environmental data of the EPIX detector\n"); 
   fprintf(outF, "-- To regenerate use envDataFpgaLut.cpp\n"); 
   fprintf(outF, "-- Maciej Kwiatkowski (mkwiatko@slac.stanford.edu)\n"); 
   fprintf(outF, "-- Generation date %s\n", str_date); 
   fprintf(outF, "\n"); 
   
   fprintf(outF, "library ieee;\n"); 
   fprintf(outF, "use ieee.std_logic_1164.all;\n"); 
   fprintf(outF, "use ieee.std_logic_arith.all;\n"); 
   fprintf(outF, "use ieee.std_logic_unsigned.all;\n"); 
   fprintf(outF, "\n"); 
   fprintf(outF, "package SlowAdcPkg is\n"); 
   
   //Write TH0 values
   fprintf(csvF, "TH0,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_TH0_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         fprintf(outF, "%2.2hhX", (int)(th_lut_value[32*i+(31-j)] & 0xFFFF) >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_TH0_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         fprintf(outF, "%2.2hhX", (int)th_lut_value[32*i+(31-j)] & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         if (i==127 && j==31)
            fprintf(csvF, "%hd", (int)th_lut_value[32*i+j] & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", (int)th_lut_value[32*i+j] & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   //Write TH1 values
   fprintf(csvF, "TH1,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_TH1_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         fprintf(outF, "%2.2hhX", (int)(th_lut_value[32*i+(31-j)] & 0xFFFF) >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_TH1_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         fprintf(outF, "%2.2hhX", (int)th_lut_value[32*i+(31-j)] & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         if (i==127 && j==31)
            fprintf(csvF, "%hd", (int)th_lut_value[32*i+j] & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", (int)th_lut_value[32*i+j] & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   //Write HUM values
   fprintf(csvF, "HUM,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_HUM_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*HUM_COMP+HUM_SHIFT)*HUM_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_HUM_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*HUM_COMP+HUM_SHIFT)*HUM_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*HUM_COMP+HUM_SHIFT)*HUM_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   //Write IANA values
   fprintf(csvF, "IANA,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_IANA_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IANA_COMP+IANA_SHIFT)*IANA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_IANA_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IANA_COMP+IANA_SHIFT)*IANA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*IANA_COMP+IANA_SHIFT)*IANA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   //Write IDIG values
   fprintf(csvF, "IDIG,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_IDIG_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IDIG_COMP+IDIG_SHIFT)*IDIG_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_IDIG_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IDIG_COMP+IDIG_SHIFT)*IDIG_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*IDIG_COMP+IDIG_SHIFT)*IDIG_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   //Write IGUA values
   fprintf(csvF, "IGUA,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_IGUA_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IGUA_COMP+IGUA_SHIFT)*IGUA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_IGUA_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IGUA_COMP+IGUA_SHIFT)*IGUA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*IGUA_COMP+IGUA_SHIFT)*IGUA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   //Write IBIA values
   fprintf(csvF, "IBIA,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_IBIA_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IBIA_COMP+IBIA_SHIFT)*IBIA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_IBIA_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*IBIA_COMP+IBIA_SHIFT)*IBIA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*IBIA_COMP+IBIA_SHIFT)*IBIA_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   //Write AVIN values
   fprintf(csvF, "AVIN,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_AVIN_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*AVIN_COMP+AVIN_SHIFT)*AVIN_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_AVIN_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*AVIN_COMP+AVIN_SHIFT)*AVIN_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*AVIN_COMP+AVIN_SHIFT)*AVIN_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   //Write DVIN values
   fprintf(csvF, "DVIN,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_DVIN_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*DVIN_COMP+DVIN_SHIFT)*DVIN_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_DVIN_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*DVIN_COMP+DVIN_SHIFT)*DVIN_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i & 0xFF); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write CSV file for graphical verification of error
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+j);
         adc_i = (int)((adc_d*DVIN_COMP+DVIN_SHIFT)*DVIN_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         if (i==127 && j==31)
            fprintf(csvF, "%hd", adc_i & 0xFFFF); 
         else
            fprintf(csvF, "%hd,", adc_i & 0xFFFF); 
      }
   }
   fprintf(csvF, "\n");
   
   
   fprintf(outF, "end SlowAdcPkg;\n"); 
   
   fclose(outF);
   fclose(csvF);
}
