#!/usr/bin/env bash
set -Eeuo pipefail

kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='NAME:.metadata.name,REVISION:.spec.source.targetRevision,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'

echo
echo 'Images in yas-dev:'
kubectl get deployments -n yas-dev \
  -o custom-columns='DEPLOYMENT:.metadata.name,IMAGE:.spec.template.spec.containers[0].image' 2>/dev/null || true

echo
echo 'Images in yas-staging:'
kubectl get deployments -n yas-staging \
  -o custom-columns='DEPLOYMENT:.metadata.name,IMAGE:.spec.template.spec.containers[0].image' 2>/dev/null || true
