#!/bin/bash

# =============================
# Colors & Formatting
# =============================
GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

# =============================
# Banner
# =============================
print_banner() {
  echo -e "\n\033[1;34m"
  echo "######################################################################"
  echo "#                                                                    #"
  echo "#                X27 Docker & Update Setup Script                    #"
  echo "#                                                                    #"
  echo "######################################################################"
  echo -e "\033[0m\n"
}

print_success() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# =============================
# Docker Installation
# =============================
install_docker() {
  echo "Downloading Docker installation script..."
  curl -fsSL https://get.docker.com -o get-docker.sh

  echo "Running Docker installation script..."
  sudo sh get-docker.sh

  if [ $? -eq 0 ]; then
    print_success "Docker installed successfully!"
  else
    print_error "Docker installation failed!"
    exit 1
  fi

  rm get-docker.sh
}

# =============================
# Portainer Installation
# =============================
install_portainer() {
  echo "Creating Docker volume for Portainer..."
  sudo docker volume create portainer_data

  echo "Running Portainer CE container..."
  sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
    portainer/portainer-ce:latest

  if [ $? -eq 0 ]; then
    print_success "Portainer CE installed successfully!"
  else
    print_error "Portainer CE installation failed!"
  fi
}

# =============================
# Update Script Deployment
# =============================
install_update_script() {
  TARGET="/usr/local/bin/update"
  echo -e "${CYAN}${BOLD}📦 Deploying update script to $TARGET...${NC}"

  sudo tee "$TARGET" > /dev/null <<'EOF'
#!/bin/bash
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RED="\033[0;31m"
BOLD="\033[1m"
NC="\033[0m"

echo -e "${CYAN}${BOLD}🧼 Starting full system update...${NC}"

if command -v dnf &>/dev/null; then
  PM="dnf"
elif command -v apt &>/dev/null; then
  PM="apt"
else
  echo -e "${RED}❌ No supported package manager found (dnf or apt).${NC}"
  exit 1
fi

echo -e "${GREEN}📦 Updating system packages with $PM...${NC}"
if [ "$PM" = "dnf" ]; then
  sudo dnf upgrade --refresh -y
elif [ "$PM" = "apt" ]; then
  sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
fi

if command -v flatpak &>/dev/null; then
  echo -e "${GREEN}📦 Updating Flatpaks...${NC}"
  flatpak update -y
fi

if command -v docker &>/dev/null; then
  CONTAINER_COUNT=$(sudo docker ps -a -q | wc -l)
  if [ "$CONTAINER_COUNT" -eq 0 ]; then
    echo -e "${CYAN}📭 No Docker containers found. Skipping Watchtower.${NC}"
  else
    echo -e "${GREEN}🚀 Running Watchtower once to update containers...${NC}"
    sudo docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower \
      --run-once --cleanup
  fi
else
  echo -e "${CYAN}⚠️ Docker not installed. Skipping container updates.${NC}"
fi

echo -e "${BOLD}${GREEN}✅ System update completed successfully!${NC}"
EOF

  echo -en "${BOLD}❓ Make the script executable with chmod +x? [y/N]: ${NC}"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo chmod +x "$TARGET"
    echo -e "${GREEN}✅ Script is now executable. You can run it with: ${BOLD}update${NC}"
  else
    echo -e "${RED}⚠️ Skipped chmod. You must run this manually if you want to execute the script:${NC}"
    echo -e "${BOLD} sudo chmod +x $TARGET${NC}"
  fi
}

# =============================
# Script Execution Flow
# =============================
print_banner

install_docker

echo -n "Do you want to install Portainer CE (y/n)? "
read -r install_portainer_choice
if [[ "$install_portainer_choice" =~ ^[Yy]$ ]]; then
  install_portainer
else
  echo "Skipping Portainer installation."
fi

echo -n "Do you want to deploy the system update script (y/n)? "
read -r deploy_update_choice
if [[ "$deploy_update_choice" =~ ^[Yy]$ ]]; then
  install_update_script
else
  echo "Skipping update script deployment."
fi

echo
print_success "X27 Docker & Update Setup completed!"
