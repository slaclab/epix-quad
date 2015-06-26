# Variables
MACHINE := $(shell uname -m)

# RCE Build
ifeq ($(MACHINE), armv7l)
   PYTHON=python2
else
   PYTHON=python
endif

all:
	${PYTHON} setup.py build
	${PYTHON} setup.py install --home=.

clean:
	rm -rf build
	rm -rf lib
