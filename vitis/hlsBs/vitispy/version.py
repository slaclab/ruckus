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


class VitisVersion:
    '''
    DESCRIPTION
    Determines the Vitis versioning.

    There are two methods, a fast and slow method.
      1. The slow method launches the vitis --version command
      2. The fast method looks for the version in the XILINX_HLS path

   One might think the the slow method is the approved method to find
   the version in a portable way. This would be true if the command
   did what it said. What is does is return the standard Vitis splash
   banner which then must be parsed.  Since this is just random text
   containing the version (for example, there is nothing like verion =
   2024.1), so there is no guarantee that the text stays the same
   version to version. Looking for version in the XILINX_HLS directory
   path seems no less hokey.

   God, they make it hard to do the right thing.

   RETURNS
   The version is presented as global python variable (Version) and contains
     - Full  version number  2024.2
     - Major version number  2024
     - Minor version number  .2
    '''
    # --------------------------------------------------------------------------
    #

    def __init__(self):
        import re

        found = False

        # ----------------------------------------------------------
        # FAST search -- find the version in the directory path
        # -----------------------------------------------------
        regexpr = r"20[0-9][0-9]\.[0-9]"
        vdir = os.getenv('XILINX_HLS')
        while vdir:
            vdir, full = os.path.split(vdir)
            version = re.search(regexpr, full)
            if version:
                full = version.group()
                self.version = full[0:6]
                self.major = full[0:4]
                self.minor = full[5:6]
                return
        # ----------------------------------------------------------

        # ----------------------------------------------------------
        # SLOW search -- find the version in the Vitis splash banner
        # ----------------------------------------------------------
        import subprocess

        try:
            result = subprocess.run(['vitis', '--version'],
                                    capture_output=True, text=True)

        except FileNotFoundError:
            print("failure")
            return "Vitis not found in PATH"

        else:
            regexpr = r"v20[0-9][0-9]\.[0-9]"
            version = re.search(regexpr, result.stdout)
            full = version.group()
            self.version = full[1:7]
            self.major = full[1:5]
            self.minor = full[6:7]

        return
    # --------------------------------------------------------------------------


Version = VitisVersion()
