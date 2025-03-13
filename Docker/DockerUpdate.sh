#!/bin/bash

# Function to print a styled header
print_header() {
  echo "========================================="
  echo "      Portainer & Watchtower Script      "
  echo "========================================="
}

# Function to prompt for updating Portainer
prompt_update_portainer() {
  echo -n "Do you want to update Portainer? (yes/no): "
  read -r response
  if [[ "$response" == "yes" ]]; then
    update_portainer
  else
    echo "Skipping Portainer update."
  fi
}

# Function to update Portainer
update_portainer() {
  echo "Stopping the existing Portainer container..."
  docker stop portainer

  echo "Removing the existing Portainer container..."
  docker rm portainer

  echo "Pulling the latest Portainer CE image..."
  docker pull portainer/portainer-ce:latest

  echo "Deploying the updated Portainer container..."
  docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
}

# Function to run Watchtower
run_watchtower() {
  echo "Running Watchtower to check for updates once..."
  docker run --rm \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --run-once
}

# Main script
print_header
prompt_update_portainer
run_watchtower
echo "========================================="
echo "          Script Execution Done          "
echo "========================================="
