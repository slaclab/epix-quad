//-----------------------------------------------------------------------------
// File          : KpixControl.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 04/12/2011
// Project       : Heavy Photon KpixControl
//-----------------------------------------------------------------------------
// Description :
// Control FPGA container
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 04/12/2011: created
//-----------------------------------------------------------------------------
#include <KpixControl.h>
#include <OptoFpga.h>
#include <ConFpga.h>
#include <Register.h>
#include <Variable.h>
#include <Command.h>
#include <CommLink.h>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
using namespace std;

// Constructor
KpixControl::KpixControl ( CommLink *commLink, string defFile, uint kpixCount ) : System("KpixControl",commLink) {

   // Description
   desc_ = "Kpix Control";
   
   // Data mask, lane 0, vc 0
   commLink->setDataMask(0x11);

   if ( defFile == "" ) defaults_ = "xml/defaults.xml";
   else defaults_ = defFile;

   // Set run states
   vector<string> states;
   states.resize(3);
   states[0] = "Stopped";
   states[1] = "Running";
   states[2] = "Running Calibration";
   getVariable("RunState")->setEnums(states);

   // Set run rates
   vector<string> rates;
   rates.resize(12);
   rates[0]  = "1Hz";
   rates[1]  = "10Hz";
   rates[2]  = "20Hz";
   rates[3]  = "30Hz";
   rates[4]  = "40Hz";
   rates[5]  = "50Hz";
   rates[6]  = "60Hz";
   rates[7]  = "70Hz";
   rates[8]  = "80Hz";
   rates[9]  = "90Hz";
   rates[10] = "100Hz";
   rates[11] = "No Limit";
   getVariable("RunRate")->setEnums(rates);

   // Data file nameing controls
   addVariable(new Variable("DataBase",Variable::Configuration));
   getVariable("DataBase")->setDescription("Base directory for auto data data files");

   addVariable(new Variable("DataAuto",Variable::Configuration));
   getVariable("DataAuto")->setDescription("Enable automatic data name generation");
   getVariable("DataAuto")->setTrueFalse();

   // Calib/dist control variables
   addVariable(new Variable("CalMeanCount",Variable::Configuration));
   getVariable("CalMeanCount")->setDescription("Set number of iterations for mean fitting");
   getVariable("CalMeanCount")->setRange(1,10000);
   getVariable("CalMeanCount")->setInt(4000);

   addVariable(new Variable("CalDacMin",Variable::Configuration));
   getVariable("CalDacMin")->setDescription("Min DAC value for calibration");
   getVariable("CalDacMin")->setRange(0,255);
   getVariable("CalDacMin")->setInt(0);

   addVariable(new Variable("CalDacMax",Variable::Configuration));
   getVariable("CalDacMax")->setDescription("Max DAC value for calibration");
   getVariable("CalDacMax")->setRange(0,255);
   getVariable("CalDacMax")->setInt(255);

   addVariable(new Variable("CalDacStep",Variable::Configuration));
   getVariable("CalDacStep")->setDescription("DAC increment value for calibration");
   getVariable("CalDacStep")->setRange(1,255);
   getVariable("CalDacStep")->setInt(0);

   addVariable(new Variable("CalDacCount",Variable::Configuration));
   getVariable("CalDacCount")->setDescription("Number of iterations to take at each dac value");
   getVariable("CalDacCount")->setRange(0,255);
   getVariable("CalDacCount")->setInt(1);

   addVariable(new Variable("CalChanMin",Variable::Configuration));
   getVariable("CalChanMin")->setDescription("Calibration channel min");
   getVariable("CalChanMin")->setRange(0,1023);
   getVariable("CalChanMin")->setInt(0);

   addVariable(new Variable("CalChanMax",Variable::Configuration));
   getVariable("CalChanMax")->setDescription("Calibration channel max");
   getVariable("CalChanMax")->setRange(0,1023);
   getVariable("CalChanMax")->setInt(1023);

   addVariable(new Variable("CalState",Variable::Status));
   getVariable("CalState")->setDescription("Calibration state");
   vector<string> calState;
   calState.resize(3);
   calState[0] = "Idle";
   calState[1] = "Baseline";
   calState[2] = "Inject";
   getVariable("CalState")->setEnums(calState);

   addVariable(new Variable("CalChannel",Variable::Status));
   getVariable("CalChannel")->setDescription("Calibration channel");
   getVariable("CalChannel")->setComp(0,1,0,"");
   getVariable("CalChannel")->setInt(0);

   addVariable(new Variable("CalDac",Variable::Status));
   getVariable("CalDac")->setDescription("Calibration DAC value");
   getVariable("CalDac")->setComp(0,1,0,"");
   getVariable("CalDac")->setInt(0);

   addVariable(new Variable("UserDataA",Variable::Configuration));
   getVariable("UserDataA")->setDescription("User defined data field");

   addVariable(new Variable("UserDataB",Variable::Configuration));
   getVariable("UserDataB")->setDescription("User defined data field");

   addVariable(new Variable("UserDataC",Variable::Configuration));
   getVariable("UserDataC")->setDescription("User defined data field");

   addVariable(new Variable("UserDataD",Variable::Configuration));
   getVariable("UserDataD")->setDescription("User defined data field");

   // Add sub-devices
   addDevice(new ConFpga(0, 0, kpixCount, this));
}

// Deconstructor
KpixControl::~KpixControl ( ) { }

// Setup config for calibration
void KpixControl::calibConfig ( uint channel, uint dac ) {
   uint            x;
   uint            col;
   uint            row;
   string          modeString;
   stringstream    newConfig;
   newConfig.str("");

   // Row column index
   col = (channel>1023)?32:(channel/32);
   row = channel%32;

   // Disable self trigger. Set forced trigger
   newConfig << "<system><config><cntrlFpga>";
   newConfig << "<RunMode>Calibrate</RunMode>";
   newConfig << "<kpixAsic>";
   newConfig << "<CntrlCalSource>Internal</CntrlCalSource>";
   newConfig << "<CntrlForceTrigSource>Internal</CntrlForceTrigSource>";
   newConfig << "<CntrlTrigDisable>True</CntrlTrigDisable>";
   newConfig << "<DacCalibration>"<< dec << dac << "</DacCalibration>";
   for (x=0; x < 32; x++) {
      newConfig << "<Chan_" << setw(4) << setfill('0') << dec << (x*32) << "_" << setw(4) << setfill('0') << dec << ((x*32)+31) << ">";
      modeString = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD";
      if ( col == x ) modeString[row] = 'C';
      newConfig << modeString;
      newConfig << "</Chan_" << setw(4) << setfill('0') << dec << (x*32) << "_" << setw(4) << setfill('0') << dec << ((x*32)+31) << ">";
   }
   newConfig << "</kpixAsic></cntrlFpga></config></system>\n";
   parseXml(newConfig.str(),false);

   // Update a few status variables in data file
   newConfig.str("");
   newConfig << "<status>" << endl;
   newConfig << "<CalState>"   << getVariable("CalState")->get()   << "</CalState>" << endl;
   newConfig << "<CalChannel>" << getVariable("CalChannel")->get() << "</CalChannel>" << endl;
   newConfig << "<CalDac>"     << getVariable("CalDac")->get()     << "</CalDac>" << endl;
   newConfig << "</status>" << endl;
   commLink_->addStatus(newConfig.str());
   usleep(100);
}

void KpixControl::swRunThread() {
   struct timespec tme;
   ulong           ctime;
   ulong           ltime;
   uint            runTotal;
   uint            stepTotal;
   uint            lastData;
   uint            calMeanCount;
   uint            calDacCount;
   uint            calDacMin;
   uint            calDacMax;
   uint            calDacStep;
   uint            calChanMin;
   uint            calChanMax;
   uint            calTotal;
   uint            calChan;
   uint            calDac;
   bool            gotEvent;
   stringstream    oldConfig;
   stringstream    xml;

   oldConfig.str("");

   // Setup run status and init clock
   lastData    = commLink_->dataRxCount();
   runTotal    = 0;
   stepTotal   = 0;
   swRunning_  = true;
   swRunError_ = "";
   clock_gettime(CLOCK_REALTIME,&tme);
   ltime = (tme.tv_sec * 1000000) + (tme.tv_nsec/1000);

   // Show start
   if ( debug_ ) {
      cout << "KpixControl::runThread -> Name: " << name_ 
           << ", Run Started"
           << ", RunState=" << dec << getVariable("RunState")->get()
           << ", RunCount=" << dec << swRunCount_
           << ", RunPeriod=" << dec << swRunPeriod_ << endl;
   }

   try {

      // Enable run counter register
      device("cntrlFpga",0)->set("RunEnable","True");
      writeConfig(false);

      // Calibration run enabled
      if ( getVariable("RunState")->get() == "Running Calibration" ) {
         calMeanCount = getVariable("CalMeanCount")->getInt();
         calDacCount  = getVariable("CalDacCount")->getInt();
         calDacMin    = getVariable("CalDacMin")->getInt();
         calDacMax    = getVariable("CalDacMax")->getInt();
         calDacStep   = getVariable("CalDacStep")->getInt();
         calChanMin   = getVariable("CalChanMin")->getInt();
         calChanMax   = getVariable("CalChanMax")->getInt();
         calTotal     = calMeanCount + ((calChanMax - calChanMin + 1) * ((calDacMax - calDacMin + 1)/calDacStep) * calDacCount);
         calChan      = calChanMin;
         calDac       = calDacMin;

         // Save old configuration
         oldConfig << "<system>" << endl << configString(true,false) << "</system>" << endl;

         // Update variables
         getVariable("CalState")->set("Baseline");
         getVariable("CalChannel")->setInt(0);
         getVariable("CalDac")->setInt(0);

         // Update config
         calibConfig(9999,calDac);
      }
      else getVariable("CalState")->set("Idle");

      // Run
      while ( swRunEnable_ ) {

         // Delay between attempts
         do {
            usleep(1);
            clock_gettime(CLOCK_REALTIME,&tme);
            ctime = (tme.tv_sec * 1000000) + (tme.tv_nsec/1000);
         } while ( (ctime-ltime) < swRunPeriod_);

         // Check that we received a data frame
         gotEvent = true;

         while ( commLink_->dataRxCount() == lastData ) {
            usleep(1);
            clock_gettime(CLOCK_REALTIME,&tme);
            ctime = (tme.tv_sec * 1000000) + (tme.tv_nsec/1000);

            // One second has passed. event was missed.
            if ( (ctime-ltime) > 1000000) {
               gotEvent = false;
               if ( debug_ ) cout << "KpixControl::runThread -> Missed data event. Retrying" << endl;

               // Verify and re-configure here

               break;
            }
            if ( !swRunEnable_ ) break;
         }
         if ( !swRunEnable_ ) break; 

         // Setup next calibration data point
         if ( getVariable("RunState")->get() == "Running Calibration" ) {
            if ( gotEvent ) {
               runTotal++;
               stepTotal++;
            }
            getVariable("RunProgress")->setInt((uint)(((double)runTotal/(double)calTotal)*100.0));

            // running baseline
            if ( gotEvent && getVariable("CalState")->get() == "Baseline" ) {

               // Mean run is done
               if ( runTotal >= calMeanCount ) {

                  // Cal count value is zero
                  if ( calDacCount == 0 ) break;

                  // Setup calibration
                  else {
                     usleep(100000);
                     getVariable("CalState")->set("Inject");
                     calChan = calChanMin;
                     calDac  = calDacMin;
                     getVariable("CalChannel")->setInt(calChan);
                     getVariable("CalDac")->setInt(calDac);
                     calibConfig(calChan,calDac);
                     stepTotal = 0;
                  }
               }
            }

            // running calibration
            else if ( gotEvent && getVariable("CalState")->get() == "Inject" ) {

               // Have we taken enough points at this value?
               if ( stepTotal >= calDacCount ) {

                  // Increment cal dac
                  calDac += calDacStep;
                  if ( calDac > calDacMax ) {
                     usleep(100000);
                     calDac = calDacMin;
                     calChan++;
                  }

                  // Are we done?
                  if ( calChan > calChanMax ) break;

                  // Write config
                  getVariable("CalChannel")->setInt(calChan);
                  getVariable("CalDac")->setInt(calDac);
                  calibConfig(calChan,calDac);
                  stepTotal = 0;
               }
            }
         }
         else {
            if ( gotEvent ) runTotal++;
            if ( swRunCount_ == 0 ) getVariable("RunProgress")->setInt(0);
            else getVariable("RunProgress")->setInt((uint)(((double)runTotal/(double)swRunCount_)*100.0));
            if ( swRunCount_ != 0 && runTotal >= swRunCount_ ) break;
         }

         // Execute command
         lastData = commLink_->dataRxCount();
         ltime = ctime;
         commLink_->queueRunCommand();
      }

      // Restore configuration here
      if ( getVariable("RunState")->get() == "Running Calibration" ) {
         getVariable("CalState")->set("Idle");
         getVariable("CalChannel")->setInt(0);
         parseXml(oldConfig.str(),false);
         usleep(100);
      }

      // Set run
      usleep(100);
      device("cntrlFpga",0)->set("RunEnable","False");
      writeConfig(false);

   } catch (string error) { swRunError_ = error; }

   // Cleanup
   sleep(1);

   getVariable("RunState")->set(swRunRetState_);
   swRunning_ = false;
}

// Method to process a command
void KpixControl::command ( string name, string arg ) {
   stringstream tmp;
   stringstream dateString;
   long         tme;
   struct tm    *tm_data;

   // Intercept file open command, overwrite data file variable
   if ( name == "OpenDataFile" && getVariable("DataAuto")->get() == "True" ) {
      time(&tme);
      tm_data = localtime(&tme);
      tmp.str("");
      tmp << getVariable("DataBase")->get() << "/";
      tmp << dec << (tm_data->tm_year + 1900) << "_";
      tmp << dec << setw(2) << setfill('0') << (tm_data->tm_mon+1) << "_";
      tmp << dec << setw(2) << setfill('0') << tm_data->tm_mday    << "_";
      tmp << dec << setw(2) << setfill('0') << tm_data->tm_hour    << "_";
      tmp << dec << setw(2) << setfill('0') << tm_data->tm_min     << "_";
      tmp << dec << setw(2) << setfill('0') << tm_data->tm_sec;
      tmp << ".bin";
      getVariable("DataFile")->set(tmp.str());
   }
   System::command(name,arg);
}

// Method to set run state
void KpixControl::setRunState ( string state ) {
   stringstream err;
   uint         toCount;
   uint         runNumber;

   // Stopped state is requested
   if ( state == "Stopped" ) {

      if ( swRunEnable_ ) {
         swRunEnable_ = false;
         pthread_join(swRunThread_,NULL);
      }

      allStatusReq_ = true;
      addRunStop();
   }


   // Running state is requested
   else if ( !swRunning_ && ( state == "Running"    ||
                              state == "Running Calibration" ) ) {

      // Set run command 
      device("cntrlFpga",0)->setRunCommand("KpixRun");

      // Increment run number
      runNumber = getVariable("RunNumber")->getInt() + 1;
      getVariable("RunNumber")->setInt(runNumber);
      addRunStart();

      swRunRetState_ = "Stopped";
      swRunEnable_   = true;
      getVariable("RunState")->set(state);

      // Setup run parameters
      swRunCount_ = getInt("RunCount");
      if      ( get("RunRate") == "100Hz"    ) swRunPeriod_ =   10000;
      else if ( get("RunRate") == "90Hz"     ) swRunPeriod_ =   11111;
      else if ( get("RunRate") == "80Hz"     ) swRunPeriod_ =   12500;
      else if ( get("RunRate") == "70Hz"     ) swRunPeriod_ =   14286;
      else if ( get("RunRate") == "60Hz"     ) swRunPeriod_ =   16667;
      else if ( get("RunRate") == "50Hz"     ) swRunPeriod_ =   20000;
      else if ( get("RunRate") == "40Hz"     ) swRunPeriod_ =   25000;
      else if ( get("RunRate") == "30Hz"     ) swRunPeriod_ =   33333;
      else if ( get("RunRate") == "20Hz"     ) swRunPeriod_ =   50000;
      else if ( get("RunRate") == "10Hz"     ) swRunPeriod_ =  100000;
      else if ( get("RunRate") == "1Hz"      ) swRunPeriod_ = 1000000;
      else if ( get("RunRate") == "No Limit" ) swRunPeriod_ = 0;
      else swRunPeriod_ = 1000000;

      // Start thread
      if ( pthread_create(&swRunThread_,NULL,swRunStatic,this) ) {
         err << "KpixControl::startRun -> Failed to create ioThread" << endl;
         if ( debug_ ) cout << err.str();
         getVariable("RunState")->set(swRunRetState_);
         throw(err.str());
      }

      // Wait for thread to start
      toCount = 0;
      while ( !swRunning_ ) {
         usleep(100);
         toCount++;
         if ( toCount > 1000 ) {
            swRunEnable_ = false;
            err << "KpixControl::startRun -> Timeout waiting for runthread" << endl;
            if ( debug_ ) cout << err.str();
            getVariable("RunState")->set(swRunRetState_);
            throw(err.str());
         }
      }
   }
}

//! Method to return state string
string KpixControl::localState ( ) {
   string loc = "";

   loc = "System Ready To Take Data.\n";

   if ( getVariable("RunState")->get() == "Running Calibration" ) {
      loc.append("Calibration running: ");
      loc.append(getVariable("CalState")->get());
      if ( getVariable("CalState")->get() == "Inject" ) {
         loc.append(" Channel: ");
         loc.append(getVariable("CalChannel")->get());
      }
      loc.append("\n");
   }

   return(loc);
}

//! Method to perform soft reset
void KpixControl::softReset ( ) {
   System::softReset();

   device("cntrlFpga",0)->command("CountReset","");
}

//! Method to perform hard reset
void KpixControl::hardReset ( ) {
   bool gotVer = false;
   uint count = 0;

   System::hardReset();

   device("cntrlFpga",0)->command("FirmwareReset","");
   do {
      sleep(1);
      try { 
         gotVer = true;
         device("cntrlFpga",0)->readSingle("Version");
      } catch ( string err ) { 
         if ( count > 5 ) {
            gotVer = true;
            throw(string("KpixControl::hardReset -> Error contacting fpga"));
         }
         else {
            count++;
            gotVer = false;
         }
      }
   } while ( !gotVer );
   //device("cntrlFpga",0)->command("KpixHardReset","");
}

