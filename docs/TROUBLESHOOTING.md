# Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `docker : not recognized` (PowerShell) | Docker Desktop not installed/started | Install Docker Desktop, start it, wait for "Engine running", reopen PowerShell |
| Docker Desktop won't start | WSL2/virtualization off | Run `wsl --install` (admin), reboot, enable virtualization in BIOS |
| Port 8080 already in use | Another program uses it | `$env:HOST_PORT=8081; docker compose up -d` |
| Container "unhealthy" | App not answering `/healthz` | `docker logs devops-platform`; `docker inspect --format '{{json .State.Health}}' devops-platform` |
| Container exits immediately with read-only errors | `read_only: true` blocks a path | Check `docker logs`; add the path under `tmpfs:` in docker-compose.yml (or remove `read_only` temporarily) |
| `Permission denied (publickey)` | Wrong user/key | Ubuntu AMI user is `ubuntu`; use the `.pem` from launch; check `AWS_USERNAME` |
| `UNPROTECTED PRIVATE KEY FILE` (Windows) | Key permissions too open | Run the `icacls` commands in docs/DEPLOYMENT.md |
| SSH times out | Security group / IP changed | EC2 -> Security Groups -> fix port 22 source; check instance is running |
| Browser cannot open the IP | Port 80 closed or Nginx down | Open port 80 in the security group; `sudo systemctl status nginx`; `sudo nginx -t`; `sudo ufw status` |
| Nginx `502 Bad Gateway` | Container not running | `docker ps`; `curl 127.0.0.1:8080/healthz`; `docker compose up -d` |
| `docker: permission denied ... docker.sock` | Not in docker group | `sudo usermod -aG docker $USER` then log out/in |
| Actions: "Missing GitHub secret" | Secret not set | Repo -> Settings -> Secrets and variables -> Actions -> add `AWS_HOST`, `AWS_USERNAME`, `AWS_SSH_PRIVATE_KEY` |
| Actions: `denied` pulling from GHCR on server | Token/permissions | Deploy job needs `packages: read`; first push must have succeeded; image name must be lowercase |
| Actions: ShellCheck fails | Script style issue | Read the SC code in the log (https://www.shellcheck.net/wiki/SCxxxx) and fix |
| Trivy gate fails | Fixable CRITICAL vuln | See docs/SECURITY.md "Fixing vulnerabilities" |
| Trivy action/tag not found | Pinned version unavailable | Update the version after `aquasecurity/trivy-action@` to a current release from its GitHub releases page |
| Cron doesn't run | cron service/paths | `systemctl status cron`; `crontab -l`; `grep CRON /var/log/syslog`; use absolute paths |
| Dashboard shows "No monitoring data" | `STATUS_FILE` not set / dir missing | Re-run `setup-cron.sh` with `STATUS_FILE=/var/lib/devops-monitor/status.json`; check `ls -l /var/lib/devops-monitor` |
