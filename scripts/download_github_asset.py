# ----------------------------------------------------------------------------
# Description: Used to download an asset from a tag release on Github
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
import requests
from github import Github # PyGithub
import argparse

# Set up argument parsing
parser = argparse.ArgumentParser(description="Download assets from GitHub releases in private repositories.")
parser.add_argument("--repo_name", type=str, required=True, help="Repository name, e.g., 'slaclab/epix-hr-m-320k'")
parser.add_argument("--asset_name", type=str, required=True, help="Asset name to download, e.g., 'ePixHRM320k-0x01000400-20240323061941-dnajjar-ff123db.mcs'")
parser.add_argument("--release_tag", type=str, required=True, help="Release tag, e.g., 'v1.1.4'")

args = parser.parse_args()

# Ensure GITHUB_TOKEN is set in your environment variables
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
if GITHUB_TOKEN is None:
    raise ValueError("GITHUB_TOKEN environment variable not set.")

# Initialize PyGithub with the GitHub token for authentication
g = Github(GITHUB_TOKEN)

# Use the arguments for the repository name, asset name, and release tag
repo_name = args.repo_name
asset_name = args.asset_name
release_tag = args.release_tag

# Get the repository object
repo = g.get_repo(repo_name)

# Get the release by tag
release = repo.get_release(release_tag)

# Find the correct asset by name
asset_to_download = None
for asset in release.get_assets():
    if asset.name == asset_name:
        asset_to_download = asset
        break

if asset_to_download is not None:
    # The API provides an authenticated URL for assets in private repositories
    asset_url = asset_to_download.url

    headers = {'Authorization': f'token {GITHUB_TOKEN}', 'Accept': 'application/octet-stream'}
    response = requests.get(asset_url, headers=headers, stream=True)

    if response.status_code == 200:
        with open(asset_name, 'wb') as file:
            for chunk in response.iter_content(chunk_size=128):
                file.write(chunk)
        print(f"Downloaded {asset_name}")
    else:
        print(f"Failed to download {asset_name}: {response.status_code}")
else:
    print("Asset not found in the release.")
