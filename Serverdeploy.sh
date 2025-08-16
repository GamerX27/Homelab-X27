#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

# Debian check
if [[ ! -f /etc/debian_version ]]; then
  echo -e "${RED}This script is for Debian-based systems only.${NC}"
  exit 1
fi

echo -e "${CYAN}${BOLD}Debian setup script${NC}"

confirm () {
  local msg="$1"
  read -rp "$msg [y/N]: " ans || true
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

# 1) Docker install
if confirm "${BOLD}Install Docker Engine from official Docker repo?${NC}"; then
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
  echo -e "${GREEN}Docker installed and running.${NC}"
else
  echo -e "${CYAN}Skipping Docker installation.${NC}"
fi

# 2) Portainer
if command -v docker &>/dev/null; then
  if confirm "${BOLD}Install Portainer CE (Docker web UI)?${NC}"; then
    docker volume create portainer_data >/dev/null
    docker run -d \
      -p 9000:9000 -p 8000:8000 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce
    echo -e "${GREEN}Portainer running on http://localhost:9000${NC}"
  fi
fi

# 3) Install update helper
TARGET="/usr/local/bin/update"
sudo tee "$TARGET" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; NC=$'\033[0m'
echo -e "${CYAN}${BOLD}🧼 Starting full system update...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
if command -v flatpak &>/dev/null; then
  flatpak update -y
fi
if command -v docker &>/dev/null; then
  CONTAINER_COUNT=$(docker ps -a -q | wc -l || echo 0)
  if [[ "$CONTAINER_COUNT" -gt 0 ]]; then
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower \
      --run-once --cleanup
  fi
fi
echo -e "${BOLD}${GREEN}✅ System update completed!${NC}"
EOF

# Always chmod before running
sudo chmod +x "$TARGET"
echo -e "${GREEN}Helper installed and made executable.${NC}"

# Run it
sudo "$TARGET"
