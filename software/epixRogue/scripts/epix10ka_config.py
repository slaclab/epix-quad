#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Configure/Dump ePix10ka pixels/matrix

:Author: Faisal Abu-Nimeh (abunimeh@slac.stanford.edu)
:License: https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html
:Date: 20170816
:Style: OpenStack Style Guidelines https://docs.openstack.org/developer/hacking/
:vcs_id: $Id$
"""
import argparse
import csv
import ePixFpga as fpga
import logging
import pyrogue.utilities.fileio
import rogue

EPIX10KAROWS = 178
EPIX10KACOLS = 192
EPIX10KABNKS = 4
EPIX10KACOLSPBNK = EPIX10KACOLS // EPIX10KABNKS


class ePixBoard(pyrogue.Root):
    """The ePixBoard Class. A pyrogue Root subclass."""

    def __enter__(self):
        """Root enter."""
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """Root exit."""
        super().stop()

    def __init__(self):
        """Initialize me."""
        super().__init__(name='ePixBoard', description='ePix 10ka Board')

        pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0', 0, 1)  # Registers for ePix board
        srp = rogue.protocols.srp.SrpV0()  # construct register proto
        pyrogue.streamConnectBiDir(pgpVc1, srp)  # connect srp <--> pgpVc1
        # logging.getLogger('pyrogue').setLevel(logging.DEBUG)

        # add devices to board
        self.add(fpga.Epix10ka(name='Epix10ka', offset=0, memBase=srp, enabled=True))
        self.add(pyrogue.RunControl(name='runControl', rates={1: '1 Hz', 10: '10 Hz', 30: '30 Hz'}))
        self.add(pyrogue.utilities.fileio.StreamWriter(name='dataWriter'))

        self.start()


def main():
    """Routine to config epix matrix. This uses argparse to get cli params.

    Simple script using rogue library.

    Example execution:
        # Dump entire matrix config
        $ ./scripts/epix10a_config.py -y yml/config.yml -d

        # configure pixel row=10 column= 131 to 0011
        $ ./scripts/epix10a_config.py -y yml/config.yml -p 10 131 -s 3

        # set entire matrix configuration to 0000
        $ ./scripts/epix10a_config.py -y yml/config.yml -m 0
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true", help="Show debugging info")
    parser.add_argument("-d", "--dumpmatrix", action="store_true", help="dump matrix config to csv")
    parser.add_argument("-r", "--setrow", nargs=2, type=int, metavar=('row', 'value'),
                        help="set row to value")
    parser.add_argument("-c", "--setcol", nargs=2, type=int, metavar=('col', 'value'),
                        help="set column to value")
    parser.add_argument("-m", "--setmatrix", nargs=1, type=int, metavar=('value'),
                        help="set entire matrix to value")
    parser.add_argument("-a", "--asic", nargs=1, type=int, metavar=('value'),
                        help="config ASIC 0..3")
    parser.add_argument("-s", "--setpixel", nargs=1, type=int, metavar=('value'),
                        help="config value to single pixel")
    parser.add_argument("-p", "--pixel", nargs=2, type=int, metavar=('row', 'col'),
                        help="pixel location")
    parser.add_argument("-y", "--yml", nargs=1, metavar=('YMLFILE'),
                        help="yml config file.")
    parser.add_argument("-w", "--write", nargs=1, metavar=('YMLFILE'),
                        help="dump yml config for all ASICs.")
    args = parser.parse_args()

    # set logging level
    if args.verbose:
        myloglevel = logging.DEBUG
    else:
        myloglevel = logging.INFO
    # create own logger, rogue hijacks default logger
    conf_log = logging.getLogger("epix10ka.conflog")
    conf_log.setLevel(myloglevel)

    # we can either dump the current config in all asics or set a new config
    if args.write:
        with ePixBoard() as board:
            # dump all configs regardless if ASICs are physically present or not
            board.Epix10ka.Epix10kaAsic0.enable.set(True)
            board.Epix10ka.Epix10kaAsic1.enable.set(True)
            board.Epix10ka.Epix10kaAsic2.enable.set(True)
            board.Epix10ka.Epix10kaAsic3.enable.set(True)
            board.writeConfig(args.write[0])
            conf_log.info("YML config dumped to [%s]", args.write[0])
            return 0
    else:
        # if we are configuring a new YML then check if it exist
        if args.yml:
            try:
                with open(args.yml[0]):
                    pass
            except IOError as e:
                conf_log.error("cannot open yaml config file [%s]", args.yml[0])
                return 1
        else:
            conf_log.error("YML config file is required.")
            parser.print_help()
            return 1

    if args.asic:
        # we will always have a valid ASIC number regardless of what the user inputs
        asic = args.asic[0] % 4
        conf_log.info("Config ASIC %d" % (asic))
    else:
        asic = 0  # default to asic 0 if user doesn't care
        conf_log.info("[DEFAULT] Config ASIC 0")

    with ePixBoard() as board:
        # demand the FPGA to read the YML and config itself
        board.readConfig(args.yml[0])
        # figure out which ASIC the user wants us to configure
        targetASIC = getattr(board.Epix10ka, 'Epix10kaAsic' + str(asic))

        # set entire matrix to a certain value
        if args.setmatrix:
            mset = args.setmatrix[0] & 0xF  # value is only 4 bits
            # targetASIC.PrepareMultiConfig()
            targetASIC._rawWrite(0x00008000*4, 0)
            # targetASIC.WriteMatrixData.set(mset)
            targetASIC._rawWrite(0x00004000*4, mset)
            conf_log.debug("Pixel Matrix is set to 0x%x" % (mset))

        # set entire row to a certain value
        if args.setrow:
            row = args.setrow[0] % EPIX10KAROWS  # wrap values in case they are invalid
            rset = args.setrow[1] & 0xF  # value is only 4 bits
            # targetASIC.PrepareMultiConfig()
            targetASIC._rawWrite(0x00008000*4, 0)
            # targetASIC.RowCounter.set(row)
            targetASIC._rawWrite(0x00006011*4, row)
            # targetASIC.WriteRowData.set(rset)
            targetASIC._rawWrite(0x00002000*4, rset)
            conf_log.debug("row %d is set to 0x%x" % (row, rset))

        # set entire column to a certain value
        if args.setcol:
            col = args.setcol[0] % EPIX10KAROWS  # wrap values in case they are invalid
            cset = args.setcol[1] & 0xF  # value is only 4 bits
            bcol = getbcol(col)  # get column word
            # targetASIC.PrepareMultiConfig()
            targetASIC._rawWrite(0x00008000*4, 0)
            # targetASIC.ColCounter.set(bcol)
            targetASIC._rawWrite(0x00006013*4, bcol)
            targetASIC.WriteColData.set(cset)
            conf_log.debug("row %d is set to 0x%x" % (col, cset))

        # set/get single pixel
        if args.pixel:
            row = args.pixel[0] % EPIX10KAROWS  # wrap values in case they are invalid
            col = args.pixel[1] % EPIX10KACOLS  # wrap values in case they are invalid
            bcol = getbcol(col)  # get column word

            # targetASIC.PrepareMultiConfig()
            targetASIC._rawWrite(0x00008000*4, 0)
            # targetASIC.RowCounter.set(row)
            targetASIC._rawWrite(0x00006011*4, row)
            # targetASIC.ColCounter.set(bcol)
            targetASIC._rawWrite(0x00006013*4, bcol)

            if args.setpixel:  # write pixel config
                config = args.setpixel[0] & 0xF  # value is only 4 bits
                # targetASIC.WritePixelData.set(config)
                targetASIC._rawWrite(0x00005000*4, config)
                conf_log.info("(%d,%d) set value: 0x%x" % (row, col, config))
                conf_log.debug("bcol: 0x%x" % (bcol))
            else:  # read pixel config
                # config = targetASIC.WritePixelData.get()
                config = targetASIC._rawRead(0x00005000*4)
                conf_log.info("(%d,%d) got value: 0x%x" % (row, col, config))
                conf_log.debug("bcol: 0x%x" % (bcol))

        # dump matrix to csv file
        if args.dumpmatrix:
            # create zero matrix, size = rows x columns
            configmatrix = [[0 for x in range(EPIX10KACOLS)] for y in range(EPIX10KAROWS)]
            conf_log.info("dumping entire matrix config...")
            # targetASIC.PrepareMultiConfig()
            targetASIC._rawWrite(0x00008000*4, 0)
            for c in range(EPIX10KACOLS):  # loop column
                ibcol = getbcol(c)  # get column word
                for r in range(EPIX10KAROWS):  # loop row
                    # go thru pixel read sequence
                    # targetASIC.RowCounter.set(r)
                    targetASIC._rawWrite(0x00006011*4, r)
                    # targetASIC.ColCounter.set(ibcol)
                    targetASIC._rawWrite(0x00006013*4, ibcol)
                    # configmatrix[r][c] = targetASIC.WritePixelData.get()
                    configmatrix[r][c] = targetASIC._rawRead(0x00005000*4)
            # write matrix to csv file
            try:
                with open('matrixdump.csv', 'w') as mycsvfile:
                    wr = csv.writer(mycsvfile)
                    wr.writerows(configmatrix)
            except IOError as e:
                conf_log.error("cannot dump to csv file")
                return 1


def getbcol(col=0):
    """Routine to convert human column number to single epix10ka bank+column bits."""
    # D_C_B_A_C6_C5_..._C0
    # C6..C0 is a 7-bit column addr in bank, i.e., 0..47 for epix10ka
    # letters A..D disable bank

    # figure out which bank we're in
    bank = col // EPIX10KACOLSPBNK

    if bank == 1:
        bcol = 0x680 + col % EPIX10KACOLSPBNK
    elif bank == 2:
        bcol = 0x580 + col % EPIX10KACOLSPBNK
    elif bank == 3:
        bcol = 0x380 + col % EPIX10KACOLSPBNK
    else:
        bcol = 0x700 + col % EPIX10KACOLSPBNK  # default is bank0

    return bcol


if __name__ == "__main__":
    main()
