#!/usr/bin/env bash
set -euo pipefail

# ===== Debian-only setup =====

# Pretty output (CRLF-safe)
GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

# Sanity: must be Debian/Ubuntu-family and have sudo
[[ -f /etc/debian_version ]] || { echo -e "${RED}This script is for Debian-based systems only.${NC}"; exit 1; }
command -v sudo >/dev/null || { echo -e "${RED}sudo is required.${NC}"; exit 1; }

echo -e "${CYAN}${BOLD}Debian setup script${NC}"

confirm () {
  local msg="$1"
  read -rp "$msg [y/N]: " ans || true
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

# Ensure this file has LF endings (no-op if already fine)
sed -i 's/\r$//' "$0" 2>/dev/null || true

# ===== 1) Optional: install Docker from official Docker repo =====
if confirm "${BOLD}Install Docker Engine from Docker's official repository?${NC}"; then
  echo -e "${CYAN}Preparing APT and Docker repo...${NC}"
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release

  # Keyring + repo
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  echo -e "${CYAN}Installing Docker packages...${NC}"
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io

  sudo systemctl enable --now docker
  echo -e "${GREEN}✅ Docker installed and running.${NC}"
else
  echo -e "${CYAN}Skipping Docker installation.${NC}"
fi

# ===== 2) Optional: Portainer CE =====
if command -v docker &>/dev/null; then
  if confirm "${BOLD}Install Portainer CE (Docker web UI)?${NC}"; then
    echo -e "${CYAN}Deploying Portainer...${NC}"
    docker volume create portainer_data >/dev/null
    docker run -d \
      -p 9000:9000 -p 8000:8000 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce
    echo -e "${GREEN}✅ Portainer CE is running on http://localhost:9000${NC}"
  else
    echo -e "${CYAN}Skipping Portainer.${NC}"
  fi
else
  echo -e "${CYAN}Docker not installed—skipping Portainer step.${NC}"
fi

# ===== 3) Install the "update" helper and run it =====
TARGET="/usr/local/bin/update"
echo -e "${CYAN}${BOLD}Installing update helper to ${TARGET}...${NC}"
sudo tee "$TARGET" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; NC=$'\033[0m'
echo -e "${CYAN}${BOLD}🧼 Starting full system update...${NC}"

# Debian/Ubuntu apt flow
if command -v apt &>/dev/null; then
  sudo apt update
  sudo apt upgrade -y
  sudo apt autoremove -y
else
  echo -e "${RED}This helper expects apt (Debian/Ubuntu).${NC}"
  exit 1
fi

# Flatpak (optional)
if command -v flatpak &>/dev/null; then
  echo -e "${GREEN}📦 Updating Flatpaks...${NC}"
  flatpak update -y
fi

# Docker containers (optional)
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

# Permissions + run
sudo chown root:root "$TARGET"
sudo chmod 0755 "$TARGET"
echo -e "${GREEN}Installed. Run anytime with: ${BOLD}update${NC}"

echo -e "${CYAN}${BOLD}Running update now...${NC}"
sudo bash "$TARGET"
