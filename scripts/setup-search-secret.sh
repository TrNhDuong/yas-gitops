#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${1:-}"
if [[ "${NAMESPACE}" != "yas-dev" && "${NAMESPACE}" != "yas-staging" ]]; then
  echo "Usage: ELASTIC_USERNAME=... ELASTIC_PASSWORD=... $0 yas-dev|yas-staging" >&2
  exit 2
fi

: "${ELASTIC_USERNAME:?Set ELASTIC_USERNAME}"
: "${ELASTIC_PASSWORD:?Set ELASTIC_PASSWORD}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic search-elasticsearch-credentials \
  -n "${NAMESPACE}" \
  --from-literal=username="${ELASTIC_USERNAME}" \
  --from-literal=password="${ELASTIC_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
