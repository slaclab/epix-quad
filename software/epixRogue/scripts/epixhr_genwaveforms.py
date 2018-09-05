#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import matplotlib.pyplot as plt
import numpy as np
import sys

dac_resol = 2**16-1
dac_mem = 1024

# incr ramp
ramp = np.linspace(0, dac_resol, dac_mem, dtype=int)
np.savetxt("ramp.csv", ramp, fmt="%d")

# decr ramp
rampf = np.linspace(dac_resol, 0, dac_mem, dtype=int)
np.savetxt("rampf.csv", rampf, fmt="%d")

# sine
angle = 2*np.pi*np.linspace(0, 1, dac_mem)
sine = dac_resol/2*np.sin(angle)+dac_resol/2
np.savetxt("sine.csv", sine, fmt="%d")

if len(sys.argv) > 1 and sys.argv[1] == '-p':
    plt.figure(1,figsize=(8,6),dpi=150)
    plt.xlabel('Time (Bin)')
    plt.ylabel('Amplitude (ADU)')
    plt.title('DAC Waveforms')
    plt.plot(ramp)
    plt.plot(rampf)
    plt.plot(sine)
    plt.show()
