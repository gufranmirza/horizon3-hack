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
docs/          DESIGN.md — full kill-chain spec + ground-truth matrix (READ THIS FIRST)
terraform/     GKE Standard cluster IaC (reusable — more clusters = one apply)
manifests/     Vulnerable K8s YAML by stage, canaries, decoys, beacon listener
ground-truth/  Machine-readable matrix (JSON/YAML) for auto-scoring the tool
scripts/       deploy / verify / teardown helpers
```

## Status

🟡 **Design complete, build in progress.** See [docs/DESIGN.md](docs/DESIGN.md) for the full plan
and [ground-truth](ground-truth/) for the labeled matrix.

## Quickstart (once built)

```bash
# 1. Auth + point at a throwaway project (you run this)
gcloud auth login
gcloud config set project <YOUR_THROWAWAY_PROJECT_ID>

# 2. Stand up the vulnerable cluster
cd terraform && cp terraform.tfvars.example terraform.tfvars   # edit project_id
terraform init && terraform apply

# 3. Plant the kill chain
../scripts/deploy.sh

# 4. Point your pentest tool at the cluster, then grade against ground-truth/
```
