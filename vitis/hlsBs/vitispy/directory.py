# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import os

# ------------------------------------------------------------------------------
class HlsDirectory :
    '''
    DESCRIPTION
    Captures the names of various sub directories
    '''
    def __init__ (self, file) :
        self.root = os.path.split (os.path.split (file)[0])[0]
        self.cfg  = os.path.join  (self.root, 'cfg')
        self.tcl  = os.path.join  (self.root, 'tcl')
        self.sh   = os.path.join  (self.root,  'sh')
        return

    def __str__ (self) :
        return (f"Directory.root  = {self.root}\n" +
                f"         .cfg   = {self.cfg}\n"  +
                f"         .tcl   = {self.tcl}\n"  +
                f"         .sh    = {self.sh}\n")
# ------------------------------------------------------------------------------

Directory = HlsDirectory (__file__)
