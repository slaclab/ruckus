#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : Firmware Release Generation
# ----------------------------------------------------------------------------
# Description:
# Script to generate rogue.zip and cpsw.tar.gz files as well as creating
# a github release with proper release attachments.
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
import yaml
import argparse
import zipfile
import tarfile

import git    # GitPython
import github # PyGithub

import re
from getpass import getpass
import releaseNotes

# Set the argument parser
parser = argparse.ArgumentParser('Release Generation')

# Add arguments
parser.add_argument(
    "--project",
    type     = str,
    required = True,
    help     = "Project directory path"
)

parser.add_argument(
    "--release",
    type     = str,
    required = False,
    default  = None,
    help     = "Release target to generate"
)

parser.add_argument(
    "--build",
    type     = str,
    required = False,
    default  = None,
    help     = "Build base name to include (for single target release), 'latest' to auto select"
)

parser.add_argument(
    "--version",
    type     = str,
    required = False,
    default  = None,
    help     = "Version value for release."
)

parser.add_argument(
    "--prev",
    type     = str,
    required = False,
    default  = None,
    help     = "Previous version for release notes comparison."
)

parser.add_argument(
    "--token",
    type     = str,
    required = False,
    default  = None,
    help     = "Token for github"
)

parser.add_argument(
    "--push",
    action   = 'count',
    help     = "Add --push arg to tag repository and push release to github"
)

# Get the arguments
args = parser.parse_args()

# Directories
FirmwareDir = args.project

# Detect empty release name
if args.release == "":
    args.release = None

def loadReleaseConfig():
    relFile = os.path.join(FirmwareDir,'releases.yaml')

    try:
        with open(relFile) as f:
            txt = f.read()
            cfg = yaml.load(txt)
    except Exception as e:
        raise Exception(f"Failed to load project release file {relFile}")

    if not 'GitBase' in cfg or cfg['GitBase'] is None:
        raise Exception("Invalid release config. GitBase key is missing or empty!")

    if not 'Releases' in cfg or cfg['Releases'] is None:
        raise Exception("Invalid release config. Releases key is missing or empty!")

    if not 'Targets' in cfg or cfg['Targets'] is None:
        raise Exception("Invalid release config. Targets key is missing or empty!")

    return cfg

def getVersion():
    ver  = args.version
    prev = args.prev

    if ver is None:
        ver = input('\nEnter version for release (i.e. v1.2.3): ')

    if args.push is not None:
        if prev is None:
            prev = input('\nEnter previous version for compare (i.e. v1.2.3) or enter for none: ')

    print(f'\nUsing version {ver} and previous version {prev}\n')

    return ver, prev

def releaseType(ver):
    parts = str.split(ver.replace('v', ''), '.')
    if parts[-1] != '0':
        return 'Patch'
    if parts[-2] != '0':
        return 'Minor'
    return 'Major'

def selectRelease(cfg):
    relName = args.release

    print("")
    print("Available Releases:")

    keyList = list(cfg['Releases'].keys())

    for idx,val in enumerate(keyList):
        print(f"    {idx}: {val}")

    if relName is not None:
        print(f"\nUsing command line arg release: {relName}")

        if relName not in keyList:
            raise Exception(f"Invalid command line release arg: {relName}")

    elif len(keyList) == 1:
        relName = keyList[0]
        print(f"\nAuto selecting release: {relName}")

    else:
        idx = int(input('\nEnter index ot release to generate: '))

        if idx >= len(keyList):
            raise Exception("Invalid release index")

        else:
            relName = keyList[idx]

    if '-' in relName:
        raise Exception(f"Invalid release name. Release names with '-' are not support in python!")

    relData = cfg['Releases'][relName]

    if not 'Targets' in relData or relData['Targets'] is None:
        raise Exception(f"Invalid release config. Targets list in release {relName} is missing or empty!")

    if not 'Types' in relData or relData['Types'] is None:
        raise Exception(f"Invalid release config. Types list in release {relName} is missing or empty!")

    if not 'Primary' in relData or relData['Primary'] is None:
        relData['Primary'] = False

    return relName, relData

def selectBuildImages(cfg, relName, relData):
    retList = []

    for target in relData['Targets']:

        if not target in cfg['Targets']:
            raise Exception(f"Invalid release config. Referenced target {target} is missing in target list.!")

        if not 'ImageDir' in cfg['Targets'][target] or cfg['Targets'][target]['ImageDir'] is None:
            raise Exception(f"Invalid release config. ImageDir for target {target} is missing or empty!")

        if not 'Extensions' in cfg['Targets'][target] or cfg['Targets'][target]['Extensions'] is None:
            raise Exception(f"Invalid release config. Extensions list for target {target} is missing or empty!")

        extensions = cfg['Targets'][target]['Extensions']
        imageDir = os.path.join(FirmwareDir,cfg['Targets'][target]['ImageDir'])

        buildName = args.build
        dirList = [f for f in os.listdir(imageDir) if os.path.isfile(os.path.join(imageDir,f))]

        print(f"\nFinding builds for target {target}:")

        # Get a list of build names with the format:
        #   buildName = $(PROJECT)-$(PRJ_VERSION)-$(BUILD_TIME)-$(USER)-$(GIT_HASH_SHORT)
        # File name will either be:
        #   buildName.extension
        # or
        #   buildName_subType.extension
        baseList = set()

        for fn in dirList:
            if target in fn:
                fileName = fn[len(target):]
                if '_' in fileName:
                    baseList.add(target+fileName.split('_')[0])
                else:
                    baseList.add(target+fileName.split('.')[0])

        sortList = sorted(baseList)
        for idx,val in enumerate(sortList):
            print(f"    {idx}: {val}")

        if buildName == 'latest':
            buildName = sortList[-1]
            print(f"\nAuto selecting latest build: {buildName}")

        elif buildName is not None:
            print(f"\nUsing command line arg build: {buildName}")

            if buildName not in sortList:
                raise Exception(f"Invalid command line build arg: {buildName}")

        else:
            idx = int(input('\nEnter index of build to include for target {}: '.format(target)))

            if idx >= len(sortList):
                raise Exception("Invalid build index")

            else:
                buildName = sortList[idx]

        tarExp = [re.compile(f'{buildName}\.{ext}$') for ext in extensions]
        tarExp.extend([re.compile(f'{buildName}_.\w*\.{ext}$') for ext in extensions])

        print(f"\nFinding images for target {target}, build {buildName}...")
        for f in dirList:
            for exp in tarExp:
                if exp.match(f):
                    print(f"    Found: {f}");
                    retList.append(os.path.join(imageDir,f))

    return retList

def genFileList(base,root,entries,typ):
    retList = []

    if '__pycache__' not in root:
        for e in entries:
            if '__pycache__' not in e:
                fullPath = os.path.join(root,e)
                subPath  = fullPath.replace(base+'/','')

                retList.append({'type':typ,
                                'fullPath':fullPath,
                                'subPath': subPath})

    return retList

def selectDirectories(cfg, key):
    retList = []

    if key in cfg and cfg[key] is not None:
        for d in cfg[key]:
            base = os.path.join(FirmwareDir,d)

            for root, folders, files in os.walk(base):
                retList.extend(genFileList(base,root,folders,'folder'))
                retList.extend(genFileList(base,root,files,'file'))

    return retList

def selectFiles(cfg, key):
    retList = []

    if key in cfg and cfg[key] is not None:
        for f in cfg[key]:
            retList.append(os.path.join(FirmwareDir,f))

    return retList

def buildCondaFiles(cfg,zipFile,ver,relName):

    # Create conda-recipe/build.sh
    tmpTxt =  '#!/usr/bin/bash\n\n'
    tmpTxt += 'python setup.py install\n\n'

    with zipFile.open('conda-recipe/build.sh','w') as f:
        f.write(tmpTxt.encode('utf-8'))

    # Conda names must be all lowercase
    relNameLower = relName.lower()

    # Create conda-recipe/meta.yaml
    tmpTxt =  'package:\n'
    tmpTxt += f'  name: {relNameLower}\n'
    tmpTxt += f'  version: {ver}\n'
    tmpTxt += f'\n'
    tmpTxt += 'source:\n'
    tmpTxt += f'  path: ..\n'
    tmpTxt += f'\n'
    tmpTxt += 'requirements:\n'
    tmpTxt += f'  build:\n'
    tmpTxt += f'    - rogue\n'
    tmpTxt += f'    - python\n'
    tmpTxt += f'    - setuptools\n'
    tmpTxt += f'\n'
    tmpTxt += f'  run:\n'
    tmpTxt += f'    - rogue\n'
    tmpTxt += f'    - python\n'

    if 'CondaDependencies' in cfg and cfg['CondaDependencies'] is not None:
        for f in cfg['CondaDependencies']:
            tmpTxt += f'    - {f}\n'

    tmpTxt += f'\n'
    tmpTxt += 'about:\n'
    tmpTxt += f'  license: SLAC Open License\n'
    tmpTxt += f'  license_file: LICENSE.txt\n'
    tmpTxt += f'\n'

    with zipFile.open('conda-recipe/meta.yaml','w') as f:
        f.write(tmpTxt.encode('utf-8'))

    # Conda build script
    tmpTxt  = '#!/usr/bin/bash\n\n'
    tmpTxt += 'conda build --debug conda-recipe --output-folder bld-dir -c tidair-tag -c conda-forge\n'
    tmpTxt += '\n'

    # Create conda.sh
    with zipFile.open('conda.sh','w') as f:
        f.write(tmpTxt.encode('utf-8'))

def buildSetupPy(zipFile,ver,relName,packList,sList):

    # setuptools version creates and installs a .egg file which will not work with
    # our image and config data! Use distutils version for now.
    setupPy  =  "\n\nfrom distutils.core import setup\n\n"
    #setupPy  =  "\n\nfrom setuptools import setup\n\n"
    setupPy +=  "setup (\n"
    setupPy += f"   name='{relName}',\n"
    setupPy += f"   version='{ver}',\n"
    setupPy +=  "   packages=[\n"

    for f in packList:
        setupPy += f"             '{f}',\n"

    # Close package section of setup.py
    setupPy +=  "            ],\n"

    # Close up setup.py file
    setupPy +=  "   package_dir={'':'python'},\n"
    setupPy +=  "   package_data={'" + cfg['TopRoguePackage'] + "':['config/*','images/*']},\n"

    if len(sList) != 0:
        setupPy +=  "   scripts=[\n"

        for f in sList:
            fn = 'scripts/' + os.path.basename(f)
            setupPy += f"             '{fn}',\n"

        setupPy +=  "            ],\n"

    setupPy += ")\n"

    with zipFile.open('setup.py','w') as sf: sf.write(setupPy.encode('utf-8'))


def buildRogueFile(zipName, cfg, ver, relName, relData, imgList):
    print("\nFinding Rogue Files...")
    pList = selectDirectories(cfg, 'RoguePackages')
    cList = selectDirectories(cfg, 'RogueConfig')
    sList = selectFiles(cfg,       'RogueScripts')

    if len(pList) == 0:
        raise Exception(f"Invalid release config. Rogue packages list is empty!")

    if not 'TopRoguePackage' in cfg or cfg['TopRoguePackage'] is None:
        raise Exception("Invalid release config. TopRoguePackage is not defined!")

    topInit = 'python/' + cfg['TopRoguePackage'] + '/__init__.py'
    topPath = None
    packList = []

    # zipimport does not support compression: https://bugs.python.org/issue21751
    with zipfile.ZipFile(file=zipName, mode='w', compression=zipfile.ZIP_STORED, compresslevel=None) as zf:
        print(f"\nCreating Rogue zipfile {zipName}")

        # Add license file, should be at top level
        lFile = os.path.join(args.project,cfg['GitBase'],'LICENSE.txt')
        zf.write(lFile,'LICENSE.txt')

        # Walk through collected python list
        for e in pList:
            dst = 'python/' + e['subPath']

            # Don't add raw version of TopRoguePackage/__init__.py
            # Save path name for later, otherwise add file to zipfile
            if dst == topInit:
                topPath = e['fullPath']
            else:
                zf.write(e['fullPath'],dst)

            # Add all package folders to setup.py file
            if e['type'] == 'folder':
                packList.append(e['subPath'])

        # Walk through collected configuration list
        for e in cList:
            dst = 'python/' + cfg['TopRoguePackage'] + '/config/' + e['subPath']
            zf.write(e['fullPath'],dst)

        # Walk through collected image list
        for e in imgList:
            # Check if a .gz version exists
            if os.path.isfile(e + '.gz'):
                # Write the compressed version into the rogue_XXX.zip instead
                img = e + '.gz'
            else:
                # Using non-compressed version of the file
                img = e
            dst = 'python/' + cfg['TopRoguePackage'] + '/images/' + os.path.basename(img)

            # Check that the file does NOT already exists
            if dst not in zf.namelist():
                zf.write(img,dst)

        # Walk through collected script list
        for e in sList:
            dst = 'scripts/' + os.path.basename(e)
            zf.write(e,dst)

        if topPath is None:
            raise Exception(f"Failed to find file: firmware/python/{topInit}")

        with open(topPath,'r') as f:
            newInit = ""

            for line in f:
                if (not 'import os'   in line) and \
                   (not '__version__' in line) and \
                   (not 'ConfigDir'   in line) and \
                   (not 'ImageDir'    in line): newInit += line

        # Append new lines
        newInit += "\n\n"
        newInit += "##################### Added by release script ###################\n"
        newInit += "import os\n"
        newInit += f"__version__ = '{ver}'\n"
        newInit += "ConfigDir = os.path.dirname(__file__) + '/config'\n"
        newInit += "ImageDir  = os.path.dirname(__file__) + '/images'\n"
        newInit += "#################################################################\n"

        with zf.open(topInit,'w') as f:
            f.write(newInit.encode('utf-8'))

        # Add setup.py file
        buildSetupPy(zf,ver,relName,packList,sList)

        # Add conda files
        buildCondaFiles(cfg,zf,ver,relName)


def buildCpswFile(tarName, cfg, ver, relName, relData, imgList):
    print("\nFinding CPSW Files...")
    sList = selectDirectories(cfg, 'CpswSource')
    cList = selectDirectories(cfg, 'CpswConfig')

    baseDir = relName + '_project.yaml'

    if len(sList) == 0:
        raise Exception(f"Invalid release config. Cpsw packages list is empty!")

    with tarfile.open(tarName,'w:gz') as tf:
        print(f"\nCreating CPSW tarfile {tarName}")

        for e in sList:
            if e['type'] == 'file':
                tf.add(name=e['fullPath'],arcname=baseDir+'/'+e['subPath'],recursive=False)

        for e in cList:
            if e['type'] == 'file':
                tf.add(name=e['fullPath'],arcname=baseDir+'/config/'+e['subPath'],recursive=False)

def pushRelease(cfg, relName, relData, ver, tagAttach, prev):
    gitDir = os.path.join(args.project,cfg['GitBase'])

    print(f"GitDir = {gitDir}")

    locRepo = git.Repo(gitDir)

    url = locRepo.remote().url
    if not url.endswith('.git'): url += '.git'

    # Get the git repo's name (assumption that exists in the github.com/slaclab organization)
    project = re.compile(r'slaclab/(?P<name>.*?)(?P<ext>\.git?)').search(url).group('name')

    # Prevent "dirty" git clone (uncommitted code) from pushing tags
    if locRepo.is_dirty():
        raise(Exception("Cannot create tag! Git repo is dirty!"))

    # Check if this is a primary release
    if relData['Primary']:
        tag = f'{ver}'
        msg = f'{releaseType(ver)} Release {ver}'
    else:
        tag = f'{relName}_{ver}'
        msg = f'{relName} {releaseType(ver)} Release {ver}'

    print("\nLogging into github....\n")

    if args.token is not None:
        print("Using github token from command line arg.")
        token = args.token
    else:
        token = os.environ.get('GITHUB_TOKEN')

        if token is None:
            print("Enter your github token. If you do no have one you can generate it here:");
            print("    https://github.com/settings/tokens");
            print("You may set it in your environment as GITHUB_TOKEN")
            token = input("\nGithub token: ");
        else:
            print("Using github token from user's environment.")

    gh = github.Github(token)
    remRepo = gh.get_repo(f'slaclab/{project}')

    print(f"\nCreating and pushing tag {tag} .... ")
    newTag = locRepo.create_tag(path=tag, message=msg)
    locRepo.remotes.origin.push(newTag)

    if prev != "":
        if relData['Primary']:
            relOld = prev
            relNew = ver
        else:
            relOld = '{relName}_{prev}'
            relNew = '{relName}_{ver}'

        print("\nGenerating release notes ...")
        md = releaseNotes.getReleaseNotes(git.Git(gitDir), remRepo, oldTag=relOld, newTag=relNew)
    else:
        md = "No release notes"

    md += "\n\nRelease generated with SLAC ruckus releaseGen script\n"

    remRel = remRepo.create_git_release(tag=tag,name=msg, message=md, draft=False)

    print("\nUploading attachments ...")
    for t in tagAttach:
        remRel.upload_asset(t)


if __name__ == "__main__":
    cfg = loadReleaseConfig()
    relName,relData = selectRelease(cfg)
    imgList = selectBuildImages(cfg,relName,relData)
    ver, prev = getVersion()

    print("Release = {}".format(relName))
    print("Version = {}".format(ver))
    print("Images  = ")
    for imgName in imgList:
        print("\t{}".format(imgName))

    tagAttach = imgList

    # Determine if we generate a Rogue zipfile
    if 'Rogue' in relData['Types']:

        if relData['Primary']: zipName = os.path.join(os.getcwd(),f'rogue_{ver}.zip')
        else: zipName = os.path.join(os.getcwd(),f'rogue_{relName}_{ver}.zip')

        buildRogueFile(zipName,cfg,ver,relName,relData,imgList)
        tagAttach.append(zipName)

    # Determine if we generate a CPSW tarball
    if 'CPSW' in relData['Types']:
        tarName = f'cpsw_{relName}_{ver}.tar.gz'
        buildCpswFile(tarName,cfg,ver,relName,relData,imgList)
        tagAttach.append(tarName)

    if args.push is not None:
        pushRelease(cfg,relName,relData,ver,tagAttach,prev)

