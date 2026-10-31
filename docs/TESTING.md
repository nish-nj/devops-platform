# Testing Checklist & Verification Status

Status legend: **Implemented** (file exists) / **Syntax checked** / **Locally tested** / **Cloud deployed** / **Not verified**.
This table was filled in honestly while the project was generated in a sandbox WITHOUT Docker, Trivy, Nginx, cron or internet access.

| Component | Status | Evidence |
|---|---|---|
| Web app (HTML/CSS/JS) | Implemented, JS syntax checked, served over HTTP locally | `node --check` ok; `python -m http.server` returned 200 for `/` and `/js/app.js`. Browser rendering **not verified** |
| Dockerfile / Compose | Implemented, Compose YAML parsed | Image build and container start **Not verified** (no Docker in sandbox) |
| Host Nginx + container nginx config | Implemented | `nginx -t` **Not verified** |
| monitor.sh | **Locally tested** (Linux) | Ran OK; exit 10 on warnings; exit 1 on invalid input; log + valid JSON written |
| setup-cron.sh | Syntax checked only | `crontab` unavailable in sandbox: cron install **Not verified** |
| validate.py | Locally tested | Passes on the final tree |
| GitHub Actions workflow | Implemented, YAML parsed | Execution **Not verified**; action tag `trivy-action@0.28.0` should be confirmed |
| Trivy scan | Implemented | **No report exists yet** - nothing was scanned. Run it yourself (below) |
| EC2 deployment | **Not verified** | Requires your AWS account |

## Run these yourself (tick when done)
- [ ] `python scripts/validate.py` passes
- [ ] `docker compose up -d --build` -> http://localhost:8080 loads; `docker ps` shows `healthy`
- [ ] `docker exec devops-platform id` shows uid=101 (non-root)
- [ ] `bash scripts/trivy-scan.sh` (Git Bash/WSL) produces `reports/trivy-report.txt`
- [ ] Push to GitHub -> Actions run is green; `trivy-report` artifact downloaded
- [ ] Image visible under repo Packages (GHCR)
- [ ] `curl http://<EC2_IP>/healthz` returns `ok`
- [ ] Dashboard Monitoring cards show live values after cron runs
- [ ] `crontab -l` shows the job; `tail $HOME/monitor.log` grows every 5 minutes
- [ ] Take screenshots (README section 18)
