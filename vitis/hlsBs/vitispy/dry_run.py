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


class DryRun:

    def __init__(self, dry_run):
        self.dry_run = dry_run
        return

    @staticmethod
    def add_arguments(parser):
        parser.add_argument(
            '--dry-run',
            help='Just list the actions',
            action='store_true',
            default=False,
            dest='dry_run')
        return

    def __bool__(self):
        return self.dry_run

    def print(self, printer):
        if self.dry_run:
            printer.line('Dry run', str(self.dry_run) + "   <--- Note")
        return

    dry_run: bool
