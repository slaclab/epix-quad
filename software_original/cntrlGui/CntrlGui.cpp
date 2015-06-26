//-----------------------------------------------------------------------------
// File          : CntrlGui.cpp
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 03/22/2011
// Project       : General purpose
//-----------------------------------------------------------------------------
// Description :
// Main program
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 03/22/2011: created
//-----------------------------------------------------------------------------
#include <iostream>
#include <iomanip>
#include <sstream>
#include <string>
#include <signal.h>
#include <unistd.h>
#include <QApplication>
#include <QErrorMessage>
#include <QObject>
#include "XmlClient.h"
#include "MainWindow.h"
#include "SystemWindow.h"
#include "CommandWindow.h"
#include "VariableWindow.h"
#include "SummaryWindow.h"
using namespace std;

// Main Function
int main ( int argc, char **argv ) {
   int x;

   // Determine the number of hosts
   int count = (argc > 3)?argc-2:1;

   QString host[count];
   int     port;

   // Start application
   QApplication a( argc, argv );

   if ( argc < 2 ) {
      host[0] = "localhost";
      port    = 8090;
   }
   else if ( argc > 2 ) {
      host[0] = argv[1];
      port    = atoi(argv[2]);

      for (x=1; x < count; x++) host[x] = argv[x+2];
   }

   XmlClient     xmlClient[count];
   MainWindow    mainWin[count];
   SummaryWindow sumWin(count,mainWin);

   for (x=0; x < count; x++) {

      // Local?
      if ( host[x] == "localhost" ) mainWin[x].systemWindow->setLocal(true);

      // System signals
      QObject::connect(mainWin[x].systemWindow,SIGNAL(sendCommand(QString)),&xmlClient[x],SLOT(sendCommand(QString)));
      QObject::connect(mainWin[x].systemWindow,SIGNAL(sendConfigCommand(QString,QString)),&xmlClient[x],SLOT(sendConfigCommand(QString,QString)));

      // Command signals
      QObject::connect(mainWin[x].commandWindow,SIGNAL(sendCommand(QString)),&xmlClient[x],SLOT(sendCommand(QString)));

      // Status signals
      QObject::connect(mainWin[x].statusWindow,SIGNAL(sendCommand(QString)),&xmlClient[x],SLOT(sendCommand(QString)));

      // Config signals
      QObject::connect(mainWin[x].configWindow,SIGNAL(sendCommand(QString)),&xmlClient[x],SLOT(sendCommand(QString)));
      QObject::connect(mainWin[x].configWindow,SIGNAL(sendConfig(QString)),&xmlClient[x],SLOT(sendConfig(QString)));

      // Summary signals
      QObject::connect(&sumWin,SIGNAL(sendCommand(QString)),&xmlClient[x],SLOT(sendCommand(QString)));

      // XML signals
      QObject::connect(&xmlClient[x],SIGNAL(xmlMessage(int,QDomNode)),mainWin[x].systemWindow,SLOT(xmlMessage(int,QDomNode)));
      QObject::connect(&xmlClient[x],SIGNAL(xmlMessage(int,QDomNode)),mainWin[x].commandWindow,SLOT(xmlMessage(int,QDomNode)));
      QObject::connect(&xmlClient[x],SIGNAL(xmlMessage(int,QDomNode)),mainWin[x].statusWindow,SLOT(xmlMessage(int,QDomNode)));
      QObject::connect(&xmlClient[x],SIGNAL(xmlMessage(int,QDomNode)),mainWin[x].configWindow,SLOT(xmlMessage(int,QDomNode)));
      QObject::connect(&xmlClient[x],SIGNAL(xmlMessage(int,QDomNode)),&mainWin[x],SLOT(xmlMessage(int,QDomNode)));
      QObject::connect(&xmlClient[x],SIGNAL(xmlMessage(int,QDomNode)),&sumWin,SLOT(xmlMessage(int,QDomNode)));

      // Exit on lost connection
      QObject::connect(&xmlClient[x],SIGNAL(lostConnection()),&a,SLOT(closeAllWindows()));
   }

   // Exit on last window closed
   QObject::connect(&a,SIGNAL(lastWindowClosed()), &a, SLOT(quit())); 

   // Open hosts
   for (x=0; x < count; x++) {
      printf("Connecting window %i to host %s, Port %i\n",x,qPrintable(host[x]),port);
      xmlClient[x].openServer(x,host[x],port);
   }

   if ( count == 1 ) mainWin[0].show();
   else sumWin.show();

   // Run application
   return(a.exec());
}

