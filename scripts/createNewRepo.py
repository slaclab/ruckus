#!/usr/bin/env python3
# ----------------------------------------------------------------------------
# Description: Script to create a new github repo
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
import argparse
import time

import github # PyGithub

#############################################################################################

# Convert str to bool
def argBool(s):
    return s.lower() in ['true', 't', 'yes', '1']

# Set the argument parser
parser = argparse.ArgumentParser('Create New Project')

# Add arguments
parser.add_argument(
    '--name',
    type     = str,
    required = True,
    help     = 'New Repo name for https://github.com/ (example: slaclab/my-new-project)',
)

parser.add_argument(
    '--token',
    type     = str,
    required = False,
    default  = None,
    help     = 'Token for github'
)

parser.add_argument(
    '--private',
    type     = argBool,
    required = False,
    default  = True,
    help     = 'Privacy Setting for new repo: Set true (default) if private repo.  Set false if public repo',
)

parser.add_argument(
    '--org',
    type     = str,
    required = False,
    default  = 'slaclab',
    help     = 'Name of Github organization repository (default: slaclab)',
)

parser.add_argument(
    '--userRepo',
    type     = argBool,
    required = False,
    default  = False,
    help     = 'Set true if you want to make the repo in your user\'s workspace instead of an organization workspace',
)

parser.add_argument(
    '--submodules',
    nargs    = '+',
    required = False,
    default  =  ['https://github.com/slaclab/ruckus.git',
                 'https://github.com/slaclab/surf.git',],
    help     = 'List of submodules'
)

##########################
## Adding User Permissions
##########################
parser.add_argument(
    '--adminUser',
    nargs    = '+',
    required = False,
    default  = None,
    help     = 'List of admin users'
)

parser.add_argument(
    '--writeUser',
    nargs    = '+',
    required = False,
    default  = None,
    help     = 'List of write users'
)

parser.add_argument(
    '--readUser',
    nargs    = '+',
    required = False,
    default  = None,
    help     = 'List of read users'
)

##########################
## Adding Team Permissions
##########################

parser.add_argument(
    '--adminTeam',
    nargs    = '+',
    required = False,
    default  = [ ['slaclab','tid-id-es-admin'] ],
    help     = 'List of admin teams [org,team_name]'
)

parser.add_argument(
    '--writeTeam',
    nargs    = '+',
    required = False,
    default  = [ ['slaclab','tid-id-es'] ],
    help     = 'List of write teams [org,team_name]'
)

parser.add_argument(
    '--readTeam',
    nargs    = '+',
    required = False,
    default  = None,
    help     = 'List of read teams'
)

# Get the arguments
args = parser.parse_args()

#############################################################################################

def githubLogin():

    # Inform the user that you are logging in
    print('\nLogging into github....\n')

    # Check if token arg defined
    if args.token is not None:

        # Inform the user that command line arg is being used
        print('Using github token from command line arg.')

        # Set the token value
        token = args.token

    # Check if token arg NOT defined
    else:

        # Set the token value from environmental variable
        token = os.environ.get('GITHUB_TOKEN')

        # Check if token is NOT defined
        if token is None:

            # Ask for the token from the command line prompt
            print('Enter your github token. If you do no have one you can generate it here:')
            print('    https://github.com/settings/tokens')
            print('You may set it in your environment as GITHUB_TOKEN\n')

            # Set the token value
            token = input('\nGithub token: ')

        # Else the token was defined
        else:

            # Inform the user that you are using GITHUB_TOKEN
            print('Using github token from user\'s environment.\n')

    # Now that you have a token, log into Github
    gh = github.Github(token)

    # Return the github login object
    return gh

#############################################################################################

def createNewRepo(gh):

    # Check if creating repo in user's workspace
    if args.userRepo:

        # Get the user works space
        workspace = gh.get_user()

    # Else creating repo in organization space
    else:

        # Get the organization
        workspace = gh.get_organization(args.org)

    # Create the repo in the workspace
    repo = workspace.create_repo(
        name      = args.name,
        private   = args.private,
        auto_init = True,
    )

    # Inform the user that the repo was created
    print(f'Created \"https://github.com/{repo.full_name}\" repo\n')

    # Return the Github repo object
    return repo

#############################################################################################

def setPermissions(gh,repo):

    # Inform the user that you are logging in
    print('Setting Git repo permissions...')

    # Always set the current user who created the repo as admin
    currentUser = gh.get_user().login
    print( f'Current User Admin Permission: {currentUser}' )
    repo.add_to_collaborators(
        collaborator = currentUser,
        permission   = 'admin',
    )

    ##########################
    ## Adding User Permissions
    ##########################

    # Check for list of users with admin permissions
    if args.adminUser is not None:
        for user in args.adminUser:
            print( f'User Admin Permission: {user}' )
            repo.add_to_collaborators(
                collaborator = user,
                permission   = 'admin',
            )

    # Check for list of users with write permissions
    if args.writeUser is not None:
        for user in args.writeUser:
            print( f'User Write Permission: {user}' )
            repo.add_to_collaborators(
                collaborator = user,
                permission   = 'push',
            )

    # Check for list of users with read permissions
    if args.readUser is not None:
        for user in args.readUser:
            print( f'User Read Permission: {user}' )
            repo.add_to_collaborators(
                collaborator = user,
                permission   = 'pull',
            )

    ##########################
    ## Adding Team Permissions
    ##########################

    # Check for list of teams with admin permissions
    if args.adminTeam is not None:
        for [orgName, teamName] in args.adminTeam:
            print( f'Team Admin Permission: {orgName}/{teamName}' )
            org = gh.get_organization(orgName)
            team = org.get_team_by_slug(teamName)
            updateTeamRepository(team, repo, 'admin')

    # Check for list of teams with write permissions
    if args.writeTeam is not None:
        for [orgName, teamName] in args.writeTeam:
            print( f'Team Write Permission: {orgName}/{teamName}' )
            org = gh.get_organization(orgName)
            team = org.get_team_by_slug(teamName)
            updateTeamRepository(team, repo, 'push')

    # Check for list of teams with read permissions
    if args.readTeam is not None:
        for [orgName, teamName] in args.readTeam:
            print( f'Team Read Permission: {orgName}/{teamName}' )
            org = gh.get_organization(orgName)
            team = org.get_team_by_slug(teamName)
            updateTeamRepository(team, repo, 'pull')

    print('\n')

#############################################################################################

# Team.set_repo_permission() is deprecated, use Team.update_team_repository() instead
def updateTeamRepository(team, repo, permission):
    try:
        team.update_team_repository(repo, permission)
    except:
        team.set_repo_permission(repo, permission)

#############################################################################################

def setupNewRepoStructure(repo):

    # Setting up the new Github repo's file structure and submodules
    print('Setting up the new Github repo\'s file structure and submodules...')

    # Get the base ruckus directory
    baseDir = os.path.realpath(__file__).split('scripts')[0]

    # Add the LICENSE.txt
    repo.create_file(
        path    = 'LICENSE.txt',
        message = 'Adding License.txt',
        content = open(f'{baseDir}/LICENSE.txt').read(),
    )

    # Add the .gitignore
    repo.create_file(
        path    = '.gitignore',
        message = 'Adding .gitignore',
        content = open(f'{baseDir}/.gitignore').read(),
    )

    # Add the .gitattributes
    repo.create_file(
        path    = '.gitattributes',
        message = 'Adding .gitattributes',
        content = open(f'{baseDir}/.gitattributes').read(),
    )

    # Check if submodule path(s) exist
    if args.submodules is not None:

        #####################################################
        # I couldn't find a python API for submodules ...
        # so I am going to do this step using an actual clone
        # A.K.A. "brute force method"
        #####################################################
        time.sleep(10)
        os.system(f'git clone --recursive https://github.com/{repo.full_name}')
        os.system(f'cd {args.name}; mkdir firmware; cd firmware; mkdir submodules; git pull')
        for submodule in args.submodules:
            os.system(f'cd {args.name}/firmware/submodules; git submodule add {submodule}')
        os.system(f'cd {args.name}; git commit -m \"adding submdoules\"; git push')
        os.system(f'rm -rf {args.name}')

    print('\n')

#############################################################################################

def setBranchProtection(repo):
    # Creating Setting Branch Protection for main
    print('Creating Setting Branch Protection for main...\n')
    for idx in ['main']:
        repo.get_branch(idx).edit_protection()

#############################################################################################

if __name__ == '__main__':

    # Log into Github
    gh   = githubLogin()

    # Create a new Github repo
    repo = createNewRepo(gh)

    # Set the User/Team permissions
    setPermissions(gh,repo)

    # Setup the new repo's structure
    setupNewRepoStructure(repo)

    # Set the branch protections
    setBranchProtection(repo)

    # Create first initial release
    repo.create_git_release(
        tag     = 'v0.0.0',
        name    = 'Initial Release',
        message = 'First Tagged Release',
        draft   =False,
    )

    print("Success!")
