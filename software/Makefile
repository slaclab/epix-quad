# Variables
CC     := g++
DEF    :=
BIN    := $(PWD)/bin
OBJ    := $(PWD)/.obj
CFLAGS := -Wall `xml2-config --cflags` -I$(PWD)/generic -I$(PWD)/custom
LFLAGS := `xml2-config --libs` -lpthread -lrt

# Generic Sources
GEN_DIR := $(PWD)/generic
GEN_SRC := $(wildcard $(GEN_DIR)/*.cpp)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Custom Sources
CST_DIR := $(PWD)/custom
CST_SRC := $(wildcard $(CST_DIR)/*.cpp)
CST_HDR := $(wildcard $(CST_DIR)/*.h)
CST_OBJ := $(patsubst $(CST_DIR)/%.cpp,$(OBJ)/%.o,$(CST_SRC))

# Util Sources
UTL_DIR := $(PWD)/util
UTL_SRC := $(wildcard $(UTL_DIR)/*.cpp)
UTL_BIN := $(patsubst $(UTL_DIR)/%.cpp,$(BIN)/%,$(UTL_SRC))

# Default
all: dir $(GEN_OBJ) $(CST_OBJ) $(UTL_BIN) gui

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f $(BIN)/*
	cd cntrlGui; make clean

# Compile Common Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Custom Sources
$(OBJ)/%.o: $(CST_DIR)/%.cpp $(CST_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile utilities
$(BIN)/%: $(UTL_DIR)/%.cpp $(GEN_OBJ) $(CST_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/* -o $@ $< $(LFLAGS) 

# Compile gui
gui:
	cd cntrlGui; qmake
	cd cntrlGui; make

