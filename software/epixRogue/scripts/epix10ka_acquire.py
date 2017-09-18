#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Acquire data from epix10ka

:Author: Faisal Abu-Nimeh (abunimeh@slac.stanford.edu)
:License: https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html
:Date: 20170725
:Style: OpenStack Style Guidelines https://docs.openstack.org/developer/hacking/
:vcs_id: $Id$
"""
import argparse
import ePixFpga as fpga
import logging
import os
import pyrogue.utilities.fileio
import rogue
import sys
import time


def main():
    """Routine to acquire data. This uses argparse to get cli params.

    Example script using rogue library.

    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true", help="Show debugging info.")
    parser.add_argument("-a", "--asic", nargs=1, type=int, metavar=('value'),
                        help="config ASIC 0..3")
    parser.add_argument("-n", "--nosave", action="store_true", help="Dont save data to disk")
    parser.add_argument("-l", "--linearitytest", action="store_true", help="Enable Test Pulser")
    parser.add_argument("-s", "--setmatrix", nargs=1, metavar=('smat'), type=int,
                        help="Set Matrix config.")
    parser.add_argument("-o", "--outputfile", nargs=1, metavar=('FILE'),
                        help="File name to save acquired data to.")
    parser.add_argument("-y", "--yml", nargs=1, metavar=('YMLFILE'),
                        help="yml config file.", required=True)
    parser.add_argument("-t", "--time", nargs=1, metavar=('DURATION'), type=float,
                        help="total acquisition time.", required=True)
    args = parser.parse_args()

    if args.verbose:
        myloglevel = logging.DEBUG
    else:
        myloglevel = logging.INFO
    # create own logger, rogue hijacks default logger
    acq_log = logging.getLogger("epix10ka.acquirelog")
    acq_log.setLevel(myloglevel)
    # logging.getLogger('pyrogue').setLevel(logging.DEBUG)

    if args.asic:
        asic = args.asic[0] % 4
        acq_log.info("Config ASIC %d" % (asic))
    else:
        asic = 0
        acq_log.info("[DEFAULT] Config ASIC 0")

    if args.yml:
        if not os.path.isfile(args.yml[0]):
            acq_log.error("[%s] yml config file is missing!", args.yml[0])
            sys.exit(1)

    if args.outputfile:
        ofilename = args.outputfile[0]
        if os.path.isfile(args.outputfile[0]):
            acq_log.warning("[%s] output file already exists, appending...!", args.outputfile[0])
    else:
        ofilename = time.strftime("%Y%m%d-%H%M%S") + ".dat"  # default file name

    if args.time[0] <= 0:
        acq_log.error("duration [%f] must be larger than 0", args.outputfile[0])
        sys.exit(1)

    # Set base
    board = pyrogue.Root(name='ePixBoard', description='ePix 10ka Board')

    # open pgpcard file descriptor
    pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 1, 0)  # Data & cmds
    pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 1, 1)  # Registers for ePix board
    acq_log.debug("PGP Card Version: %x" % (pgpVc0.getInfo().version))

    # config path
    srp = rogue.protocols.srp.SrpV0()  # construct register proto
    pyrogue.streamConnectBiDir(pgpVc1, srp)  # connect srp <--> pgpVc1

    # data path
    dw = pyrogue.utilities.fileio.StreamWriter(name='dataWriter')
    pyrogue.streamConnect(pgpVc0, dw.getChannel(0x1))  # connect pgpvc0 --> file

    # add devices to board
    board.add(dw)
    board.add(fpga.Epix10ka(name='Epix10ka', offset=0, memBase=srp, enabled=True))

    board.start(pollEn=False)

    # command board to read ePix config
    board.readConfig(args.yml[0])
    targetASIC = getattr(board.Epix10ka, 'Epix10kaAsic' + str(asic))

    if args.asic:
        if args.setmatrix:
            # targetASIC.PrepareMultiConfig()
            targetASIC._rawWrite(0x00008000*4, 0)
            # targetASIC.WriteMatrixData.set(args.setmatrix[0])
            targetASIC._rawWrite(0x00004000*4, args.setmatrix[0])
            acq_log.info("Set Matrix to %d" % (args.setmatrix[0]))

        # targetASIC.CmdPrepForRead()
        targetASIC._rawWrite(0, 0)
        acq_log.debug("Sent ASIC%d CmdPrepForRead()" % (args.asic[0]))
    else:
        if args.setmatrix:
            mset = args.setmatrix[0] & 0xF  # value is only 4 bits
            # board.Epix10ka.Epix10kaAsic0.PrepareMultiConfig()
            board.Epix10ka.Epix10kaAsic0._rawWrite(0x00008000*4, 0)
            # board.Epix10ka.Epix10kaAsic0.WriteMatrixData.set(args.setmatrix[0])
            board.Epix10ka.Epix10kaAsic0.WriteMatrixData._rawWrite(0x00004000*4, mset)
            acq_log.info("A0 Set Matrix to %d" % (args.setmatrix[0]))
            # board.Epix10ka.Epix10kaAsic1.PrepareMultiConfig()
            board.Epix10ka.Epix10kaAsic1._rawWrite(0x00008000*4, 0)
            # board.Epix10ka.Epix10kaAsic1.WriteMatrixData.set(args.setmatrix[0])
            board.Epix10ka.Epix10kaAsic1.WriteMatrixData._rawWrite(0x00004000*4, mset)
            acq_log.info("A1 Set Matrix to %d" % (args.setmatrix[0]))
            # board.Epix10ka.Epix10kaAsic2.PrepareMultiConfig()
            board.Epix10ka.Epix10kaAsic2._rawWrite(0x00008000*4, 0)
            # board.Epix10ka.Epix10kaAsic2.WriteMatrixData.set(args.setmatrix[0])
            board.Epix10ka.Epix10kaAsic2.WriteMatrixData._rawWrite(0x00004000*4, mset)
            acq_log.info("A2 Set Matrix to %d" % (args.setmatrix[0]))
            # board.Epix10ka.Epix10kaAsic3.PrepareMultiConfig()
            board.Epix10ka.Epix10kaAsic3._rawWrite(0x00008000*4, 0)
            # board.Epix10ka.Epix10kaAsic3.WriteMatrixData.set(args.setmatrix[0])
            board.Epix10ka.Epix10kaAsic3.WriteMatrixData._rawWrite(0x00004000*4, mset)
            acq_log.info("A3 Set Matrix to %d" % (args.setmatrix[0]))
        # board.Epix10ka.Epix10kaAsic0.CmdPrepForRead()
        # board.Epix10ka.Epix10kaAsic1.CmdPrepForRead()
        # board.Epix10ka.Epix10kaAsic2.CmdPrepForRead()
        # board.Epix10ka.Epix10kaAsic3.CmdPrepForRead()
        board.Epix10ka.Epix10kaAsic0._rawWrite(0, 0)
        board.Epix10ka.Epix10kaAsic1._rawWrite(0, 0)
        board.Epix10ka.Epix10kaAsic2._rawWrite(0, 0)
        board.Epix10ka.Epix10kaAsic3._rawWrite(0, 0)
        acq_log.debug("Sent ASICs CmdPrepForRead()")

    board.dataWriter.dataFile.set(ofilename)  # tell datawriter where to write data

    # enable test bits if we are doing linearity tests
    if args.linearitytest and args.asic:
        targetASIC.test.set(True)
        targetASIC.atest.set(True)
        acq_log.info("Enable Test Bits")

    acq_log.info("Finished configuration. Acquiring data ...")
    # start with a clean slate
    board.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(False)
    board.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
    board.Epix10ka.EpixFpgaRegisters.AcqCountReset.set(1)
    board.Epix10ka.EpixFpgaRegisters.AcqCountReset.set(0)
    board.Epix10ka.EpixFpgaRegisters.SeqCountReset.set(1)
    board.Epix10ka.EpixFpgaRegisters.SeqCountReset.set(0)
    if not args.nosave:
        board.dataWriter.open.set(True)  # open file
    else:
        acq_log.info("won't save to disk")
    # acquire data for specific duration
    board.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(True)
    board.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
    if args.linearitytest and args.asic:
        time.sleep(0.5)
        targetASIC.PulserR.post(True)
        time.sleep(0.5)
        targetASIC.PulserR.post(False)
        acq_log.info("Test Pulse Sent")

    time.sleep(args.time[0])  # acquisition time
    acq_log.info("Flushing...")
    board.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(False)
    board.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
    if not args.nosave:
        board.dataWriter.open.set(False)

    board.stop()
    acq_log.info("Done")

if __name__ == "__main__":
    main()
