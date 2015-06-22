# Variables
CC     := g++
DEF    :=
BIN    := $(PWD)/bin
OBJ    := $(PWD)/.obj
CFLAGS := -Wall `xml2-config --cflags` -I$(PWD)/generic -I$(PWD)/epix -I$(PWD)/offline
LFLAGS := `xml2-config --libs` -pthread -lrt -lbz2

# Generic Sources
GEN_DIR := $(PWD)/generic
GEN_SRC := $(wildcard $(GEN_DIR)/*.cpp)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Epix Sources
EPX_DIR := $(PWD)/epix
EPX_SRC := $(wildcard $(EPX_DIR)/*.cpp)
EPX_HDR := $(wildcard $(EPX_DIR)/*.h)
EPX_OBJ := $(patsubst $(EPX_DIR)/%.cpp,$(OBJ)/%.o,$(EPX_SRC))

# Util Sources
UTL_DIR := $(PWD)/util
UTL_SRC := $(wildcard $(UTL_DIR)/*.cpp)
UTL_BIN := $(patsubst $(UTL_DIR)/%.cpp,$(BIN)/%,$(UTL_SRC))

# Default
all: dir $(GEN_OBJ) $(EPX_OBJ) $(UTL_BIN) gui ana online pylibs

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f $(BIN)/*
	cd cntrlGui; qmake; gmake clean
	cd root; gmake clean
	cd python; gmake clean
ifneq ($(QWTDIR),)
	cd onlineGui; qmake; gmake clean
endif

# Compile Common Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Tracker Sources
$(OBJ)/%.o: $(EPX_DIR)/%.cpp $(EPX_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile utilities
$(BIN)/%: $(UTL_DIR)/%.cpp $(GEN_OBJ) $(EPX_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

# root
ana:
#ifneq ($(ROOTSYS),)
#	cd root; gmake
#endif

# python libs
pylibs:
ifneq ($(PYTHONPATH),)
	cd python; gmake
endif

# Compile gui
gui:
	cd cntrlGui; qmake
	cd cntrlGui; gmake

# online gui
online:
ifneq ($(QWTDIR),)
	cd onlineGui; qmake
	cd onlineGui; gmake
endif

