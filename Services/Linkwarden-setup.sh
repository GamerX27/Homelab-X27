#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Docker installation
if command_exists docker; then
    echo "Docker is already installed."
else
    read -p "Docker is not installed. Would you like to install it? (y/n): " install_docker
    if [[ "$install_docker" =~ ^[Yy]$ ]]; then
        # Install Docker
        echo "Installing Docker..."
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        echo "Docker installed successfully."
    else
        echo "Docker is required to run Linkwarden. Exiting."
        exit 1
    fi
fi

# Check for Docker Compose installation
if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose is already installed."
else
    read -p "Docker Compose is not installed. Would you like to install it? (y/n): " install_compose
    if [[ "$install_compose" =~ ^[Yy]$ ]]; then
        # Install Docker Compose plugin
        echo "Installing Docker Compose..."
        sudo apt update
        sudo apt install -y docker-compose-plugin
        echo "Docker Compose installed successfully."
    else
        echo "Docker Compose is required to run Linkwarden. Exiting."
        exit 1
    fi
fi

# Create a directory for Linkwarden and navigate into it
mkdir -p ~/linkwarden && cd ~/linkwarden

# Download the docker-compose.yml and .env.sample files
curl -O https://raw.githubusercontent.com/linkwarden/linkwarden/main/docker-compose.yml
curl -L https://raw.githubusercontent.com/linkwarden/linkwarden/main/.env.sample -o .env

# Generate a random 32-character alphanumeric string for NEXTAUTH_SECRET
NEXTAUTH_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

# Generate a random 16-character alphanumeric string for POSTGRES_PASSWORD
POSTGRES_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)

# Update the .env file with the generated secrets
sed -i "s|NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET=$NEXTAUTH_SECRET|" .env
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env

# Start Linkwarden using Docker Compose
docker compose up -d

# Output the generated credentials
echo "Linkwarden has been successfully installed and is running."
echo "You can access it at http://localhost:3000"
echo "Generated credentials:"
echo "NEXTAUTH_SECRET: $NEXTAUTH_SECRET"
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
