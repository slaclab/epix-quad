
# Python 3 support
#source /usr/local/python/Python-3.5.2/settings.sh
source /usr/local/boost/1.62.0_p3/settings.sh

# Python 2 support
#source /afs/slac.stanford.edu/g/reseng/python/2.7.13/settings.csh
#source /afs/slac.stanford.edu/g/reseng/boost/1.62.0_p2/settings.csh

#source /usr/local/zeromq/4.2.0/settings.sh
#source /usr/local/epics/base-R3-16-0/settings.sh

# Package directories
export EPIXROGUE_DIR=${PWD}
#setenv SURF_DIR   ${PWD}/../surf
export  SURF_DIR=${PWD}/../../firmware/modules/surf
export  ROGUE_DIR=${PWD}/../rogue

# Setup python path
export PYTHONPATH=${PWD}/python:${SURF_DIR}/python:${ROGUE_DIR}/python:${PYTHONPATH}

# Setup library path
export  LD_LIBRARY_PATH=${ROGUE_DIR}/python::${LD_LIBRARY_PATH}


# Boost thread library names differ from system to system, not all have -mt
export BOOST_THREAD=-lboost_thread-mt

