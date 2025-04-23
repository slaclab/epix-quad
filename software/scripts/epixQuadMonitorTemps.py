#!/usr/bin/env python3
##############################################################################
# This file is part of 'EPIX'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
# https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'EPIX', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
##############################################################################
import setupLibPaths

import sys
import pyrogue as pr
#import pyrogue.gui
import pyrogue.pydm
import rogue
import argparse
import ePixQuad as quad

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import time
from datetime import datetime

from scipy import stats
#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Convert str to bool
def argBool(s):
    return s.lower() in ['true', 't', 'yes', '1']



#parser.add_argument(
#    "--yml",
#    type=str,
#    required=False,
#    default='',
#    help="Configuration file",
#)

#parser.add_argument(
#    "--bitmask",
#    type=str,
#    required=True,
#    default='',
#    help="Pixel bitmap file",
#)

#parser.add_argument(
#    "--inj",
#    type=str,
#    required=True,
#    default='t',
#    help="Flash bitmap",
#)

parser.add_argument(
    "--dev",
    type=str,
    required=False,
    default='/dev/datadev_0',
    help="Data card type pgp3_cardG3, datadev or simulation)",
)

parser.add_argument(
    "--l",
    type=int,
    required=True,
    help="PGP lane number [0 ~ 3]",
)

# Get the arguments
args = parser.parse_args()

#################################################################

# Set base
with quad.Top(
    hwType='datadev',
    dev=args.dev,
    lane=args.l,
    promWrEn=False,
) as root:

    sensors = [
        'ShtTemp',
        'NctLocTemp', 
        'NctRemTemp', 
        'Therm0_Temp', 
        'Therm1_Temp', 
        'PwrDigTemp',
        'PwrAnaTemp',
        'A0_2_5V_H_Temp',
        'A0_2_5V_L_Temp',
        'A1_2_5V_H_Temp',
        'A1_2_5V_L_Temp',
        'A2_2_5V_H_Temp',
        'A2_2_5V_L_Temp',
        'A3_2_5V_H_Temp',
        'A3_2_5V_L_Temp',
        'D0_2_5V_Temp',
        'D1_2_5V_Temp',
        'A0_1_8V_Temp',
        'A2_1_8V_Temp',
        'A2_1_8V_Temp',
        'PcbAnaTemp0',
        'PcbAnaTemp1',
        'PcbAnaTemp2',
        'TrOptTemp'
    ]
        
    timestamps = []
    temperatures = [[] for _ in range(len(sensors))]
    
    # Create figure and axis
    plt.ion()  # Turn on interactive mode
    fig, ax = plt.subplots()
    lines = [ax.plot_date([], [], '-', label=sensors[i])[0] for i in range(len(sensors))]

    ax.set_xlabel("Time")
    ax.set_ylabel("Temperature (°C)")
    #ax.legend(loc='upper left', ncol=2)
    # Move legend to the right outside the plot
    ax.legend(loc='center left', bbox_to_anchor=(1.02, 0.5), borderaxespad=0.)

    plt.tight_layout()  # Adjust layout to prevent clipping
    fig.autofmt_xdate()
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
    
    while plt.fignum_exists(fig.number):

        root.ReadAll()
        
        temperatures[0].append(root.EpixQuadMonitor.ShtTemp.get())
        temperatures[1].append(root.EpixQuadMonitor.NctLocTemp.get())
        temperatures[2].append(root.EpixQuadMonitor.NctRemTemp.get())
        temperatures[3].append(root.EpixQuadMonitor.Therm0_Temp.get())
        temperatures[4].append(root.EpixQuadMonitor.Therm1_Temp.get())
        temperatures[5].append(root.EpixQuadMonitor.PwrDigTemp.get())
        temperatures[6].append(root.EpixQuadMonitor.PwrAnaTemp.get())
        temperatures[7].append(root.EpixQuadMonitor.A0_2_5V_H_Temp.get())
        temperatures[8].append(root.EpixQuadMonitor.A0_2_5V_L_Temp.get())
        temperatures[9].append(root.EpixQuadMonitor.A1_2_5V_H_Temp.get())
        temperatures[10].append(root.EpixQuadMonitor.A1_2_5V_L_Temp.get())
        temperatures[11].append(root.EpixQuadMonitor.A2_2_5V_H_Temp.get())
        temperatures[12].append(root.EpixQuadMonitor.A2_2_5V_L_Temp.get())
        temperatures[13].append(root.EpixQuadMonitor.A3_2_5V_H_Temp.get())
        temperatures[14].append(root.EpixQuadMonitor.A3_2_5V_L_Temp.get())
        temperatures[15].append(root.EpixQuadMonitor.D0_2_5V_Temp.get())
        temperatures[16].append(root.EpixQuadMonitor.D1_2_5V_Temp.get())
        temperatures[17].append(root.EpixQuadMonitor.A0_1_8V_Temp.get())
        temperatures[18].append(root.EpixQuadMonitor.A2_1_8V_Temp.get())
        temperatures[19].append(root.EpixQuadMonitor.A2_1_8V_Temp.get())
        temperatures[20].append(root.EpixQuadMonitor.PcbAnaTemp0.get())
        temperatures[21].append(root.EpixQuadMonitor.PcbAnaTemp1.get())
        temperatures[22].append(root.EpixQuadMonitor.PcbAnaTemp2.get())
        temperatures[23].append(root.EpixQuadMonitor.TrOptTemp.get())
        
        timestamps.append(datetime.now())
        
        for i in range(len(sensors)):
            lines[i].set_data(timestamps, temperatures[i])

        ax.relim()
        ax.autoscale_view()
        plt.draw()
        plt.pause(1)  # Pause for 1 second and allow GUI update
            
    plt.show()

