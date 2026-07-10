#!/usr/bin/env python3
"""Update one image tag in apps/main or apps/staging without PyYAML.

The script keeps the manifest formatting stable. It identifies the Argo CD
Application by helm.releaseName, then updates backend.image.tag or ui.image.tag.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", required=True, choices=("main", "staging"))
    parser.add_argument("--service", required=True, help="Helm releaseName, e.g. tax")
    parser.add_argument("--tag", required=True)
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Path to yas-gitops checkout",
    )
    return parser.parse_args()


def find_manifest(env_dir: Path, service: str) -> Path:
    release_pattern = re.compile(r"^\s*releaseName:\s*['\"]?([^'\"\s]+)")
    matches: list[Path] = []
    for path in sorted(env_dir.glob("*.yaml")):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = release_pattern.match(line)
            if match and match.group(1) == service:
                matches.append(path)
                break
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected exactly one manifest for releaseName={service!r} in {env_dir}; "
            f"found {[str(p) for p in matches]}"
        )
    return matches[0]


def update_tag(path: Path, new_tag: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    tag_name = re.compile(r"^\s*-\s+name:\s+(?:backend|ui)\.image\.tag\s*$")
    value_line = re.compile(r"^(\s*)value:\s*.*?(\r?\n)?$")

    for index, line in enumerate(lines):
        if not tag_name.match(line.rstrip("\r\n")):
            continue
        for value_index in range(index + 1, min(index + 5, len(lines))):
            match = value_line.match(lines[value_index])
            if match:
                newline = match.group(2) or "\n"
                lines[value_index] = f"{match.group(1)}value: {new_tag}{newline}"
                path.write_text("".join(lines), encoding="utf-8")
                return
        raise RuntimeError(f"Found image tag parameter but no value in {path}")

    raise RuntimeError(f"No backend.image.tag or ui.image.tag parameter in {path}")


def main() -> int:
    args = parse_args()
    root = Path(args.repo_root).resolve()
    env_dir = root / "apps" / args.branch
    if not env_dir.is_dir():
        raise RuntimeError(f"Missing environment directory: {env_dir}")

    manifest = find_manifest(env_dir, args.service)
    update_tag(manifest, args.tag)
    print(f"Updated {manifest.relative_to(root)} -> {args.tag}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # clear CI failure message
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
