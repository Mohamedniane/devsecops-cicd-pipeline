#!/usr/bin/env python3
import json, os, sys

# Chargement des seuils depuis les variables GitLab CI
THRESHOLD = int(os.environ.get('GATE_THRESHOLD', '60'))
PENALTY_SECRET = int(os.environ.get('GATE_PENALTY_SECRET', '50'))
PENALTY_CRITICAL = int(os.environ.get('GATE_PENALTY_CRITICAL', '10'))
PENALTY_HIGH = int(os.environ.get('GATE_PENALTY_HIGH', '3'))
PENALTY_SAST_ERROR = int(os.environ.get('GATE_PENALTY_SAST_ERROR', '5'))
PENALTY_SAST_WARNING = int(os.environ.get('GATE_PENALTY_SAST_WARNING', '2'))
PENALTY_DEPENDENCY = int(os.environ.get('GATE_PENALTY_DEPENDENCY', '7'))

def safe_load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None

score = 100
details = []

# --- GitLeaks ---
gitleaks = safe_load('gitleaks-report.json')
secrets = len(gitleaks) if isinstance(gitleaks, list) else 0
score -= secrets * PENALTY_SECRET
details.append(f'Secrets (GitLeaks):    {secrets:3d} x -{PENALTY_SECRET}')

# --- Semgrep ---
semgrep = safe_load('semgrep-report.json')
if semgrep and 'results' in semgrep:
    sast_err = sum(1 for r in semgrep['results']
                   if r.get('extra', {}).get('severity') == 'ERROR')
    sast_warn = sum(1 for r in semgrep['results']
                    if r.get('extra', {}).get('severity') == 'WARNING')
    score -= sast_err * PENALTY_SAST_ERROR
    score -= sast_warn * PENALTY_SAST_WARNING
    details.append(f'SAST ERROR:            {sast_err:3d} x -{PENALTY_SAST_ERROR}')
    details.append(f'SAST WARNING:          {sast_warn:3d} x -{PENALTY_SAST_WARNING}')

# --- pip-audit ---
dep = safe_load('dependency-report.json')
if dep and 'dependencies' in dep:
    cves_dep = sum(len(d.get('vulns', [])) for d in dep['dependencies'])
    score -= cves_dep * PENALTY_DEPENDENCY
    details.append(f'DEPS CVE:              {cves_dep:3d} x -{PENALTY_DEPENDENCY}')

# --- Trivy ---
trivy = safe_load('trivy-report.json')
if trivy and 'Results' in trivy:
    crit = high = 0
    for res in trivy['Results']:
        for v in res.get('Vulnerabilities', []) or []:
            if v.get('Severity') == 'CRITICAL': crit += 1
            elif v.get('Severity') == 'HIGH':   high += 1
    score -= crit * PENALTY_CRITICAL
    score -= high * PENALTY_HIGH
    details.append(f'IMAGE CVE CRITICAL:    {crit:3d} x -{PENALTY_CRITICAL}')
    details.append(f'IMAGE CVE HIGH:        {high:3d} x -{PENALTY_HIGH}')

# CRITIQUE : clamp a 0 AVANT comparaison (coherence affichage/decision)
score = max(0, score)

print('=' * 50)
for line in details: print(line)
print('=' * 50)
print(f'Score final : {score}/100  |  Seuil : {THRESHOLD}/100')
if score < THRESHOLD:
    print('>>> DEPLOIEMENT BLOQUE <<<')
    sys.exit(1)
else:
    print('>>> DEPLOIEMENT AUTORISE <<<')
    sys.exit(0)
