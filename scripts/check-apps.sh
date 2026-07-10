#!/usr/bin/env bash
set -Eeuo pipefail

controller_spec="$(kubectl get sts argocd-application-controller -n argocd -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
controller_ready="$(kubectl get sts argocd-application-controller -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"

echo "application-controller: desired=${controller_spec:-0}, ready=${controller_ready:-0}"

kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='NAME:.metadata.name,BRANCH:.spec.source.targetRevision,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'

failed=0
if [[ "${controller_spec:-0}" != "1" || "${controller_ready:-0}" != "1" ]]; then
  echo "FAIL: argocd-application-controller must be 1/1." >&2
  failed=1
fi

while IFS='|' read -r name branch sync health; do
  [[ -z "${name}" ]] && continue
  case "${name}" in
    yas-main-*) expected=main ;;
    yas-staging-*) expected=staging ;;
    *) continue ;;
  esac

  if [[ "${branch}" != "${expected}" ]]; then
    echo "FAIL: ${name} tracks ${branch}, expected ${expected}." >&2
    failed=1
  fi
  if [[ "${sync}" != "Synced" || "${health}" != "Healthy" ]]; then
    echo "WAIT/FAIL: ${name} is ${sync}/${health}." >&2
    failed=1
  fi
done < <(
  kubectl get applications.argoproj.io -n argocd \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.source.targetRevision}{"|"}{.status.sync.status}{"|"}{.status.health.status}{"\n"}{end}'
)

exit "${failed}"
