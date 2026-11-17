# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

from dataclasses import dataclass

# ----------------------------------------------------------------------------
@dataclass
class SgrSeq:
    '''
    Description:
    Defines the Select Graphic Renditions for colors and text types
    '''
    # ------------------------------------------------------------------------
    nrm = "\033[0m"

    # Text types
    bold = "\033[1m"
    dim = "\033[2m"
    italic = "\033[3m"
    b_italic = "\033[1;3m"
    underline = "\033[4m"
    blink = "\033[5m"
    reverse = "\033[7m"
    hidden = "\033[8m"
    strikethrough = "\033[9m"

    # Standard colors
    black = "\033[30m"
    red = "\033[31m"
    green = "\033[32m"
    yellow = "\033[33m"
    blue = "\033[34m"
    magenta = "\033[35m"
    cyan = "\033[36m"
    white = "\033[37m"

    # Italics colors
    i_black = "\033[30;3m"
    i_red = "\033[31;3m"
    i_green = "\033[32;3m"
    i_yellow = "\033[33;3m"
    i_blue = "\033[34;3m"
    i_magenta = "\033[35;3m"
    i_cyan = "\033[36;3m"
    _white = "\033[37;3m"

    # Bold colors
    b_black = "\033[30;1m"
    b_red = "\033[31;1m"
    b_green = "\033[32;1m"
    b_yellow = "\033[33;1m"
    b_blue = "\033[34;1m"
    b_magenta = "\033[35;1m"
    b_cyan = "\033[36;1m"
    b_white = "\033[37;1m"

    # Bold Italics colors
    bi_black = "\033[30;1;3m"
    bi_red = "\033[31;1;3m"
    bi_green = "\033[32;1;3m"
    bi_yellow = "\033[33;1;3m"
    bi_blue = "\033[34;1;3m"
    bi_magenta = "\033[35;1;3m"
    bi_cyan = "\033[36;1;3m"
    bi_white = "\033[37;1;z3m"

    # Background colors
    bg_black = "\033[40m"
    bg_red = "\033[41m"
    bg_green = "\033[42m"
    bg_yellow = "\033[43m"
    bg_blue = "\033[44m"
    bg_magenta = "\033[45m"
    bg_cyan = "\033[46m"
    bg_white = "\033[47m"

    # Backgroud Bold Colors
    bgb_black = "\033[100m"
    bgb_red = "\033[101m"
    bgb_green = "\033[102m"
    bgb_yellow = "\033[103m"
    bgb_blue = "\033[104m"
    bgb_magenta = "\033[105m"
    bgb_cyan = "\033[106m"
    bgb_white = "\033[107m"

# -----------------------------------------------------------------------------
def out (what, esc0, esc1, esc2):
    print (esc0 + what + Ansi.nrm + ' ' +
           esc1 + what + Ansi.nrm + ' ' +
           esc1 + what + Ansi.nrm )

def out1 (what, esc):
    print (esc + what + Ansi.nrm )


# ----------------------------------------------------------------------------
def out (what, *escs):
    for esc in escs:
        print (esc + what + SgrSeq.nrm, end="")
    print ()
    return
# ----------------------------------------------------------------------------


# ----------------------------------------------------------------------------
if __name__ == "__main__":

   out ("Red          ", SgrSeq.red,     SgrSeq.b_red,     SgrSeq.i_red,     SgrSeq.bi_red,     SgrSeq.bgb_red)
   out ("Green        ", SgrSeq.green,   SgrSeq.b_green,   SgrSeq.i_green,   SgrSeq.bi_green,   SgrSeq.bgb_green)
   out ("Yellow       ", SgrSeq.yellow,  SgrSeq.b_yellow,  SgrSeq.i_yellow,  SgrSeq.bi_yellow,  SgrSeq.bgb_yellow)
   out ("Blue         ", SgrSeq.blue,    SgrSeq.b_blue,    SgrSeq.i_blue,    SgrSeq.bi_blue,    SgrSeq.bgb_blue)
   out ("Magenta      ", SgrSeq.magenta, SgrSeq.b_magenta, SgrSeq.i_magenta, SgrSeq.bi_magenta, SgrSeq.bgb_magenta)
   out ("Cyan         ", SgrSeq.cyan,    SgrSeq.b_cyan,    SgrSeq.i_cyan,    SgrSeq.bi_cyan,    SgrSeq.bgb_cyan)
   out ("Bold         ", SgrSeq.bold)
   out ("Italic       ", SgrSeq.italic)
   out ("Bold Italic  ", SgrSeq.b_italic)
   out ("Underline    ", SgrSeq.underline)
   out ("Blink        ", SgrSeq.blink)
   out ("Reverse      ", SgrSeq.reverse)
   out ("Hidden       ", SgrSeq.hidden)
   out ("Strikethrough", SgrSeq.strikethrough)
# ----------------------------------------------------------------------------
