# Variables
CC     := g++
DEF    :=
BIN    := $(PWD)/bin
OBJ    := $(PWD)/.obj
CFLAGS := -Wall `xml2-config --cflags` -I$(PWD)/deviceLib -I$(PWD)/generic -I$(PWD)/epix -I$(PWD)/offline
LFLAGS := `xml2-config --libs` -pthread -lrt -lbz2 -lgsl -lgslcblas -lm

# Device Lib Sources
DEV_DIR := $(PWD)/deviceLib
DEV_SRC := $(wildcard $(DEV_DIR)/*.cpp)
DEV_HDR := $(wildcard $(DEV_DIR)/*.h)
DEV_OBJ := $(patsubst $(DEV_DIR)/%.cpp,$(OBJ)/%.o,$(DEV_SRC))

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
# UTL_DIR := $(PWD)/util
# UTL_SRC := $(wildcard $(UTL_DIR)/*.cpp)
# UTL_BIN := $(patsubst $(UTL_DIR)/%.cpp,$(BIN)/%,$(UTL_SRC))

# Epix util Sources
UTL_EPIX_DIR := $(PWD)/util/epix
UTL_EPIX_SRC := $(wildcard $(UTL_EPIX_DIR)/*.cpp)
UTL_EPIX_BIN := $(patsubst $(UTL_EPIX_DIR)/%.cpp,$(BIN)/%,$(UTL_EPIX_SRC))

# Tixel util Sources
UTL_TIXE_DIR := $(PWD)/util/tixel
UTL_TIXE_SRC := $(wildcard $(UTL_TIXE_DIR)/*.cpp)
UTL_TIXE_BIN := $(patsubst $(UTL_TIXE_DIR)/%.cpp,$(BIN)/%,$(UTL_TIXE_SRC))

# Cpix util Sources
UTL_CPIX_DIR := $(PWD)/util/cpix
UTL_CPIX_SRC := $(wildcard $(UTL_CPIX_DIR)/*.cpp)
UTL_CPIX_BIN := $(patsubst $(UTL_CPIX_DIR)/%.cpp,$(BIN)/%,$(UTL_CPIX_SRC))

# Common util Sources
UTL_COMM_DIR := $(PWD)/util/comm
UTL_COMM_SRC := $(wildcard $(UTL_COMM_DIR)/*.cpp)
UTL_COMM_BIN := $(patsubst $(UTL_COMM_DIR)/%.cpp,$(BIN)/%,$(UTL_COMM_SRC))

# Default
all: dir $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ) $(UTL_EPIX_BIN) $(UTL_TIXE_BIN) $(UTL_CPIX_BIN) $(UTL_COMM_BIN) gui ana online pylibs
#all: dir $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ) $(UTL_BIN) gui ana online pylibs
#all: dir $(GEN_OBJ) $(EPX_OBJ) $(UTL_BIN) gui ana online 

epix: dir $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ) $(UTL_EPIX_BIN) gui online pylibs
tixel: dir $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ) $(UTL_TIXE_BIN) gui online pylibs
cpix: dir $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ) $(UTL_CPIX_BIN) gui online pylibs
comm: dir $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ) $(UTL_COMM_BIN) gui online pylibs

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

# Compile Dev Lib Sources
$(OBJ)/%.o: $(DEV_DIR)/%.cpp $(DEV_DIR)/%.h 
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Common Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h 
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Tracker Sources
$(OBJ)/%.o: $(EPX_DIR)/%.cpp $(EPX_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile utilities
#$(BIN)/%: $(UTL_DIR)/%.cpp $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ)
#	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

$(BIN)/%: $(UTL_EPIX_DIR)/%.cpp $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

$(BIN)/%: $(UTL_TIXE_DIR)/%.cpp $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

$(BIN)/%: $(UTL_CPIX_DIR)/%.cpp $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

$(BIN)/%: $(UTL_COMM_DIR)/%.cpp $(DEV_OBJ) $(GEN_OBJ) $(EPX_OBJ)
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

