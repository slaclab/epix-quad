#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define TH0_COMP     12.210012   // 5V / 2^12 / 0.0001A
#define TH0_SHIFT    0.0
#define TH0_SCALE    1.0

#define TH1_COMP     12.210012   // 5V / 2^12 / 0.0001A
#define TH1_SHIFT    0.0
#define TH1_SCALE    1.0

#define VDIO_COMP    0.001221    // 5V / 2^12                           
#define VDIO_SHIFT   0.0
#define VDIO_SCALE   1000.0      // (V * 1000)

#define HUM_COMP     0.06399377  // 5V / 2^12 / 3V / 0.00636
#define HUM_SHIFT    (-23.8)     // constant
#define HUM_SCALE    100.0       // (%RH * 100)

#define IANA_COMP    5.19575     // 5V / 2^12 / 470ohm * 1000 ( * 1000 for mA) * 2
#define IANA_SHIFT   0.0
#define IANA_SCALE   1.0

#define IDIG_COMP    2.59787     // 5V / 2^12 / 470ohm * 1000 ( * 1000 for mA)
#define IDIG_SHIFT   0.0
#define IDIG_SCALE   1.0

#define IGUA_COMP    0.001221    // 5V / 2^12 (mA)                       
#define IGUA_SHIFT   0.0
#define IGUA_SCALE   1000.0      // (mA * 1000)

#define IBIA_COMP    0.006105    // 5V * 5 / 2^12 (mA)                  
#define IBIA_SHIFT   0.0
#define IBIA_SCALE   1000.0      // (mA * 1000)

#define AVIN_COMP    0.00353113  // 4.82V (calibrated) / 2^12 * 3       
#define AVIN_SHIFT   0.0
#define AVIN_SCALE   1000.0      // (Vin * 1000)

#define DVIN_COMP    0.00353113  // 4.82V (calibrated) / 2^12 * 3      
#define DVIN_SHIFT   0.0
#define DVIN_SCALE   1000.0      // (Vin * 1000)

int main ()
{
   FILE *outF;
   FILE *csvF;
   double adc_d;   
   int adc_i;   
   
   struct tm *tm;
   time_t t;
   char str_date[100];
   
   t = time(NULL);
   tm = localtime(&t);
   strftime(str_date, sizeof(str_date), "%m/%d/%Y", tm);
   
   outF = fopen("SlowAdcPkg.vhd", "w");
   csvF = fopen("SlowAdcPkg.csv", "w");
   
   if (outF == NULL) {
      printf("Can't open file for write\n");
      exit(1);
   }
   
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
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*TH0_COMP+TH0_SHIFT)*TH0_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_TH0_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*TH0_COMP+TH0_SHIFT)*TH0_SCALE);
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
         adc_i = (int)((adc_d*TH0_COMP+TH0_SHIFT)*TH0_SCALE);
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
   
   
   //Write TH1 values
   fprintf(csvF, "TH1,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_TH1_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*TH1_COMP+TH1_SHIFT)*TH1_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_TH1_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*TH1_COMP+TH1_SHIFT)*TH1_SCALE);
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
         adc_i = (int)((adc_d*TH1_COMP+TH1_SHIFT)*TH1_SCALE);
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
   
   
   //Write VDIO values
   fprintf(csvF, "VDIO,"); 
   for(int i=0; i<128; i++) {
      //Write high byte memory initialization vector
      fprintf(outF, "constant INIT_H_VDIO_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*VDIO_COMP+VDIO_SHIFT)*VDIO_SCALE);
         if (adc_i > 32767)
            adc_i = 32767;
         if (adc_i < -32768)
            adc_i = -32768;
         fprintf(outF, "%2.2hhX", adc_i >> 8); 
      }
      fprintf(outF, "\";\n"); 
      
      //Write low byte memory initialization vector
      fprintf(outF, "constant INIT_L_VDIO_%2.2hhX : bit_vector(255 downto 0) := X\"", i); 
      for(int j=0; j<32; j++) {
         adc_d = (double)(32*i+(31-j));
         adc_i = (int)((adc_d*VDIO_COMP+VDIO_SHIFT)*VDIO_SCALE);
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
         adc_i = (int)((adc_d*VDIO_COMP+VDIO_SHIFT)*VDIO_SCALE);
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
