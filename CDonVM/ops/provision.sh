#!/usr/bin/env bash
set -euo pipefail

APP="${APP:-simpliapp}"
ROOT="/opt/$APP"

# --- Docker + Compose ---
if ! command -v docker >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg ufw
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER" || true
fi

# --- Arbo ---
sudo mkdir -p "$ROOT/nginx" "$ROOT/app"
sudo chown -R "$USER":"$USER" "$ROOT"

# --- UFW (idempotent) ---
sudo ufw allow OpenSSH || true
sudo ufw allow 80/tcp || true
sudo ufw allow 443/tcp || true
yes | sudo ufw enable || true

# --- Swap 1G (si absent) ---
if ! grep -q '/swapfile' /etc/fstab; then
  sudo fallocate -l 1G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  sudo swapon -a
fi

# --- Systemd pour Compose ---
UNIT="/etc/systemd/system/${APP}-compose.service"
if [ ! -f "$UNIT" ]; then
  sudo bash -lc "cat > '$UNIT' <<EOF
[Unit]
Description=${APP} Docker Compose
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${ROOT}
RemainAfterExit=true
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF"
  sudo systemctl daemon-reload
  sudo systemctl enable "${APP}-compose"
fi

echo "Provision terminé"
