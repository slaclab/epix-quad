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
import time

from scipy import stats
#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Convert str to bool
def argBool(s):
    return s.lower() in ['true', 't', 'yes', '1']



parser.add_argument(
    "--yml",
    type=str,
    required=False,
    default='',
    help="Configuration file",
)

parser.add_argument(
    "--bitmask",
    type=str,
    required=True,
    default='',
    help="Pixel bitmap file",
)

parser.add_argument(
    "--inj",
    type=str,
    required=True,
    default='t',
    help="Flash bitmap",
)

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

#appTop = pr.gui.application(sys.argv)

# Set base
with quad.Top(
    hwType='datadev',
    dev=args.dev,
    lane=args.l,
    promWrEn=False,
) as root:
#     pyrogue.waitCntrlC()
    
    # Step 0 : Init camera reader
    cameraReader = quad.CameraReader(cameraType='ePixQuad', refreshRate = 0.1)
    cameraReader.currentCam.bitMask = 0x3fff
    
    cameraReader << root.pgpVc0
    
    # Step 1 : Load the config (yml file)
    root.ReadAll()
    
    if args.yml is not None:
        try:
            root.LoadConfig(args.yml)
        except Exception as e:
            print('[Error] Config loading failed')
            exit(-1)
            
        root.ReadAll()
        print('[Done] Configuration loaded')
    else:
        print('[Warning] No YML file to load')
    
    # Step 2 : Disable trigger 
    root.SystemRegs.TrigEn.set(False)
    
    # Step 3 : Load pixelBitmap (banks file) and prepare for charge injection
    chargeInjTemplate = np.loadtxt(args.bitmask, delimiter=",", dtype=np.float32)
    chargeInjData = np.zeros((cameraReader.currentCam.sensorHeight, cameraReader.currentCam.sensorWidth), dtype=np.float32)
    
    asicWidth = len(chargeInjTemplate[0])
    asicHeight = len(chargeInjTemplate)
    
    positions = [
        (0, asicHeight, 0, asicWidth, True), 
        (0, asicHeight, asicWidth, 2*asicWidth, True), 
        (asicHeight, 2*asicHeight, 0, asicWidth, False), 
        (asicHeight, 2*asicHeight, asicWidth, 2*asicWidth, False),
        
        (0, asicHeight, 2*asicWidth, 3*asicWidth, True), 
        (0, asicHeight, 3*asicWidth, 4*asicWidth, True), 
        (asicHeight, 2*asicHeight, 2*asicWidth, 3*asicWidth, False), 
        (asicHeight, 2*asicHeight, 3*asicWidth, 4*asicWidth, False),
        
        (2*asicHeight, 3*asicHeight, 0, asicWidth, True), 
        (2*asicHeight, 3*asicHeight, asicWidth, 2*asicWidth, True), 
        (3*asicHeight, 4*asicHeight, 0, asicWidth, False), 
        (3*asicHeight, 4*asicHeight, asicWidth, 2*asicWidth, False),
        
        (2*asicHeight, 3*asicHeight, 2*asicWidth, 3*asicWidth, True), 
        (2*asicHeight, 3*asicHeight, 3*asicWidth, 4*asicWidth, True), 
        (3*asicHeight, 4*asicHeight, 2*asicWidth, 3*asicWidth, False), 
        (3*asicHeight, 4*asicHeight, 3*asicWidth, 4*asicWidth, False),
    ]
    
    for i in range(16):
        if root.Epix10kaSaci[i].enable.get():
            pulser = root.Epix10kaSaci[i].Pulser.get()
            chargeInjTemplate_scaled = np.copy(chargeInjTemplate)
        
            r_start, r_end, c_start, c_end, flip = positions[i]
            img = np.flipud(np.fliplr(chargeInjTemplate_scaled)) if flip else chargeInjTemplate_scaled
            chargeInjData[r_start:r_end, c_start:c_end] = img
    
            if argBool(args.inj):
                root.Epix10kaSaci[i].SetPixelBitmap(args.bitmask)
        
    # Step 4 : Enable trigger
    root.SystemRegs.TrigEn.set(True)
    
    # Step 5 : Initialize matplot viewer
    plt.ion() 
    fig, ax = plt.subplots()
    data = np.random.randint(0, 10, (10, 10))  # Initial 2D array
    im = ax.imshow(data, cmap='gray', interpolation='nearest')
    plt.colorbar(im)
    
    # Step 6 : scan ADC pipeline delay's values
    #    - Set ADC pipeline
    #    - Set dark
    #    - Calibrate pulser (measure pulser to ADC tranfert function by scanning pulser settings)
    #    - Extract pulser settings(per ASICs) and compute the injection template (+ remove ASIC fake rows)
    #    - Compute template - camera's image and extract data (number of wrong pixel, ADU delta)
    
    outcome = {'delay': [], 'badPixels': [], 'maxDev': [], 'minDev': [], 'devAmp': []}
    
    for adcPipeline in range(0x30, 0x50):
            
        #Set ADC Pipeline
        v = 0xaaaa0000 + adcPipeline
        root.RdoutCore.AdcPipelineDelay.set(v)
        
        #Set dark
        for i in range(16):
            root.Epix10kaSaci[i].test.set(False)
        
        cameraReader.darkRequest = True
        while cameraReader.darkRequest:
            time.sleep(0.1)

        for i in range(16):
            root.Epix10kaSaci[i].test.set(True)
        
        #Initialize pulser
        pulser = 20
        for i in range(16):
            root.Epix10kaSaci[i].Pulser.set(pulser)
        
        #Wait for new image
        imgts = cameraReader.imgts
        while imgts == cameraReader.imgts:
            continue
            
        asics = [{'x': [], 'y': []} for _ in range(16)]
        pulser = 0
    
        while pulser < 30:
            
            if cameraReader.img is not None:
                d = np.array(cameraReader.img)
            
                for i in range(16):
                    r_start, r_end, c_start, c_end, flip = positions[i]
                    highest = d[r_start:r_end, c_start:c_end].max()
                    asics[i]['x'].append(pulser)
                    asics[i]['y'].append(highest)
                    
                pulser = pulser + 1
                for i in range(16):
                    root.Epix10kaSaci[i].Pulser.set(pulser)
                
            #Wait for new image
            imgts = cameraReader.imgts
            while imgts == cameraReader.imgts:
                continue
            
        print('Measurement for {}'.format(adcPipeline))
        template = np.zeros((cameraReader.currentCam.sensorHeight, cameraReader.currentCam.sensorWidth), dtype=np.float32)
            
        for i in range(16):
            # Extract x and y from the dictionary
            x = np.array(asics[i]['x'])
            y = np.array(asics[i]['y'])

            # Perform linear regression
            slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)
            #print(f"    [{i}] Linear function: y = {slope:.2f}x + {intercept:.2f}")
                
            r_start, r_end, c_start, c_end, flip = positions[i]
            template[r_start:r_end, c_start:c_end] = chargeInjData[r_start:r_end, c_start:c_end] * (slope * pulser + intercept)
        
        # Remove ASIC fake rows
        template[0][:] = 0
        template[1][:] = 0
        template[354][:] = 0
        template[355][:] = 0
        
        delta = template - d
        
        h = np.max(delta)
        count = np.count_nonzero(delta > 400)
        
        delta[delta > 400] = 0
            
        print("    Pixel deviation: min({}), max({}), std({})".format(np.min(delta), np.max(delta), np.std(delta)))
        print("    Number of bad pixels: {}".format(count))
    
        outcome['delay'].append(adcPipeline)
        outcome['badPixels'].append(count)
        outcome['maxDev'].append(np.max(delta))
        outcome['minDev'].append(np.min(delta))
        outcome['devAmp'].append(np.max(delta) - np.min(delta))
            
        im.set_data(np.abs(delta))
        im.set_clim(vmin=0, vmax=400)
        plt.draw()
        plt.pause(0.1)
            
    plt.ioff()  
    plt.show()
    
    # Step 7 : 
    min_bad_pixels = np.min(outcome['badPixels'])
    colors = ['red' if bp > min_bad_pixels else 'green' for bp in outcome['badPixels']]
    plt.scatter(outcome['delay'], outcome['devAmp'], c=colors, edgecolors='black')

    # Labels and title
    plt.xlabel('ADC Pipeline delay (unit)')
    plt.ylabel('Pixel deviation from template')
    plt.title('ADC calibration')

    # Show plot
    plt.show()

