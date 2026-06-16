

# ------------------------------------------------------------------------------
# Cannot use relative paths when executing as a main
# This avoids polluting sys.path when not main
# --------------------------------------------------
if __name__  == '__main__' :
    import os,sys,glob

    sys.path.append (Directory.root)
    from vitispy.dictionary import *
    from vitispy.project    import Project
    from vitispy.maps       import Maps

else :
    import   os,glob
    from .dictionary import Dictionary
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
class Maps () :

    def __init__ (self, dictionaries) :

        srcs = {}


        # Is this a single dictionary
        if isinstance (dictionaries, Dictionary) :
            # dictionaries is just one dictionary
            self.compile (srcs, dictionaries)

        else :
            # Is this a list,tuple of dictionaries
            is_list = all(issubclass (type(x), Dictionary) for x in dictionaries)
            if is_list :

                for dictionary in dictionaries :
                    n = self.compile (srcs, dictionary)

            # Is this a lists or tuples of dictionaries
            elif isinstance (dictionaries, (list, tuple)) :

                for dictionaryList in dictionaries :

                    # Is this a single dictionary
                    if isinstance (dictionaryList, Dictionary) :
                        self.compile (srcs, dictionaryList)

                    # Is this a list,tuple of multiple dictionaries
                    elif all(issubclass (type(x), Dictionary) for x in dictionaryList) :

                        for dictionary in dictionaryList :
                            self.compile (srcs, dictionary)
                    else :
                        print ("ERROR: Unknown dictionaries specification\n"
                               "       This may be\n"
                               "         a) A single dictionary\n"
                               "         b) A list or tuple of dictionaries\n"
                               "         c) A lists or tuples of dictionaries\n")

        # -------------------------------------------------------------
        # Calculate the number permutations/combinations in all the
        # compiled 'srcs' and make a list of dictionaries large enough
        # to accomodate them all
        # -------------------------------------------------------------
        map_cnt = 1
        for k,v in srcs.items () : map_cnt *= len (v)
        self.maps = [ {} for _ in range(map_cnt) ]

        left  = len (srcs)
        for key, values in srcs.items () :
            n     = len (values)
            den   = map_cnt // n
            left -= 1
            for map_idx in range (0, map_cnt) :

                # `----------------------------------------------
                # Repeat on all but the last, then alternate
                # eg. if have 2 srcs of lens 3 and 2 (total of 6)
                #    Ordering is
                #         0 0
                #         0 1
                #         1 0
                #         1 1
                #         2 0
                #         2 1
                # if hav 3 lens 2, 3, 2 (total 12)
                #   0.      0   0  0
                #   1.      0   0  1
                #   2.      1   0  0
                #   3.      1   1  1
                #   4.      0   1  0
                #   5.      0   1  1
                #   6.      1   2  0
                #   7.      1   2  1
                #   8.      0   2  0
                #   9.      0   3  1
                #  10.      1   3  0
                #  11.      1   3  1
                # `---------------------------------------------
                val_idx = (map_idx // den) if left else (map_idx % n)
                v       = values[val_idx]

                # Add primary key and value
                self.maps[map_idx][key]      = v[0]

                # Add derived keys and values
                if v[1] :
                    for dv in v[1] :
                        self.maps[map_idx][dv[0]] = dv[1]

        if False :
            print ("Final map")
            idx = 0
            for dictionary in self.maps :
                print (f"\nMap {idx}")
                for k,v in dictionary.items() :
                    print (f"{k} : {v}")
                idx += 1
        return
    # --------------------------------------------------------------------------


    # --------------------------------------------------------------------------
    @staticmethod
    def add_derived (srcs, primary_key, kvs, sep) :
        if kvs is None : return None
        derived = []
        sep     = '_'
        for k,v in kvs :

            dkey = primary_key + sep + k

            # -------------------------------------------------
            # Note: there really can't be duplicates in
            #       secondary keys since they are prefixed with
            #       a unique primary key
            # There is perverse case where the user could define
            # a primary key with the same name, so should check
            # --------------------------------------------------
            if  dkey in srcs :
                print (f"WARNING: Ignoring duplicate secondary {dkey} entry of\n"
                               f"         {v}")
                return -1

            derived.append ([dkey, v])

        return derived

    @staticmethod
    def add_srcs (srcs, primary_key, primary_val, kvs, sep) :

        if not primary_key in srcs :
            # ----------------------------------------
            # First time this key has been encountered
            # Compose  derived key,values
            # ----------------------------------------
            derived = Maps.add_derived (srcs, primary_key, kvs, sep)
            srcs[primary_key] = [[primary_val, derived]]
            return

        else :

            # --------------------------------------------------
            # Not the first, so need to check this key is unique
            # before appending
            # --------------------------------------------------
            if primary_val in srcs[primary_key] :

                print (f"WARNING: Ignoring duplicate {key} entry of\n"
                       f"         {primary_val}")
                return -1

            else :
                derived = Maps.add_derived (srcs, primary_key, kvs, sep)
                srcs[primary_key].append ([primary_val, derived])

        return
    # ------------------------------------------------------------------------------


    # ------------------------------------------------------------------------------
    @staticmethod
    def compile (srcs, dictionary) :
        '''
        Compiles each the entry in the dictionary into possibly an expanded set of
        sources if the dictionary value contains wildcards or a list

        Args:
           srcs      : Expanded source information consisting of the primary
                       key information and derived entries
           dictionary: The user's dictionary definition

        Examples of dictionaries

           dictionary = Dictionary('fpga', ['Fpgas', [fpga0, fpga1])
           dictionary = Dictionary('file', ['Files', ['cfgs/*.cfg'])

           or the preferred in user code since it hides implementation details

           dictionary = Dictionary_of_Fpgas('fpga', [fpga0, fpga1])
           dictionary = Dictionary_of_Files('file', ['cfgs/*.cfg'])
        '''

        key       = dictionary.key
        dtype, vs = dictionary.tvs

        if dtype == 'Builds' :
            for build in vs :
                kvs = [ [ 'id' , build[0] ]]
                Maps.add_srcs (srcs, key, build[1], kvs, '_')
            return len (vs)

        if dtype == 'Files' :
            errs   = 0
            nfiles = 0
            for file_specs in vs :
                files = glob.glob (os.path.expandvars (file_specs))

                # ---------------------------------
                # Check that some files where found
                # ---------------------------------
                if  len (files) == 0 :
                    errs  += 1
                    print ( "\nERROR: No files found satisfying\n"
                             f"       {file_specs}\n")
                    continue
                elif errs :
                    # No reason to expand after have errors
                    continue

                for file in files :
                    path = os.path.realpath (os.path.expandvars (file))
                    dirs, namext = os.path.split (path)
                    dir          = os.path.split (dirs)[1]
                    name, ext    = os.path.splitext (namext)

                    # Derived key,values for files
                    kvs = [ [ 'dir',  dir],
                            ['name', name] ]

                    Maps.add_srcs (srcs, key, path, kvs, '_')
                nfiles += len (files)

            if errs : exit (-1)
            return nfiles

        if dtype == 'Fpgas' :

            for fpga in vs :
                # Derived key values for fpgas
                kvs = [ [          'id', fpga.id          ],
                        [        'part', fpga.part        ],
                        [       'clock', fpga.clock       ],
                        ['uncertainity', fpga.uncertainity] ]

                Maps.add_srcs (srcs, key, fpga, kvs, '_')
            return len (vs)

        if dtype == 'Values' :
            for val in vs :
                Maps.add_srcs (srcs, key, val, None, '_')
            return len (vs)

        return
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
if __name__ == "__main__" :

    # Convience variables
    build0 =     ('b0', { 'top'     : 'processStream',
                         'tb'      : [ 'tbFiles'],
                         'syn'     : [ 'synFiles'],
                         'ldflags' : 'ldFlags etc',
                         'csim'    : 'csim_arg0',
                         'cosim'   : 'cosim_arg0' } )

    build1 =    ['b1', { 'top'     : 'processStream',
                         'tb'      : [ 'tbFiles'],
                         'syn'     : [ 'synFiles'],
                         'ldflags' : 'ldFlags etc',
                         'csim'    : 'csim_arg0',
                         'cosim'   : 'cosim_arg0' } ]

    files    = '${SNL_ROOT}/internal/tests/layers/*d_same/*.hh'
    fpgas    = ( Project.Fpga ('xcku115-flvb2104-2-i', '6',  None, 'f0'),
                 Project.Fpga ('xcku115-flvb2104-2-i', '5',  None, 'f1') )

    dictionaries = ( Dictionary_of_Builds   ('build',   [build0, build]),
                     Dictionary_of_Files    ('network',           files),
                     Dictionary_of_Fpgas    ('fpga'  ,            fpgas),
                     Dictionary_of_Values   ('value',       [1, 2, 3]) )
    template     = "xyz-{product_id}-{network_name}-{fpga_id}-{value}"
    maps         = Maps (dictionaries)

    idx = 0
    for map in maps.maps :
        s = template.format_map (map)
        print (f"{idx:3d}: {s}")
        idx += 1

    sys.exit (0)
# ------------------------------------------------------------------------------
