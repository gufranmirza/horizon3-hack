# horizon3-hack — Kubernetes Pentest Simulation Environment

A **bespoke, deliberately-vulnerable GKE cluster** used as **ground truth** to benchmark a
Kubernetes pentesting tool/agent. We plant a single connected **kill chain** (edge → worker node)
plus ambient misconfigurations and **honeypots**, then run the tool under test and grade its
output against a labeled matrix.

> ⚠️ **This repo provisions an intentionally insecure cluster. NEVER deploy it in production,
> or in any project/VPC connected to production. Use an isolated, throwaway GCP project.**

## Why

Testing a pentest agent needs *ground truth*: which vulns are really there, at what difficulty,
and — critically — whether the tool **actually exploited** them vs. pattern-matched/hallucinated.
This environment answers all three:

- **Kill chain (edge → node):** one connected storyline, so a good agent should chain 27 planted
  weaknesses from the ingress to worker-node root + cluster-admin.
- **Difficulty tiers T1→T4:** trivial single-findings up to subtle multi-primitive combinations.
- **Honeypots:** *canaries* prove real execution (report must contain a value only reachable by
  genuinely interacting), *decoys* catch pattern-matchers (look vulnerable, aren't exploitable).

Scope is **in-cluster only** — no GCP/IAM cloud pivot (node SA left default, no IAM granted).

## Layout

```
docs/
  K8s-sim-design.md               Full kill-chain spec + design rationale (READ THIS FIRST)
  k8s-ground-truth.json           Machine-readable matrix for auto-scoring the tool
  K8s-kill-chain-verification.md  Validated end-to-end exploitation report (with evidence)
deployment/
  terraform/                      GKE Standard cluster IaC (reusable — more clusters = one apply)
  manifests/                      Vulnerable K8s YAML by stage, canaries, decoys, beacon listener
scripts/                          deploy / verify / teardown helpers
```

## Status

🟢 **Built, deployed, and validated end-to-end** (internet → cluster-admin; all 4 canaries fired).
See [docs/K8s-sim-design.md](docs/K8s-sim-design.md) for the design,
[docs/k8s-ground-truth.json](docs/k8s-ground-truth.json) for the labeled matrix, and
[docs/K8s-kill-chain-verification.md](docs/K8s-kill-chain-verification.md) for the verification report.

## Quickstart

```bash
# 1. Auth + point at a throwaway project (you run this)
gcloud auth login
gcloud config set project <YOUR_THROWAWAY_PROJECT_ID>

# 2. Stand up the vulnerable cluster
cd deployment/terraform && cp terraform.tfvars.example terraform.tfvars   # edit project_id
terraform init && terraform apply
cd ../..

# 3. Plant the kill chain (run from repo root)
scripts/deploy.sh

# 4. Sanity-check, then point your pentest tool at the cluster
scripts/verify.sh
# ...grade the tool's output against docs/k8s-ground-truth.json

# Teardown between test windows (add --cluster to also terraform destroy)
scripts/teardown.sh
```
