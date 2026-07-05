#!/usr/bin/env bash
set -euo pipefail

for ns in yas-dev yas-staging; do
  echo "===== $ns ====="
  kubectl get pods,svc,endpoints -n "$ns" || true
  echo
  kubectl get applications -n argocd | grep "$ns" || true
  echo
 done
