# docs/conf.py
import subprocess

project = "ruckus"
author = "SLAC National Accelerator Laboratory"
copyright = "2024, SLAC National Accelerator Laboratory"

try:
    release = subprocess.check_output(
        ["git", "describe", "--tags", "--abbrev=0"],
        stderr=subprocess.DEVNULL,
    ).decode().strip()
except Exception:
    release = "dev"
version = release

extensions = [
    "myst_parser",
    "sphinx_copybutton",
]

html_theme = "furo"
html_title = "ruckus"
html_baseurl = "https://slaclab.github.io/ruckus/"

source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
