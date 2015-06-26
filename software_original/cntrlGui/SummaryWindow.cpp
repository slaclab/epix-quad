//-----------------------------------------------------------------------------
// File          : SummaryWindow.cpp
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
#include <iostream>
#include <sstream>
#include <string>
#include <unistd.h>
#include <QDomDocument>
#include <QObject>
#include <QHeaderView>
#include <QMessageBox>
#include <QTabWidget>
#include <QTableWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLineEdit>
#include <QGroupBox>
#include <QFileDialog>
#include <QInputDialog>
#include <QFormLayout>
#include <QComboBox>
#include <QLabel>
#include "SummaryWindow.h"
#include "VariableHolder.h"
using namespace std;

// Create group box for status
QGroupBox *SummaryWindow::statusBox () {
   int x;

   QGroupBox *gbox = new QGroupBox("System State");

   QVBoxLayout *vbox = new QVBoxLayout;
   gbox->setLayout(vbox);

   statTable_ = new QTableWidget;
   statTable_->setRowCount(count_);
   statTable_->setColumnCount(5);

   QStringList header;
   header << "Device Name" << "Run State" << "Status" << "Reg Rx" << "Timeouts";
   statTable_->setHorizontalHeaderLabels(header);
   statTable_->verticalHeader()->setVisible(false);
   statTable_->setEditTriggers(QAbstractItemView::NoEditTriggers);
   statTable_->setSelectionMode(QAbstractItemView::SingleSelection);
   statTable_->setShowGrid(false);
   statTable_->horizontalHeader()->setStretchLastSection(false);
   statTable_->horizontalHeader()->setResizeMode(0, QHeaderView::ResizeToContents);
   statTable_->setMinimumHeight(400);
   statTable_->setMinimumWidth(500);

   for (x=0; x < count_; x++) {

      systemName_[x] = new QTableWidgetItem("Not Connected!");
      statTable_->setItem(x, 0, systemName_[x]);

      sysRunState_[x] = new QTableWidgetItem("");
      statTable_->setItem(x, 1, sysRunState_[x]);

      sysStatus_[x] = new QTableWidgetItem("");
      statTable_->setItem(x, 2, sysStatus_[x]);

      sysRegRx_[x] = new QTableWidgetItem("");
      statTable_->setItem(x, 3, sysRegRx_[x]);

      sysTimeouts_[x] = new QTableWidgetItem("");
      statTable_->setItem(x, 4, sysTimeouts_[x]);
   }

   connect( statTable_, SIGNAL( cellDoubleClicked (int, int) ), this, SLOT( cellSelected( int, int ) ) );

   vbox->addWidget(statTable_); 

   return(gbox);
}

// Create group box for config file read
QGroupBox *SummaryWindow::configBox () {

   QGroupBox *gbox = new QGroupBox("Configuration And Control");

   QVBoxLayout *vbox = new QVBoxLayout;
   gbox->setLayout(vbox);

   QHBoxLayout *hbox1 = new QHBoxLayout;
   vbox->addLayout(hbox1);

   hardReset_ = new QPushButton("HardReset");
   hbox1->addWidget(hardReset_);

   softReset_ = new QPushButton("SoftReset");
   hbox1->addWidget(softReset_);

   refreshState_ = new QPushButton("RefreshState");
   hbox1->addWidget(refreshState_);

   QHBoxLayout *hbox2 = new QHBoxLayout;
   vbox->addLayout(hbox2);

   setDefaults_ = new QPushButton("Set Defaults");
   hbox2->addWidget(setDefaults_);

   configRead_ = new QPushButton("Load Settings");
   hbox2->addWidget(configRead_);

   QPushButton *tb = new QPushButton("Reset Counters");
   hbox2->addWidget(tb);

   connect(setDefaults_,SIGNAL(pressed()),this,SLOT(setDefaultsPressed()));
   connect(configRead_,SIGNAL(pressed()),this,SLOT(configReadPressed()));
   connect(refreshState_,SIGNAL(pressed()),this,SLOT(refreshStatePressed()));
   connect(softReset_,SIGNAL(pressed()),this,SLOT(softResetPressed()));
   connect(hardReset_,SIGNAL(pressed()),this,SLOT(hardResetPressed()));
   connect(tb,SIGNAL(pressed()),this,SLOT(resetCountPressed()));
  
   return(gbox);
}


// Create group box for software run control
QGroupBox *SummaryWindow::runBox () {

   QGroupBox *gbox = new QGroupBox("Run Control");

   QVBoxLayout *vbox = new QVBoxLayout;
   gbox->setLayout(vbox);

   QFormLayout *form = new QFormLayout;
   form->setRowWrapPolicy(QFormLayout::DontWrapRows);
   form->setFormAlignment(Qt::AlignHCenter | Qt::AlignTop);
   form->setLabelAlignment(Qt::AlignRight);
   vbox->addLayout(form);

   runState_ = new QComboBox;
   form->addRow(tr("Run State:"),runState_);

   connect(runState_,SIGNAL(activated(const QString &)),this,SLOT(runStateActivated(const QString &)));

   return(gbox);
}


// Constructor
SummaryWindow::SummaryWindow (int count, MainWindow *wins, QWidget *parent ) : QWidget (parent) {
   QString tmp;

   count_     = count;
   wins_      = wins;

   systemName_  = (QTableWidgetItem **)malloc(sizeof(QTableWidgetItem *)*count);
   sysRunState_ = (QTableWidgetItem **)malloc(sizeof(QTableWidgetItem *)*count);
   sysStatus_   = (QTableWidgetItem **)malloc(sizeof(QTableWidgetItem *)*count);
   sysTimeouts_ = (QTableWidgetItem **)malloc(sizeof(QTableWidgetItem *)*count);
   sysRegRx_    = (QTableWidgetItem **)malloc(sizeof(QTableWidgetItem *)*count);

   QVBoxLayout *top = new QVBoxLayout;
   setLayout(top); 

   top->addWidget(statusBox());
   top->addWidget(configBox());
   top->addWidget(runBox());

   lastLoadSettings_ = "";

   setWindowTitle("System Control");
}

// Delete
SummaryWindow::~SummaryWindow ( ) { 
   delete systemName_;
   delete sysRunState_;
   delete sysStatus_;
   delete sysTimeouts_;
   delete sysRegRx_;
}

void SummaryWindow::setDefaultsPressed() {
   sendCommand("<SetDefaults/>");
}

void SummaryWindow::configReadPressed() {
   QString cmd;
   QString fileName;

   QString label = "Config File";
   for (int x=0; x < 150; x++) label += " ";

   fileName = QInputDialog::getText(this, tr("Config File"), label, QLineEdit::Normal, lastLoadSettings_,0 ,0);

   if ( fileName != "" ) {
      cmd = "<ReadXmlFile>";
      cmd.append(fileName);
      cmd.append("</ReadXmlFile>");
      sendCommand(cmd);
      lastLoadSettings_ = fileName;
   }
}

void SummaryWindow::refreshStatePressed() {
   sendCommand("<RefreshState/>");
}

void SummaryWindow::hardResetPressed() {
   usleep(100);
   sendCommand("<HardReset/>");
}

void SummaryWindow::softResetPressed() {
   usleep(100);
   sendCommand("<SoftReset/>");
}

void SummaryWindow::cmdResStatus(int idx, QDomNode node) {
   QString     value;
   int  x;
   bool ok;

   while (! node.isNull() ) {

      if ( node.isElement() ) {
         if ( node.nodeName() == "RegRxCount"    ) {
            sysRegRx_[idx]->setText(QString().setNum(node.firstChild().nodeValue().toUInt(&ok,0)).append(" "));
            statTable_->resizeColumnsToContents();
         }
         else if ( node.nodeName() == "TimeoutCount"  ) {
            sysTimeouts_[idx]->setText(QString().setNum(node.firstChild().nodeValue().toUInt(&ok,0)).append(" "));
            statTable_->resizeColumnsToContents();
         }
         else if ( node.nodeName() == "SystemStatus"    ) {
            value = node.firstChild().nodeValue();

            if ( value == "Ready" ) sysStatus_[idx]->setBackground(QBrush(Qt::white));
            else if ( value == "Error" ) sysStatus_[idx]->setBackground(QBrush(Qt::red));
            else sysStatus_[idx]->setBackground(QBrush(Qt::yellow));

            sysStatus_[idx]->setText(value.append(" "));
            statTable_->resizeColumnsToContents();

         }
         else if ( node.nodeName() == "RunState" ) {

            sysRunState_[idx]->setText(node.firstChild().nodeValue().append(" "));
            statTable_->resizeColumnsToContents();

            if ( idx == 0 ) {
               x = runState_->findText(node.firstChild().nodeValue());
               runState_->setCurrentIndex(x);
            }
         }
         else if ( idx == 0 && node.nodeName() == "WorkingDir" ) {
            value = node.firstChild().nodeValue();
            if ( lastLoadSettings_ == "" ) {
               lastLoadSettings_ = value;
               lastLoadSettings_.append("/config/defaults.xml");
            }
         }
      }

      node = node.nextSibling();
   }
   update();
}

void SummaryWindow::cmdResStructure (int idx, QDomNode node) {
   VariableHolder *local = NULL;
   vector<QString> enums;
   uint            x;

   while ( ! node.isNull() ) {
      if ( node.isElement() ) {

         // Create holder
         local = new VariableHolder;

         if ( node.nodeName() == "description" ) {
            systemName_[idx]->setText(node.firstChild().nodeValue().append(" "));
            statTable_->resizeColumnsToContents();
         }

         // Command found
         else if ( idx == 0 && node.nodeName() == "variable" ) {
            local->addVariable(node.firstChild());
            enums = local->getEnums();

            if ( local->shortName() == "RunState" ) {
               for (x=0; x < enums.size(); x++ ) runState_->addItem(enums[x]);
            }
         }
         delete local;
      }
      node = node.nextSibling();
   }
}

void SummaryWindow::xmlMessage (int idx, QDomNode node) {
   while ( ! node.isNull() ) {

      // Status response
      if ( node.nodeName() == "status" ) cmdResStatus(idx, node.firstChild());

      // Structure response
      else if ( node.nodeName() == "structure" ) cmdResStructure(idx, node.firstChild());

      node = node.nextSibling();
   }
}

void SummaryWindow::resetCountPressed() {
   sendCommand("<ResetCount/>");
}

void SummaryWindow::runStateActivated(const QString &state) {
   QString cmd;

   cmd = "<SetRunState>";
   cmd.append(state);
   cmd.append("</SetRunState>");
   sendCommand(cmd);
}

void SummaryWindow::cellSelected (int x, int) {
   wins_[x].show();
}
