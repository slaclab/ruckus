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
from types import SimpleNamespace


# --------------------------------------------------------------------------
# GIT
# --------------------------------------------------------------------------
class Git:
    def __init__(self, root):
        import subprocess
        from directory import Directory

        self.repo = None
        script = os.path.join(Directory.sh, 'git.sh')
        cmd = ['sh', script]
        with subprocess.Popen(cmd,
                              cwd=root,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True,
                              bufsize=1) as process:

            for line in process.stdout:
                line = line.strip()
                info = eval(line)

                repo = info['Repo']
                if repo:
                    self.valid = True
                    self.repo = info['Repo']
                    self.tag = info['Tag']
                    self.dirty = info['Dirty']
                    self.branch = info['Branch']
                    self.hash_long = info['HashLong']
                    self.hash_short = info['HashShort']
                    self.hash_msg = info['HashMsg']
                else:
                    self.valid = False
                    self.repo = "None"
                    self.tag = "None"
                    self.dirty = True
                    self.branch = "NonEo"
                    self.hash_long = "None"
                    self.hash_short = "None"
                    self.hash_msg = "None"
                    break

            process.wait()

        self.ns = SimpleNamespace (repo       = self.repo,
                                   tag        = self.tag,
                                   dirty      = self.dirty,
                                   branch     = self.branch,
                                   hash_long  = self.hash_long,
                                   hash_short = self.hash_short,
                                   hash_msg   = self.hash_msg
                                   )
        self.map = {"git" : self.ns}
        return

    def print(self, printer, pad: int, verbose):
        if self.repo is None:
            return

        dirty_msg = "Dirty" if self.dirty else "Clean"
        pm3 = pad - len('Git')
        printer.line(f"Git{' '*pm3}.repo", self.repo)
        printer.line(f"{' '*pad}.branch", self.branch)

        if not self.dirty:
            printer.line(f"{' '*pad}.hash", self.hash_short)
            printer.line(f"{' '*pad}.tag", self.tag)
        else:
            printer.line(f"{' '*pad}.dirty", dirty_msg)

        return
# --------------------------------------------------------------------------
# END: Product.Git
# --------------------------------------------------------------------------
