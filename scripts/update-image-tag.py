#!/usr/bin/env python3
"""Update one Argo CD Application in the GitOps repository.

Routing is explicit:
- environment=main updates apps/main and normally keeps targetRevision=main.
- environment=staging updates apps/staging and may pin targetRevision to a Git
  release tag such as v1.2.0.

The script intentionally avoids PyYAML so it can run on a stock GitHub runner
without installing dependencies and keeps existing manifest formatting stable.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SEMVER_TAG = re.compile(r"^v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True, choices=("main", "staging"))
    parser.add_argument("--service", required=True, help="Helm releaseName, e.g. tax")
    parser.add_argument("--tag", required=True, help="Docker image tag")
    parser.add_argument("--repository", help="Optional full Docker repository")
    parser.add_argument(
        "--source-revision",
        help="Optional chart Git revision. Use main for dev or vX.Y.Z for a release.",
    )
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Path to the yas-gitops checkout",
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
            f"Expected one manifest for releaseName={service!r} in {env_dir}; "
            f"found {[str(p) for p in matches]}"
        )
    return matches[0]


def replace_target_revision(text: str, revision: str) -> str:
    pattern = re.compile(r"(?m)^(\s*targetRevision:\s*).+$")
    updated, count = pattern.subn(rf"\g<1>{revision}", text, count=1)
    if count != 1:
        raise RuntimeError("No unique spec.source.targetRevision found")
    return updated


def update_parameter(text: str, suffix: str, new_value: str) -> str:
    lines = text.splitlines(keepends=True)
    name_pattern = re.compile(rf"^\s*-\s+name:\s+(?:backend|ui)\.image\.{suffix}\s*$")
    value_pattern = re.compile(r"^(\s*)value:\s*.*?(\r?\n)?$")

    for index, line in enumerate(lines):
        if not name_pattern.match(line.rstrip("\r\n")):
            continue
        for value_index in range(index + 1, min(index + 5, len(lines))):
            match = value_pattern.match(lines[value_index])
            if match:
                newline = match.group(2) or "\n"
                lines[value_index] = f"{match.group(1)}value: {new_value}{newline}"
                return "".join(lines)
        raise RuntimeError(f"Found image.{suffix} parameter but no value")

    raise RuntimeError(f"No backend.image.{suffix} or ui.image.{suffix} parameter")


def main() -> int:
    args = parse_args()
    root = Path(args.repo_root).resolve()
    env_dir = root / "apps" / args.environment
    if not env_dir.is_dir():
        raise RuntimeError(f"Missing environment directory: {env_dir}")

    if args.environment == "staging" and args.source_revision:
        if not SEMVER_TAG.fullmatch(args.source_revision):
            raise RuntimeError(
                "Staging source revision must be a release tag like v1.2.0"
            )
        if args.tag != args.source_revision:
            raise RuntimeError(
                "For a release promotion, Docker tag and source revision must match"
            )

    manifest = find_manifest(env_dir, args.service)
    text = manifest.read_text(encoding="utf-8")

    if args.repository:
        text = update_parameter(text, "repository", args.repository)
    text = update_parameter(text, "tag", args.tag)
    if args.source_revision:
        text = replace_target_revision(text, args.source_revision)

    manifest.write_text(text, encoding="utf-8")
    print(
        f"Updated {manifest.relative_to(root)}: image={args.repository or '(unchanged)'}:{args.tag}, "
        f"sourceRevision={args.source_revision or '(unchanged)'}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
