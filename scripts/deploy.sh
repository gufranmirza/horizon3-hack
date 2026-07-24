#!/usr/bin/env bash
# Plant the full kill chain onto the cluster. Idempotent (safe to re-run).
# Prereqs: gcloud auth + project set, cluster created via terraform/, kubectl+helm.
set -euo pipefail

PROJECT="${PROJECT:-horizon3-hack26sfo-3706}"
CLUSTER="${CLUSTER:-pentest-sim}"
ZONE="${ZONE:-us-central1-a}"
INGRESS_CHART_VERSION="${INGRESS_CHART_VERSION:-4.11.2}"  # controller 1.11.2 = IngressNightmare-vulnerable (<1.11.5)
DASHBOARD_VERSION="${DASHBOARD_VERSION:-v2.7.0}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> [0/5] kubeconfig for ${CLUSTER}"
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE" --project "$PROJECT"

echo "==> [1/5] namespaces + kill-chain manifests"
kubectl apply -f "$HERE/deployment/manifests/00-namespaces.yaml"
kubectl apply -f "$HERE/deployment/manifests/20-foothold.yaml"
kubectl apply -f "$HERE/deployment/manifests/30-rbac.yaml"
kubectl apply -f "$HERE/deployment/manifests/50-node-and-secrets.yaml"
kubectl apply -f "$HERE/deployment/manifests/70-honeypots.yaml"
kubectl apply -f "$HERE/deployment/manifests/80-decoys.yaml"
kubectl apply -f "$HERE/deployment/manifests/40-breakout.yaml"   # after ns (PSA privileged) exists

echo "==> [2/5] vulnerable ingress-nginx (chart ${INGRESS_CHART_VERSION}) [V02/V04]"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version "$INGRESS_CHART_VERSION" \
  --set controller.allowSnippetAnnotations=true \
  --set controller.service.type=LoadBalancer

echo "==> [3/5] edge ingress + exposed internal admin [V03]"
echo "    waiting for ingress-nginx controller + admission webhook to be ready..."
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s || true
# Wait until the admission webhook has endpoints, else Ingress creation 500s.
for i in $(seq 1 30); do
  eps="$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  [ -n "$eps" ] && break
  sleep 5
done
kubectl apply -f "$HERE/deployment/manifests/10-edge.yaml" || echo "WARN: edge ingress apply failed (webhook not ready?) — re-run deploy.sh"

echo "==> [4/5] exposed Kubernetes Dashboard, skip-login + cluster-admin [V01]"
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml"
# Make it anonymously usable and all-powerful (the Tesla-style misconfig):
kubectl -n kubernetes-dashboard patch deployment kubernetes-dashboard --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-skip-login"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--disable-settings-authorizer"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--enable-insecure-login"}
]' || true
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:kubernetes-dashboard \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kubernetes-dashboard patch service kubernetes-dashboard \
  -p '{"spec":{"type":"LoadBalancer"}}' || true

echo "==> [5/5] done. External IPs (may take ~60s to populate):"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide 2>/dev/null || true
kubectl get svc -n kubernetes-dashboard kubernetes-dashboard -o wide 2>/dev/null || true
echo "NodePort admin (V03): http://<any-node-external-ip>:30080"
echo "Run scripts/verify.sh to sanity-check the planted chain."
