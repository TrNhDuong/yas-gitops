#!/usr/bin/env bash
set -Eeuo pipefail

REQUIRE_RELEASE_TAG="${REQUIRE_RELEASE_TAG:-false}"
controller_spec="$(kubectl get sts argocd-application-controller -n argocd -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
controller_ready="$(kubectl get sts argocd-application-controller -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"

echo "application-controller: desired=${controller_spec:-0}, ready=${controller_ready:-0}"

kubectl get applications.argoproj.io -n argocd \
  -o custom-columns='NAME:.metadata.name,REVISION:.spec.source.targetRevision,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'

failed=0
if [[ "${controller_spec:-0}" != "1" || "${controller_ready:-0}" != "1" ]]; then
  echo "FAIL: argocd-application-controller must be 1/1." >&2
  failed=1
fi

while IFS='|' read -r name revision namespace sync health; do
  [[ -z "${name}" ]] && continue
  case "${name}" in
    yas-main-root|yas-staging-root)
      expected_revision=main
      expected_namespace=argocd
      ;;
    yas-main-*)
      expected_revision=main
      expected_namespace=yas-dev
      ;;
    yas-staging-*)
      expected_namespace=yas-staging
      if [[ "${REQUIRE_RELEASE_TAG}" == "true" ]]; then
        if [[ ! "${revision}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
          echo "FAIL: ${name} revision ${revision} is not a release tag." >&2
          failed=1
        fi
        expected_revision="${revision}"
      else
        # Before the first release, staging may bootstrap from main.
        if [[ "${revision}" != "main" && ! "${revision}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
          echo "FAIL: ${name} revision ${revision} is neither main nor a release tag." >&2
          failed=1
        fi
        expected_revision="${revision}"
      fi
      ;;
    *) continue ;;
  esac

  if [[ "${revision}" != "${expected_revision}" ]]; then
    echo "FAIL: ${name} tracks ${revision}, expected ${expected_revision}." >&2
    failed=1
  fi
  if [[ "${namespace}" != "${expected_namespace}" ]]; then
    echo "FAIL: ${name} targets ${namespace}, expected ${expected_namespace}." >&2
    failed=1
  fi
  if [[ "${sync}" != "Synced" || "${health}" != "Healthy" ]]; then
    echo "WAIT/FAIL: ${name} is ${sync}/${health}." >&2
    failed=1
  fi
done < <(
  kubectl get applications.argoproj.io -n argocd \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.source.targetRevision}{"|"}{.spec.destination.namespace}{"|"}{.status.sync.status}{"|"}{.status.health.status}{"\n"}{end}'
)

exit "${failed}"
