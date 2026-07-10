#!/usr/bin/env bash
set -Eeuo pipefail

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_MANIFEST_URL="${ARGOCD_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl is required" >&2
  exit 1
}

kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Server-side apply avoids the CRD annotation-size problem seen with client-side apply.
kubectl apply --server-side --force-conflicts \
  -n "${ARGOCD_NAMESPACE}" \
  -f "${ARGOCD_MANIFEST_URL}"

# This controller must be running for reconciliation, health assessment and auto-sync.
kubectl scale statefulset argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --replicas=1

kubectl patch configmap argocd-cm \
  -n "${ARGOCD_NAMESPACE}" \
  --type merge \
  -p '{"data":{"application.instanceLabelKey":"argocd.argoproj.io/instance"}}'

for deployment in \
  argocd-applicationset-controller \
  argocd-dex-server \
  argocd-notifications-controller \
  argocd-redis \
  argocd-repo-server \
  argocd-server; do
  kubectl rollout status "deployment/${deployment}" \
    -n "${ARGOCD_NAMESPACE}" \
    --timeout=300s
done

kubectl rollout status statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=300s

kubectl get pods -n "${ARGOCD_NAMESPACE}"
