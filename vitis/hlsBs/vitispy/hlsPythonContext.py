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
    Extracts the Vits HLS python run-time environment/context in an attempt
    to make the scripts execute uniformily across all VITIS versions > 2024.1

    Args:
      action:  'get'

    Action
      Launches vitis -s this script with a 'set' as a command line parameter.
      This same script is then run within the VITIS HLS runtime environment where
      it extracts the VITIS HLS runtime context.

      It returns a string of 2 bash shell semi-colon separate commands that
      sets 2 environment variables
         hlsPython          : Used as python interpreter for the selected
                              VITIS version
         HLS_PROJECT_IMPORT_PYPATHS: Used internally by the python scripts
                            to set the PYTHONPATH and LD_LIBRARY_PATH

     This string can then be used to set these environment variables in the
     calling bash shell:
         eval `python $RUCKUS_ROOT/<install_dir>/hlsPythonContext get
'''
# ------------------------------------------------------------------------------


import sys
import os
import subprocess


#------------------------------------------------------------------------------
# Dispatch to 'get' processing
# ----------------------------
if sys.argv[1] == 'get' :

    # ----------------------------------------------------------------------------
    # Relaunch this script, only this time running within the VITIS PYTHON context
    # ----------------------------------------------------------------------------
    script = os.path.realpath (__file__)
    result = subprocess.run (['vitis',
                              '-s',
                              __file__,
                              'extract'], capture_output=True, text=True)

    # -------------------------------------------------------------------
    # Filter out the VITIS PYTHON banner by locating the 'export' command
    # and return the export commands to the calling bash shell
    # -----------------------------------------------------------------
    out = result.stdout.find ('export')
    print (result.stdout[out:])
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Extract the VITIS PYTHON runtime environment
# --------------------------------------------
elif sys.argv[1] == 'extract' :

    pypaths = "\'"
    vitis_root_vitispy = os.path.realpath (os.path.split (__file__)[0])
    vitis_root         = os.path.split (vitis_root_vitispy)[0]

    for pypath in sys.path :
        if pypath == vitis_root_vitispy : pypaths += vitis_root + ':'
        else                            : pypaths += pypath     + ':'
    pypaths += "\'"


    ld_library_path = os.getenv ('LD_LIBRARY_PATH')
    if ld_library_path is None : ld_library_path = ''
    else                       : ld_library_path = "\'" + ld_library_path + "\'"
    paths  = ("\"[ ['PYTHONPATH'," + pypaths + "]  ]\"")

    import_pypaths = os.path.realpath (os.path.join (vitis_root_vitispy, 'import_pypaths.py'))

    # Format the exported python intepreter and python paths
    output = ("export hlsPython="                   + sys.executable  + '; '
           +  "export HLS_PROJECT_LD_LIBRARY_PATH=" + ld_library_path + '; '
           +  "export HLS_PROJECT_IMPORT_PYPATHS="  + import_pypaths  + '; '
           +  "export HLS_PROJECT_PYPATHS="         + paths)

    print (output)
# -------------------------------------------------------------------------------
