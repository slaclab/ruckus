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
import json
import re

class ComponentInfo :

    ErrNoCfgFile  = 1
    ErrNoCompPath = 2
    ErrJsonDecode = 4
    ErrUnknown    = 8

    def __init__ (self, component_path, silence_error = False) :

        vitis_comp_path = os.path.join (component_path, 'vitis-comp.json')
        self.errs = 0

        try:
            with open(vitis_comp_path, 'r') as f:
                data = json.load(f)

                cfgs = data['configuration']['configFiles']
                cfg  = cfgs[0]

                # Starting at 2025.1,
                # the cfg directory is relative to the component path
                # so check if the cfg is relative and add the component path
                if (os.path.isabs (cfg) == False) :
                    cfg = os.path.join (component_path, cfg)

                self.cfg_files = os.path.realpath (cfg)

                work_dir = data['configuration']['work_dir']
                if (os.path.isabs (work_dir) == False) :
                    work_dir = os.path.join (component_path, work_dir)

                self.work_dir = os.path.realpath (work_dir)
                self.hls_dir  = os.path.join (self.work_dir, 'hls')
                self.csim_dir = os.path.join (self.hls_dir,  'csim')
                self.csim_bld = os.path.join (self.csim_dir, 'build')
                self.csim_exe = os.path.join (self.csim_bld, 'csim.exe')
                self.cmp_name = data['name']

                try:
                    with open (self.cfg_files, 'r') as file:
                        pattern = r"%(\w*)%"
                        replace = r"${\1}"

                        self.csim_argv = ''
                        self.sim_argv  = ''
                        self.syn_dcp   = False

                        look : int = 15
                        for line in file :

                            if    (look & 1) and (line[0:9] == "csim.argv") :
                                idx = line[9:].find ('--')
                                self.csim_argv = re.sub (pattern, replace, line[idx+9:])
                                look &= ~1
                                if look == 0 : break

                            elif  (look & 2) and (line[0:8] == "sim.argv") :
                                idx = line[8:].find ('--')
                                self.sim_argv = re.sub (pattern, replace, line[idx+8:])
                                look &= ~2
                                if look == 0 : break

                            elif (look & 4) and (line[0:7] == 'syn.top') :
                                idx = line[7:].find ('=')
                                self.hls_top_level = line[idx+7+1:].strip ()
                                look &= ~4
                                if look == 0: break

                            elif (look&8) and (line[0:16]=='vivado.syn_dcp=1'):
                                look        &= ~8
                                self.syn_dcp = True
                                if look == 0: break


                except FileNotFoundError:
                    self.errs |= ComponentInfo.ErrNoCfgFile
                    if not silence_error :
                        print (f"Error; The {self.cfg_files} was not found")


        except FileNotFoundError:
            self.errs |= ComponentInfo.ErrNoCompPath
            if not silence_error :
                print(f"Error: The file '{vitis_comp_path}' was not found.")

        except json.JSONDecodeError as e:
            self.errs |= ComponentInfo.ErrJsonDecode
            if not silence_error :
                print(f"Error decoding JSON from '{vitis_comp_path}': {e}")

        except Exception as e:
            self.errs |= ComponentInfo.ErrUnknown
            if not silence_error :
                print(f"An unexpected error occurred: {e}")
# ------------------------------------------------------------------------------
