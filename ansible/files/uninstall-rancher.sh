#!/usr/bin/env bash
# Run by ./manage.sh uninstall-rancher (rancher-platform)
set -euo pipefail
# The play sets KUBECONFIG and PATH.

echo "--- Removing Rancher and cert-manager (RKE2 stays) ---"
# Stop Rancher first so it does not reinstall the apps removed below.
if kubectl get deployment rancher -n cattle-system >/dev/null 2>&1; then
    kubectl scale deployment rancher -n cattle-system --replicas=0
    kubectl wait pods -n cattle-system -l app=rancher --for=delete --timeout=300s
fi

# The chart's post-delete hook Job finds the rancher release it is part of, fails to uninstall it and
# ends in BackoffLimitExceeded. Skip the hook and run its cleanup here.
helm uninstall rancher -n cattle-system --no-hooks --wait --timeout 10m --ignore-not-found
for ns in cattle-fleet-system cattle-system rancher-operator-system; do
    for app in $(helm list -n "${ns}" --all -q); do
        [[ "${app}" == *-crd ]] && continue
        helm uninstall "${app}" -n "${ns}" --wait --timeout 5m
    done
    kubectl get pods -n "${ns}" -o name 2>/dev/null | { grep '^pod/helm-operation-' || true; } |
        xargs -r kubectl delete -n "${ns}" --ignore-not-found
done
kubectl delete apiservice v1.ext.cattle.io --ignore-not-found

helm uninstall cert-manager -n cert-manager --wait --ignore-not-found
kubectl delete namespace cattle-system cert-manager --ignore-not-found
echo "--- Done ---"
