#!/usr/bin/env bash
set -euo pipefail

# Debian-only guard
[ -f /etc/debian_version ] || { echo "This script is for Debian-based systems only."; exit 1; }

echo "Installing Docker Engine from Docker's official repository..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
echo "✅ Docker installed and running."

# ---- Portainer (optional — prompt ALWAYS shown) ----
read -rp "Install Portainer CE (Docker web UI) on 9443? [y/N]: " install_portainer
case "${install_portainer:-}" in
  [Yy])
    echo "Installing Portainer CE..."
    docker volume create portainer_data >/dev/null
    docker run -d -p 9443:9443 --name portainer --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
      portainer/portainer-ce:latest
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "✅ Portainer is running at: https://${HOST_IP}:9443"
    ;;
  *)
    echo "Skipping Portainer installation."
    ;;
esac

# ---- Install 'update' helper and run once ----
TARGET="/usr/local/bin/update"
echo "Installing update helper to ${TARGET}..."
sudo tee "$TARGET" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Starting full system update..."
sudo apt update
sudo apt -y upgrade
sudo apt -y autoremove

if command -v flatpak >/dev/null 2>&1; then
  echo "Updating Flatpaks..."
  flatpak update -y
fi

if command -v docker >/dev/null 2>&1; then
  cnt=$(docker ps -a -q | wc -l || echo 0)
  if [ "$cnt" -gt 0 ]; then
    echo "Updating containers via Watchtower (one-time)..."
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once --cleanup
  else
    echo "No containers found. Skipping Watchtower."
  fi
else
  echo "Docker not installed. Skipping container updates."
fi

echo "✅ System update completed!"
EOF

sudo chmod +x "$TARGET"
echo "✅ Update helper installed. Run anytime with: update"
echo "Running update now..."
sudo "$TARGET"
