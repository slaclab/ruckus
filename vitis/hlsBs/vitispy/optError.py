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
from vitispy.sgrseq import SgrSeq


def optError (cmd, prmType, prm, opt, optList, allowed) :

    opts = ""
    last = len(optList) - 1
    idx = 0
    for o in optList:
        opts += o
        if idx == last:
            break
        opts += ','
        idx += 1

    nrm = SgrSeq.nrm
    italic = SgrSeq.italic
    b_italic = SgrSeq.b_italic
    red = SgrSeq.red
    green = SgrSeq.green

    print (f"\n{red}ERROR{nrm}: {prmType} {italic}{opt}{nrm} for {italic}--{prm}{nrm} is not one of\n"
                   f"       [{italic}{allowed}{nrm}]\n\n"
                   f" Perhaps\n"
                    "  - A misspelled options ...or...\n"
                   f"  - The component selection, {italic}i.e. '{opt}'{nrm}, is immediately after {italic}--{prm}{nrm}.\n\n"
                   f"    $ {italic}{cmd} --{prm} '{opts}'              {nrm}# {b_italic}Wrong{nrm}: {italic}'{opt}' will be eaten by --{prm}{nrm}\n"
                   f"    $ {italic}{cmd} '{opts}' --{prm}              # Okay{nrm}\n"
                   f"    $ {italic}{cmd} --{prm} --components='{opts}' # Safest{nrm}\n\n"
                   f"    The optional argument {italic}'--{prm}'{nrm} accepts a list.\n"
                   f"    According to bash rules, that will be whatever immediately follows, {italic}i.e.{nrm} '{opts}'\n\n"
                   f"    {green}SUGGESTION{nrm}: Either specify the positional argument as the first argument or\n"
                   f"                use the safer, optional argument {italic}--component='{opts}'{nrm}\n", file=sys.stderr)
    return
