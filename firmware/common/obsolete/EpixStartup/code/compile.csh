#!/bin/tcsh

../compiler/src/pico -i EpixStartupCode.psm -o EpixStartupCode.hex -l EpixStartupCode.l
python ../compiler/hex2vhd.py -i EpixStartupCode.hex -o EpixStartupCode.vhd -t JTAG_LOADER_6_single_ROM_form.vhd

