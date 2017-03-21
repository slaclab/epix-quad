import sys
import os.path
import time
import pyrogue
import rogue.utilities
import rogue.utilities.fileio

import coulter

reader = rogue.utilities.fileio.StreamReader()
parser = coulter.CoulterFrameParser()

pyrogue.streamConnect(reader, parser)

def main(args):
    reader.open(args[1])
    print('opened', args[1])
    reader.closeWait()
    print('closed', args[1])
    outfile = os.path.basename(args[1])
    parser.noise(outfile)

if __name__ == "__main__":
    main(sys.argv)
