import os
import subprocess

def display_manpage (cmd_path) :

    cmd_dirnam       = os.path.splitext (cmd_path)[0]
    cmd_dir, cmd_nam = os.path.split (cmd_dirnam)
    man_nam          = cmd_nam + '.1'
    cmd_dir          = os.path.join (os.path.split (cmd_dir)[0], 'man1')
    man_path         = os.path.join (cmd_dir, man_nam)

    try :
        subprocess.run (['man', man_path])
    except :
        pass
        #print (f"'man' command {cmd_nam} not found", file=sys.stderr)
