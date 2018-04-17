#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate epix10ka linearity pulses for all possible epixk10ka modes.

Loop through all possible epix10ka gain modes and pulse the entire area
using 4x4 non-overlapping blocks

:Author: Faisal Abu-Nimeh (abunimeh@slac.stanford.edu)
:License: https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html
:Date: 20180221
:Style: OpenStack Style Guidelines https://docs.openstack.org/developer/hacking/
:vcs_id: $Id$
"""

import filecmp
import logging
import numpy as np
import os

# epix10ka ASIC const
ASICS = 4
EPIX10KAROWS = 178  # 176 + 2 calibs
EPIX10KACOLS = 192
EPIX10KABNKS = 4
EPIX10KACOLSPBNK = EPIX10KACOLS // EPIX10KABNKS
# loop config
CONFIGBLOCKS = 2  # number of blocks to interleave
CONFIGBLOCKRUN = 2  # number of runs per block
REPEATS = 6  # number of times to repeat this file dump
MASKTRIALS = 3

OUTDIR = "./out/"  # location where to dump .csv and .dat files

# myloglevel = logging.INFO
myloglevel = logging.DEBUG

logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=myloglevel)
np.set_printoptions(formatter={'int': hex})
# np.set_printoptions(threshold=np.nan)

# modes: [pixelmask, tr_bit]
modes = [[int('1101', 2), 1],  # FH -- 13 fixed-high
         [int('1001', 2), 1],  # FL -- 9 fixed-low
         [int('1101', 2), 0],  # FM -- 13 fixed-medium
         [int('0001', 2), 1],  # AH -- 1 auto-high2low
         [int('0001', 2), 0],  # AM -- 1 auto-med2low
         [int('0101', 2), 1],  # RH -- 5 reset-high
         [int('0101', 2), 0]]  # RM -- 5 reset medium

calibrows = np.zeros((2, EPIX10KACOLS), dtype=np.uint8)  # last two rows
calibrows[1,:] = 15  # set last row to 15 to match dump
for rep in range(REPEATS):
    logging.info("REP:%d" % (rep))
    # loop thru all possible gain modes
    for mode in modes:
        pmask = mode[0]
        tr = mode[1]
        hr = 0
        # if we are in fixed-high mode set hrtest to 1
        if pmask == int('1101', 2) and tr == 1:
            hr = 1
        logging.info("mask:0x%x, tr:%d" % (pmask, tr))
        # loop thru a given 4x4 block
        for block in range(CONFIGBLOCKS):
            logging.debug("block %d" % (block))
            # empty config block, we will fill it with our config
            configblock = np.zeros((CONFIGBLOCKS, CONFIGBLOCKS), dtype=np.uint8)

            # for a given block, shift test pattern to avoid having two
            # neighboring pixels firing at the same time
            for blockrun in range(CONFIGBLOCKRUN):
                fname_pre = "r_%d_m_%d_tr%d_b_%d_s_%d" % (rep, pmask, tr, block, blockrun)
                if not blockrun:
                    configblock[0, block] = pmask
                else:
                    configblock = np.roll(configblock, 1, axis=0)  # shift by one row
                    configblock = np.roll(configblock, -1, axis=1)  # shift by one col

                logging.debug("block: %d, blockrun: %d, mode: %d" % (block, blockrun, pmask))
                # create mask for entire ASIC
                # replicate configblock pattern n times to fit ASIC dimensions
                mat = np.tile(configblock, (EPIX10KAROWS//CONFIGBLOCKS, EPIX10KACOLS//CONFIGBLOCKS))
                mat[EPIX10KAROWS-2:EPIX10KAROWS, :] = calibrows
                logging.debug(mat.shape)
                csvfile = OUTDIR + fname_pre + '.csv'
                np.savetxt(csvfile, mat, fmt='%d', delimiter=',', newline='\r\n')

                # write matrix config for all 4 ASICs
                for asic in range(ASICS):
                    for mtrials in range(MASKTRIALS):
                        os.system("python3 epix10ka_config.py -y yml/pulser.yml -a %d -o %s" % (asic, csvfile))
                        os.system("python3 epix10ka_config.py -y yml/pulser.yml -a %d -d" % (asic))
                        if filecmp.cmp('matrixdump.csv', csvfile):
                            logging.debug("\tcsv files match")
                            break
                        else:
                            if mtrials == MASKTRIALS-1:
                                logging.error("config failed for asic: %d, block: %d, blockrun: %d, mode: %d" % (asic, block, blockrun, pmask))

                # acquire
                datfile = OUTDIR + fname_pre + '.dat'
                # run for 20 seconds, this is enough for all modes to capture entire pulse
                execstr = "python3 epix10ka_acquire.py -r %d -x %d" % (tr, hr)
                execstr = execstr + " -y yml/pulser.yml -l -t 20 -o %s" % (datfile)
                logging.info(execstr)
                os.system(execstr)

logging.info("Done")
