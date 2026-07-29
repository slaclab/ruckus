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
import sys
from pathlib import Path
import shutil
import vitispy.files

# -------------------------------------------------------------------------------


class Workspace:
    @staticmethod
    def set(client, ws):

        try:
            client.set_workspace(path=ws)

        except Exception as e:
            print(f"\n{'='*78}\n"
                  f"Error: In setting the workspace\n"
                  f"       {ws}\n\n"
                  f"       Almost invariably this is due to a bug in the Vitis Python code when\n"
                  f"       another server, commonly the IDE, is attached to the same workspace.\n\n"
                  f"Suggested Actions:\n"
                  f"       1. Kill the IDE or whatever is running the other server.\n"
                  f"       2. Set  the IDE to a different workspace.\n"
                  f"          -- Merely closing the workspace appears to be insufficient.\n"
                  f"       3. Wait till Xilinx/AMD fixes it (not recommended).\n"
                  f"{'='*78}\n")

            sys.exit()

        return

    @staticmethod
    def get(workspace_template):
        wsx = os.path.expandvars(workspace_template)
        ws = str(Path(vitispy.files.add_version(wsx)).resolve())
        return ws

    @staticmethod
    def create(client, ws):
        client.set_workspace(ws)
        return

    @staticmethod
    def remove(ws):
        shutil.rmtree(ws)
        return

    @staticmethod
    def replace(client, ws):
        Workspace.remove(ws)
        Workspace.create(client, ws)

    @staticmethod
    def exists(ws):
        return os.path.exists(ws)

    @staticmethod
    def add_arguments(parser):
        parser.add_argument('--workspace',
                            default=None,
                            help='Workspace directory')

        parser.add_argument('--build-root',
                            default=None,
                            dest='build_root',
                            help='Build root directory')

        return
# -------------------------------------------------------------------------------
