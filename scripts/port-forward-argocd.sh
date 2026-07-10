#!/usr/bin/env bash
set -Eeuo pipefail

ADDRESS="${ADDRESS:-127.0.0.1}"
LOCAL_PORT="${LOCAL_PORT:-8081}"

exec kubectl port-forward service/argocd-server \
  -n argocd \
  "${LOCAL_PORT}:443" \
  --address "${ADDRESS}"
