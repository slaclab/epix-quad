//-----------------------------------------------------------------------------
// File          : SummaryWindow.h
// Author        : Ryan Herbst  <rherbst@slac.stanford.edu>
// Created       : 10/04/2011
// Project       : General Purpose
//-----------------------------------------------------------------------------
// Description :
// System window in top GUI
//-----------------------------------------------------------------------------
// Copyright (c) 2011 by SLAC. All rights reserved.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 10/04/2011: created
//-----------------------------------------------------------------------------
#ifndef __SUMMARY_WINDOW_H__
#define __SUMMARY_WINDOW_H__

#include <QWidget>
#include <QDomDocument>
#include <QTableWidgetItem>
#include <QGroupBox>
#include <QTabWidget>
#include <QPushButton>
#include <QComboBox>
#include <QSpinBox>
#include <QObject>
#include <QTextEdit>
#include <QProgressBar>
#include "MainWindow.h"
using namespace std;

class CommandHolder;

class SummaryWindow : public QWidget {
   
   Q_OBJECT

      // Window groups
      QGroupBox *statusBox();
      QGroupBox *configBox();
      QGroupBox *runBox();

      // Objects
      QPushButton      *setDefaults_;
      QPushButton      *configRead_;
      QPushButton      *refreshState_;
      QPushButton      *softReset_;
      QPushButton      *hardReset_;
      QComboBox        *runState_;

      // Status Objects
      QTableWidget     *statTable_;
      QTableWidgetItem **systemName_;
      QTableWidgetItem **sysRunState_;
      QTableWidgetItem **sysStatus_;
      QTableWidgetItem **sysTimeouts_;
      QTableWidgetItem **sysRegRx_;

      // Process response
      void cmdResStatus    (int idx, QDomNode node);
      void cmdResStructure (int idx, QDomNode node);

      // Holders
      QString lastLoadSettings_;
      QString workingDir_;

      int count_;
      MainWindow *wins_;

   public:

      // Creation Class
      SummaryWindow ( int count, MainWindow *wins, QWidget *parent = NULL );

      // Delete
      ~SummaryWindow ( );

   public slots:

      void cellSelected(int,int);
      void setDefaultsPressed();
      void configReadPressed();
      void refreshStatePressed();
      void resetCountPressed();
      void runStateActivated(const QString &);
      void hardResetPressed();
      void softResetPressed();

      void xmlMessage      (int idx, QDomNode node);

   signals:

      void sendCommand(QString cmd);
};

#endif
