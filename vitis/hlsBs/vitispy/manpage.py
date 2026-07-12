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
import subprocess


def display_manpage(cmd_path):

    cmd_dirnam = os.path.splitext(cmd_path)[0]
    cmd_dir, cmd_nam = os.path.split(cmd_dirnam)
    man_nam = cmd_nam + '.1'
    cmd_dir = os.path.join(os.path.split(cmd_dir)[0], 'man1')
    man_path = os.path.join(cmd_dir, man_nam)

    try:
        subprocess.run(['man', man_path])
    except Exception:
        pass
        # print (f"'man' command {cmd_nam} not found", file=sys.stderr)
