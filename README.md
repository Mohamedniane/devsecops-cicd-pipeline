# DevSecOps CI/CD Pipeline with Kubernetes (K3s) & Wazuh SIEM

> Master's Thesis · Central University of Tunis · Defense July 2026
> Author: **Niane Mohamed** · [LinkedIn](https://linkedin.com/in/muhammed-niane) · muhammedniane@gmail.com

End-to-end secure software delivery pipeline combining Infrastructure-as-Code, a 7-stage DevSecOps pipeline with a custom scoring-based Security Gate, Kubernetes orchestration, and centralized SIEM monitoring — all deployed on a resource-constrained 3-VM lab with a single WSL2 control node.

[![Terraform](https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white)](https://terraform.io)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://ansible.com)
[![GitLab CI](https://img.shields.io/badge/GitLab_CI-FC6D26?logo=gitlab&logoColor=white)](https://gitlab.com)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-2496ED?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Wazuh](https://img.shields.io/badge/Wazuh-005B9A?logo=wazuh&logoColor=white)](https://wazuh.com)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Infrastructure as Code](#infrastructure-as-code)
4. [7-Stage Security Pipeline](#7-stage-security-pipeline)
5. [Custom Security Gate](#custom-security-gate)
6. [Kubernetes Deployment (K3s)](#kubernetes-deployment-k3s)
7. [Wazuh SIEM](#wazuh-siem)
8. [Reproducibility](#reproducibility)
9. [Results & Findings](#results--findings)
10. [Skills Demonstrated](#skills-demonstrated)

---

## Overview

### Problem statement

Most published DevSecOps reference architectures assume large cloud budgets (managed Kubernetes, managed SIEM, paid SAST/DAST licenses). SMEs and regulated environments with tight compliance boundaries (on-premise only, air-gapped labs, cost constraints) rarely see applicable blueprints.

### Thesis goal

Design and build a **production-grade-equivalent** DevSecOps pipeline that:

- Enforces **shift-left security** with open-source tooling only
- Runs entirely on **isolated infrastructure** (Host-Only network, no cloud)
- Fits on **< 20 GB RAM total** across all VMs
- Integrates **centralized observability** from CI to runtime
- Produces **audit-ready evidence** for ISO 27001 / GDPR compliance reviews

### Tech stack

| Layer | Technologies |
|---|---|
| Control plane | WSL2 · Ubuntu 22.04 · Terraform · Ansible · kubectl |
| Source & CI/CD | GitLab CE 16.8 · Docker Runner |
| Security scanners | GitLeaks · Semgrep · pip-audit · Trivy |
| Orchestration | K3s (lightweight Kubernetes) |
| Application | Flask (Python) — sample workload |
| SIEM | Wazuh Manager · OpenSearch · Filebeat 7.10.2 OSS |
| Threat framework | MITRE ATT&CK |

---

## Architecture

![Architecture diagram](docs/architecture.svg)

### Component map

```
┌─────────────────────────────────────────────────────────┐
│  WSL2 — Ubuntu 22.04 — Single control node              │
│  Terraform · Ansible · kubectl                          │
│                                                         │
└────────────┬────────────┬────────────┬──────────────────┘
             │            │            │
   Host-Only 192.168.137.0/24 — isolated
             │            │            │
       ┌─────▼─────┐┌─────▼─────┐┌─────▼─────┐
       │  VM1      ││  VM2      ││  VM3      │
       │  GitLab   ││  K3s      ││  Wazuh    │
       │  .10      ││  .20      ││  .30      │
       │  6 GB     ││  4 GB     ││  8 GB     │
       └───────────┘└───────────┘└───────────┘
```

### Design decisions

| Decision | Rationale |
|---|---|
| WSL2 as control node (not a 4th VM) | Saves 2 GB RAM; developer machine already runs WSL2 for day-to-day work |
| K3s instead of full Kubernetes | 70% smaller footprint, sufficient for single-node prod parity |
| Host-Only network | Zero attack surface from internet; simulates air-gapped enterprise lab |
| Self-hosted GitLab CE + registry | No dependency on SaaS; DSGVO-friendly (data stays on-prem) |
| Wazuh + OpenSearch (not paid SIEM) | Open-source, MITRE ATT&CK-ready out of the box |

---

## Infrastructure as Code

### Terraform — VM provisioning

Terraform provisions the 3 VMs via VirtualBox's native `VBoxManage` CLI (no VirtualBox provider required, keeping the dependency surface minimal).

```hcl
# terraform/main.tf — simplified
resource "null_resource" "vm_gitlab" {
  provisioner "local-exec" {
    command = "VBoxManage.exe createvm --name gitlab --ostype Ubuntu_64 --register"
  }
  # ... memory, NIC, host-only adapter, disk attachment
}
```

### Ansible — configuration management

Playbooks run directly from WSL2 over SSH. One playbook per VM role, plus a shared `common` role for baseline hardening (SSH config, firewall, unattended upgrades).

```
ansible/
├── inventory.yml
├── playbooks/
│   ├── site.yml
│   ├── gitlab.yml
│   ├── k3s.yml
│   └── wazuh.yml
└── roles/
    ├── common/
    ├── gitlab/
    ├── k3s-server/
    └── wazuh-manager/
```

---

## 7-Stage Security Pipeline

Defined in `.gitlab-ci.yml` — runs on every push to `main` or `develop`.

```
┌──────────┐  ┌─────────┐  ┌───────────┐  ┌──────────┐  ┌───────┐  ┌──────────────┐  ┌─────────┐
│ GitLeaks │→ │ Semgrep │→ │ pip-audit │→ │ Docker   │→ │ Trivy │→ │ Security     │→ │ Deploy  │
│ secrets  │  │ SAST    │  │ CVE scan  │  │ Build    │  │ image │  │ Gate (score) │  │ + DAST  │
└──────────┘  └─────────┘  └───────────┘  └──────────┘  └───────┘  └──────────────┘  └─────────┘
```

| Stage | Tool | What it catches | Blocks on |
|---|---|---|---|
| 1 | GitLeaks | Hardcoded API keys, tokens, passwords in git history | Any finding |
| 2 | Semgrep | SAST — OWASP Top 10, dangerous patterns, weak crypto | HIGH severity |
| 3 | pip-audit | Known CVEs in Python dependencies | CRITICAL CVE |
| 4 | Docker Build | Multi-stage build, non-root user, minimal base image | Build failure |
| 5 | Trivy | Container image CVEs (OS + language layers) | HIGH/CRITICAL |
| 6 | **Security Gate** | Aggregated score of all previous stages | **Score < 60/100** |
| 7 | Deploy + DAST | `kubectl apply` to K3s + OWASP ZAP active scan | Deployment or DAST failure |

### Artifacts produced per run

- JSON reports from each scanner (archived 90 days)
- Trivy SBOM in CycloneDX format
- Signed container image in GitLab Registry (tagged by commit SHA)
- OWASP ZAP HTML report

---

## Custom Security Gate

The novelty of this thesis: replacing the industry-standard **binary pass/fail** gate with a **scoring model** inspired by SSVC (Stakeholder-Specific Vulnerability Categorization).

### Why scoring, not binary?

A binary gate forces a choice: either every CRITICAL CVE blocks the build (then nothing ever deploys), or you whitelist CVEs (then compliance erodes). A scoring model lets you encode **risk tolerance as policy**.

### Scoring model

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

## Kubernetes Deployment (K3s)

### Why K3s over k8s?

| Metric | Full Kubernetes | K3s |
|---|---|---|
| Memory footprint | ~2 GB | ~512 MB |
| Install complexity | kubeadm + CNI + storage class + ... | Single binary |
| Prod parity for single-node | ✓ | ✓ |
| Suitable for thesis lab | ✗ (too heavy) | ✓ |

### Deployment specs

```yaml
# k8s/deployment.yaml — simplified
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pfe-app
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0   # zero-downtime deployments
      maxSurge: 1
  template:
    spec:
      containers:
      - name: flask
        image: registry.gitlab.local/project/pfe-app:${CI_COMMIT_SHA}
        securityContext:
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
---
apiVersion: v1
kind: Service
metadata:
  name: pfe-app
spec:
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 30500
```

### Rolling update demonstration

Every successful pipeline run triggers a rolling update. New pods must pass liveness/readiness probes before the old pods are terminated — true zero-downtime deployment validated in the lab.

---

## Wazuh SIEM

### Components

| Component | Role | Port |
|---|---|---|
| Wazuh Manager | Analysis engine + MITRE rules | 1514 (agents), 1515 (registration) |
| Wazuh Indexer | OpenSearch fork, stores events | 9200 |
| Wazuh Dashboard | OpenSearch Dashboards frontend | 443 |
| Filebeat 7.10.2 OSS | Forwards Manager → Indexer | internal |

### Agent coverage

- **VM1 (GitLab)** — monitors CI runner activity, GitLab audit logs, failed authentication
- **VM2 (K3s)** — monitors kubelet logs, container stdout/stderr, pod lifecycle events

### Custom MITRE ATT&CK rules implemented

| Rule | ATT&CK Technique | Detects |
|---|---|---|
| Pipeline secret leak | T1552.001 | GitLeaks finding that reaches artifact storage |
| Unusual kubectl activity | T1609 | `kubectl exec` outside deployment windows |
| Suspicious image pull | T1610 | Image pulled from unauthorized registry |
| Container breakout attempt | T1611 | Syscall patterns matching known escapes |

---

## Reproducibility

### Requirements

- Windows 10/11 with WSL2 (Ubuntu 22.04)
- VirtualBox 7.0+
- 20 GB RAM available (6 + 4 + 8 + 2 for WSL2)
- 80 GB free disk

### Quickstart

```bash
# 1. Clone this repo in WSL2
git clone https://github.com/Mohamedniane/devsecops-k3s-thesis.git
cd devsecops-k3s-thesis

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
- **45 min** full lab provisioning from zero (Terraform + Ansible)
- **< 3 min** pipeline execution on trivial code change (7 stages)
- **0 s** downtime during deployment (validated across 50+ rolling updates)

### Qualitative lessons

1. **Scoring gates > binary gates** for teams with mature security maturity — they encourage improvement rather than suppression.
2. **K3s is genuinely prod-parity** for single-node workloads. The thesis deliberately tested scenarios where K3s would differ from full Kubernetes — none were found for standard Deployment/Service/ConfigMap workflows.
3. **Wazuh correlation rules require tuning** — out-of-the-box rulesets produced ~40% false positives. Custom rules tuned to the pipeline context brought this under 5%.
4. **Secrets detection must run before anything else** — a secret that reaches any downstream tool (even a scanner's cache) is compromised.

### Limitations acknowledged

- Single-node K3s — true HA would require 3+ nodes
- No production traffic load testing — lab only
- MITRE rules tuned to Flask-app context — other frameworks would need adaptation

---

## Skills Demonstrated

- **Infrastructure as Code:** Terraform, Ansible, multi-VM orchestration
- **CI/CD engineering:** GitLab CI, Docker Runner, pipeline optimization
- **DevSecOps tooling:** SAST (Semgrep), SCA (pip-audit), container scanning (Trivy), secrets detection (GitLeaks), DAST (OWASP ZAP)
- **Kubernetes:** K3s, Deployments, Services, rolling updates, security contexts, Registry integration
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
