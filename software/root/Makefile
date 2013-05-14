# Variables
CFLAGS  := -Wall `xml2-config --cflags` `root-config --cflags` -I$(PWD)/../kpix -I$(PWD)/../generic
LFLAGS  := `xml2-config --libs` `root-config --libs` -lMinuit -lrt
CC      := g++
BIN     := $(PWD)/../bin
OBJ     := $(PWD)/.obj

# Generic Sources
GEN_DIR := $(PWD)/../generic
GEN_SRC := $(GEN_DIR)/Data.cpp $(GEN_DIR)/DataRead.cpp $(GEN_DIR)/XmlVariables.cpp
GEN_HDR := $(GEN_DIR)/Data.h   $(GEN_DIR)/DataRead.h   $(GEN_DIR)/XmlVariables.h
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Offline Sources
KPX_DIR := $(PWD)/../kpix
KPX_SRC := $(KPX_DIR)/KpixSample.cpp $(KPX_DIR)/KpixEvent.cpp $(KPX_DIR)/KpixCalibRead.cpp
KPX_HDR := $(KPX_DIR)/KpixSample.h   $(KPX_DIR)/KpixEvent.h   $(KPX_DIR)/KpixCalibRead.h
KPX_OBJ := $(patsubst $(KPX_DIR)/%.cpp,$(OBJ)/%.o,$(KPX_SRC))

# Root Sources
ROOT_DIR := $(PWD)
ROOT_SRC := $(wildcard $(ROOT_DIR)/*.cpp)
ROOT_BIN := $(patsubst $(ROOT_DIR)/%.cpp,$(BIN)/%,$(ROOT_SRC))

# Default
all: dir $(GEN_OBJ) $(KPX_OBJ) $(ROOT_BIN) $(BIN)/root_kpix

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
	rm -f  $(UTL_BIN)

# Pre-process the headers for root
$(OBJ)/kpix_headers.C: $(GEN_HDR) $(KPX_HDR)
	rootcint -f $(OBJ)/kpix_headers.C -c $(DEF) $(CFLAGS) $(GEN_HDR) $(KPX_HDR) $(ROOT_DEF)

# Compile Offline Sources
$(OBJ)/%.o: $(KPX_DIR)/%.cpp $(KPX_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile Generic Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Comile applications
$(BIN)/%: $(ROOT_DIR)/%.cpp $(KPX_OBJ) $(GEN_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/*.o -o $@ $< $(LFLAGS) 

# Comile root
$(BIN)/root_kpix: root_kpix.cc $(KPX_OBJ) $(GEN_OBJ) $(OBJ)/kpix_headers.C
	$(CC) $(CFLAGS) $(LFLAGS) $(DEF) $(OBJ)/*.o -o $(BIN)/root_kpix root_kpix.cc $(OBJ)/kpix_headers.C
