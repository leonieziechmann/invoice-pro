#!/usr/bin/env python3
"""Weekly check of the pinned upstream tools against their latest releases.

  upstream.py --pinned NAME=VERSION ... [--markdown FILE]

The e-invoice checks pin their tools in flake.nix: the Mustang CLI, the KoSIT
validator and its XRechnung configuration, and Typst (from the pinned
nixpkgs). The script asks GitHub for the latest release of each (`gh api`,
authenticated by GH_TOKEN) and writes a report of the pins that are behind,
which .github/workflows/upstream-check.yaml puts into one issue. Drafts and
pre-releases do not count.

Only the standard library and the GitHub CLI are needed.
Exit code: 0 every pin is the latest release, 1 an update is available, 2 error.
"""

import argparse
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

# name -> (title, GitHub repository, pattern of the release tags whose group
# is the version, what to do for an update)
ARTIFACTS = {
    "mustang-cli": (
        "Mustang CLI",
        "ZUGFeRD/mustangproject",
        r"core-(\d+(?:\.\d+)+)",
        "Update `version` and the hash of `mustang-cli` in flake.nix, run the corpus "
        "(`nix run .#zugferd-corpus`), `nix run .#validate-all-zugferd` and the Factur-X PDF check with "
        "`nix run .#zugferd-xmp -- --update`, review the diff of tests/zugferd/xmp/ and "
        "tools/zugferd/validator-differences.toml (a newer Mustang may agree with KoSIT on more rules), and "
        "update the version in docs/docs/e-invoicing.md (XMP recipe), tests/TESTING.md and tools/zugferd.",
    ),
    "kosit-validator": (
        "KoSIT validator",
        "itplr-kosit/validator",
        r"v(\d+(?:\.\d+)+)",
        "Update `version` and the hash of `kosit-validator` in flake.nix, run the corpus and "
        "`nix run .#validate-all-zugferd`, and update the version in tests/TESTING.md and tools/zugferd.",
    ),
    "xrechnung-configuration": (
        "XRechnung configuration of KoSIT",
        "itplr-kosit/validator-configuration-xrechnung",
        r"(?:v|release-)(\d{4}-\d{2}-\d{2})",
        "Update `version`, the XRechnung version in the URL and the hash of `xrechnung-configuration` in "
        "flake.nix, run the corpus and `nix run .#validate-all-zugferd`, and review "
        "tools/zugferd/validator-differences.toml: the CEN and XRechnung Schematron may have changed.",
    ),
    "typst": (
        "Typst",
        "typst/typst",
        r"v(\d+(?:\.\d+)+)",
        "Update the nixpkgs input (`nix flake update nixpkgs`) once nixpkgs has the release, and run all "
        "checks. If the release can write custom XMP metadata (https://github.com/typst/typst/issues/5667), "
        "write the Factur-X metadata with src/zugferd/xmp.typ; `nix run .#zugferd-xmp` fails on new "
        "definitions of the `pdf` module.",
    ),
}

TITLE = "Upstream updates of the e-invoice tools"


class UpstreamError(Exception):
    """GitHub or the pins cannot be read; the message says why."""


def version_key(version):
    """(1, 6, 3) of "1.6.3", (2026, 8, 31) of "2026-08-31"."""
    return tuple(int(part) for part in re.split(r"[.-]", version))


def latest(name, releases):
    """(version, URL) of the newest release whose tag matches the pattern of
    `name`, drafts and pre-releases left out; None without one."""
    pattern = re.compile(ARTIFACTS[name][2] + r"$")
    best = None
    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue
        m = pattern.match(release.get("tag_name") or "")
        if not m:
            continue
        candidate = (version_key(m.group(1)), m.group(1), release.get("html_url"))
        if best is None or candidate[0] > best[0]:
            best = candidate
    return (best[1], best[2]) if best else None


def fetch_releases(repo):
    """The latest 100 releases of a GitHub repository (GitHub CLI)."""
    try:
        proc = subprocess.run(["gh", "api", f"repos/{repo}/releases?per_page=100"],
                              capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        raise UpstreamError("the GitHub CLI (gh) is not installed")
    if proc.returncode != 0:
        raise UpstreamError(f"gh api repos/{repo}/releases failed: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def compare(pinned, fetch=fetch_releases):
    """[(name, pinned version, latest version, URL)] of the pins that are
    behind their latest release."""
    behind = []
    for name, version in pinned.items():
        if name not in ARTIFACTS:
            raise UpstreamError(f"unknown artifact {name!r} (one of {', '.join(ARTIFACTS)})")
        found = latest(name, fetch(ARTIFACTS[name][1]))
        if found is None:
            raise UpstreamError(f"no release of {ARTIFACTS[name][1]} matches {ARTIFACTS[name][2]}")
        if version_key(found[0]) > version_key(version):
            behind.append((name, version, found[0], found[1]))
    return behind


def markdown(behind, pinned, today=None):
    """The body of the issue."""
    today = today or datetime.date.today().isoformat()
    lines = [
        "The e-invoice checks pin their tools in `flake.nix`. Newer releases are available:",
        "",
        "| Tool | Pinned | Latest | Release |",
        "| :--- | :----- | :----- | :------ |",
    ]
    for name, version, newest, url in behind:
        lines.append(f"| {ARTIFACTS[name][0]} | {version} | {newest} | {url} |")
    lines += ["", "What to do:", ""]
    for name, _, _, _ in behind:
        lines.append(f"- **{ARTIFACTS[name][0]}:** {ARTIFACTS[name][3]}")
    current = [f"{ARTIFACTS[name][0]} {version}" for name, version in pinned.items()
               if name not in {b[0] for b in behind}]
    if current:
        lines += ["", "Up to date: " + ", ".join(current) + "."]
    lines += ["", f"_Checked on {today} by `.github/workflows/upstream-check.yaml` (`tools/zugferd/upstream.py`)._"]
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pinned", action="append", default=[], metavar="NAME=VERSION",
                    help=f"a pinned version; NAME is one of {', '.join(ARTIFACTS)}")
    ap.add_argument("--markdown", default=None, help="write the report for the issue to this file")
    args = ap.parse_args(argv)
    pinned = {}
    for item in args.pinned:
        name, sep, version = item.partition("=")
        if not sep or not version.strip():
            print(f"error: --pinned {item!r} is not NAME=VERSION", file=sys.stderr)
            return 2
        pinned[name.strip()] = version.strip()
    if not pinned:
        print("error: no --pinned versions", file=sys.stderr)
        return 2
    try:
        behind = compare(pinned)
    except UpstreamError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    for name, version in pinned.items():
        newer = next((b for b in behind if b[0] == name), None)
        state = f"{version} -> {newer[2]} ({newer[3]})" if newer else f"{version}, the latest release"
        print(f"{ARTIFACTS[name][0]}: {state}")
    if args.markdown:
        Path(args.markdown).write_text(markdown(behind, pinned) if behind else "", encoding="utf-8")
    return 1 if behind else 0


if __name__ == "__main__":
    sys.exit(main())
