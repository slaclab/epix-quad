# Template setup_env.csh script. You should make a copy of this and 
# rename it to setup_env.csh after checkout

# Base directory
setenv BASE ${PWD}

# QT Base Directory, required for compile
#setenv QTDIR   /afs/slac/g/reseng/qt/qt_4.7.4_x64 #64-bit version
setenv QTDIR /afs/slac/g/reseng/qt/qt_4.6.3

# QWT Base Directory, uncomment to compile online gui
#setenv QWTDIR  /afs/slac/g/reseng/qt/qwt_6.0_x64

# Root base directory, uncomment to compile root programs
#setenv ROOTSYS /afs/slac/g/reseng/root/root_5.20_x64

# Python search path, uncomment to compile python script support
setenv PYTHONPATH ${BASE}/python/lib/python/

# Setup path
if ($?PATH) then
   setenv PATH ${BASE}/bin:${QTDIR}/bin:${PATH}
else
   setenv PATH ${BASE}/bin:${QTDIR}/bin
endif

# Setup library path
if ($?LD_LIBRARY_PATH) then
   setenv LD_LIBRARY_PATH ${QTDIR}/lib:${LD_LIBRARY_PATH}
else
   setenv LD_LIBRARY_PATH ${QTDIR}/lib
endif

# Optional QWT
if ($?QWTDIR) then
   setenv LD_LIBRARY_PATH ${QWTDIR}/lib:${LD_LIBRARY_PATH}
endif

# Optional root
if ($?ROOTSYS) then
   setenv PATH ${ROOTSYS}/bin:${PATH}
   setenv LD_LIBRARY_PATH ${ROOTSYS}/lib:${LD_LIBRARY_PATH}
endif

