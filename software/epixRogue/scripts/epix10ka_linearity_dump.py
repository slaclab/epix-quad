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

import logging
import numpy as np
import os

# epix10ka ASIC const
EPIX10KAROWS = 178  # 176 + 2 calibs
EPIX10KACOLS = 192
EPIX10KABNKS = 4
EPIX10KACOLSPBNK = EPIX10KACOLS // EPIX10KABNKS
# loop config
CONFIGBLOCKS = 4  # number of blocks to interleave
CONFIGBLOCKRUN = 4  # number of runs per block
REPEATS = 2  # number of times to repeat this file dump

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
for rep in range(REPEATS):
    logging.info("REP:%d" % (rep))
    # loop thru all possible gain modes
    for mode in modes:
        pmask = mode[0]
        tr = mode[1]
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

                mat = np.concatenate((mat, calibrows))
                logging.debug(mat.shape)
                csvfile = OUTDIR + fname_pre + '.csv'
                np.savetxt(csvfile, mat, fmt='%d', delimiter=',')

                # write matrix config for all 4 ASICs
                os.system("python3 epix10ka_config.py -y yml/pulser.yml -a 0 -o %s" % (csvfile))
                os.system("python3 epix10ka_config.py -y yml/pulser.yml -a 1 -o %s" % (csvfile))
                os.system("python3 epix10ka_config.py -y yml/pulser.yml -a 2 -o %s" % (csvfile))
                os.system("python3 epix10ka_config.py -y yml/pulser.yml -a 3 -o %s" % (csvfile))

                # acquire
                datfile = OUTDIR + fname_pre + '.dat'
                # run for 20 seconds, this is enough for all modes to capture entire pulse
                execstr = "python3 epix10ka_acquire.py -r %d" % (tr)
                execstr = execstr + " -y yml/pulser.yml -l -t 20 -o %s" % (datfile)
                logging.info(execstr)
                os.system(execstr)

logging.info("Done")
