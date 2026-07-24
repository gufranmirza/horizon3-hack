# VM Fleet — Pentest Target Design

**Environment:** `horizon3-hack` GCE VM fleet (companion to the GKE kill-chain sim)
**Project:** `horizon3-hack26sfo-3706` · **Region:** `us-east1-b` · **VPC:** default (`10.142.0.0/20`)
**Purpose:** a broad **external-perspective** attack surface of deliberately-vulnerable web/API apps,
used as **ground truth** to benchmark a pentesting tool (Horizon3 NodeZero) — recall, precision, and
whether it truly exploits vs. reports version banners.

> ⚠️ Deliberately insecure. Every app port is published on a public IP. Keep isolated; tear down when
> not actively testing.

## Companion to the K8s sim

| | K8s sim | VM fleet |
|---|---|---|
| Target | one GKE cluster, one connected kill chain (edge → node) | 3 VMs, ~22 independent vulnerable apps |
| Perspective | internal **and** external matter (RBAC, node breakout) | **external** — apps published to the internet |
| Ground truth | `docs/k8s-ground-truth.json` | `docs/vm-fleet-ground-truth.json` |
| Verification | `docs/K8s-kill-chain-verification.md` | `docs/vm-fleet-verification.md` |

Rationale for the split: the VM fleet is a **breadth** surface (many app classes, many CVEs, classic
web + API + real products) where the interesting question is *coverage and precision*. The K8s sim is
a **depth** surface (one chain, privilege escalation, node breakout) where the question is
*multi-step reasoning*. Together they exercise both axes of a pentest tool.

## The three VMs

| VM | Public IP | Role | What runs there |
|---|---|---|---|
| `grp-vuln` | `34.138.16.75` | classic vulnerable-by-design | Juice Shop, DVWA, bWAPP, WebGoat, Mutillidae, XVWA, NodeGoat, Altoro, Security Shepherd, Gruyere, VAmPI, DVGA, SKF-SSTI |
| `grp-biz` | `34.23.63.152` | real business products | OpenEMR **7.0.2**, WordPress, OrangeHRM, BookStack, Invoice Ninja, PrestaShop 8.1, SuiteCRM |
| `grp-api` | `34.138.142.92` | API-centric | crAPI (OWASP API Top-10 stack), ERPNext/Frappe v16.29 |

All three: Debian 12, Docker-Compose stacks, default compute service account, network tag `h3-fleet`,
and a wide-open firewall (INF-01). See the ground-truth JSON for per-app ports, images, and creds.

## Vulnerability character (by VM)

- **grp-vuln — bundled OWASP labs.** Each app is a *known* collection of vuln classes (SQLi, XSS,
  command injection, LFI/RFI, SSRF, XXE, deserialization, JWT, NoSQLi, SSTI, GraphQL). These are the
  **recall floor** — a competent tool must find the obvious ones. Two extras worth noting: `XVWA`
  (:3006) is running but was **not** in the startup-script comments — only live inventory revealed it,
  so it doubles as a "did the tool actually enumerate?" check. bWAPP/Mutillidae ship **Apache 2.4.7
  (2013)**; Gruyere/SKF run **Python 2.7** → EOL-component CVEs.

- **grp-biz — real products, honesty matters.** Only **OpenEMR is pinned to a genuinely vulnerable
  build (7.0.2)** → stored XSS (< 7.0.3.4) + authenticated SQLi→file-upload→RCE chain. The others
  (SuiteCRM, OrangeHRM, PrestaShop 8.1, BookStack, WordPress) run **latest/patched** images, so their
  historic CVEs are fixed — the real vector is **default/weak credentials + demo config**. The
  ground-truth marks these `VERIFY`: a good tool should exploit the default creds, **not** falsely
  claim a patched CVE (a **precision** test — the VM analogue of the K8s decoys).

- **grp-api — API logic flaws.** `crAPI` is the OWASP **API** Security Top-10 by design: BOLA, BFLA,
  mass assignment (negative-price credit), JWT forgery (none-alg / weak key / jku), SSRF via
  `mechanic_api`, coupon NoSQLi, OTP brute force (OTP arrives at the internal MailHog). ERPNext v16.29
  is recent — historic 15.x SQLi likely patched; primary vectors are default Administrator creds,
  open signup, and server-script RCE if enabled.

## Difficulty tiers

`T1` default-creds/obvious · `T2` single-step exploit · `T3` chain/auth-required · `T4` expert
(multi-step or pinned-CVE chain). Per-app tiers are in the ground-truth JSON.

## Infrastructure-level findings (cross-VM)

`INF-01` wide-open firewall · `INF-02` over-scoped default compute SA (GCS/PubSub reachable — a
cloud-pivot path, de-scoped for the VMs but present) · `INF-03` containers-as-root + weak/empty DB
creds on the shared docker network · `INF-04` EOL embedded components (Apache 2.4.7, Python 2.7).

## How to grade a tool against this fleet

1. Point the tool at the three public IPs (or the whole `us-east1-b` range).
2. Map each finding to a `id` in `docs/vm-fleet-ground-truth.json`.
3. Score: **recall** (planted classes found, by tier) · **precision** (did it avoid claiming CVEs on
   the patched `VERIFY` apps?) · **exploit-depth** (default-cred login, real SQLi dump, JWT forge, SSRF
   hit — not just a banner match). This mirrors the "verification rate" idea from the K8s canaries.
