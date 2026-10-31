# Resume Description & Interview Q&A

## Resume-ready description (edit after YOU have deployed it)
**Cloud-Native DevOps Deployment & Monitoring Platform** | Docker, GitHub Actions, AWS EC2, Nginx, Trivy, Bash
- Containerized a responsive monitoring dashboard with a multi-stage, non-root Docker image (read-only filesystem, dropped capabilities, health checks).
- Built a GitHub Actions CI/CD pipeline: validation, ShellCheck, image build, Trivy scan with a fail-on-critical policy, GHCR publishing, and SSH deployment to AWS EC2 using least-privilege tokens and GitHub Secrets.
- Deployed on Ubuntu EC2 behind an Nginx reverse proxy with restricted security groups, key-only SSH and ufw.
- Wrote a Bash monitor (CPU/RAM/disk/uptime, thresholds, logging, JSON output) scheduled with cron and surfaced live in the dashboard.
*Only keep the lines you have actually demonstrated.*

## Interview questions
1. **Walk me through your pipeline.** Push -> validate -> build image -> Trivy -> push to GHCR -> SSH deploy -> smoke test on `/healthz`. PRs run everything except push/deploy.
2. **Why Trivy, and what does your policy do?** It finds known CVEs in OS packages/libraries. I report all severities but fail only on fixable CRITICAL ones, so builds aren't blocked by issues nobody can fix yet.
3. **How do you handle secrets?** GitHub Secrets for the SSH key/host; the GHCR login uses the ephemeral `GITHUB_TOKEN` via stdin; nothing is committed, and CI scans for key patterns.
4. **Why non-root containers?** A compromise then has fewer privileges; combined with `cap_drop`, `no-new-privileges` and read-only FS it limits blast radius.
5. **Why Nginx on the host AND in the container?** The container serves static files on an unprivileged port; host Nginx is the public entry point (ports 80/443, TLS, routing, extra services) while the container stays bound to localhost.
6. **How does cron work / how do you debug it?** `crontab -l` lists jobs; five time fields; minimal environment, so use absolute paths and pass variables explicitly; check `/var/log/syslog` and the script's own log.
7. **How would you roll back?** Redeploy a previous image tag (`IMAGE=...:<old-sha> docker compose up -d`) - every build is tagged with its commit SHA.
8. **What would you improve?** HTTPS via certbot, SSM instead of open SSH, Terraform for the EC2/security group, Prometheus/Grafana, image signing (cosign), blue/green deployments.
9. **Docker image vs container?** Image = immutable template; container = running instance.
10. **Security group vs ufw?** Security group is the cloud firewall outside the instance; ufw is the OS firewall inside. Defense in depth.
11. **Why not use `latest` for deploys?** Not reproducible; the pipeline deploys the commit-SHA tag.
12. **Be honest about gaps.** State which parts you ran yourself (use the testing checklist).
