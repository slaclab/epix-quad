# Setup environment
source /afs/slac/g/reseng/rogue/v3.7.0/setup_rogue.sh

# Python Package directories
export EPIXROGUE_DIR=${PWD}/python
export SURF_DIR=${PWD}/../../firmware/submodules/surf/python

# Setup python path
export PYTHONPATH=${PWD}/python:${EPIXROGUE_DIR}:${SURF_DIR}:${PYTHONPATH}
