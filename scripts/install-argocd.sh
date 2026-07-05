#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NS="${ARGOCD_NS:-argocd}"
INSTALL_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "==> Create namespace ${ARGOCD_NS}"
kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Install/upgrade ArgoCD with server-side apply"
kubectl apply --server-side --force-conflicts -n "${ARGOCD_NS}" -f "${INSTALL_MANIFEST}"

echo "==> Configure ArgoCD resource tracking label"
# Helm charts often use app.kubernetes.io/instance in Service selectors.
# ArgoCD also uses this label by default, so use a separate tracking label to avoid breaking Helm selectors.
kubectl patch cm argocd-cm -n "${ARGOCD_NS}" --type merge \
  -p '{"data":{"application.instanceLabelKey":"argocd.argoproj.io/instance"}}'

echo "==> Restart ArgoCD components to reload config"
kubectl rollout restart statefulset/argocd-application-controller -n "${ARGOCD_NS}" || true
kubectl rollout restart deploy/argocd-server -n "${ARGOCD_NS}" || true
kubectl rollout restart deploy/argocd-repo-server -n "${ARGOCD_NS}" || true

echo "==> Wait for ArgoCD pods"
kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NS}" --timeout=300s || true
kubectl rollout status deploy/argocd-server -n "${ARGOCD_NS}" --timeout=300s || true
kubectl rollout status deploy/argocd-repo-server -n "${ARGOCD_NS}" --timeout=300s || true
kubectl get pods -n "${ARGOCD_NS}"

echo "==> Initial admin password"
if kubectl get secret argocd-initial-admin-secret -n "${ARGOCD_NS}" >/dev/null 2>&1; then
  kubectl get secret argocd-initial-admin-secret -n "${ARGOCD_NS}" \
    -o jsonpath='{.data.password}' | base64 -d
  echo
else
  echo "argocd-initial-admin-secret not found. It may have been removed after password change."
fi
