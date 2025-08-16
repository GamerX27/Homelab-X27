#!/usr/bin/env bash
set -euo pipefail

# Debian-only
[[ -f /etc/debian_version ]] || { echo "This script is for Debian-based systems only."; exit 1; }

# Simple colors
GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

echo -e "${CYAN}${BOLD}Debian setup${NC}"

# --- 1) Always install Docker from Docker repo ---
echo -e "${CYAN}Installing Docker Engine from Docker's official repository...${NC}"
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
echo -e "${GREEN}✔ Docker installed and running.${NC}"

# --- 2) OPTIONAL: Portainer CE (prompt always shown) ---
read -rp "Install Portainer CE (Docker web UI)? [y/N]: " install_portainer
if [[ "${install_portainer:-}" =~ ^[Yy]$ ]]; then
  echo "Installing Portainer CE..."
  docker volume create portainer_data >/dev/null
  # Expose HTTPS on 9443 (no 9000); single line to avoid parsing issues
  docker run -d -p 9443:9443 --name portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
    portainer/portainer-ce:latest
  HOST_IP=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}✔ Portainer is running at: https://${HOST_IP}:9443${NC}"
else
  echo "Skipping Portainer installation."
fi

# --- 3) Install 'update' helper and run it once ---
TARGET="/usr/local/bin/update"
echo "Installing update helper to ${TARGET}..."
sudo tee "$TARGET" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'
echo -e "${CYAN}${BOLD}Starting full system update...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
if command -v flatpak &>/dev/null; then
  echo "Updating Flatpaks..."
  flatpak update -y
fi
if command -v docker &>/dev/null; then
  cnt=$(docker ps -a -q | wc -l || echo 0)
  if [[ "$cnt" -gt 0 ]]; then
    echo "Updating containers via Watchtower (one-time)..."
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once --cleanup
  else
    echo "No containers found. Skipping Watchtower."
  fi
else
  echo "Docker not installed. Skipping container updates."
fi
echo -e "${GREEN}${BOLD}System update completed!${NC}"
EOF
sudo chmod +x "$TARGET"
echo -e "${GREEN}✔ Update helper installed. Run anytime with: ${BOLD}update${NC}"

echo "Running update once now..."
sudo "$TARGET"
