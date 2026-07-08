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
'''
    Adds the paths in HLSBS_PYPATHS to sys.path

    This acts to make a consistent interface for the various AMD/XILINX VITIS
    HLS releases.  As a public service, non-existent path names are filtered
    from the sys.path.  WARNING: This could be an issue if these are created
    on the fly.
'''
# ------------------------------------------------------------------------------

import sys
import os

# ------------------------------------------------------------------------------
idx     = __name__.find (' ')
name    = __name__[0:idx]      # Name of function to perform

if name == 'add_paths' :

    spaths = __name__[idx+1:] # String representation of the paths
    known  = eval (spaths)

    # --------------------------------------------------------
    # Get the colon separated paths which is presented as list
    # --------------------------------------------------------
    paths       = str (os.getenv ('HLSBS_PYPATHS'))

    # ---------------------------------------------------------------
    # Convert the string representation of the list to an actual list
    # ---------------------------------------------------------------
    pythonpaths = eval (paths)

    # ------------------------------------------
    # Change the colon seperated paths to a list
    # ------------------------------------------
    pypaths   = pythonpaths[0][1].split (':')

    # -------------------------
    # Filter non-existent paths
    # -------------------------
    sys_path = []
    for pypath in sys.path :
        if os.path.exists (pypath) :
            sys_path.append (pypath)
        else  :
            pass
    sys.path = sys_path

    # --------------------
    # Add in any new paths
    # --------------------
    for pypath in pypaths :

        # Reject if non-existent
        if not os.path.exists (pypath) : continue

        # Add if not already there
        if pypath not in sys.path :
            sys.path.append(pypath)
        else :
            pass

# ------------------------------------------------------------------------------
