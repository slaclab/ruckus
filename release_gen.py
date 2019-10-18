#!/usr/bin/env python3

import os
import yaml
import argparse
import zipfile

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
    "--user", 
    type     = str, 
    required = False,
    default  = None,
    help     = "Username for github"
)

parser.add_argument(
    "--password",
    type     = str, 
    required = False,
    default  = None,
    help     = "Password for github"
)

parser.add_argument(
    "--push", 
    action   = 'count',
    help     = "Add --push arg to tag repository and push release to github"
)

# Get the arguments
args = parser.parse_args()

# Directories
FirmwareDir = os.path.join(args.project, 'firmware')
ReleaseDir  = os.path.join(FirmwareDir,'build','releases')


def loadReleaseYaml():
    relFile = os.path.join(FirmwareDir,'releases.yaml')

    try:
        with open(relFile) as f:
            txt = f.read()
            d = yaml.load(txt)
    except Exception as e:
        raise Exception(f"Failed to load project release file {relFile}")

    return d

def getVersion():
    ver  = args.version
    prev = args.prev

    if ver is None:
        ver = input('\nEnter version for release (i.e. v1.2.3): ')

    if prev is None:
        prev = input('\nEnter previous version for compare (i.e. v1.2.3): ')

    print(f'\nUsing version {ver} and previous version {prev}\n')

    return ver, prev

def selectRelease(cfg):

    rel = args.release

    print("")
    print("Available Releases:")
    keyList = list(cfg['Releases'].keys())

    for idx,val in enumerate(keyList):
        print(f"    {idx}: {val}")

    if rel is not None:
        print(f"\nUsing command line arg release: {rel}")

        if rel not in keyList:
            raise Exception(f"Invalid command line release arg: {rel}")

    elif len(keyList) == 1:
        rel = keyList[0]
        print(f"\nAuto selecting release: {rel}")

    else:
        idx = int(input('\nEnter index ot release to generate: '))

        if idx >= len(keyList):
            raise Exception("Invalid release index")

        else:
            rel = keyList[idx]

    return rel, cfg['Releases'][rel]

def selectBuildImages(cfg, relData):
    retList = []

    for target in relData['Targets']:
        imageDir = os.path.join(FirmwareDir,'targets',target,'images')
        extensions = cfg['Targets'][target]['Extensions']

        buildName = args.build
        dirList = [f for f in os.listdir(imageDir) if os.path.isfile(os.path.join(imageDir,f))]

        print(f"\nFinding builds for target {target}:")

        # Get a list of images
        baseList = set()

        for fn in dirList:
            if target in fn:
                baseList.add(fn.split('.')[0])

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

        tarList = [f'{buildName}.{ext}' for ext in extensions]

        print(f"\nFinding images for target {target}, build {buildName}...")
        for f in dirList:
            if f in tarList:
                retList.append(os.path.join(imageDir,f))

    return retList

def genFileList(base,root,entries,typ):
    retList = []

    for e in entries:
        fullPath = os.path.join(root,e)
        subPath  = fullPath.replace(base+'/','')

        retList.append({'type':typ,
                        'fullPath':fullPath,
                        'subPath': subPath})
    return retList

def selectFiles(dirs):
    retList = []

    for d in dirs:
        base = os.path.join(FirmwareDir,d)

        for root, folders, files in os.walk(base):
            retList.extend(genFileList(base,root,folders,'folder'))
            retList.extend(genFileList(base,root,files,'file'))

    return retList

def selectConfigFiles(cfg, relData):
    dirs    = []

    if cfg['CommonConfig']:
        dirs.extend(cfg['CommonConfig'])

    if relData['Config']:
        dirs.extend(relData['Config'])

    return selectFiles(dirs)

def selectPythonFiles(cfg, relData):
    dirs    = []

    if cfg['CommonPython']:
        dirs.extend(cfg['CommonPython'])

    if relData['Python']:
        dirs.extend(relData['Python'])

    return selectFiles(dirs)

def buildRogueFile(zipName, cfg, ver, relName, relData, imgList):
    pList = selectPythonFiles(cfg, relData)
    cList = selectConfigFiles(cfg, relData)

    setupPy  =  "\n\nfrom distutils.core import setup\n\n"
    #setupPy  =  "\n\nfrom setuptools import setup\n\n"
    setupPy +=  "setup (\n"
    setupPy += f"   name='{relName}',\n"
    setupPy += f"   version='{ver}',\n"
    setupPy +=  "   packages=[\n"

    topInit = cfg['TopPackage'] + '/__init__.py'
    topPath = None

    with zipfile.ZipFile(zipName,'w') as zf:
        print(f"\nCreating zipfile {zipName}")

        for e in pList:
            dst = e['subPath']
            #print(f"   {dst}")

            # Don't add raw version of TopPackage/__init__.py
            if e['subPath'] == topInit:
                topPath = e['fullPath']
            else:
                zf.write(e['fullPath'],dst)

            if e['type'] == 'folder':
                setupPy +=  "             '{}',\n".format(dst)

        setupPy +=  "            ],\n"

        for e in cList:
            dst = cfg['TopPackage'] + '/config/' + e['subPath']
            #print(f"   {dst}")
            zf.write(e['fullPath'],dst)

        for e in imgList:
            dst = cfg['TopPackage'] + '/images/' + os.path.basename(e)
            #print(f"   {dst}")
            zf.write(e,dst)

        # Generate setup.py payload
        setupPy +=  "   package_data={'" + cfg['TopPackage'] + "':['config/*','images/*']}\n"
        setupPy += ")\n"

        with zf.open('setup.py','w') as sf: sf.write(setupPy.encode('utf-8'))

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

def pushRelease(relName, ver, tagAttach, prev):
    locRepo = git.Repo(args.project)

    url = locRepo.remote().url
    if not url.endswith('.git'): url += '.git'

    project = re.compile(r'slaclab/(?P<name>.*?)(?P<ext>\.git?)').search(url).group('name')

    if locRepo.is_dirty():
        raise(Exception("Cannot create tag! Git repo is dirty!"))

    tag = f'{relName}_{ver}'
    msg = f'{relName} version {ver}'

    print(f"\nCreating and pushing tag {tag} .... ")
    newTag = locRepo.create_tag(path=tag, message=msg)
    locRepo.remotes.origin.push(newTag)

    print("\nLogging into github....")

    if args.user is None:
        username = input("Username for github: ")
    else:
        username = args.user

    if args.password is None:
        password = getpass("Password for github: ")
    else:
        password = args.password

    tagRange = f'{relName}_{prev}..{relName}_{ver}'

    gh = github.Github(username,password)
    remRepo = gh.get_repo(f'slaclab/{project}')

    print("\nGenerating release notes ...")
    md = releaseNotes.getReleaseNotes(git.Git(args.project), remRepo, tagRange)
    remRel = remRepo.create_git_release(tag=tag,name=msg, message=md, draft=False)

    print("\nUploading attahments ...")
    for t in tagAttach:
        remRel.upload_asset(t)

if __name__ == "__main__":
    cfg = loadReleaseYaml()
    relName,relData = selectRelease(cfg)
    imgList = selectBuildImages(cfg,relData)
    ver, prev = getVersion()

    print("Release = {}".format(relName))
    print("Images = {}".format(imgList))
    print("Version = {}".format(ver))

    tagAttach = imgList

    # Determine if we generate a Rogue zipfile
    if 'Rogue' in relData['Types']:
        zipName = f'rogue_{relName}_{ver}.zip'
        buildRogueFile(zipName,cfg,ver,relName,relData,imgList)
        tagAttach.append(zipName)

    # Determine if we generate a Rogue zipfile
    if 'CPSW' in relData['Types']:
        print("Not sure how to do cpsw release yet!")
        pass

    if args.push is not None:
        pushRelease(relName,ver,tagAttach,prev)


