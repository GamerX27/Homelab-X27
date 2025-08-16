# ---- Portainer (optional — truly interactive prompt) ----
if [ -t 0 ]; then
  echo
  read -r -p "Do you want to install Portainer CE (Docker web UI) on port 9443? [y/N]: " response </dev/tty
  if [[ "$response" =~ ^[Yy]$ ]]; then
    if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
      echo "Portainer container already exists. Skipping new install."
      docker start portainer >/dev/null 2>&1 || true
    else
      echo "Installing Portainer CE..."
      docker volume create portainer_data >/dev/null
      docker run -d -p 9443:9443 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
        portainer/portainer-ce:latest
    fi
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "✅ Portainer is available at: https://${HOST_IP}:9443"
  else
    echo "Skipping Portainer installation."
  fi
else
  echo "No interactive TTY detected. Skipping Portainer installation."
fi
