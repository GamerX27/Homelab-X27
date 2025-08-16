#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

# --- Debian check ---
if [[ ! -f /etc/debian_version ]]; then
  echo -e "${RED}This script is for Debian-based systems only.${NC}"
  exit 1
fi

echo -e "${CYAN}${BOLD}Debian setup script${NC}"

# --- 1) Always install Docker ---
echo -e "${CYAN}Installing Docker Engine from official Docker repository...${NC}"
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
echo -e "${GREEN}✅ Docker installed and running.${NC}"

# --- 2) Always prompt for Portainer (since Docker is guaranteed) ---
read -rp "$(echo -e "${BOLD}Install Portainer CE (Docker web UI)? [y/N]:${NC} ")" install_portainer
if [[ "$install_portainer" =~ ^[Yy]$ ]]; then
  echo -e "${CYAN}Installing Portainer CE...${NC}"
  docker volume create portainer_data >/dev/null
  docker run -d \
    -p 9000:9000 -p 8000:8000 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce
  echo -e "${GREEN}✅ Portainer is running on http://localhost:9000${NC}"
else
  echo -e "${CYAN}Skipping Portainer installation.${NC}"
fi

# --- 3) Install update helper ---
TARGET="/usr/local/bin/update"
echo -e "${CYAN}${BOLD}Installing update helper to ${TARGET}...${NC}"
sudo tee "$TARGET" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; NC=$'\033[0m'

echo -e "${CYAN}${BOLD}🧼 Starting full system update...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

if command -v flatpak &>/dev/null; then
  echo -e "${GREEN}📦 Updating Flatpaks...${NC}"
  flatpak update -y
fi

if command -v docker &>/dev/null; then
  CONTAINER_COUNT=$(docker ps -a -q | wc -l || echo 0)
  if [[ "$CONTAINER_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}🚀 Updating containers via Watchtower (one-time)...${NC}"
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower \
      --run-once --cleanup
  else
    echo -e "${CYAN}📭 No containers found. Skipping Watchtower.${NC}"
  fi
else
  echo -e "${CYAN}⚠️ Docker not installed. Skipping container updates.${NC}"
fi

echo -e "${BOLD}${GREEN}✅ System update completed!${NC}"
EOF

# Make helper executable
sudo chmod +x "$TARGET"
echo -e "${GREEN}✅ Update helper installed. Run anytime with: ${BOLD}update${NC}"

# Run helper now
echo -e "${CYAN}${BOLD}Running update now...${NC}"
sudo "$TARGET"
