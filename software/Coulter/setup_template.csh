
# Package directories
setenv COULTER_DIR    ${PWD}
setenv SURF_DIR   ${PWD}/../../firmware/submodules/surf
setenv ROGUE_DIR  ${PWD}/../rogue

# Boot thread library names differ from system to system, not all have -mt
setenv BOOST_THREAD -lboost_thread-mt

source ${ROGUE_DIR}/setup_template.csh

setenv PYTHONPATH ${COULTER_DIR}/python:${SURF_DIR}/python:$PYTHONPATH
