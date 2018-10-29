# Setup environment
#source /afs/slac/g/reseng/rogue/pre-release/setup_rogue.csh
source /afs/slac/g/reseng/rogue/v2.12.0/setup_env.csh

# Python Package directories
setenv EPIXROGUE_DIR ${PWD}/python
setenv SURF_DIR      ${PWD}/../../firmware/submodules/surf/python

# Setup python path
setenv PYTHONPATH ${PWD}/python:${EPIXROGUE_DIR}:${SURF_DIR}:${PYTHONPATH}
