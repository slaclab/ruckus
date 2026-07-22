# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import os.path
import importlib.util
from importlib.machinery import SourceFileLoader

# ------------------------------------------------------------------------------
# File to be imported as a module
# ------------------------------------------------------------------------------


class ImportFile:
    def __init__(self, file):

        self.file_path = os.path.expandvars(file)
        self.module_name = os.path.splitext(
            os.path.split(self.file_path)[1])[0]

        # ------------------------------------------------------
        # Manually create a custum loader for this specific file
        # This allows arbitray file extensions
        # ------------------------------------------------------
        loader = SourceFileLoader(self.module_name, self.file_path)

        # Create the module spec from this loader directly
        self.spec = importlib.util.spec_from_loader(self.module_name, loader)

        return

    def add(self):
        self.module = importlib.util.module_from_spec(self.spec)
        return

    def load(self):
        self.spec.loader.exec_module(self.module)
# ------------------------------------------------------------------------------
