#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_REPO="${SOURCE_REPO:-https://github.com/TrNhDuong/yas_devops.git}"
RELEASE_TAG="${RELEASE_TAG:-}"

if git ls-remote --exit-code --heads "${SOURCE_REPO}" refs/heads/main >/dev/null 2>&1; then
  echo "OK: source branch main exists"
else
  echo "FAIL: source branch main does not exist in ${SOURCE_REPO}" >&2
  exit 1
fi

if [[ -n "${RELEASE_TAG}" ]]; then
  if [[ ! "${RELEASE_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
    echo "FAIL: RELEASE_TAG must look like v1.2.0" >&2
    exit 1
  fi
  if git ls-remote --exit-code --tags "${SOURCE_REPO}" "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
    echo "OK: release tag ${RELEASE_TAG} exists"
  else
    echo "FAIL: release tag ${RELEASE_TAG} does not exist in ${SOURCE_REPO}" >&2
    exit 1
  fi
fi
