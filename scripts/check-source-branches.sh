#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_REPO="${SOURCE_REPO:-https://github.com/TrNhDuong/yas_devops.git}"

for branch in main staging; do
  if git ls-remote --exit-code --heads "${SOURCE_REPO}" "refs/heads/${branch}" >/dev/null 2>&1; then
    echo "OK: source branch ${branch} exists"
  else
    echo "MISSING: source branch ${branch} does not exist in ${SOURCE_REPO}" >&2
    exit 1
  fi
done
