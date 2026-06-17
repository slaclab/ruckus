#! /usr/bin/python3

# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import sys
import os
import json

# -----------------------------------------------------------------------------
component_path = sys.argv[1]

#print (f"\n\nPython: Component_path = {component_path}")
vitis_comp_path = os.path.join (component_path, 'vitis-comp.json')
#print (f"Python:  Vitis_comp_path = {vitis_comp_path}")
try:
    with open(vitis_comp_path, 'r') as f:
        data = json.load(f)

    cfgs = data['configuration']['configFiles']
    cfg  = cfgs[0]

    # Starting at 2025.1, if directory is not included if the configuration file
    # is in component path, so check if the cfg has a directory, if not paste one on.

    if (os.path.isabs (cfg) != True) :
#    cfg_dir = os.path.dirname (cfg)
#    if (len (cfg_dir) == 0) :
        cfg = os.path.join (component_path, cfg)

    print(f"{cfg}")

except FileNotFoundError:
    print(f"Error: The file '{vitis_comp_path}' was not found.")
except json.JSONDecodeError as e:
    print(f"Error decoding JSON from '{vitis_comp_path}': {e}")
except Exception as e:
    print(f"An unexpected error occurred: {e}")
