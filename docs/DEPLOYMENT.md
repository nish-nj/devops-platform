# AWS EC2 Deployment Guide

> **Cost warning:** EC2, public IPv4 addresses and data transfer can incur charges. Use one small instance
> (t3.micro / t2.micro, free-tier eligible only on some accounts), set an AWS Budget alert, and **terminate the
> instance when you finish demos**.

## 1. Create the instance (AWS Console)
1. Sign in -> region of your choice -> **EC2 -> Launch instance**.
2. Name: `devops-platform`. AMI: **Ubuntu Server 24.04 LTS** (or 22.04).
3. Instance type: **t3.micro** (or t2.micro). 
4. **Key pair -> Create new** -> RSA, `.pem` -> download `devops-platform.pem` (you cannot download it again).
5. Network settings -> **Create security group** with:
   - SSH (22): source **My IP** (not 0.0.0.0/0).
   - HTTP (80): source Anywhere (0.0.0.0/0).
   - Do NOT open 8080; the container listens on 127.0.0.1 only.
6. Storage: 8-10 GiB gp3. Launch. Copy the **Public IPv4 address**.
> If your home IP changes, update the SSH rule (EC2 -> Security Groups). GitHub-hosted runners use changing IPs, so the
> deploy job needs port 22 reachable from them. For a demo, you may temporarily allow 22 from anywhere **with key-only login**
> (password login is disabled by default on Ubuntu AMIs), then restore it. Production alternative: a self-hosted runner or AWS SSM.

## 2. Connect from Windows PowerShell
```powershell
# Restrict the key file permissions (SSH refuses keys that are too open)
icacls .\devops-platform.pem /inheritance:r
icacls .\devops-platform.pem /grant:r "$($env:USERNAME):(R)"
ssh -i .\devops-platform.pem ubuntu@<EC2_PUBLIC_IP>
```

## 3. Copy the project and bootstrap (first time only)
From PowerShell in the project folder:
```powershell
scp -i .\devops-platform.pem -r deploy monitoring docker-compose.yml ubuntu@<EC2_PUBLIC_IP>:~/devops-platform/
```
On the server (Ubuntu):
```bash
bash ~/devops-platform/deploy/ec2-bootstrap.sh   # installs Docker, Nginx, cron, ufw; configures Nginx
exit                                              # log out, then ssh back in so the docker group applies
docker run --rm hello-world                       # confirms Docker works
```
(`scp` needs `~/devops-platform` to exist; if it fails run `ssh ... "mkdir -p ~/devops-platform"` first.)

## 4. First deployment
Push to `main` and let the pipeline deploy (see README section 10), **or** manually on the server:
```bash
cd ~/devops-platform
docker login ghcr.io -u <GITHUB_USER>        # password = a PAT with read:packages (only for manual pulls)
IMAGE=ghcr.io/<github_user_lowercase>/<repo_lowercase>/devops-platform:latest docker compose up -d
```

## 5. Enable monitoring on the server
```bash
cd ~/devops-platform/monitoring
chmod +x monitor.sh setup-cron.sh
STATUS_FILE=/var/lib/devops-monitor/status.json LOG_FILE=$HOME/monitor.log ./monitor.sh   # test run
STATUS_FILE=/var/lib/devops-monitor/status.json LOG_FILE=$HOME/monitor.log ./setup-cron.sh 5
```
Open `http://<EC2_PUBLIC_IP>/` - the Monitoring cards fill from `/monitor/status.json`.

## 6. Test
```bash
curl -i http://127.0.0.1:8080/healthz      # container directly
curl -i http://127.0.0.1/healthz           # through host Nginx
docker ps                                   # STATUS should say "healthy"
```
From your laptop: `curl.exe http://<EC2_PUBLIC_IP>/healthz` and open the IP in a browser.

## 7. HTTPS / domain (optional)
Point a DNS A record at the instance, then `sudo apt install certbot python3-certbot-nginx` and
`sudo certbot --nginx -d your.domain` (also open port 443 in the security group).

## 8. Clean up (stop charges)
EC2 -> Instances -> select -> **Instance state -> Terminate**. Release any Elastic IP; delete the unused security group/key pair.
