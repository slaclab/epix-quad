#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Acquire data from epix10ka

:Author: Faisal Abu-Nimeh (abunimeh@slac.stanford.edu)
:Licesnse: https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html
:Date: 20170725
:Style: OpenStack Style Guidelines https://docs.openstack.org/developer/hacking/
:vcs_id: $Id$
"""
import argparse
import ePixFpga as fpga
import logging
import os
import pyrogue.utilities.fileio
import rogue.hardware.pgp
import sys
import time


def main():
    """Routine to acquire data. This uses argparse to get cli params.

    Example script using rogue library.

    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true", help="Show debugging info.")
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

    # set logging based on args
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=myloglevel)

    if args.yml:
        if not os.path.isfile(args.yml[0]):
            logging.error("[%s] yml config file is missing!", args.yml[0])
            sys.exit(1)

    if args.outputfile:
        ofilename = args.outputfile[0]
        if os.path.isfile(args.outputfile[0]):
            logging.warning("[%s] output file already exists, appending...!", args.outputfile[0])
            # sys.exit(1)
    else:
        ofilename = time.strftime("%Y%m%d-%H%M%S") + ".dat"  # default file name

    if args.time[0] <= 0:
        logging.error("duration [%f] must be larger than 0", args.outputfile[0])
        sys.exit(1)

    # Set base
    ePixBoard = pyrogue.Root(name='ePixBoard', description='ePix 10ka Board')

    # open pgpcard file descriptor TODO(abunimeh) verify channels
    pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 0, 0)  # Data & cmds
    pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 0, 1)  # Registers for ePix board
    # pgpVc2 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 0, 2)  # PseudoScope
    # pgpVc3 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 0, 3)  # Monitoring (Slow ADC)
    logging.debug("PGP Card Version: %x" % (pgpVc0.getInfo().version))

    # construct datawriter, cmd, and srp
    dw = pyrogue.utilities.fileio.StreamWriter(name='dataWriter')
    cmd = rogue.protocols.srp.Cmd()  # construct command proto
    srp = rogue.protocols.srp.SrpV0()  # construct register proto

    # connect data, cmd, and srp streamer
    pyrogue.streamConnect(pgpVc0, dw.getChannel(0x1))  # connect pgpvc0 --> file
    pyrogue.streamConnect(cmd, pgpVc0)  # connect cmd --> pgpVc0
    pyrogue.streamConnectBiDir(pgpVc1, srp)  # connect srp <--> pgpVc1

    # add devices to board
    ePixBoard.add(dw)
    ePixBoard.add(fpga.Epix10ka(name='Epix10ka', offset=0, memBase=srp, hidden=False,
                                enabled=True))
    # Good to go
    ePixBoard.start(pollEn=False)

    # command board to read ePix config
    ePixBoard.readConfig(args.yml[0])

    # TODO(abunimeh) verify if matrix is indeed cleared
    ePixBoard.Epix10ka.Epix10kaAsic0.ClearMatrix()  # Clear configuration bits of all pixels
    ePixBoard.dataWriter.dataFile.set(ofilename)  # tell datawriter where to write data

    # start with a clean slate
    ePixBoard.Epix10ka.EpixFpgaRegisters.AcqCountReset.set(1)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AcqCountReset.set(0)
    ePixBoard.Epix10ka.EpixFpgaRegisters.SeqCountReset.set(1)
    ePixBoard.Epix10ka.EpixFpgaRegisters.SeqCountReset.set(0)
    # double down on this auto daq run enable
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(False)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)

    ePixBoard.dataWriter.open.set(True)  # open file
    # acquire data for specific duration
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(True)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(True)
    time.sleep(args.time[0])  # acquisition time
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoDaqEnable.set(False)
    ePixBoard.Epix10ka.EpixFpgaRegisters.AutoRunEnable.set(False)
    ePixBoard.dataWriter.open.set(False)

    ePixBoard.stop()
    logging.info("Done")


if __name__ == "__main__":
    main()
