#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jun  3 11:31:52 2024

@author: blaj
"""

import numpy as np

fpath = './'

ny,nx = 178,192

mask = np.zeros((ny,nx),dtype=np.int8)

for iy in range(0,ny,4):
    for ix in range(0,nx,4):
        mask[iy,ix] = 1

np.savetxt(fpath+'mask.csv', mask, fmt='%1d', delimiter=',')
