#!/bin/bash

# Function to print a large banner
print_banner() {
  echo -e "\n\033[1;34m"
  echo "######################################################################"
  echo "#                                                                    #"
  echo "#                X27 Docker Setup Script                             #"
  echo "#                                                                    #"
  echo "######################################################################"
  echo -e "\033[0m\n"
}

# Function for printing colored text
print_success() {
  echo -e "\033[1;32m$1\033[0m"  # Green text
}

print_error() {
  echo -e "\033[1;31m$1\033[0m"  # Red text
}

# Function to install Docker
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

  # Clean up
  rm get-docker.sh
}

# Function to install Portainer CE
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

# Start of the script
print_banner

# Step 1: Install Docker
install_docker

# Step 2: Prompt user for Portainer installation
echo -n "Do you want to install Portainer CE (y/n)? "
read -r install_portainer

if [ "$install_portainer" == "y" ] || [ "$install_portainer" == "Y" ]; then
  install_portainer
else
  echo "Skipping Portainer installation."
fi

# Final message
echo
print_success "X27 Docker Setup completed!"
