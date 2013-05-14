# Variables
CC     := g++
DEF    := -DMAKE_SW_VERSION=\"kpixSw_3.04\"
BIN    := $(PWD)/bin
OBJ    := $(PWD)/.obj
CFLAGS := -Wall `xml2-config --cflags` -I$(PWD)/generic -I$(PWD)/kpix -I$(PWD)/offline
LFLAGS := `xml2-config --libs` -pthread -lrt

# Generic Sources
GEN_DIR := $(PWD)/generic
GEN_SRC := $(wildcard $(GEN_DIR)/*.cpp)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Kpix Sources
KPX_DIR := $(PWD)/kpix
KPX_SRC := $(wildcard $(KPX_DIR)/*.cpp)
KPX_HDR := $(wildcard $(KPX_DIR)/*.h)
KPX_OBJ := $(patsubst $(KPX_DIR)/%.cpp,$(OBJ)/%.o,$(KPX_SRC))

# Util Sources
UTL_DIR := $(PWD)/util
UTL_SRC := $(wildcard $(UTL_DIR)/*.cpp)
UTL_BIN := $(patsubst $(UTL_DIR)/%.cpp,$(BIN)/%,$(UTL_SRC))

# Default
all: dir $(GEN_OBJ) $(KPX_OBJ) $(UTL_BIN) gui ana online pylibs

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
$(OBJ)/%.o: $(KPX_DIR)/%.cpp $(KPX_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile utilities
$(BIN)/%: $(UTL_DIR)/%.cpp $(GEN_OBJ) $(KPX_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

# root
ana:
ifneq ($(ROOTSYS),)
	cd root; gmake
endif

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

