#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NS="${ARGOCD_NS:-argocd}"

echo "==> Configure ArgoCD to use argocd.argoproj.io/instance for resource tracking"
kubectl patch cm argocd-cm -n "${ARGOCD_NS}" --type merge \
  -p '{"data":{"application.instanceLabelKey":"argocd.argoproj.io/instance"}}'

echo "==> Restart ArgoCD components"
kubectl rollout restart statefulset/argocd-application-controller -n "${ARGOCD_NS}" || true
kubectl rollout restart deploy/argocd-server -n "${ARGOCD_NS}" || true
kubectl rollout restart deploy/argocd-repo-server -n "${ARGOCD_NS}" || true

kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NS}" --timeout=300s || true
kubectl rollout status deploy/argocd-server -n "${ARGOCD_NS}" --timeout=300s || true
kubectl rollout status deploy/argocd-repo-server -n "${ARGOCD_NS}" --timeout=300s || true
