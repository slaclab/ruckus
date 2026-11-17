# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Cannot use relative paths when executing as main
# This avoids polluting sys.path when not main
# ------------------------------------------------
if __name__ == '__main__':
    pass
else:
    import os
    import glob
    import array
    from types import SimpleNamespace
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Maps ():

    class Src:
        def __init__(self, ctb_type, prefix, kvs):
            self.ctb_type = ctb_type
            self.prefix = prefix
            self.kvs = [kvs]
            return

    def __init__(self, ctbs, ctb_type):
        # ---------------------------------------------------------
        # Is this a single contributor?
        # This is all but impossible since there must be at least 2
        #  - A CtbBuids
        #  - A CtbFpgas
        # ---------------------------------------------------------
        if isinstance(ctbs, ctb_type):
            srcs_list = [[] for _ in range(1)]

            # ctbs is just one ctb
            self.compile(srcs_list, ctbs)

        else:
            # Is this a list or tuple of contributors?
            is_list = all(issubclass(type(ctb), ctb_type)
                          for ctb in ctbs)
            if is_list:
                srcs_list = [{} for _ in range(1)]

                for ctb in ctbs:
                    n = self.compile(srcs_list[0], ctb)

            # Is this lists or tuples of contributors?
            elif isinstance(ctbs, (list, tuple)):

                srcs_list = [[] for _ in range (len (ctbs)) ]

                idx = 0
                err = 0
                for ctbList in ctbs:

                    # ------------------------------------
                    # Is this a single contributor?
                    # Almost impossible, see comment above
                    # ------------------------------------
                    if isinstance(ctbList, ctb_type):
                        self.compile(srcs_list[idx], ctbList)

                    # Is this a list,tuple of multiple contributors
                    else:

                        for ctb in ctbList:
                            if issubclass(type(ctb), ctb_type):
                                self.compile(srcs_list[idx], ctb)

                            elif isinstance (ctb, (list, tuple)):
                                for c in ctb:
                                    if  issubclass(type(c), ctb_type):
                                        self.compile (srcs_list[idx], c)
                                    else:
                                        err += 1
                            else:
                                err += 1

                    if err:
                        print("ERROR: Unknown contributors specification\n"
                              "       This may be\n"
                              "         a) A single contributor\n"
                              "         b) A list or tuple of contributor\n"
                              "         c) A lists or tuples of contributor\n",
                              file = sys.stderr)
                    idx += 1

        # -------------------------------------------------------------
        # Calculate the number of permutations/combinations in all the
        # compiled 'srcs' and make a list of contributor types large
        # enough to accommodate them all.
        # -------------------------------------------------------------
        map_tot = 0
        map_cnts = []
        self.ctb_types = array.array ('i', [-1,-1,-1,-1,-1])
        for srcs in srcs_list:

            map_cnt = 1
            idx = 0
            for src in srcs:
                if    src.ctb_type == 'Builds' : self.ctb_types[0] = idx
                elif  src.ctb_type == 'Fpgas'  : self.ctb_types[1] = idx
                idx += 1
                map_cnt *= len (src.kvs)

            # Keep track of the map count by source
            map_cnts.append (map_cnt)
            map_tot += map_cnt

        self.maps = [{} for _ in range(map_tot)]

        # ------------------------------------------------------------
        #  Need to form every permutation of the maps
        #  Each src has some number of maps. For example, 3 maps
        #     Map 0   2
        #     Map 1   3
        #     Map 2   2
        # For a total of 12 maps of every permutation.  Consider a 3
        # digit number where the radix is its length.
        #
        #  M  M0   M1  M2
        #  0   0    0   0
        #  1   0    0   1
        #  2   0    1   0
        #  3   0    1   1
        #  4   0    2   0
        #  5   0    2   1
        #  6   1    0   0
        #  7   1    0   1
        #  8   1    1   0
        #  9   1    1   1
        # 10   1    2   0
        # 11   1    2   1
        #
        #        Length Cumulative   #Maps/Cumulative = Repeated
        #    M0       2          2      12/(2)                 6
        #    M1       3        2*3      12/(2*3)               2
        #    M2       2      2*3*2      12/(2*3*2)             1
        # -------------------------------------------------------
        src_idx = 0
        map_gdx = 0
        for srcs in srcs_list:
            map_cnt = map_cnts[src_idx]
            src_idx += 1
            n = 1
            for src in srcs:

                prefix = src.prefix

                l = len(src.kvs)
                n = n * l
                map_idx = map_gdx;
                rep = map_cnt // n

                for idx in range(0, n):

                    val_idx = idx % l
                    for idy in range(0, rep):

                        v = src.kvs[val_idx]

                        # print (f"Adding maps[{map_idx}][{prefix}] = {v}")

                        # Add prefix and value (attributes)
                        self.maps[map_idx][prefix] = v

                        map_idx += 1

            # ------------------------------------------
            # Done with this set of maps
            # Advance the global map index past this set
            # ------------------------------------------
            map_gdx += map_cnt

        if False:
            print("Final map")
            idx = 0
            for ctb in self.maps:
                print(f"\nContributor {idx}")
                for k, v in ctb.items():
                    print(f"{k} : {v}")
                idx += 1
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def add_srcs(srcs, ctb_type, prefix, kvs):
        '''
        Adds or appends a source to the list of sources

        Args:
            srcs   : The list of sources to be added to or have an existing one
                     appended to
           ctb_type: The contributor type, i.e. 'Builds', 'Fpgas', etc.
           prefix  : The prefix used to reference the list of attributes in kvs.
                     e.g. 'builds', 'fpgas'.
           kvs     : The attributes preseentation as a SimpleNamespace,
                     e.g. for fpgas this would be
                        'id'          : <identification>,
                        'part'        : <fpga part>
                        'clock'       : <clock in frequency, nsecs, etc>
                        'uncertainty' : <clock uncertainity, None=Default, +/-nsec, etc>

         The usage of the prefix and the attributes in kvs in the fpga example
         is {fpga.id}, {fpga.part}, etc. This is generally used in formating string
         with the prefix, kvs being captured in a format_map.

         If the prefix has been encountered before, it must occur with in a
         different contributor type.  The rule is 'prefixes must be unique
         across all contributor source types, e.g. if the prefix 'fpga' is
         used in an Product.CtbFpga contributor, it can not be used in any other
         Product.Ctb<xxxx> contributor.  If it does, it is an error.

         Once it is determined that it has occurred in the same source type
         its kvs/attributes are appended. An example would be an
           Product.CtbFpgas ('fpga', (fpga0, fpga1).

        Here both fpga0 and fpga1 share the same prefix and result in two
        instances of the otherwise same component being created, one wiht fpga0
        and one with fpga1.

        If the prefix has not been encountered before, by virtue that the prefix
        must be unique to the contributor source type, this must represent a new
        new source, so one is created and added to list of soruces.
        '''
        for src in srcs:
            if prefix == src.prefix:

                if ctb_type != src.ctb_type :

                    # ------------------------------------------------------------
                    # This is an internal error
                    # This should have been flagged when entering the contributors
                    # ------------------------------------------------------------
                    print(f"ERROR: Contributor prefix {prefix} found in differings\n"
                          f"       {ctb_type} & src.ctb_type\n")
                    return -1

                # -----------------------------------------------------------
                # Have seen this prefix with this source type, append to kvs
                # -----------------------------------------------------------
                src.kvs.append (kvs)
                return 0
        # --------------------------------------------------

        # ------------------------------------------------
        # First time this source type has been encountered
        # Create its source and add to list of sources.

        # ------------------------------------------------
        src = Maps.Src (ctb_type, prefix, kvs)
        srcs.append (src)
        return 0
    # --------------------------------------------------------------------------


    # -------------------------------------------------------------------------
    @staticmethod
    def compile(srcs, contributor):
        '''
        Compiles each entry in the contributor into possibly an expanded
        set of sources if the contributor value contains wildcards or a list

        Args:
           srcs        : Filled in with contributor information consisting of
                         the  contributor type and its prefix and kvs/namespace
                         attributes (i.e. for fpga this might be
                          prefix = 'fpgas'
                          kvs/namespace = SimpleNamespace ('id' : <id>,
                                                           'part' : <fpga_part,
                                                           etc)
           contributor: The user's contributor definition

        Examples of contributors

           contributor = Product.CtbFgpas('fpga', ['Fpgas', [fpga0, fpga1])
           contributor = Product.CtFpgas('file', ['Files', ['cfgs/*.cfg'])
        '''

        prefix = contributor.prefix
        dtype, vs = contributor.kvs

        if dtype == 'Builds':
            for build in vs:

                # The kvs/namespace for the build
                kvs = SimpleNamespace(object = build, id = build.id)
                Maps.add_srcs(srcs, 'Builds', prefix, kvs)

            return len(vs)

        if dtype == 'Files':
            errs = 0
            nfiles = 0
            for file_specs in vs:
                files = glob.glob(os.path.expandvars(file_specs))

                # --------------------------------
                # Check that some files were found
                # --------------------------------
                if len(files) == 0:
                    errs += 1
                    print("\nERROR: No files found satisfying\n"
                          f"       {file_specs}\n")
                    continue
                elif errs:
                    # No reason to expand after have errors
                    continue

                for file in files:
                    path = os.path.realpath(os.path.expandvars(file))
                    dirs, namext = os.path.split(path)
                    dir = os.path.split(dirs)[1]
                    name, ext = os.path.splitext(namext)

                    # The kvs/namspace for the file
                    kvs = SimpleNamespace (object = file,
                                           path   = path,
                                           dir    = dir,
                                           name   = name,
                                           ext    = ext)

                    Maps.add_srcs(srcs, 'Files', prefix, kvs)
                nfiles += len(files)

            if errs:
                exit(-1)
            return nfiles

        if dtype == 'Fpgas':

            for fpga in vs:

                # The kvs/namespacer fo the fpga
                kvs = SimpleNamespace (object     = fpga,
                                       id         = fpga.id,
                                      part        = fpga.part,
                                      clock       = fpga.clock,
                                      uncertainty = fpga.uncertainty)
                Maps.add_srcs(srcs, 'Fpgas', prefix, kvs)
            return len(vs)

        if dtype == 'Values':
            for id_val in vs:

                val = id_val.value
                id  = id_val.id if id_val.id else val

                # The kvs/namspace of the value
                kvs = SimpleNamespace (object = id_val,
                                       id     = id,
                                       value  = val)

                Maps.add_srcs(srcs, 'Values', prefix, kvs)
            return len(vs)

        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
def doit():

    import os
    import sys
    sys.path.append(os.path.split(os.path.split(__file__)[0])[0])

    from vitispy.directory import Directory
    sys.path.append(Directory.root)
    from vitispy.product import Product
    from vitispy.maps import Maps

    # Convenience variables
    include_path = os.path.join ('$SNL_ROOT', 'include')
    includes     = Product.IncludePaths (root  = None,
                                         paths = include_path)

    defines       = Product.IncludeFiles ('STREAM_SEED',
                                         '{network}',
                                         include_path)

    tb = Product.Sources (root     = '$SNL_ROOT',
                          files    = [ 'src/snl/SnlTest.cc'],
                          includes = [            includes ],
                          defines  = [             defines ])

    syn = Product.Sources (root    =  '$SNL_ROOT',
                          files    =  'src/snl/SnlNetwork.cc',
                          includes =                 includes,
                          defines  =                  defines)

    build0 = ('b0', Product.Build(top        = 'processStream',
                                  tb         =  (tb, tb),
                                  syn        =  (syn,),
                                  ldflags    = 'ldFlags',
                                  csim_argv  = 'csim_arg0',
                                  cosim_argv = 'cosim_arg0'))

    build1 = ('b1', Product.Build(top        = 'processStream',
                                  tb         =  tb,
                                  syn        =  syn,
                                  ldflags    = 'ldFlags',
                                  csim_argv  = 'csim_arg0',
                                  cosim_argv = 'cosim_arg0'))

    files = '${SNL_TESTS}/tests/layers/networks/conv*_same/*.hh'
    files = os.path.expandvars(files)
    fpgas = (Product.Fpga('xcku115-flvb2104-2-i', '6', None, 'f0'),
             Product.Fpga('xcku115-flvb2104-2-i', '5', None, 'f1'))

    contributors = (Product.CtbBuilds('build', [build0, build1]),
                    Product.CtbFiles('network', files),
                    Product.CtbFpgas('fpga',    fpgas),
                    Product.CtbValues('def', (1, 2, 3)))
    template = "xyz-{build.id}-{network.name}-{fpga.id}-d{def.value}"


    maps = Maps(contributors, Product._Ctb)

    idx = 0
    for map in maps.maps:
        s = template.format_map(map)
        print(f"{idx:3d}: {s}")
        idx += 1

    return 0
# ------------------------------------------------------------------------------


if __name__ == "__main__":

    status = doit()
    exit(status)
