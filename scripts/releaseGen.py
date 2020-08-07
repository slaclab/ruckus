#-----------------------------------------------------------------------------
# Title      : Release generation
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
import git                 # GitPython
from github import Github  # PyGithub
import re
import releaseNotes

ghRepo = os.environ.get('TRAVIS_REPO_SLUG')
token  = os.environ.get('GH_REPO_TOKEN')
newTag = os.environ.get('TRAVIS_TAG')

if ghRepo is None:
    exit("TRAVIS_REPO_SLUG not in environment.")

if token is None:
    exit("GH_REPO_TOKEN not in environment.")

if newTag is None:
    exit("TRAVIS_TAG not in environment.")

# Check tag to make sure it is a proper release: va.b.c
vpat = re.compile('v?\d+\.\d+\.\d+')

if vpat.match(newTag) is None:
    exit("Not a release version")

# Git server
gh = Github(token)
remRepo = gh.get_repo(ghRepo)

# Find previous tag
oldTag = git.Git('.').describe('--abbrev=0','--tags',newTag + '^')

# Get release notes
md = releaseNotes.getReleaseNotes(locRepo = git.Git('.'), remRepo = remRepo, oldTag = oldTag, newTag = newTag)

def releaseType(ver):
    parts = str.split(ver.replace('v', ''), '.')
    if parts[-1] != '0':
        return 'Patch'
    if parts[-2] != '0':
        return 'Minor'
    return 'Major'

newName = f'{releaseType(newTag)} Release {newTag}'

# Check if tag already exists
try:
    remRepo.get_release(newTag)
except:
    # Create release using tag
    remRel = remRepo.create_git_release(tag=newTag, name=newName, message=md, draft=False)
    print("Success!")
else:
    exit(f'{newTag} release already exists')
