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


class Category:
    '''
    Categorize a list of options to be acted by an action as
            Command option  Target       Applies to
         1.     'existing'  Existing     Existing targets
         2.      'missing'  Missing      Missing  targets
         3.        'kruft'  CruftLo      Low confidence cruft
         4.        'Kruft'  CruftHi      High confidence cruft
         5.        'cruft'  CruftLo & Hi Both low and high confidence cruft

    Existing and missing are fairly self-explanatory, e.g. list=existing or
    list=missing.

    Cruft is more nuanced. Cruft refers to targets that are unknown to the
    current project. For example a configuration file is added, then the naming
    convention changes. The original file still exists, but is not among the
    new project's configuration files.

    Continuing with this example, if a component associated with this leftover
    configuration file exists in the workspace, that component contains a
    reference to its configuration file. One can be highly confident that this
    is a leftover configuration file as opposed to some random file.

    Contrast this with the case where the component does not exist. All one has
    to go on from the project definition is that there is a list of directories
    that contain the configuration files. Given there could be other files in
    these directories also, there is no hard way to distinguish what is or is
    not a configuration file, so some heuristic has been chosen.  In the case
    of configuration files, this heuristic is whether the file extension matches
    that used by the directory defined in the list of projects. Normally this
    would be '.cfg', but that is simply a convention.  This method has slightly
    more generality. One could try to read the file's contents, but this is error
    prone.  What's to say this is just not some file that looks like a
    configuration file.  Maybe it is a file used to document a configuration
    file containing an example.  Bottom line, cateogrizing such target as cruft
    is deemed low confidence.  Any destructive action on it should be carefully
    vetted
    '''

    Existing : int =  1
    Missing  : int =  2
    CruftLo  : int =  4
    CruftHi  : int =  8
    Cruft    : int = 12
    All      : int = 15

    # --------------------------------------------------------------------------
    @staticmethod
    def is_in (s, lst) :
        n = len (s)
        for member in lst:
            if s == member[0:n] : return True
        return False
    # --------------------------------------------------------------------------

    @staticmethod
    def categorize (olist, default_opt) :
        if not olist : return default_opt

        msk = 0
        if Category.is_in ('e', olist) : msk |= Category.Existing
        if Category.is_in ('m', olist) : msk |= Category.Missing
        if Category.is_in ('k', olist) : msk |= Category.CruftLo
        if Category.is_in ('K', olist) : msk |= Category.CruftHi
        if Category.is_in ('c', olist) : msk |= Category.Cruft
        if Category.is_in ('a', olist) : msk |= Category.All

        if msk == 0 : msk = default_opt
        return msk
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    @staticmethod
    def byComponents (targets) :

        categories = Category ()

        for target in targets :
            cfg_path   = target.cfg_path
            cfg_exists = os.path.isfile (cfg_path) if cfg_path else False
            cmp_path   = target.cmp_path
            cmp_exists = os.path.isdir  (cmp_path) if cmp_path else False
            if cfg_exists :
                if cmp_exists : categories.existing.append (target)
                else          : categories.missing .append (target)
            else :
                if cmp_exists : categories.cruft_hi.append (target)
                else          : categories.cruft_lo.append (target)

        return categories
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def getCategories (workspace, configurations, components, cmpList) :
        import glob
        import fnmatch
        from   .componentInfo import ComponentInfo

        class Target :
            def __init__ (self, cmp_name, cmp_path, cfg_path, cmp_err) :
                self.cmp_name = cmp_name
                self.cmp_path = cmp_path
                self.cfg_path = cfg_path
                self.cmp_err  = cmp_err
                return


        if not isinstance (configurations, (list, tuple)) :
            configurations = [configurations]

        if components == None : cmp_template = '{cfg_name}'
        else :                  cmp_template = components

        categories  = Category ()

        # ---------------------------------------------------------
        # Construct all the legitimate configuration and components
        # ---------------------------------------------------------

        # Make a list the components in the workspace
        cmp_ignores = ['_ide', 'logs']
        cmp_paths   = glob.glob (os.path.join (workspace, '*'))
        cmp_names   = []

        cfg_paths = []
        for cfg in configurations :
            paths = glob.glob (cfg)
            for cfg_path in paths :

                # Check if already seen
                if cfg_path in cfg_paths : continue

                # Add to seen list
                cfg_paths.append (cfg_path)
                cfg_name = os.path.split (os.path.splitext (cfg_path)[0])[1]
                cmp_name = cmp_template.format (cfg_name = cfg_name)

                # Does this pattern match one of requested components
                match = False
                for cmp in cmpList :
                    match = fnmatch.fnmatch (cmp_name, cmp)
                    if match : break

                # If not a match, but in the list of actual components
                # then remove from the cmp_paths to consider, otherwise
                # would be called cruft when it simply is not of interest.
                cmp_path = os.path.join (workspace, cmp_name)
                if not match and  cmp_path in cmp_paths :
                    cmp_paths.remove (cmp_path)
                    continue

                # Have a match with components of interest

                exists = os.path.isdir (cmp_path)
                target = Target (cmp_name, cmp_path, cfg_path, 0)

                # Categorize as existing or missing
                if exists :
                    cmp_info       = ComponentInfo (cmp_path, True)
                    target.cmp_err = cmp_info.errs

                    # Check if the information in the component's
                    # json file is good. If so, it is considered 'good'
                    if  target.cmp_err == 0 and cfg_path == cmp_info.cfg_files :
                        categories.existing.append (target)
                        cmp_paths.remove (cmp_path)
                    else :
                        # There is something wrong with it, probably
                        # need to invent a new category. It is put in
                        # dubious category
                        cmp_name = os.path.split (cmp_path)[1]
                        cmp_paths.remove (cmp_path)
                        if cmp_name not in cmp_ignores :
                            categories.cruft_lo.append (target)

                else      :
                    categories.missing.append  (target)


        # Any left over in the cmp_paths is deemed cruft
        for cmp_path in cmp_paths :
            cmp_name = os.path.split (cmp_path)[1]
            if cmp_name not in cmp_ignores :

                cmp_info = ComponentInfo (cmp_path, True)

                # Does this look like a component
                if cmp_info.errs == 0 :
                    categories.cruft_hi.append (Target (cmp_name,
                                                        cmp_path,
                                                        None,
                                                        0))

        return categories
    # --------------------------------------------------------------------------


    @staticmethod
    def categorizeByComponent (workspace, cmpList) :

        import glob
        from .targets import TargetMin

        categories  =  Category ()
        cmp_names   = []
        cmp_ignores = ['_ide', 'logs']

        for cmp in cmpList :
            wc    = os.path.join (workspace, cmp)
            paths = glob.glob (wc)

            for cmp_path in paths :
                if not os.path.isdir (cmp_path) : continue

                cmp_name = os.path.split (cmp_path)[1]
                if cmp_name in cmp_names        : continue
                if cmp_name in cmp_ignores      : continue

                cmp_names.append   (cmp_name)
                target = TargetMin (cmp_name, cmp_path)
                if target.errs : categories.cruft_hi.append (target)
                else           : categories.existing.append (target)

        return categories
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    def __init__ (self) :
        self.existing = []
        self.missing  = []
        self.cruft_hi = []
        self.cruft_lo = []
    # --------------------------------------------------------------------------

# ------------------------------------------------------------------------------
