# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

import argparse

class SplitArgs(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None) :
        if values : setattr(namespace, self.dest, values[0].split(','))
        else      : setattr(namespace, self.dest, [])

class Action :

    @staticmethod
    def add_arguments (parser, what) :
        group = parser.add_mutually_exclusive_group ()


        group.add_argument  ('--list',
                             help    = 'List ' + what,
                             nargs   = '*',
                             const   = '--no_value--',
                             action  =  SplitArgs)

        group. add_argument ('--clean',
                             help    = 'Clean ' + what,
                             nargs   = '*',
                             const   = '--no_value--',
                             action  =  SplitArgs)

        group. add_argument ('--create',
                             help    = 'Create ' + what,
                             nargs   = '*',
                             const   = '--no_value--',
                             action  =  SplitArgs)


        group. add_argument ('--replace',
                             help    = 'Clean ' + what,
                             nargs   = '*',
                             const   = '--no_value--',
                             action  =  SplitArgs)


    List         : int = 1
    Clean        : int = 2
    Create       : int = 4
    Replace      : int = 8

    def __init__ (self, args) :
        self.action = 0
        if args.list    is not None : self.action |= Action.List
        if args.clean   is not None : self.action |= Action.Clean
        if args.create  is not None : self.action |= Action.Create
        if args.replace is not None : self.action |= Action.Replace

    # --------------------------------------------------------------------------
    @staticmethod
    def is_in (s, l) :
        n = len (s)
        for member in l:
            if s == member[0:n] : return True
        return False
    # --------------------------------------------------------------------------

    @staticmethod
    def get_opts (olist, default_opt) :
        if not olist : return default_opt

        msk = 0
        if Action.is_in ('e', olist) : msk |= Action.Existing
        if Action.is_in ('m', olist) : msk |= Action.Missing
        if Action.is_in ('c', olist) : msk |= Action.Cruft
        if Action.is_in ('a', olist) : msk |= Action.All

        if msk == 0 : msk = default_opt
        return msk


    @staticmethod
    def isList (action) :
        return True if (action &     List) else False

    @staticmethod
    def isClean (action) :
        return True if (action &    Clean) else False

    @staticmethod
    def isCreate (action) :
        return True if (action &   Create) else False

    @staticmethod
    def isReplace (action) :
        return True if (action & Replace) else False
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
