# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# FPGA
# ------------------------------------------------------------------------------
class Fpga:
    def __init__(self, part, clock, uncertainity, id=None):
        self.part = part
        self.clock = clock
        self.uncertainity = uncertainity
        self.id = id
        return

    @staticmethod
    def add_arguments(parser):  # Fpga
        parser.add_argument('--fpga',          help='fpga part',
                            default='xcku115-flvb2104-2-i')
        parser.add_argument(
            '--clock',         help='fpga clock',      default=6)
        parser.add_argument('--uncertainity',  help='fpga clock uncertainity')
        parser.add_argument(
            '--fid',           help='fpga identifier', default=None)
        return

    # --------------------------------------------------------------------------
    # Add the fpga to the configuration file
    # --------------------------------------------------------------------------
    def add(self, cfg_file):    # Fpga
        cfg_file.set_value(key='part',  value=self.part)
        cfg_file.set_value(section='hls', key='clock', value=self.clock)

        if (self.uncertainity):
            cfg_file.set_value(section='hls', key='clock_uncertainty',
                               value=self.uncertainity)
        return
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # Print the FPGA specification
    # --------------------------------------------------------------------------
    def print(self, printer):  # Fpga
        if (self.uncertainity):
            uncertainity = self.uncertainity
        else:
            uncertainity = "Vitis Default"

        clock = self.clock + '+/-' + uncertainity
        print()
        printer.prefixed_line('Fpga', '.part', self.part)
        printer.prefixed_line('',    '.clock', clock)
        if self.id:
            printer.prefixed_line('', '.id', self.id)
        return

    # ------------------------------------------------------------------------------
    def __str__(self):
        uncertainity = self.uncertainity if self.uncertainity else 'Vitis Default'
        str = self.id + ' => ' + self.part + ' @ ' + self.clock + ' -/+ ' + uncertainity
        return str
    # ------------------------------------------------------------------------------
