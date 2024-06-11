#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : Release notes generation
# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------

##
# @file releaseNotes.py
# Generate release notes for pull requests relative to a tag.

from collections import OrderedDict as odict
import re


def getReleaseNotes(locRepo, remRepo, oldTag, newTag):

    # Get logs
    loginfo = locRepo.log(f"{oldTag}...{newTag}", '--grep', "Merge pull request")

    # Grouping of recors
    records = odict({'Bug': [],
                     'Enhancement': [],
                     'Documentation': [],
                     'Interface-change': [],
                     'Unlabeled': []})

    details = []
    entry = {}

    # Parse the log entries
    for line in loginfo.splitlines():

        if line.startswith('Author:'):
            entry['Author'] = line[7:].lstrip()

        elif line.startswith('Date:'):
            entry['Date'] = line[5:].lstrip()

        elif 'Merge pull request' in line:
            entry['PR'] = line.split()[3].lstrip()
            entry['Branch'] = line.split()[5].lstrip()

            # Get PR info from github
            req = remRepo.get_pull(int(entry['PR'][1:]))

            # Check for empty PR description
            if not req.body or req.body.strip() == "":
                pr_url = f"https://github.com/{remRepo.full_name}/pull/{entry['PR'][1:]}"
                raise ValueError(f"Pull request {entry['PR']} has an empty description. Please open your web browser, go to this PR, and fill in the description: {pr_url}")

            # Detect Release Candidate PRs
            if ('main' in req.base.label or 'master' in req.base.label) and 'pre-release' in req.head.label:
                entry['IsRC'] = True

            entry['Title'] = req.title
            entry['body'] = req.body

            entry['changes'] = req.additions + req.deletions
            entry['Pull'] = entry['PR'] + f" ({req.additions} additions, {req.deletions} deletions, {req.changed_files} files changed)"

            # Detect JIRA entry
            if entry['Branch'].lower().startswith('slaclab/es'):
                url = 'https://jira.slac.stanford.edu/issues/{}'.format(entry['Branch'].split('/')[1])
                entry['Jira'] = url
            else:
                entry['Jira'] = None

            entry['Labels'] = None
            for lbl in req.get_labels():
                if entry['Labels'] is None:
                    entry['Labels'] = lbl.name.lower()
                else:
                    entry['Labels'] += ', ' + lbl.name.lower()

            # Attempt to locate any issues mentioned in the body and comments
            entry['Issues'] = None

            # Generate a list with the bodies of the PR and all its comments
            bodies = [entry['body']]
            for c in req.get_issue_comments():
                bodies.append(c.body)

            # Look for the pattern '#\d+' in all the bodies, and add then to the
            # entry['Issues'] list, avoiding duplications
            for body in bodies:
                iList = re.compile(r'(#\d+)').findall(body)
                if iList is not None:
                    for issue in iList:
                        if entry['Issues'] is None:
                            entry['Issues'] = issue
                        elif issue not in entry['Issues']:
                            entry['Issues'] += ', ' + issue

            # Add both to details list and sectioned summary list
            found = False
            if entry['Labels'] is not None:
                for label in records.keys():

                    if label.lower() in entry['Labels']:
                        records[label].append(entry)
                        found = True

            if not found:
                records['Unlabeled'].append(entry)

            details.append(entry)
            entry = {}

    # Generate summary text
    md = f'# Pull Requests Since {oldTag}\n'

    # Summary list is sectioned
    for label in ['Interface-change', 'Bug', 'Enhancement', 'Documentation', 'Unlabeled']:
        subLab = ""

        # Sort by changes
        entries = sorted(records[label], key=lambda v: v['changes'], reverse=True)

        for entry in entries:
            if 'IsRC' not in entry:
                subLab += f" 1. {entry['PR']} - {entry['Title']}\n"

        if len(subLab) > 0:
            md += f"### {label}\n" + subLab

    # Detailed list
    det = '# Pull Request Details\n'

    # Sort records by pull request number
    details = sorted(details, key=lambda v: v['PR'], reverse=False)

    # Generate detailed PR notes
    for entry in details:
        if 'IsRC' not in entry: # Don't generate output for Release Candidate PRs
            det += f"### {entry['Title']}"
            det += '\n|||\n|---:|:---|\n'

            for i in ['Author', 'Date', 'Pull', 'Branch', 'Issues', 'Jira', 'Labels']:
                if entry[i] is not None:
                    det += f'|**{i}:**|{entry[i]}|\n'

            det += '\n**Notes:**\n'
            for line in entry['body'].splitlines():
                det += '> ' + line + '\n'
            det += '\n-------\n'
            det += '\n\n'


    # Include details
    md += det

    return md

if __name__ == "__main__":
    import os

    import git   # https://gitpython.readthedocs.io/en/stable/tutorial.html
    from github import Github # https://pygithub.readthedocs.io/en/latest/introduction.html

    # Get most recent and previous tag
    newTag = git.Git('.').describe('--tags')
    oldTag = git.Git('.').describe('--abbrev=0','--tags',newTag + '^')

    print(f"Using range: {oldTag}...{newTag}")

    # Local git clone
    locRepo = git.Git('.')

    url = locRepo.remote('get-url','origin')
    if not url.endswith('.git'):
        url += '.git'

    project = re.compile(r'slaclab/(?P<name>.*?).git').search(url).group('name')

    # Connect to the Git server
    token = os.environ.get('GITHUB_TOKEN')

    if token is None:
        print("Enter your github token. If you do no have one you can generate it here:")
        print("    https://github.com/settings/tokens")
        print("You may set it in your environment as GITHUB_TOKEN")
        token = input("\nGithub token: ")

    else:
        print("Using github token from user's environment.")

    github = Github(token)

    # Get the repo information
    remRepo = github.get_repo(f'slaclab/{project}')

    md = getReleaseNotes(
        locRepo  = locRepo,
        remRepo  = remRepo,
        oldTag   = oldTag,
        newTag   = newTag)

    print(md)
