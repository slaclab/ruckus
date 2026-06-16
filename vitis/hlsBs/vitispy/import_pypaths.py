# ------------------------------------------------------------------------------

''' Adds the paths in HLS_PROJECT_PYPATHS to sys.path

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
    paths       = str (os.getenv ('HLS_PROJECT_PYPATHS'))

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
