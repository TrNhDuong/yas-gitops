#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-yas-staging}"

kubectl get namespace "$NAMESPACE" >/dev/null || kubectl create namespace "$NAMESPACE"
kubectl get secret elasticsearch-es-elastic-user -n elasticsearch >/dev/null

ES_PASS=$(kubectl get secret elasticsearch-es-elastic-user -n elasticsearch   -o go-template='{{.data.elastic | base64decode}}')

kubectl create secret generic search-elasticsearch-credentials   -n "$NAMESPACE"   --from-literal=username=elastic   --from-literal=password="$ES_PASS"   --dry-run=client -o yaml | kubectl apply -f -

kubectl get secret search-elasticsearch-credentials -n "$NAMESPACE"
