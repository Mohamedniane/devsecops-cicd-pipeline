# DevSecOps CI/CD Security Pipeline

> 🎓 **Master's Thesis Project** — Central University of Tunis, 2026
> End-to-end secure CI/CD pipeline with integrated security controls at every stage of the SDLC.

[![Terraform](https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white)](https://terraform.io)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)](https://ansible.com)
[![GitLab CI](https://img.shields.io/badge/GitLab_CI-FC6D26?logo=gitlab&logoColor=white)](https://gitlab.com)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](https://docker.com)
[![Wazuh](https://img.shields.io/badge/Wazuh-005B9A?logo=wazuh&logoColor=white)](https://wazuh.com)

---

## 🎯 Project Overview

This project implements a **fully automated, security-first CI/CD pipeline** designed to embed security controls directly into the software delivery lifecycle. The goal was to move security from a post-deployment afterthought to a first-class engineering discipline — the core principle of DevSecOps.

The pipeline was designed, deployed, and tested on **local infrastructure** to validate the architecture end-to-end before any production rollout.

---

## 🏗️ Architecture

```
┌──────────────┐     ┌───────────────┐     ┌───────────────┐
│  Developer   │────▶│   GitLab CE   ────▶│Docker Runner  │
│    Commit    │     │   Repository  │     │   Pipeline    │ 
└──────────────┘     └───────────────┘     └───────┬───────┘
                                                   │
        ┌──────────────────────────────────────────┤
        ▼                                          ▼
┌───────────────┐  ┌─────────────┐  ┌──────────────────────┐
│ SAST Scanner  │  │DAST Scanner │  │ Container + Secrets  │
│   Semgrep     │  │  OWASP ZAP  │  │  Trivy + GitLeaks    │
└───────┬───────┘  └──────┬──────┘  └──────────┬───────────┘
        │                 │                    │
        └─────────────────┼────────────────────┘
                          ▼
                ┌──────────────────┐
                │  Wazuh + ELK     │
                │   Centralized    │
                │      SIEM        │
                └──────────────────┘
```

---

## 🛠️ Tech Stack

### Infrastructure as Code
- **Terraform** — Infrastructure provisioning
- **Ansible** — Configuration management and server hardening

### CI/CD Orchestration
- **GitLab CE** — Self-hosted Git + CI/CD platform
- **GitLab Runner (Docker Executor)** — Containerized job execution

### Security Controls
| Control | Tool | Stage |
|---------|------|-------|
| **SAST** (Static Code Analysis) | Semgrep | Code commit |
| **DAST** (Dynamic Testing) | OWASP ZAP | Staging |
| **Secrets Detection** | GitLeaks | Pre-commit |
| **Container Scanning** | Trivy | Build stage |
| **Dependency Security (SCA)** | Dependabot | Continuous |

### Monitoring & SIEM
- **Wazuh** — HIDS, compliance, vulnerability detection
- **Elastic Stack (ELK)** — Log aggregation, correlation, and visualization

---

## 🚀 Key Results

- ✅ **100% pipeline event coverage** in centralized SIEM
- ✅ **5 automated security gates** before any merge to main branch
- ✅ **Zero secrets leakage** through automated GitLeaks enforcement
- ✅ **Shift-left security** — vulnerabilities caught at commit time, not production

---

## 📁 Repository Structure

```
devsecops-cicd-pipeline/
├── terraform/              # IaC provisioning modules
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ansible/                # Configuration playbooks
│   ├── gitlab-runner.yml
│   ├── wazuh-agent.yml
│   └── hardening.yml
├── .gitlab-ci.yml         # CI/CD pipeline definition
├── security/
│   ├── semgrep-rules/     # Custom SAST rules
│   ├── zap-baseline.conf  # DAST scan configuration
│   └── trivy-policy.yaml  # Container scan policy
├── wazuh/
│   ├── decoders/
│   └── rules/
├── docs/
│   ├── architecture.md
│   ├── setup-guide.md
│   └── threat-model.md
└── README.md
```

---

## 📖 Documentation

- [Architecture Deep Dive](./docs/architecture.md)
- [Setup Guide](./docs/setup-guide.md)
- [Threat Model](./docs/threat-model.md)

---

## 🎓 Academic Context

This work was submitted as part of the requirements for the **Master's Degree in Cybersecurity** at the Central University of Tunis (2026). The thesis explores how security automation can reduce incident response time while maintaining developer velocity.

---

## 📫 Contact

**Niane Mohamed Youssouf**
Cybersecurity & Network Engineer

- 💼 [LinkedIn](https://linkedin.com/in/muhammed-niane)
- ✉️ muhammedniane@gmail.com
- 🌐 [GitHub Profile](https://github.com/Mohamedniane)

---

## 📄 License

This project is released under the MIT License. See [LICENSE](./LICENSE) for details.

> ⚠️ **Disclaimer:** This project is for educational and research purposes only. All security testing tools must be used in authorized environments.
