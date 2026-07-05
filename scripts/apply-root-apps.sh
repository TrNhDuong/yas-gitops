#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"

case "$ENVIRONMENT" in
  dev)
    kubectl apply -f bootstrap/dev-root.yaml
    ;;
  staging)
    kubectl apply -f bootstrap/staging-root.yaml
    ;;
  all)
    kubectl apply -f bootstrap/all-roots.yaml
    ;;
  *)
    echo "Usage: $0 dev|staging|all" >&2
    exit 1
    ;;
esac

kubectl get applications -n argocd
