#!/usr/bin/env bash
set -euo pipefail

OLD_GITOPS="${1:-https://github.com/TrNhDuong/yas-gitops.git}"
NEW_GITOPS="${2:-}"
OLD_REV="${3:-fix/k8s-minikube-yas-deploy}"
NEW_REV="${4:-}"

if [[ -z "$NEW_GITOPS" && -z "$NEW_REV" ]]; then
  echo "Usage: $0 <old_gitops_url> <new_gitops_url> [old_revision] [new_revision]" >&2
  echo "Example: $0 https://github.com/TrNhDuong/yas-gitops.git https://github.com/TrNhDuong/my-yas-gitops.git fix/k8s-minikube-yas-deploy develop" >&2
  exit 1
fi

if [[ -n "$NEW_GITOPS" ]]; then
  grep -RIl "$OLD_GITOPS" bootstrap apps | xargs -r sed -i "s|$OLD_GITOPS|$NEW_GITOPS|g"
fi

if [[ -n "$NEW_REV" ]]; then
  grep -RIl "$OLD_REV" apps | xargs -r sed -i "s|$OLD_REV|$NEW_REV|g"
fi
