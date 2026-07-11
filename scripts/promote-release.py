#!/usr/bin/env python3
"""Promote one Git tag to staging for selected or all image-bearing services.

Run this only after the corresponding Docker images with the same release tag
exist. It updates both image.tag and spec.source.targetRevision in apps/staging.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

SEMVER_TAG = re.compile(r"^v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--services", nargs="*", help="Release names; omit for all")
    parser.add_argument(
        "--repo-root", default=str(Path(__file__).resolve().parents[1])
    )
    return parser.parse_args()


def image_services(staging_dir: Path) -> list[str]:
    release = re.compile(r"^\s*releaseName:\s*([^\s]+)")
    image_tag = re.compile(r"^\s*-\s+name:\s+(?:backend|ui)\.image\.tag\s*$")
    found: list[str] = []
    for path in sorted(staging_dir.glob("*.yaml")):
        text = path.read_text(encoding="utf-8")
        if not any(image_tag.match(line) for line in text.splitlines()):
            continue
        for line in text.splitlines():
            match = release.match(line)
            if match:
                found.append(match.group(1))
                break
    return found


def main() -> int:
    args = parse_args()
    if not SEMVER_TAG.fullmatch(args.tag):
        raise RuntimeError("Tag must look like v1.2.0")

    root = Path(args.repo_root).resolve()
    services = args.services or image_services(root / "apps" / "staging")
    if not services:
        raise RuntimeError("No image-bearing services found")

    updater = root / "scripts" / "update-image-tag.py"
    for service in services:
        subprocess.run(
            [
                sys.executable,
                str(updater),
                "--repo-root",
                str(root),
                "--environment",
                "staging",
                "--service",
                service,
                "--tag",
                args.tag,
                "--source-revision",
                args.tag,
            ],
            check=True,
        )
    print(f"Promoted {args.tag} for {len(services)} services")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
