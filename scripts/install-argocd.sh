#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply --server-side --force-conflicts -n argocd \ -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "Waiting for ArgoCD pods..."
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s || true
kubectl get pods -n argocd

echo "Initial admin password:"
kubectl get secret argocd-initial-admin-secret -n argocd   -o jsonpath='{.data.password}' | base64 -d
echo
