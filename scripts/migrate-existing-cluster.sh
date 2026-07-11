#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIRM="${1:-}"

if [[ "${CONFIRM}" != "--yes" ]]; then
  cat <<'MSG'
This migration will:
  1. Keep workloads already running in yas-dev and yas-staging.
  2. Remove legacy Argo CD Application objects named yas-dev-* and yas-dev-root.
  3. Apply yas-main-root: source main -> namespace yas-dev.
  4. Apply yas-staging-root: bootstrap from main, then release tags vX.Y.Z.

Application finalizers are removed before deletion, so existing Deployments,
Services and Pods are not intentionally cascaded.
Run again with --yes to continue.
MSG
  exit 0
fi

kubectl scale sts argocd-application-controller -n argocd --replicas=1
kubectl rollout status sts/argocd-application-controller -n argocd --timeout=300s

mapfile -t legacy_apps < <(
  kubectl get applications.argoproj.io -n argocd -o name \
    | sed 's#application.argoproj.io/##' \
    | grep -E '^yas-dev(-root|-)' || true
)

for app in "${legacy_apps[@]}"; do
  kubectl patch application "${app}" -n argocd \
    --type merge \
    -p '{"metadata":{"finalizers":[]}}' >/dev/null || true
  kubectl delete application "${app}" -n argocd --ignore-not-found
done

kubectl apply -f "${ROOT_DIR}/bootstrap/all-roots.yaml"

kubectl annotate applications.argoproj.io -n argocd --all \
  argocd.argoproj.io/refresh=hard \
  --overwrite >/dev/null

cat <<'MSG'
Migration submitted. Watch reconciliation with:
  watch -n 2 'kubectl get applications -n argocd'
MSG
