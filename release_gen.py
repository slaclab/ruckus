#!/usr/bin/env python3

import os
import yaml
import argparse
import zipfile

FirmwareDir = os.path.join(os.getenv('PROJECT'), 'firmware')
ReleaseDir  = os.path.join(FirmwareDir,'build','releases')

# Set the argument parser
parser = argparse.ArgumentParser('Release Generation')

# Add arguments
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
    help     = "Build base name to include (for single target release)"
)

parser.add_argument(
    "--version", 
    type     = str,
    required = False,
    default  = None,
    help     = "Version value for release."
)

# Get the arguments
args = parser.parse_args()







def loadReleaseYaml():
    relFile = os.path.join(FirmwareDir,'releases.yaml')

    try:
        with open(relFile) as f:
            txt = f.read()
            d = yaml.load(txt)
    except Exception as e:
        raise Exception(f"Failed to load project release file {relFile}")

    return d

def selectRelease(cfg):

    rel = args.release

    if rel is None:
        print("")
        print("Available Releases:")
        keyList = list(cfg['Releases'].keys())

        for idx,val in enumerate(keyList):
            print(f"    {idx}: {val}")

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

        if buildName is None:
            print(f"\nFinding builds for target {target}:")

            # Get a list of images
            baseList = set()

            for fn in dirList:
                if target in fn:
                    baseList.add(fn.split('.')[0])

            sortList = sorted(baseList)
            for idx,val in enumerate(sortList):
                print(f"    {idx}: {val}")

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

def selectConfigDirs(cfg, relData):
    retList = []

    if cfg['CommonConfig']:
        for conf in cfg['CommonConfig']:
            retList.append(os.path.join(FirmwareDir,conf))

    if relData['Config']:
        for conf in relData['Config']:
            retList.append(os.path.join(FirmwareDir,conf))

    return retList

def selectPythonDirs(cfg, relData):
    retList = []

    if cfg['CommonPython']:
        for py in cfg['CommonPython']:
            retList.append(os.path.join(FirmwareDir,py))

    if relData['Python']:
        for py in relData['Python']:
            retList.append(os.path.join(FirmwareDir,py))

    return retList

def getVersion():
    ver = args.version

    if ver is None:
        ver = input('\nEnter version for release (i.e. v1.2.3): ')

    return ver

def addFolderToZip(zf, srcPath, arcPath):
    contents = os.walk(srcPath)
    parent = os.path.dirname(srcPath)

    for root, folders, files in contents:

        # Include add folders & files
        for fn in folders + files:
            absPath = os.path.join(root,fn)
            zipPath = absPath.replace(srcPath,arcPath)
            zf.write(absPath,zipPath)

def createSetupPy(cfg, ver, relName, relData):
    pass

def buildZipFile(cfg, ver, relName, relData, imgList):
    rel = f'{relName}_{ver}'

    with zipfile.ZipFile(rel + '.zip','w') as zf:
        print(f"\nCreating zipfile {rel}.zip")

        for pd in selectPythonDirs(cfg, relData):
            print(f"   {pd}")
            addFolderToZip(zf,pd,'python')

        for cd in selectConfigDirs(cfg, relData):
            print(f"   {cd}")
            addFolderToZip(zf,cd,'config')
            zf.write(cd)

        for im in imgList:
            print(f"   {im}")
            zf.write(im,'images/' + os.path.basename(im))

if __name__ == "__main__":
    cfg = loadReleaseYaml()
    ver = getVersion()
    relName,relData = selectRelease(cfg)
    imgList = selectBuildImages(cfg,relData)

    print("Release = {}".format(relName))
    print("Images = {}".format(imgList))
    print("Version = {}".format(ver))

    buildZipFile(cfg,ver,relName,relData,imgList)

