#!/usr/bin/env python3
# ----------------------------------------------------------------------------
# Title      : Ruckus Documentation Publisher
# ----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
# ----------------------------------------------------------------------------
"""Publish built documentation into a gh-pages worktree."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path
from typing import Literal, NotRequired, TypedDict


RELEASE_DIR_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)$")
SAFE_SLUG_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$")


class VersionEntry(TypedDict):
    slug: str
    title: str
    kind: Literal["alias", "branch", "release"]
    url: str
    target_slug: NotRequired[str | None]


class VersionsMetadata(TypedDict):
    default: str | None
    versions: list[VersionEntry]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site-dir", required=True, help="Built HTML directory to publish")
    parser.add_argument("--output-root", required=True, help="Target root inside the gh-pages tree")
    parser.add_argument(
        "--site-root",
        required=True,
        help="Public URL root for the published docs, for example /ruckus or /ruckus/staging-docs",
    )
    parser.add_argument(
        "--mode",
        required=True,
        choices=("release", "pre-release"),
        help="Publishing mode",
    )
    parser.add_argument("--version", help="Release version label for release mode")
    parser.add_argument(
        "--write-root-redirect",
        action="store_true",
        help="Write index.html at the output root redirecting to latest/",
    )
    parser.add_argument(
        "--latest-target-version",
        help="Release slug that should be labeled as the latest release in metadata",
    )
    return parser.parse_args()


def normalize_site_root(site_root: str) -> str:
    site_root = site_root.strip()
    if not site_root or site_root == "/":
        return ""
    if not site_root.startswith("/"):
        site_root = f"/{site_root}"
    return site_root.rstrip("/")


def url_join(site_root: str, *parts: str) -> str:
    pieces = [site_root.strip("/")] if site_root else [""]
    pieces.extend(part.strip("/") for part in parts if part)
    path = "/".join(piece for piece in pieces if piece)
    return f"/{path}/" if path else "/"


def sync_tree(source: Path, destination: Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source, destination)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    ensure_parent(path)
    path.write_text(content, encoding="utf-8")


def read_versions_metadata(path: Path) -> VersionsMetadata | None:
    if not path.is_file():
        return None

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None

    if not isinstance(data, dict):
        return None
    versions = data.get("versions")
    if not isinstance(versions, list):
        return None

    default_slug = data.get("default")
    if default_slug is not None and not isinstance(default_slug, str):
        default_slug = None

    return {
        "default": default_slug,
        "versions": [entry for entry in versions if isinstance(entry, dict)],
    }


def release_sort_key(slug: str) -> tuple[int, int, int]:
    match = RELEASE_DIR_RE.match(slug)
    if not match:
        return (-1, -1, -1)
    return tuple(int(part) for part in match.groups())


def validate_safe_slug(value: str, field_name: str) -> str:
    slug = value.strip()
    if not slug:
        raise ValueError(f"{field_name} cannot be empty")
    if slug in {".", ".."}:
        raise ValueError(f"{field_name} must be a single safe path segment")
    if "/" in slug or "\\" in slug:
        raise ValueError(f"{field_name} must not contain path separators")
    if not SAFE_SLUG_RE.match(slug):
        raise ValueError(
            f"{field_name} must match {SAFE_SLUG_RE.pattern} and stay within a single path segment"
        )
    return slug


def find_gh_pages_worktree_root(path: Path) -> Path | None:
    for candidate in (path, *path.parents):
        if candidate.name != "gh-pages":
            continue
        if (candidate / ".git").exists():
            return candidate
    return None


def validate_output_root(path: Path) -> Path:
    resolved = path.resolve()

    if resolved == Path(resolved.anchor):
        raise ValueError("--output-root must not be the filesystem root")

    if find_gh_pages_worktree_root(resolved) is None:
        raise ValueError(
            "--output-root must point at the prepared gh-pages worktree root or a subdirectory inside it"
        )

    return resolved


def choose_default_slug(versions: list[VersionEntry]) -> str | None:
    for preferred_slug in ("latest", "pre-release"):
        if any(entry["slug"] == preferred_slug for entry in versions):
            return preferred_slug

    newest_release = next((entry for entry in versions if entry["kind"] == "release"), None)
    if newest_release is not None:
        return newest_release["slug"]

    return versions[0]["slug"] if versions else None


def existing_latest_target_slug(output_root: Path) -> str | None:
    metadata = read_versions_metadata(output_root / "versions.json")
    if metadata is None:
        return None

    latest_entry = next((entry for entry in metadata["versions"] if entry.get("slug") == "latest"), None)
    if latest_entry is None:
        return None

    target_slug = latest_entry.get("target_slug")
    if isinstance(target_slug, str) and RELEASE_DIR_RE.match(target_slug):
        return target_slug
    return None


def collect_versions(
    output_root: Path, site_root: str, latest_target_slug: str | None = None
) -> VersionsMetadata:
    versions: list[VersionEntry] = []

    release_slugs = sorted(
        (
            path.name
            for path in output_root.iterdir()
            if path.is_dir() and RELEASE_DIR_RE.match(path.name)
        ),
        key=release_sort_key,
        reverse=True,
    )
    if latest_target_slug is None:
        latest_target_slug = existing_latest_target_slug(output_root)
    if latest_target_slug is None and release_slugs:
        latest_target_slug = release_slugs[0]

    if (output_root / "latest").is_dir():
        latest_title = "Latest Release"
        if latest_target_slug is not None:
            latest_title = f"{latest_target_slug} - Latest Release"
        versions.append(
            {
                "slug": "latest",
                "title": latest_title,
                "kind": "alias",
                "url": url_join(site_root, "latest"),
                "target_slug": latest_target_slug,
            }
        )

    if (output_root / "pre-release").is_dir():
        versions.append(
            {
                "slug": "pre-release",
                "title": "Pre-release",
                "kind": "branch",
                "url": url_join(site_root, "pre-release"),
            }
        )

    for slug in release_slugs:
        if slug == latest_target_slug and any(entry["slug"] == "latest" for entry in versions):
            continue
        versions.append(
            {
                "slug": slug,
                "title": slug,
                "kind": "release",
                "url": url_join(site_root, slug),
            }
        )

    return {"default": choose_default_slug(versions), "versions": versions}


def render_versions_page(metadata: VersionsMetadata) -> str:
    versions = metadata["versions"]
    default_slug = metadata["default"]
    latest = next((entry for entry in versions if entry["slug"] == "latest"), None)
    pre_release = next((entry for entry in versions if entry["slug"] == "pre-release"), None)
    releases = [entry for entry in versions if entry["kind"] == "release"]
    default_entry = next((entry for entry in versions if entry["slug"] == default_slug), None)

    def render_entry(entry: VersionEntry) -> str:
        return f'<li><a href="{entry["url"]}">{entry["title"]}</a></li>'

    latest_html = render_entry(latest) if latest else "<li>Not published yet.</li>"
    pre_release_html = render_entry(pre_release) if pre_release else "<li>Not published yet.</li>"
    release_html = "\n".join(render_entry(entry) for entry in releases) or "<li>No releases published yet.</li>"
    default_link_html = (
        f'<a class="home-link" href="{default_entry["url"]}">Open default docs</a>'
        if default_entry
        else "<p class=\"home-link\">No published documentation is available yet.</p>"
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Documentation Versions</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f6f8fb;
      --card: #ffffff;
      --border: #d8dee9;
      --text: #1c2533;
      --muted: #5c6b80;
      --link: #005a9c;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
    }}
    main {{
      max-width: 56rem;
      margin: 0 auto;
      padding: 3rem 1.5rem 4rem;
    }}
    h1 {{
      margin-bottom: 0.25rem;
    }}
    p {{
      color: var(--muted);
      margin-top: 0;
    }}
    section {{
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 0.75rem;
      padding: 1.25rem 1.5rem;
      margin-top: 1rem;
    }}
    ul {{
      margin: 0;
      padding-left: 1.25rem;
    }}
    a {{
      color: var(--link);
    }}
    .home-link {{
      display: inline-block;
      margin-top: 1rem;
    }}
  </style>
</head>
<body>
  <main>
    <h1>Documentation Versions</h1>
    <p>Select released or development documentation.</p>
    <section>
      <h2>Latest Release</h2>
      <ul>
        {latest_html}
      </ul>
    </section>
    <section>
      <h2>Development Docs</h2>
      <ul>
        {pre_release_html}
      </ul>
    </section>
    <section>
      <h2>Release History</h2>
      <ul>
        {release_html}
      </ul>
    </section>
    {default_link_html}
  </main>
</body>
</html>
"""


def render_redirect(target: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url={target}">
  <title>Redirecting...</title>
  <link rel="canonical" href="{target}">
</head>
<body>
  <p>Redirecting to <a href="{target}">{target}</a>.</p>
</body>
</html>
"""


def main() -> int:
    args = parse_args()

    site_dir = Path(args.site_dir).resolve()
    output_root = validate_output_root(Path(args.output_root))
    site_root = normalize_site_root(args.site_root)
    latest_target_slug = (
        validate_safe_slug(args.latest_target_version, "--latest-target-version")
        if args.latest_target_version
        else None
    )

    if not site_dir.is_dir():
        raise FileNotFoundError(f"Built site directory not found: {site_dir}")

    output_root.mkdir(parents=True, exist_ok=True)

    if args.mode == "release":
        if not args.version:
            raise ValueError("--version is required in release mode")
        version_slug = validate_safe_slug(args.version, "--version")
        sync_tree(site_dir, output_root / version_slug)
        if latest_target_slug is None or latest_target_slug == version_slug:
            sync_tree(site_dir, output_root / "latest")
    else:
        sync_tree(site_dir, output_root / "pre-release")

    metadata = collect_versions(output_root, site_root, latest_target_slug=latest_target_slug)
    write_text(output_root / "versions.json", json.dumps(metadata, indent=2, sort_keys=False) + "\n")
    write_text(output_root / "versions" / "index.html", render_versions_page(metadata))

    if args.write_root_redirect:
        write_text(output_root / "index.html", render_redirect("latest/"))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
