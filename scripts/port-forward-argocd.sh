#!/usr/bin/env bash
set -euo pipefail

kubectl port-forward svc/argocd-server -n argocd 8081:443 --address 127.0.0.1
