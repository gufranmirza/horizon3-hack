#!/usr/bin/env bash
# Remove the planted chain. Use --cluster to also destroy the GKE cluster.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> removing kill-chain manifests"
kubectl delete -f "$HERE/deployment/manifests/" --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding dashboard-admin --ignore-not-found=true
kubectl delete -f "https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml" --ignore-not-found=true 2>/dev/null || true
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true

if [ "${1:-}" = "--cluster" ]; then
  echo "==> destroying GKE cluster via terraform"
  ( cd "$HERE/deployment/terraform" && \
    GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
    terraform destroy -auto-approve )
fi
echo "==> done."
