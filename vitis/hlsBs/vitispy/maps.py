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

    def __init__(self, ctbs, ctb_type):
        srcs = {}

        # Is this a single contributor
        if isinstance(ctbs, ctb_type):
            # ctbs is just one ctb
            self.compile(srcs, ctbs)

        else:
            # Is this a list or tuple of contributors
            is_list = all(issubclass(type(ctb), ctb_type)
                          for ctb in ctbs)
            if is_list:

                for ctb in ctbs:
                    n = self.compile(srcs, ctb)

            # Is this lists or tuples of contributors
            elif isinstance(ctbs, (list, tuple)):

                for ctbList in ctbs:

                    # Is this a single contributor
                    if isinstance(ctbList, ctb_type):
                        self.compile(srcs, ctbList)

                    # Is this a list,tuple of multiple contributors
                    elif all(issubclass(type(ctb), ctb_type) for ctb in ctbList):

                        for ctb in ctbList:
                            self.compile(srcs, ctb)
                    else:
                        print("ERROR: Unknown contributors specification\n"
                              "       This may be\n"
                              "         a) A single contributor\n"
                              "         b) A list or tuple of contributor\n"
                              "         c) A lists or tuples of contributor\n",
                              file = sys.stderr)

        # -------------------------------------------------------------
        # Calculate the number of permutations/combinations in all the
        # compiled 'srcs' and make a list of contributor types large
        # enough to accommodate them all.
        # -------------------------------------------------------------
        map_cnt = 1
        self.ctb_types = array.array ('i', [-1,-1,-1,-1,-1])
        idx = 0
        for k, v in srcs.items():
            if    k == 'Builds' : self.ctb_types[0] = idx
            elif  k == 'Fpgas'  : self.ctb_types[1] = idx
            idx += 1
            for vals in v.values():
                map_cnt *= len(vals)
        self.maps = [{} for _ in range(map_cnt)]

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
        n = 1
        for k, v in srcs.items():
            for key, vals in v.items ():
                l = len(vals)
                n = n * l
                rep = map_cnt // n
                map_idx = 0
                for idx in range(0, n):

                    val_idx = idx % l
                    for idy in range(0, rep):

                        v = vals[val_idx]

                        # Add primary key and value
                        self.maps[map_idx][key] = v#[0]

                        map_idx += 1

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
    def add_srcs(srcs, src_type, primary_key, primary_val, kvs):

        if not src_type in srcs or primary_key not in srcs[src_type]  :
            # ----------------------------------------
            # First time this key has been encountered
            # Add the key values
            # ----------------------------------------
            srcs[src_type] = primary_key
            srcs[src_type] = { primary_key : [kvs] }
            return 0

        else:

            # --------------------------------------------------
            # Not the first, so need to check this key is unique
            # before appending
            # --------------------------------------------------
            if False: #primary_key in srcs[src_type]:

                print(f"WARNING: Ignoring duplicate {primary_key} entry of\n"
                      f"         {primary_val}")
                return -1

            else:
                srcs[src_type][primary_key].append(kvs)

        return 0
    # --------------------------------------------------------------------------


    # -------------------------------------------------------------------------
    @staticmethod
    def compile(srcs, contributor):
        '''
        Compiles each entry in the contributor into possibly an expanded
        set of sources if the contributor value contains wildcards or a list

        Args:
           srcs        : Expanded source information consisting of the primary
                         key information and derived entries
           contributor: The user's contributor definition

        Examples of contributors

           contributor = Product.CtbFgpas('fpga', ['Fpgas', [fpga0, fpga1])
           contributor = Product.CtFpgas('file', ['Files', ['cfgs/*.cfg'])
        '''

        key = contributor.key
        dtype, vs = contributor.tvs

        if dtype == 'Builds':
            for build in vs:
                kvs = SimpleNamespace(object = build[1], id = build[0])
                Maps.add_srcs(srcs, 'Builds', key, build[1], kvs)
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

                    # Derived key,values for files
                    kvs = SimpleNamespace (object = file,
                                           path   = path,
                                           dir    = dir,
                                           name   = name,
                                           ext    = ext)

                    Maps.add_srcs(srcs, 'Files', key, file, kvs)
                nfiles += len(files)

            if errs:
                exit(-1)
            return nfiles

        if dtype == 'Fpgas':

            for fpga in vs:
                # Derived key values for fpgas
                kvs = SimpleNamespace (object     = fpga,
                                       id         = fpga.id,
                                      part        = fpga.part,
                                      clock       = fpga.clock,
                                      uncertainty = fpga.uncertainty)
                Maps.add_srcs(srcs, 'Fpgas', key, fpga, kvs)
            return len(vs)

        if dtype == 'Values':
            for val in vs:
                kvs = SimpleNamespace (object = val,
                                       value  = val)
                Maps.add_srcs(srcs, 'Values', key, val, kvs)
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
