#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

echo -e "${CYAN}${BOLD}Welcome to your system setup script!${NC}"

# 1. Ask to install Docker from official Docker repo
read -rp "$(echo -e "${BOLD}❓ Install Docker Engine from official Docker repository? [y/N]:${NC} ")" install_docker
if [[ "$install_docker" =~ ^[Yy]$ ]]; then
  echo -e "${CYAN}➡️ Detecting OS type...${NC}"
  if [ -f /etc/fedora-release ]; then
    OS="fedora"
  elif [ -f /etc/debian_version ]; then
    OS="debian"
  else
    echo -e "${RED}❌ Unsupported OS. Exiting.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Installing Docker on ${OS^}...${NC}"
  if [ "$OS" = "debian" ]; then
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
  else
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
  fi
  sudo systemctl enable --now docker
  echo -e "${GREEN}✅ Docker installed and running.${NC}"
else
  echo -e "${CYAN}Skipping Docker installation.${NC}"
fi

# 2. Ask about Portainer CE
if command -v docker &>/dev/null; then
  read -rp "$(echo -e "${BOLD}❓ Install Portainer CE (Docker web UI)? [y/N]:${NC} ")" install_portainer
  if [[ "$install_portainer" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}📦 Installing Portainer CE...${NC}"
    docker volume create portainer_data
    docker run -d \
      -p 9000:9000 -p 8000:8000 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce
    echo -e "${GREEN}✅ Portainer CE is running on port 9000.${NC}"
  else
    echo -e "${CYAN}Skipping Portainer installation.${NC}"
  fi
else
  echo -e "${CYAN}Docker not installed—skipping Portainer step.${NC}"
fi

# 3. Deploy your update script
TARGET="/usr/local/bin/update"
echo -e "${CYAN}${BOLD}📦 Deploying update script to $TARGET...${NC}"
sudo tee "$TARGET" > /dev/null <<'EOF'
#!/bin/bash

# Fancy output
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RED="\033[0;31m"
BOLD="\033[1m"
NC="\033[0m"

echo -e "${CYAN}${BOLD}🧼 Starting full system update...${NC}"

# Detect package manager
if command -v dnf &>/dev/null; then
    PM="dnf"
elif command -v apt &>/dev/null; then
    PM="apt"
else
    echo -e "${RED}❌ No supported package manager found (dnf or apt).${NC}"
    exit 1
fi

echo -e "${GREEN}📦 Updating system packages with \$PM...${NC}"
if [ "\$PM" = "dnf" ]; then
    sudo dnf upgrade --refresh -y
elif [ "\$PM" = "apt" ]; then
    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
fi

if command -v flatpak &>/dev/null; then
    echo -e "${GREEN}📦 Updating Flatpaks...${NC}"
    flatpak update -y
fi

if command -v docker &>/dev/null; then
    CONTAINER_COUNT=\$(docker ps -a -q | wc -l)
    if [ "\$CONTAINER_COUNT" -eq 0 ]; then
        echo -e "${CYAN}📭 No Docker containers found. Skipping Watchtower.${NC}"
    else
        echo -e "${GREEN}🚀 Running Watchtower once to update containers...${NC}"
        docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            containrrr/watchtower \
            --run-once --cleanup
    fi
else
    echo -e "${CYAN}⚠️ Docker not installed. Skipping container updates.${NC}"
fi

echo -e "${BOLD}${GREEN}✅ System update completed successfully!${NC}"
EOF

# Ask to chmod
read -rp "$(echo -e "${BOLD}❓ Make the script executable now? [y/N]:${NC} ")" do_chmod
if [[ "$do_chmod" =~ ^[Yy]$ ]]; then
  sudo chmod +x "$TARGET"
  echo -e "${GREEN}✅ Script is executable. Run with: ${BOLD}update${NC}"
else
  echo -e "${RED}⚠️ You must manually run chmod +x $TARGET if you want to execute it.${NC}"
fi

# 4. Run the update script
echo -e "${CYAN}${BOLD}🚀 Now running ${TARGET}...${NC}"
sudo "$TARGET"
