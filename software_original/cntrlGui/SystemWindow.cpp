//-----------------------------------------------------------------------------
// File          : SystemWindow.cpp
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
#include "SystemWindow.h"
#include "CommandHolder.h"
#include "VariableHolder.h"
using namespace std;

// Counter table
QGroupBox *SystemWindow::counterBox() {
   QGroupBox *gb = new QGroupBox("Counters");

   QVBoxLayout *vbox = new QVBoxLayout;
   gb->setLayout(vbox);

   QHBoxLayout *hbox = new QHBoxLayout;
   vbox->addLayout(hbox);

   QFormLayout *form1 = new QFormLayout;
   form1->setRowWrapPolicy(QFormLayout::DontWrapRows);
   form1->setFieldGrowthPolicy(QFormLayout::FieldsStayAtSizeHint);
   form1->setFormAlignment(Qt::AlignHCenter | Qt::AlignTop);
   form1->setLabelAlignment(Qt::AlignRight);
   hbox->addLayout(form1);

   countRegRx_ = new QLineEdit;
   countRegRx_->setReadOnly(true);
   form1->addRow(tr("Register Rx:"),countRegRx_);

   countDataRx_ = new QLineEdit;
   countDataRx_->setReadOnly(true);
   form1->addRow(tr("Data Rx:"),countDataRx_);

   countDataFile_ = new QLineEdit;
   countDataFile_->setReadOnly(true);
   form1->addRow(tr("Data File:"),countDataFile_);
   
   QFormLayout *form2 = new QFormLayout;
   form2->setRowWrapPolicy(QFormLayout::DontWrapRows);
   form2->setFieldGrowthPolicy(QFormLayout::FieldsStayAtSizeHint);
   form2->setFormAlignment(Qt::AlignHCenter | Qt::AlignTop);
   form2->setLabelAlignment(Qt::AlignRight);
   hbox->addLayout(form2);

   countTimeout_ = new QLineEdit;
   countTimeout_->setReadOnly(true);
   form2->addRow(tr("Timeout:"),countTimeout_);

   countError_ = new QLineEdit;
   countError_->setReadOnly(true);
   form2->addRow(tr("Error:"),countError_);

   countUnexp_ = new QLineEdit;
   countUnexp_->setReadOnly(true);
   form2->addRow(tr("Unexpected:"),countUnexp_);

   QPushButton *tb = new QPushButton("Reset Counters");
   vbox->addWidget(tb);
   connect(tb,SIGNAL(pressed()),this,SLOT(resetCountPressed()));

   return(gb);
}

// Create group box for config file read
QGroupBox *SystemWindow::configBox () {

   QGroupBox *gbox = new QGroupBox("Configuration and State");

   QVBoxLayout *vbox = new QVBoxLayout;
   gbox->setLayout(vbox);

   QFormLayout *form = new QFormLayout;
   vbox->addLayout(form);

   stateLine_ = new QTextEdit();
   stateLine_->setReadOnly(true);
   QFontMetrics m (stateLine_->font());
   int RowHeight = m.lineSpacing() ;
   stateLine_->setMinimumHeight(10 * RowHeight);

   form->addRow(tr("State:"),stateLine_);

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

   configSave_ = new QPushButton("Save Settings");
   hbox2->addWidget(configSave_);

   connect(setDefaults_,SIGNAL(pressed()),this,SLOT(setDefaultsPressed()));
   connect(configRead_,SIGNAL(pressed()),this,SLOT(configReadPressed()));
   connect(configSave_,SIGNAL(pressed()),this,SLOT(configSavePressed()));
   connect(refreshState_,SIGNAL(pressed()),this,SLOT(refreshStatePressed()));
   connect(softReset_,SIGNAL(pressed()),this,SLOT(softResetPressed()));
   connect(hardReset_,SIGNAL(pressed()),this,SLOT(hardResetPressed()));
  
   return(gbox);
}


// Create group box for data file write
QGroupBox *SystemWindow::dataBox () {

   QGroupBox *gbox = new QGroupBox("Data File");

   QVBoxLayout *vbox = new QVBoxLayout;
   gbox->setLayout(vbox);

   dataFile_ = new QLineEdit;
   vbox->addWidget(dataFile_);

   QHBoxLayout *hbox = new QHBoxLayout;
   vbox->addLayout(hbox);

   dataBrowse_ = new QPushButton("Browse");
   hbox->addWidget(dataBrowse_);

   dataOpen_ = new QPushButton("Open");
   hbox->addWidget(dataOpen_);

   dataClose_ = new QPushButton("Close");
   hbox->addWidget(dataClose_);

   connect(dataBrowse_,SIGNAL(pressed()),this,SLOT(browseDataPressed()));
   connect(dataOpen_,SIGNAL(pressed()),this,SLOT(openDataPressed()));
   connect(dataClose_,SIGNAL(pressed()),this,SLOT(closeDataPressed()));
  
   return(gbox);
}

// Create group box for software run control
QGroupBox *SystemWindow::cmdBox () {

   QGroupBox *gbox = new QGroupBox("Run Control");

   QVBoxLayout *vbox = new QVBoxLayout;
   gbox->setLayout(vbox);

   QFormLayout *form = new QFormLayout;
   form->setRowWrapPolicy(QFormLayout::DontWrapRows);
   form->setFormAlignment(Qt::AlignHCenter | Qt::AlignTop);
   form->setLabelAlignment(Qt::AlignRight);
   //form->setFieldGrowthPolicy(QFormLayout::FieldsStayAtSizeHint);
   vbox->addLayout(form);

   runRate_ = new QComboBox;
   form->addRow(tr("Run Rate:"),runRate_);

   runCount_ = new QSpinBox;
   runCount_->setMinimum(0);
   runCount_->setMaximum(99999999);
   form->addRow(tr("Run Count:"),runCount_);

   runState_ = new QComboBox;
   form->addRow(tr("Run State:"),runState_);

   runProgress_ = new QProgressBar;
   vbox->addWidget(runProgress_);

   connect(runState_,SIGNAL(activated(const QString &)),this,SLOT(runStateActivated(const QString &)));

   return(gbox);
}


// Constructor
SystemWindow::SystemWindow ( QWidget *parent ) : QWidget (parent) {
   QString tmp;

   QVBoxLayout *top = new QVBoxLayout;
   setLayout(top); 

   top->addWidget(configBox());
   top->addWidget(dataBox());
   top->addWidget(cmdBox());
   top->addWidget(counterBox());

   lastLoadSettings_ = "";
   lastSaveSettings_ = "";
   lastData_ = "";

   stateMsg_  = "";
   isLocal_   = false;
}

// Delete
SystemWindow::~SystemWindow ( ) { 
}

void SystemWindow::setDefaultsPressed() {
   topConfigCommand("<SetDefaults/>");
}

void SystemWindow::configReadPressed() {
   QString cmd;
   QString fileName;

   QString label = "Config File";
   for (int x=0; x < 150; x++) label += " ";

   if ( isLocal_ ) fileName = QFileDialog::getOpenFileName(this, tr("Load Config"), lastLoadSettings_, tr("XML Files (*.xml)"));
   else fileName = QInputDialog::getText(this, tr("Config File"), label, QLineEdit::Normal, lastLoadSettings_,0 ,0);

   if ( fileName != "" ) {
      cmd = "<ReadXmlFile>";
      cmd.append(fileName);
      cmd.append("</ReadXmlFile>");
      topConfigCommand(cmd);
      lastLoadSettings_ = fileName;
   }
}

void SystemWindow::configSavePressed() {
   QString cmd;
   QString fileName;

   QString label = "Dump File";
   for (int x=0; x < 150; x++) label += " ";

   if ( isLocal_ ) fileName = QFileDialog::getSaveFileName(this, tr("Save Config"), lastSaveSettings_, tr("XML Files (*.xml)"));
   else fileName = QInputDialog::getText(this, tr("Dump File"), label, QLineEdit::Normal, lastSaveSettings_,0 ,0);

   if ( fileName != "" ) {
      cmd = "<WriteConfigXml>";
      cmd.append(fileName);
      cmd.append("</WriteConfigXml>");
      topConfigCommand(cmd);
      lastSaveSettings_ = fileName;
   }
}

void SystemWindow::refreshStatePressed() {
   stateMsg_ = "Updating State. Please Wait!\n";
   updateState();
   topConfigCommand("<RefreshState/>");
}

void SystemWindow::hardResetPressed() {
   usleep(100);
   stateMsg_ = "Sending Hard Reset. Please Wait!\n";
   sendCommand("<HardReset/>");
   updateState();
}

void SystemWindow::softResetPressed() {
   usleep(100);
   stateMsg_ = "Sending Soft Reset. Please Wait!\n";
   sendCommand("<SoftReset/>");
   updateState();
}

void SystemWindow::browseDataPressed() {
   QString fileName;

   fileName = QFileDialog::getSaveFileName(this, tr("Select Data File"), lastData_, tr("Data File (*.bin)"),0,QFileDialog::DontConfirmOverwrite);

   if ( fileName != "" ) {
      lastData_ = fileName;
      dataFile_->setText(fileName); 
   }
}

void SystemWindow::openDataPressed() {
   if ( dataFile_->text() != "" ) 
      topConfigCommand("<OpenDataFile/>");
}

void SystemWindow::closeDataPressed() {
   topConfigCommand("<CloseDataFile/>");
}

void SystemWindow::cmdResStatus(QDomNode node) {
   QStringList fields;
   QString     value;
   int         idx;
   bool ok;

   while (! node.isNull() ) {

      if ( node.isElement() ) {

         // Variables
         if ( node.nodeName() == "DataFileCount" ) 
            countDataFile_->setText(node.firstChild().nodeValue());
         else if ( node.nodeName() == "DataRxCount"   ) 
            countDataRx_->setText(node.firstChild().nodeValue());
         else if ( node.nodeName() == "RegRxCount"    ) 
            countRegRx_->setText(QString().setNum(node.firstChild().nodeValue().toUInt(&ok,0)));
         else if ( node.nodeName() == "UnexpectedCount"  ) 
            countUnexp_->setText(QString().setNum(node.firstChild().nodeValue().toUInt(&ok,0)));
         else if ( node.nodeName() == "TimeoutCount"  ) 
            countTimeout_->setText(QString().setNum(node.firstChild().nodeValue().toUInt(&ok,0)));
         else if ( node.nodeName() == "ErrorCount"    ) 
            countError_->setText(QString().setNum(node.firstChild().nodeValue().toUInt(&ok,0)));
         else if ( node.nodeName() == "SystemState"    ) {
            stateMsg_ = node.firstChild().nodeValue();
            updateState();
         }
         else if ( node.nodeName() == "SystemStatus"    ) {
            sysStatus_ = node.firstChild().nodeValue();
            updateState();
         }
         else if ( node.nodeName() == "WorkingDir" ) {
            value = node.firstChild().nodeValue();
            if ( lastLoadSettings_ == "" ) {
               lastLoadSettings_ = value;
               lastLoadSettings_.append("/config/defaults.xml");
            }
            if ( lastSaveSettings_ == "" ) {
               lastSaveSettings_ = value;
               lastSaveSettings_.append("/config/configDump.xml");
            }
            if ( lastData_ == "" ) {
               lastData_ = value;
               lastData_.append("/data.bin");
            }
         }
         else if ( node.nodeName() == "RunProgress"    ) {
            runProgress_->setRange(0,100);
            runProgress_->setValue(node.firstChild().nodeValue().toUInt(&ok,0));
         }

         // File Status
         else if ( node.nodeName() == "DataOpen" ) {

            if ( dataFile_->text() == "Data File Disabled" ) {
               dataFile_->setEnabled(false);
               dataBrowse_->setEnabled(false);
               dataOpen_->setEnabled(false);
               dataClose_->setEnabled(false);
            } else if ( node.firstChild().nodeValue() == "False" ) {
               //dataFile_->setEnabled(true);
               dataBrowse_->setEnabled(isLocal_);
               dataOpen_->setEnabled(true);
               dataClose_->setEnabled(false);
            } else {
               //dataFile_->setEnabled(false);
               dataBrowse_->setEnabled(false);
               dataOpen_->setEnabled(false);
               dataClose_->setEnabled(true);
            }
         }

         // Run state
         else if ( node.nodeName() == "RunState" ) {
            idx = runState_->findText(node.firstChild().nodeValue());
            runState_->setCurrentIndex(idx);
         }
      }

      node = node.nextSibling();
   }
   update();
}

void SystemWindow::cmdResConfig(QDomNode node) {
   QStringList fields;
   QString     value;
   int         idx;
   bool ok;

   while (! node.isNull() ) {

      if ( node.isElement() ) {

         if ( node.nodeName() == "RunRate"   ) {
            idx = runRate_->findText(node.firstChild().nodeValue());
            runRate_->setCurrentIndex(idx);
         }
         else if ( node.nodeName() == "RunCount"   ) 
            runCount_->setValue(node.firstChild().nodeValue().toUInt(&ok,0));
         else if ( node.nodeName() == "DataFile" ) 
            dataFile_->setText(node.firstChild().nodeValue());
      }

      node = node.nextSibling();
   }
   update();
}

void SystemWindow::cmdResStructure (QDomNode node) {
   VariableHolder *local = NULL;
   vector<QString> enums;
   uint            x;

   while ( ! node.isNull() ) {
      if ( node.isElement() ) {

         // Create holder
         local = new VariableHolder;

         // Command found
         if ( node.nodeName() == "variable" ) {
            local->addVariable(node.firstChild());
            enums = local->getEnums();

            if ( local->shortName() == "RunState" ) {
               for (x=0; x < enums.size(); x++ ) runState_->addItem(enums[x]);
            }

            if ( local->shortName() == "RunRate" ) {
               for (x=0; x < enums.size(); x++ ) runRate_->addItem(enums[x]);
            }
         }
         delete local;
      }
      node = node.nextSibling();
   }
}

void SystemWindow::xmlMessage (int, QDomNode node) {
   while ( ! node.isNull() ) {

      // Status response
      if ( node.nodeName() == "status" ) cmdResStatus(node.firstChild());

      // Config response
      else if ( node.nodeName() == "config" ) cmdResConfig(node.firstChild());

      // Structure response
      else if ( node.nodeName() == "structure" ) cmdResStructure(node.firstChild());

      node = node.nextSibling();
   }
}

void SystemWindow::resetCountPressed() {
   topConfigCommand("<ResetCount/>");
}

void SystemWindow::runStateActivated(const QString &state) {
   QString cmd;

   cmd = "<SetRunState>";
   cmd.append(state);
   cmd.append("</SetRunState>");
   topConfigCommand(cmd);
}

// Send command along with system window config
void SystemWindow::topConfigCommand(QString cmd) {
   QString cfg;

   cfg = "<DataFile>";
   cfg.append(dataFile_->text());
   cfg.append("</DataFile>");
   cfg.append("<RunRate>");
   cfg.append(runRate_->currentText());
   cfg.append("</RunRate>");
   cfg.append("<RunCount>");
   cfg.append(QString().setNum(runCount_->value()));
   cfg.append("</RunCount>");

   sendConfigCommand(cfg,cmd);
}

void SystemWindow::updateState () {
   QString msg;

   msg = stateMsg_;
   if ( stateLine_->toPlainText() != msg ) stateLine_->setPlainText(msg);

   QPalette p = stateLine_->palette();

   if ( sysStatus_ == "Ready" ) p.setColor(QPalette::Base, Qt::white);
   else if ( sysStatus_ == "Error" ) p.setColor(QPalette::Base, Qt::red); // Error
   else p.setColor(QPalette::Base, Qt::yellow); // Warning or unconfigured or user defined value

   stateLine_->setPalette(p);
}

void SystemWindow::setLocal ( bool local ) {
   isLocal_ = local;
}

