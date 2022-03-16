#!/usr/bin/env python3
# ----------------------------------------------------------------------------
# Description:
#   Script to convert the .bin file from opalkelly
#   into a .txt file for DM160237 I2C Evaluation Kit GUI
# ----------------------------------------------------------------------------
# https://opalkelly.com/tools/fmceepromgenerator/
# https://www.microchip.com/en-us/development-tool/DM160237
# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import argparse

from array import array

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

parser.add_argument(
    "--bin",
    type     = str,
    required = True,
    help     = "path to .bin file",
)

parser.add_argument(
    "--txt",
    type     = str,
    required = True,
    help     = "path to .txt file",
)

# Get the arguments
args = parser.parse_args()

#################################################################

if __name__ == '__main__':

    # Load the FRU binary file into python array
    data = array('B')
    with open(args.bin, 'rb') as f:
        data.fromfile(f, 256)

    # Write the loaded data into a text file
    ofd = open(args.txt, 'w')
    for i in range(len(data)):
        byte = hex(data[i]).upper()[2:].zfill(2)
        ofd.write(byte)
        if (i%8==7):
            ofd.write('\n')
    ofd.close()
