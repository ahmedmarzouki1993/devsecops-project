---
name: security-scan
description: >
  DevSecOps security scanning workflows. Use when running security scans, interpreting scan results,
  fixing CVEs, reviewing Dockerfiles for security, or working with any of the 6 security gates
  (Gitleaks, Bandit, pip-audit, Checkov, Trivy, Cosign). Auto-invoke when editing .gitlab-ci.yml,
  Dockerfile, requirements.txt, or any file in security/ directory.
allowed-tools: Read, Write, Bash, Grep, Glob
---

## Security scanning for devsecops-project

### The 6 security gates (in pipeline order)

| # | Tool      | What it scans          | Local command                                    | Fails on                  |
|---|-----------|------------------------|--------------------------------------------------|---------------------------|
| 1 | Gitleaks  | Git history for secrets | `gitleaks detect --source .`                    | Any detected secret       |
| 2 | Bandit    | Python code (SAST)     | `bandit -r app/backend/app/ -f json`             | High severity findings    |
| 3 | pip-audit | Python dependencies    | `pip-audit -r app/backend/requirements.txt`      | Known CVEs                |
| 4 | Checkov   | Terraform + K8s files  | `checkov -d terraform/ && checkov -d k8s/`       | High/critical misconfigs  |
| 5 | Trivy     | Container images       | `trivy image devsecops-backend:dev`              | Critical/High CVEs        |
| 6 | Cosign    | Image signing          | `cosign sign --key cosign.key <image>`           | Signing failure           |

### When Ahmed asks about security scan results

1. **Explain what the finding means** in plain language. Don't just say "CVE-2024-XXXX found."
2. **Assess real risk**: Is this exploitable in our context? A CVE in a dev dependency not shipped
   to production is lower priority than one in the runtime image.
3. **Provide the fix**: Pin a patched version, update base image, add .gitleaks.toml allowlist (with justification).
4. **Explain false positives**: Sometimes Bandit flags safe code. Show how to add `# nosec` with a comment explaining why.

### Dockerfile security checklist (enforce when writing/reviewing Dockerfiles)
- [ ] Multi-stage build (build tools not in final image)
- [ ] Specific version tag, never `:latest`
- [ ] Non-root user: `RUN adduser --disabled-password --uid 1001 appuser` then `USER appuser`
- [ ] No curl/wget/git/gcc in final stage
- [ ] `.dockerignore` excludes .git, tests, __pycache__, .env, node_modules
- [ ] COPY requirements first → install → COPY source (layer caching)
- [ ] No secrets in build args or ENV instructions

### Kubernetes security checklist (enforce when writing/reviewing manifests)
- [ ] `securityContext.runAsNonRoot: true`
- [ ] `securityContext.readOnlyRootFilesystem: true`
- [ ] `securityContext.allowPrivilegeEscalation: false`
- [ ] Resource requests AND limits set
- [ ] Image tag is commit SHA, not `:latest`
- [ ] No `hostNetwork`, `hostPID`, `hostIPC`
- [ ] No `privileged: true`

### Teaching points
- **Why scan order matters?** Gitleaks (3s) runs before Trivy (60s). "Fail fast" saves CI minutes.
- **Why sign images?** Without signing, anyone with ACR push access can deploy malicious code.
  Cosign creates cryptographic proof that THIS pipeline built THIS image.
- **SAST vs SCA**: Bandit = Static Application Security Testing (YOUR code). pip-audit = Software
  Composition Analysis (THIRD-PARTY code you depend on). Both matter.
