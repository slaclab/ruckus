How to Publish a Firmware Release
==================================

**Goal:** Tag a versioned firmware release on GitHub, package build artifacts, and
publish release notes using the ruckus release workflow.

Prerequisites
-------------

- A completed ``make bit`` build with artifacts in ``images/``
- A ``releases.yaml`` file at the firmware repository root (created in Step 1)
- A GitHub personal access token with ``repo`` scope set in the ``GITHUB_TOKEN``
  environment variable
- Python packages installed: ``pip install gitpython pygithub pyyaml``
- A clean git working tree — uncommitted changes will cause the script to abort

Step 1: Create ``releases.yaml``
---------------------------------

Create ``releases.yaml`` at the firmware repository root. This file describes what
artifacts to package. The minimum required schema is:

.. code-block:: yaml

   GitBase: firmware

   Targets:
     MyTarget:
       ImageDir: firmware/targets/MyTarget/images
       Extensions: [bit, mcs]

   Releases:
     MyRelease:
       Targets: [MyTarget]
       Types: [Rogue]
       Primary: true

.. note::

   Release names must NOT contain a hyphen (``-``). The release script rejects names
   with hyphens. Use underscores instead (e.g., ``MyRelease`` not ``My-Release``).

**Schema fields:**

- ``GitBase`` — base directory of the firmware git submodule (usually ``firmware``)
- ``Targets`` — map of build targets; each entry specifies where images live and what
  file extensions to include in the release archive
- ``Releases`` — map of release configurations; each entry specifies which targets to
  package, the archive type, and whether this is the primary release

**Release tag format:**

- Primary release (``Primary: true``): tag ``v1.2.3``, archive ``rogue_v1.2.3.zip``
- Non-primary release: tag ``RelName_v1.2.3``, archive ``rogue_RelName_v1.2.3.zip``

Step 2: Set the GitHub Token
-----------------------------

.. code-block:: bash

   export GITHUB_TOKEN=ghp_your_token_here

The token must have ``repo`` scope to create tags and publish GitHub releases.

Step 3: Run the Release Workflow
---------------------------------

.. code-block:: bash

   make release

This calls ``scripts/firmwareRelease.py --push`` interactively. The script prompts for:

- **Release name** — auto-selected if only one release is defined in ``releases.yaml``
- **Build base name** — enter ``latest`` to auto-select the newest build in
  ``images/``
- **Release version** — e.g., ``v1.2.3``
- **Previous tag** — the existing tag used as the starting point for release notes

To generate release files locally without pushing to GitHub (dry run):

.. code-block:: bash

   make release_files

This runs the same script without the ``--push`` flag. The packaged archive and release
notes are written to the local filesystem for inspection.

Safety Checks
-------------

The ``firmwareRelease.py`` script automatically refuses to publish if any of the
following conditions are true:

- The local git repository has uncommitted changes (dirty working tree)
- The specified previous tag does not exist locally and remotely
- The new version tag already exists (prevents duplicate releases)

Direct Script Invocation (Advanced)
-------------------------------------

For non-interactive use in CI or scripted workflows:

.. code-block:: bash

   cd $(RELEASE_DIR)
   python3 $(RUCKUS_DIR)/scripts/firmwareRelease.py \
     --project=$(TOP_DIR) \
     --release=MyRelease \
     --build=latest \
     --version=v1.2.3 \
     --push

All arguments can also be passed via environment variables or combined with
``make release`` overrides.

Troubleshooting
---------------

**"Repository is dirty"**
   Commit or stash all local changes before running ``make release``. The release
   script enforces a clean working tree to ensure that tagged releases reflect a
   known repository state.

**"Tag already exists"**
   Choose a higher version number. Git tags are permanent; do not delete and recreate
   tags once they have been pushed to GitHub.

**"github.GithubException: 401"**
   ``GITHUB_TOKEN`` is not set or has expired. Generate a new token with ``repo`` scope
   at https://github.com/settings/tokens and export it in your shell.

**"'-' in relName"**
   Rename your release in ``releases.yaml``. Hyphens are not permitted in release
   names. Replace ``My-Release`` with ``MyRelease`` or ``My_Release``.
