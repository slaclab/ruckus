# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

class Printer:
    def __init__(self, n=20, s=78, i=15, p=7):
        self.s = s
        self.n = n
        self.i = i
        self.p = p
        self.m = 3
        return

    def separator(self, c, n=None):
        if not n:
            n = self.s
        print(f"{c*n}")
        return

    def caption(self, string):
        slen = len(string)
        print(f"{string}\n"
              f"{'-'*slen}")
        return

    def header(self, string):
        self.separator('=')
        self.caption(string)
        return

    def prefixed_line(self, label, field, value, sep=':'):
        self.line(f"{label:{self.p}s}{field}", value, sep)
        return

    def line(self, label, value=None, sep=':'):
        if value:
            print(f"{label:{self.n}s}{sep} {value}")
        else:
            print(label)
        return

    def item(self, idx, caption, itm, sep=':'):
        if idx is None:
            self.itemPlain(caption, itm, sep)
            return
        else:
            if itm:
                print(f"{idx:3d}. {caption:{self.i}s}{sep} {itm}")
            else:
                print(f"{idx:3d}. {caption:{self.i}s}")
            return

    def itemPlain(self, caption, itm, sep=':'):
        if itm:
            print(f"{' ':3s}  {caption:{self.i}s}{sep} {itm}")
        else:
            print(f"{' ':3s}  {caption:{self.i}s}")
        return

    def footer(self):
        self.separator('=')
        return

    n: int
    s: int
# ------------------------------------------------------------------------------
