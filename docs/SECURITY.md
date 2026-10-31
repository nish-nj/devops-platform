# Security Notes & Trivy Policy

## Controls in this project
- No secrets in Git: `.gitignore`/`.dockerignore` exclude `.env`, `*.pem`, `*.key`; `scripts/validate.py` scans for key/token patterns in CI.
- GitHub Secrets hold `AWS_HOST`, `AWS_USERNAME`, `AWS_SSH_PRIVATE_KEY` (and optional `AWS_KNOWN_HOSTS`). GHCR uses the short-lived built-in `GITHUB_TOKEN`, so **no `GHCR_TOKEN` is needed**.
- Workflow `permissions:` default to `contents: read`; only the build job gets `packages: write`; deploy gets `packages: read`.
- Container: non-root (UID 101), `cap_drop: ALL`, `no-new-privileges`, read-only filesystem, port bound to 127.0.0.1, only Nginx (host) is public.
- Server: SSH key auth only, security group limits SSH, `ufw` allows SSH+HTTP only.
- Nginx security headers + CSP in `docker/nginx.conf`.

## Pinning SSH host keys (recommended)
On your laptop: `ssh-keyscan -t ed25519 <EC2_IP>` -> compare the fingerprint with the EC2 console (Get system log), then store the output line as secret `AWS_KNOWN_HOSTS`. Without it the workflow trusts the host on first contact (warning shown).

## Trivy policy
| Severity | Action |
|---|---|
| CRITICAL (fix available) | **Pipeline fails**, no image is pushed or deployed |
| CRITICAL (no fix yet) | Reported, not blocking (`--ignore-unfixed`); review weekly |
| HIGH | Reported; fix within 14 days |
| MEDIUM / LOW | Reported; fix during routine updates |
Reports: Actions run -> Artifacts -> `trivy-report` (table + JSON) and the run Summary.
Exceptions: add a `.trivyignore` file with the CVE ID **and a comment explaining why + expiry date**.

## Fixing vulnerabilities
1. **OS package CVE** -> use a newer base image tag (e.g. bump `nginx-unprivileged` and `alpine`), rebuild with `--pull`.
2. **App dependency CVE** -> upgrade the package (this project has none; add `npm audit`/`pip` checks if you add a backend).
3. **No fix upstream** -> switch to a smaller/distroless image, or document the exception.
4. Rebuild, re-run `scripts/trivy-scan.sh`, confirm the finding disappears.
