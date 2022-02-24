#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate epix10ka linearity pulses for Auto grain modes.

Run epix10ka auto gain modes and pulse the 1/8th of the entire asic in x number of steps.

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
TOTPIXS = (EPIX10KAROWS-2)*EPIX10KACOLS
EPIX10KABNKS = 4
EPIX10KACOLSPBNK = EPIX10KACOLS // EPIX10KABNKS
# loop config
CONFIGBLOCKS = 5
REPEATS = 6  # number of times to repeat this file dump
MASKTRIALS = 3
RSEED = 1  # random seed for rnumber generator

OUTDIR = "./out/"  # location where to dump .csv and .dat files

# myloglevel = logging.INFO
myloglevel = logging.DEBUG

logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=myloglevel)
np.set_printoptions(formatter={'int': hex})
# np.set_printoptions(threshold=np.nan)

# modes: [pixelmask, tr_bit]
modes = [
         # [int('1101', 2), 1],  # FH -- 13 fixed-high
         # [int('1001', 2), 1],  # FL -- 9 fixed-low
         # [int('1101', 2), 0],  # FM -- 13 fixed-medium
         [int('0001', 2), 1],  # AH -- 1 auto-high2low
         [int('0001', 2), 0],  # AM -- 1 auto-med2low
         # [int('0101', 2), 1],  # RH -- 5 reset-high
         # [int('0101', 2), 0]   # RM -- 5 reset medium
         ]

# create the last two rows i.e. calibrows
calibrows = np.zeros((2, EPIX10KACOLS), dtype=np.uint8)  # last two rows
calibrows[1, :] = 15  # set last row to 15 to match dump

# loop thru repeats
for rep in range(REPEATS):
    logging.info("REP:%d" % (rep))
    # loop thru gain modes
    for mode in modes:
        pmask = mode[0]
        tr = mode[1]
        hr = 0
        # if we are in fixed-high mode set hrtest to 1
        if pmask == int('1101', 2) and tr == 1:
            hr = 1
        logging.info("mask:0x%x, tr:%d" % (pmask, tr))
        # maximum number of on pixels is 1/8 of matrix
        # CONFIGBLOCKS number of cases to produce
        # start from 1 to max in CONFIGBLOCKS steps
        minonpixels = 1
        maxonpixels = TOTPIXS/8
        onpixels = np.linspace(minonpixels, maxonpixels, CONFIGBLOCKS)
        logging.debug(onpixels)
        # loop thru some random pattern
        for block in range(CONFIGBLOCKS):
            logging.debug("block %d" % (block))
            fname_pre = "r_%d_m_%d_tr%d_b_%d_s_0" % (rep, pmask, tr, block)
            # create empty mask
            mat = np.zeros(TOTPIXS)
            # create mask for entire ASIC
            np.random.seed(RSEED)
            ones = np.random.choice(range(TOTPIXS), int(onpixels[block]), replace=False)
            logging.debug("ones shape %d" % (ones.shape))
            mat[ones] = 1
            mat = mat.reshape((EPIX10KAROWS-2), EPIX10KACOLS)
            maton = np.count_nonzero(mat)
            logging.debug("number of on pixels %d" % (maton))
            # mat[EPIX10KAROWS-2:EPIX10KAROWS, :] = calibrows
            mat = np.concatenate((mat, calibrows))
            logging.debug(mat.shape)
            csvfile = OUTDIR + fname_pre + '.csv'
            np.savetxt(csvfile, mat, fmt='%d', delimiter=',', newline='\r\n')

            # write matrix config for all 4 ASICs
            for asic in range(ASICS):
                for mtrials in range(MASKTRIALS):
                    os.system("python3 epix10ka_config.py -y yml/pulser.yml -a %d -o %s" %
                              (asic, csvfile))
                    os.system("python3 epix10ka_config.py -y yml/pulser.yml -a %d -d" % (asic))
                    if filecmp.cmp('matrixdump.csv', csvfile):
                        logging.debug("\tcsv files match")
                        break
                    else:
                        if mtrials == MASKTRIALS-1:
                            errstr = "config failed for asic: %d" % (asic)
                            errstr += ", block: %d, blockrun: 0, mode: %d" % (block, pmask)
                            logging.error(errstr)

            # acquire
            datfile = OUTDIR + fname_pre + '.dat'
            # run for 20 seconds, this is enough for all modes to capture entire pulse
            execstr = "python3 epix10ka_acquire.py -r %d -x %d" % (tr, hr)
            execstr = execstr + " -y yml/pulser.yml -l -t 20 -o %s" % (datfile)
            logging.info(execstr)
            os.system(execstr)

logging.info("Done")
