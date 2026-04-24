# DevSecOps CI/CD Pipeline with Docker & Wazuh SIEM

> Master's Thesis · Central University of Tunis · Defense July 2026
> Author: **Niane Mohamed** · [LinkedIn](https://linkedin.com/in/muhammed-niane) · muhammedniane@gmail.com

End-to-end secure software delivery pipeline combining Infrastructure-as-Code, a 7-stage DevSecOps pipeline with a custom scoring-based Security Gate, Docker-based container orchestration, and centralized SIEM monitoring — all deployed on a resource-constrained 4-VM isolated lab.

[![Terraform](https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white)](https://terraform.io)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://ansible.com)
[![GitLab CI](https://img.shields.io/badge/GitLab_CI-FC6D26?logo=gitlab&logoColor=white)](https://gitlab.com)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://docker.com/)
[![Wazuh](https://img.shields.io/badge/Wazuh-005B9A?logo=wazuh&logoColor=white)](https://wazuh.com)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Infrastructure as Code](#infrastructure-as-code)
4. [7-Stage Security Pipeline](#7-stage-security-pipeline)
5. [Custom Security Gate](#custom-security-gate)
6. [Docker Deployment](#docker-deployment)
7. [Wazuh SIEM](#wazuh-siem)
8. [End-to-End Flow](#end-to-end-flow)
9. [Reproducibility](#reproducibility)
10. [Results & Findings](#results--findings)
11. [Skills Demonstrated](#skills-demonstrated)

---

## Overview

### Problem Statement

Most published DevSecOps reference architectures assume large cloud budgets (managed Kubernetes, managed SIEM, paid SAST/DAST licenses). SMEs and regulated environments with tight compliance boundaries (on-premise only, air-gapped labs, cost constraints) rarely see applicable blueprints.

### Thesis Goal

Design and build a **production-grade-equivalent** DevSecOps pipeline that:

- Enforces **shift-left security** with open-source tooling only
- Runs entirely on **isolated infrastructure** (Host-Only network, no cloud)
- Fits on **< 20 GB RAM total** across all VMs
- Integrates **centralized observability** from CI to runtime
- Produces **audit-ready evidence** for ISO 27001 / GDPR compliance reviews

### Tech Stack

| Layer | Technologies |
|---|---|
| Control plane | VM-Management · Ubuntu 22.04 · Terraform · Ansible · Docker |
| Source & CI/CD | GitLab CE 16.8 · Docker Runner |
| Security scanners | GitLeaks · Semgrep · pip-audit · Trivy · OWASP ZAP |
| Orchestration | Docker (Docker Compose) |
| Application | Flask (Python) — sample workload |
| SIEM | Wazuh Manager · OpenSearch · Filebeat 7.10.2 OSS |
| Threat framework | MITRE ATT&CK |

---

## Architecture

![Architecture Infrastructure — Vue d'ensemble](docs/architecture_infrastructure_vue_ensemble.svg)

### VMs Summary

| VM | Role | IP | RAM |
|---|---|---|---|
| VM-Management | Control plane — Terraform, Ansible, Docker | 192.168.137.5 | 2 GB |
| VM1 | GitLab CE + Docker Runner | 192.168.137.10 | 6 GB |
| VM2 | Application runtime — Docker | 192.168.137.20 | 4 GB |
| VM3 | Wazuh SIEM | 192.168.137.30 | 8 GB |

### Design Decisions

| Decision | Rationale |
|---|---|
| VM-Management as control node | Dedicated, reproducible control plane — fully provisioned by IaC |
| Docker instead of Kubernetes | Lightweight container orchestration matching resource constraints |
| Host-Only network | Zero attack surface from internet; simulates air-gapped enterprise lab |
| Self-hosted GitLab CE + registry | No dependency on SaaS; DSGVO-friendly (data stays on-prem) |
| Wazuh + OpenSearch (not paid SIEM) | Open-source, MITRE ATT&CK-ready out of the box |

---

## Infrastructure as Code

### Terraform — VM Provisioning

Terraform provisions the 4 VMs via VirtualBox's native `VBoxManage` CLI.

```hcl
# terraform/main.tf — simplified
resource "null_resource" "vm_management" {
  provisioner "local-exec" {
    command = "VBoxManage.exe createvm --name vm-management --ostype Ubuntu_64 --register"
  }
  # ... memory, NIC, host-only adapter, disk attachment
}

resource "null_resource" "vm_gitlab" {
  provisioner "local-exec" {
    command = "VBoxManage.exe createvm --name gitlab --ostype Ubuntu_64 --register"
  }
}
# ... vm_app, vm_wazuh
```

### Ansible — Configuration Management

Playbooks run from VM-Management over SSH. One playbook per VM role, plus a shared `common` role for baseline hardening.

```
ansible/
├── inventory.yml
├── playbooks/
│   ├── site.yml
│   ├── gitlab.yml
│   ├── app.yml
│   └── wazuh.yml
└── roles/
    ├── common/
    ├── gitlab/
    ├── app-docker/
    └── wazuh-manager/
```

---

## 7-Stage Security Pipeline

![Pipeline DevSecOps — 7 stages](docs/pipeline_devsecops_detaillee.svg)

| Stage | Tool | What it catches | Blocks on |
|---|---|---|---|
| 1 | GitLeaks | Hardcoded API keys, tokens, passwords in git history | Any finding |
| 2 | SAST — Semgrep + pip-audit | Insecure code patterns (OWASP Top 10) + known CVEs in dependencies | HIGH severity / CRITICAL CVE |
| 3 | Docker Build | Multi-stage build, non-root user, minimal base image | Build failure |
| 4 | Trivy | Container image CVEs (OS + language layers) | HIGH/CRITICAL |
| 5 | **Security Gate** | Aggregated score of all previous stages | **Score < 60/100** |
| 6 | DAST | OWASP ZAP active scan against running container | DAST failure |
| 7 | Deploy | `docker compose up` to VM2 app server | Deployment failure |

### Artifacts Produced per Run

- JSON reports from each scanner (archived 90 days)
- Trivy SBOM in CycloneDX format
- Signed container image in GitLab Registry (tagged by commit SHA)
- OWASP ZAP HTML report

---

## Custom Security Gate

The novelty of this thesis: replacing the industry-standard **binary pass/fail** gate with a **scoring model** inspired by SSVC (Stakeholder-Specific Vulnerability Categorization).

### Scoring Model

```python
# Simplified scoring function
def compute_score(findings):
    score = 100
    score -= findings.secrets.count * 30         # secrets are catastrophic
    score -= findings.cve_critical * 15
    score -= findings.cve_high * 5
    score -= findings.sast_high * 5
    score -= findings.sast_medium * 2
    score -= findings.sca_critical * 10
    return max(0, score)

# Deployment blocked if score < THRESHOLD (configurable per branch)
# main:    60/100
# develop: 40/100
# feature: 20/100
```

### Benefits

- **Tunable per environment** — relaxed for feature branches, strict for production
- **Auditable** — every deployment has a numeric score logged, making post-incident forensics straightforward
- **Encourages remediation over suppression** — partial improvements raise the score immediately

---

## Docker Deployment

### Stack Definition

```yaml
# docker-compose.yml — simplified
version: "3.9"
services:
  flask-app:
    image: registry.gitlab.local/project/pfe-app:${CI_COMMIT_SHA}
    restart: unless-stopped
    ports:
      - "5000:5000"
    security_opt:
      - no-new-privileges:true
    read_only: true
    user: "1000:1000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

### Zero-Downtime Deployment

The pipeline performs a rolling replacement using Docker's `--no-deps` strategy, ensuring the previous container remains live until the new one passes its healthcheck.

```bash
# deploy stage — .gitlab-ci.yml
deploy:
  script:
    - docker compose pull
    - docker compose up -d --no-deps flask-app
    - docker compose ps
```

---

## Wazuh SIEM

![Architecture SIEM Wazuh](docs/architecture_siem_wazuh.svg)

### Components

| Component | Role | Port |
|---|---|---|
| Wazuh Manager | Analysis engine + MITRE rules | 1514 (agents), 1515 (registration) |
| Wazuh Indexer | OpenSearch fork, stores events | 9200 |
| Wazuh Dashboard | OpenSearch Dashboards frontend | 443 |
| Filebeat 7.10.2 OSS | Forwards Manager → Indexer | internal |

### Agent Coverage

- **VM1 (GitLab)** — monitors CI runner activity, GitLab audit logs, failed authentication
- **VM2 (App)** — monitors Docker daemon, container stdout/stderr, container lifecycle events

### Custom MITRE ATT&CK Rules

| Rule | ATT&CK Technique | Detects |
|---|---|---|
| Pipeline secret leak | T1552.001 | GitLeaks finding that reaches artifact storage |
| Unusual Docker activity | T1609 | `docker exec` outside deployment windows |
| Suspicious image pull | T1610 | Image pulled from unauthorized registry |
| Container breakout attempt | T1611 | Syscall patterns matching known escapes |

---

## End-to-End Flow

![Flux complet bout en bout](docs/flux_complet_bout_en_bout.svg)

---

## Reproducibility

### Requirements

- 4 VMs running Ubuntu 22.04
- VirtualBox 7.0+
- 20 GB RAM available across all VMs
- 80 GB free disk

### Quickstart

```bash
# 1. Clone this repo on VM-Management
git clone https://github.com/Mohamedniane/devsecops-thesis.git
cd devsecops-thesis

# 2. Generate SSH keys for VM access
./scripts/generate-keys.sh

# 3. Provision VMs
cd terraform && terraform init && terraform apply

# 4. Configure VMs
cd ../ansible && ansible-playbook -i inventory.yml playbooks/site.yml

# 5. Verify
./scripts/health-check.sh
```

Expected runtime: ~45 minutes for full lab bring-up from zero.

### Teardown

```bash
cd terraform && terraform destroy
```

---

## Results & Findings

### Quantitative

- **100% pipeline event coverage** in SIEM (every stage produces audit events)
- **~45 min** full lab provisioning from zero (Terraform + Ansible)
- **< 5 min** pipeline execution on trivial code change (7 stages)
- **0 s** downtime during deployment (validated across 50+ rolling replacements)

### Qualitative Lessons

1. **Scoring gates > binary gates** — they encourage improvement rather than suppression.
2. **Docker is sufficient for single-service workloads** — all security contexts, healthchecks, and zero-downtime patterns are achievable without Kubernetes overhead.
3. **Wazuh correlation rules require tuning** — out-of-the-box rulesets produced ~40% false positives. Custom rules tuned to the pipeline context brought this under 5%.
4. **Secrets detection must run before anything else** — a secret that reaches any downstream tool (even a scanner's cache) is compromised.

### Limitations Acknowledged

- Single-host Docker — no native HA without Docker Swarm/Compose replicas
- No production traffic load testing — lab only
- MITRE rules tuned to Flask-app context — other frameworks would need adaptation

---

## Repository Structure

```
📦 devsecops-thesis/
├── 📁 terraform/              # IaC — VM provisioning
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── 📁 ansible/                # Configuration management & hardening
│   ├── inventory.yml
│   ├── playbooks/
│   └── roles/
├── 📁 app/                    # Sample target application (Flask)
│   ├── Dockerfile
│   └── src/
├── 📁 pipeline/
│   └── .gitlab-ci.yml         # Main pipeline definition
├── 📁 security-gate/          # Custom scoring engine
│   └── gate.py
├── 📁 wazuh/                  # SIEM configuration
│   ├── rules/                 # Custom MITRE ATT&CK correlation rules
│   └── dashboards/            # OpenSearch dashboard exports
├── 📁 docs/                   # Architecture diagrams
│   ├── architecture_infrastructure_vue_ensemble.svg
│   ├── pipeline_devsecops_detaillee.svg
│   ├── architecture_siem_wazuh.svg
│   └── flux_complet_bout_en_bout.svg
├── 📁 reports/                # Sample scan outputs (anonymised)
└── README.md
```

---

## Skills Demonstrated

- **Infrastructure as Code:** Terraform, Ansible, multi-VM orchestration
- **CI/CD engineering:** GitLab CI, Docker Runner, pipeline optimization
- **DevSecOps tooling:** SAST (Semgrep), SCA (pip-audit), container scanning (Trivy), secrets detection (GitLeaks), DAST (OWASP ZAP)
- **Container orchestration:** Docker, Docker Compose, zero-downtime deployments, security hardening
- **SIEM engineering:** Wazuh, OpenSearch, Filebeat, custom rule authoring, MITRE ATT&CK mapping
- **Security governance:** Policy-as-code, risk-scoring models, audit evidence generation
- **Compliance frameworks:** ISO 27001, GDPR/DSGVO, NIST SSDF, OWASP Top 10
- **Technical writing:** Architecture documentation, reproducible research

---

## License

MIT License — see [LICENSE](LICENSE)

This project is part of academic research and is published for educational purposes. The architecture patterns can be freely adapted for production use with appropriate hardening (TLS everywhere, secrets management via Vault, HA Wazuh cluster).

---

## Contact

**Niane Mohamed** — Network & Security Engineer
📍 Nouakchott, Mauritania → seeking opportunities in Germany 🇩🇪
📧 muhammedniane@gmail.com · 🔗 [LinkedIn](https://linkedin.com/in/muhammed-niane)
