import subprocess

project = "hlsBs"
author = "SLAC National Accelerator Laboratory"
copyright = "2026, SLAC National Accelerator Laboratory"


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
#    "sphinx_copybutton",  CAN'T FIND
]



source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}

myst_heading_anchors = 4

exclude_patterns = ["build"]

html_theme = "sphinx_rtd_theme"
#html_theme_options = {"titles_only": True, "navigation_depth": -1}
html_static_path = []
