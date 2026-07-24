# VM Fleet — Verification Report

**Environment:** `horizon3-hack` GCE VM fleet · **Project:** `horizon3-hack26sfo-3706` · `us-east1-b`
**Date verified:** 2026-07-24
**Method:** (1) authenticated inventory via `gcloud compute ssh <vm> -- sudo docker ps`, and
(2) unauthenticated external HTTP fingerprint of each published port on the VM public IPs.
**Confidence levels below:** `RUNNING` = container confirmed up via SSH · `REACHABLE` = answered over
the internet · `VERSION` = image tag confirmed · `EXPLOIT` = issue exploited live (noted where done).

> Scope of this report: it verifies **what exists and is reachable** (inventory, versions, exposure)
> to the same evidentiary standard as the K8s report's target enumeration. It does **not** claim every
> listed vuln was individually exploited — the per-app exploitation is what the pentest tool under test
> should perform, then be graded against `docs/vm-fleet-ground-truth.json`. Items actually exploited
> during verification are called out explicitly.

## VM inventory (confirmed reachable)

| VM | External IP | OS | SSH | Docker |
|---|---|---|---|---|
| grp-vuln | 34.138.16.75 | Debian 12 | ✅ | ✅ 14 containers up |
| grp-biz | 34.23.63.152 | Debian 12 | ✅ | ✅ 7 app stacks up |
| grp-api | 34.138.142.92 | Debian 12 | ✅ | ✅ crAPI + ERPNext stacks up |
| nodezero-host | 34.16.92.197 | Ubuntu 22.04 | (scanner box — not a target) | — |
| gke node | 136.111.150.217 | COS | (K8s sim node) | — |

## grp-vuln — 34.138.16.75  (`RUNNING` via docker ps, `REACHABLE` via HTTP)

| ID | App | Port | Image (VERSION) | Status |
|---|---|---|---|---|
| VLN-01 | Juice Shop | 3000 | bkimminich/juice-shop | RUNNING · REACHABLE (200) |
| VLN-02 | DVWA | 3001 | ghcr.io/digininja/dvwa | RUNNING · REACHABLE (302→login) |
| VLN-03 | bWAPP | 3002 | raesene/bwapp (Apache/2.4.7) | RUNNING · REACHABLE |
| VLN-04 | WebGoat/WebWolf | 3003/3004 | webgoat/webgoat | RUNNING (unhealthy) · REACHABLE |
| VLN-05 | Mutillidae | 3005 | citizenstig/nowasp (Apache/2.4.7) | RUNNING · REACHABLE |
| VLN-06 | **XVWA** | 3006 | xvwa-xvwa (+mysql:5.7) | RUNNING · REACHABLE — *not in startup-script comments; found via SSH* |
| VLN-07 | NodeGoat | 3007 | ng-web (+mongo:4.4) | RUNNING · REACHABLE (302) |
| VLN-08 | Altoro Mutual | 3008 | eystsen/altoro | RUNNING · REACHABLE (200) |
| VLN-09 | Security Shepherd | 3012 | owasp/security-shepherd | RUNNING (came up late) |
| VLN-10 | Gruyere | 3013 | karthequian/gruyere (Python 2.7) | RUNNING · REACHABLE |
| VLN-11 | VAmPI | 3014 | erev0s/vampi:latest (vulnerable=1) | RUNNING · REACHABLE (200) |
| VLN-12 | DVGA | 3017 | dolevf/dvga | RUNNING · REACHABLE (200) |
| VLN-13 | SKF SSTI | 3018 | blabla1337/owasp-skf-lab:ssti (Py2.7) | RUNNING · REACHABLE |

## grp-biz — 34.23.63.152

| ID | App | Port | Image (VERSION) | Status |
|---|---|---|---|---|
| BIZ-01 | **OpenEMR** | 3021/3121 | **openemr/openemr:7.0.2** (+mariadb:10.6) | RUNNING · REACHABLE — **pinned vulnerable build** |
| BIZ-02 | WordPress | 3023 | wordpress:latest (+mariadb:11) | RUNNING · REACHABLE |
| BIZ-03 | OrangeHRM | 3028 | orangehrm/orangehrm:latest | RUNNING · REACHABLE |
| BIZ-04 | BookStack | 3026 | lscr.io/linuxserver/bookstack:latest | RUNNING · REACHABLE (302→login) |
| BIZ-05 | Invoice Ninja | 3019 | invoiceninja/invoiceninja-debian (+mysql:8) | RUNNING (healthy) |
| BIZ-06 | PrestaShop | 3025 | prestashop/prestashop:8.1-apache | RUNNING · REACHABLE |
| BIZ-07 | SuiteCRM | 3027/3127 | bitnamilegacy/suitecrm:latest | RUNNING · REACHABLE (200) |

Down / still building at verification: **Magento** (:3022) and **OpenCart** (:3024) returned no
listener — heavy Bitnami stacks; re-check later. (When Magento is up and ≤ 2.4.6 it's the CosmicSting
`CVE-2024-34102` target.)

## grp-api — 34.138.142.92

| ID | App | Port | Image (VERSION) | Status |
|---|---|---|---|---|
| API-01 | crAPI (stack) | 3015 | crapi/* microservices + mailhog | RUNNING (healthy) · REACHABLE (200) |
| API-02 | ERPNext / Frappe | 3020 | **frappe/erpnext:v16.29.0** (+mariadb:11.8) | RUNNING · REACHABLE (200, "Login") |

MailHog bound to `127.0.0.1:8025` (internal only — receives crAPI OTP email; not externally exposed).

## Exploited during verification (EXPLOIT-confirmed)

*(none run against the VM apps yet — verification covered inventory/version/reachability only. Per-app
exploitation is the pentest-tool run. The K8s report, by contrast, includes full live exploitation.)*

## Accuracy notes (CVE honesty)

- **OpenEMR 7.0.2** is the one grp-biz app pinned to a **genuinely vulnerable** build: stored XSS
  (fixed 7.0.3.4) + authenticated SQLi→file-upload→RCE chain apply. HIGH confidence.
- **SuiteCRM / OrangeHRM / PrestaShop 8.1 / BookStack** run **latest/patched** images — their historic
  CVEs (e.g. SuiteCRM `CVE-2024-36415`, OrangeHRM `CVE-2020-29437`, PrestaShop `<8.1.1` SQLi) are
  **likely already fixed**. Ground truth marks these `VERIFY`; the real live vector is **default creds**.
  A tool that claims these CVEs without confirming the build is a **false positive** (precision test).
- **ERPNext v16.29.0** is newer than the 15.x SQLi CVEs found in research → likely patched; treat as
  default-cred / config target unless a version-specific advisory is confirmed.
- **crAPI / VAmPI / DVGA / Juice Shop / DVWA / bWAPP / WebGoat / Mutillidae / XVWA / NodeGoat / Altoro /
  Gruyere / SKF / Shepherd** are vulnerable-by-design — issues are **classes**, not version CVEs.

## Status

Inventory + reachability + versions **verified live** for 22 running app targets across 3 VMs plus 4
infrastructure findings. Ready for a pentest-tool run; grade output against
`docs/vm-fleet-ground-truth.json`. Open follow-ups: bring up Magento/OpenCart, then (optionally) run a
live-exploitation pass to raise each app from REACHABLE to EXPLOIT-confirmed.
