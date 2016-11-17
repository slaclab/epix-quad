# 
# ----------------------------------------------------------------------------
# Title      : rogue_example makefile
# ----------------------------------------------------------------------------
# File       : Makefile
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-23
# Last update: 2016-10-23
# ----------------------------------------------------------------------------
# Description:
# rogue_example makefile
# ----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------
# 

# Variables
CC       := g++
DEF      :=
CFLAGS   := -Wall `python2.7-config --cflags` -I$(ROGUE_DIR)/include -std=c++0x -fPIC 
LFLAGS   := `python2.7-config --ldflags` $(BOOST_THREAD) -lboost_python -lboost_system
LFLAGS   += -L`python2.7-config --prefix`/lib/ -l:rogue.so -L$(ROGUE_DIR)/python
DST      := $(PWD)/python
SHNAME   := rogue_example
SHLIB    := rogue_example.so

# Sources
LIB_SRC := $(PWD)/src
LIB_CPP := $(foreach dir,$(shell find $(LIB_SRC) -type d),$(wildcard $(dir)/*.cpp))
LIB_OBJ := $(patsubst %.cpp,%.o,$(LIB_CPP))
LIB_SHO := $(DST)/$(SHLIB)

# Targets
all: $(LIB_OBJ) $(LIB_SHO)

# Clean
clean:
	@rm -f $(LIB_OBJ)
	@rm -f $(LIB_SHO)

# Compile sources with headers
%.o: %.cpp %.h
	@echo "Compiling $@"; $(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile sources without headers
%.o: %.cpp
	@echo "Compiling $@"; $(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Shared Library
$(LIB_SHO): $(LIB_OBJ)
	@test -d $(DST) || mkdir $(DST)
	@echo "Creating $@"; $(CC) -shared -Wl,-soname,$(SHNAME) $(LIB_OBJ) $(LFLAGS) -o $@

