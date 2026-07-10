#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-all}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ready="$(kubectl get sts argocd-application-controller -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
if [[ "${ready}" != "1" ]]; then
  echo "argocd-application-controller is not ready (readyReplicas=${ready:-0})." >&2
  echo "Run ./scripts/install-argocd.sh first." >&2
  exit 1
fi

kubectl apply -f "${ROOT_DIR}/bootstrap/project.yaml"

case "${MODE}" in
  main)
    kubectl apply -f "${ROOT_DIR}/bootstrap/main-root.yaml"
    ;;
  staging)
    kubectl apply -f "${ROOT_DIR}/bootstrap/staging-root.yaml"
    ;;
  all)
    kubectl apply -f "${ROOT_DIR}/bootstrap/main-root.yaml"
    kubectl apply -f "${ROOT_DIR}/bootstrap/staging-root.yaml"
    ;;
  *)
    echo "Usage: $0 [main|staging|all]" >&2
    exit 2
    ;;
esac

kubectl annotate applications.argoproj.io -n argocd --all \
  argocd.argoproj.io/refresh=hard \
  --overwrite >/dev/null

kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='NAME:.metadata.name,BRANCH:.spec.source.targetRevision,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'
