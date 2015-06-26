# Variables
CFLAGS  := -Wall `xml2-config --cflags` `root-config --cflags` -I$(PWD)/../generic
LFLAGS  := `xml2-config --libs` `root-config --libs` -lMinuit -lrt -lbz2
CC      := g++
BIN     := $(PWD)/../bin
OBJ     := $(PWD)/.obj

# Generic Sources
GEN_DIR := $(PWD)/../generic
GEN_SRC := $(wildcard $(GEN_DIR)/*.cpp)
GEN_HDR := $(wildcard $(GEN_DIR)/*.h)
GEN_OBJ := $(patsubst $(GEN_DIR)/%.cpp,$(OBJ)/%.o,$(GEN_SRC))

# Root Sources
ROOT_DIR := $(PWD)
ROOT_SRC := $(wildcard $(ROOT_DIR)/*.cpp)
ROOT_BIN := $(patsubst $(ROOT_DIR)/%.cpp,$(BIN)/%,$(ROOT_SRC))

# Default
all: dir $(GEN_OBJ) $(ROOT_BIN) $(BIN)/

# Object directory
dir:
	test -d $(OBJ) || mkdir $(OBJ)

# Clean
clean:
	rm -rf $(OBJ)
   
# Compile Common Sources
$(OBJ)/%.o: $(GEN_DIR)/%.cpp $(GEN_DIR)/%.h
	$(CC) -c $(CFLAGS) $(DEF) -o $@ $<

# Compile applications
$(BIN)/%: $(ROOT_DIR)/%.cpp $(GEN_OBJ)
	$(CC) $(CFLAGS) $(DEF) $(OBJ)/*.o -o $@ $< $(LFLAGS) 
