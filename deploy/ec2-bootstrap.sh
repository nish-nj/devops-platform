#!/usr/bin/env bash
# ec2-bootstrap.sh - one-time setup of a fresh Ubuntu 22.04/24.04 EC2 instance.
# Run on the server:  bash ec2-bootstrap.sh   (as the normal 'ubuntu' user, uses sudo)
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as a normal user (not root); the script uses sudo." >&2; exit 1; }
REPO_DIR="${REPO_DIR:-$HOME/devops-platform}"

echo ">> Updating packages"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg nginx cron ufw

echo ">> Installing Docker Engine (official repo)"
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo usermod -aG docker "$USER"

echo ">> Project directories"
mkdir -p "$REPO_DIR"
sudo mkdir -p /var/lib/devops-monitor
sudo chown "$USER":"$USER" /var/lib/devops-monitor
sudo chmod 755 /var/lib/devops-monitor

echo ">> Configuring host Nginx"
if [[ -f "$REPO_DIR/deploy/nginx/devops-platform.conf" ]]; then
  sudo cp "$REPO_DIR/deploy/nginx/devops-platform.conf" /etc/nginx/sites-available/devops-platform
  sudo ln -sf /etc/nginx/sites-available/devops-platform /etc/nginx/sites-enabled/devops-platform
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t
  sudo systemctl enable --now nginx
  sudo systemctl reload nginx
else
  echo "NOTE: $REPO_DIR/deploy/nginx/devops-platform.conf not found yet (see docs/DEPLOYMENT.md step 6)."
fi

echo ">> Host firewall (ufw): allow SSH + HTTP only"
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw --force enable

echo ">> Done. Log out and back in so the 'docker' group applies, then run: docker run --rm hello-world"
