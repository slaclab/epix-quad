
TEMPLATE = app
FORMS    = 
HEADERS  = XmlClient.h SystemWindow.h MainWindow.h CommandHolder.h CommandWindow.h VariableHolder.h VariableWindow.h SummaryWindow.h
SOURCES  = XmlClient.cpp CntrlGui.cpp SystemWindow.cpp MainWindow.cpp CommandHolder.cpp CommandWindow.cpp  VariableHolder.cpp VariableWindow.cpp SummaryWindow.cpp
TARGET   = ../bin/cntrlGui
QT       += network xml script

