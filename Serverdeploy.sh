# ---- Portainer (optional — requires explicit consent, TTY-safe) ----
confirm() {
  # Require an interactive TTY; otherwise default to "No"
  if [ ! -t 0 ]; then
    echo "Non-interactive shell detected. Skipping Portainer installation."
    return 1
  fi

  local ans
  while true; do
    read -r -p "Install Portainer CE (Docker web UI) on 9443? [y/N]: " ans </dev/tty
    case "${ans}" in
      [Yy]) return 0 ;;
      [Nn]|"") return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

install_portainer() {
  # Don’t reinstall if it already exists
  if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "Portainer container already exists. Skipping new install."
    # Ensure it's running
    docker start portainer >/dev/null 2>&1 || true
  else
    echo "Installing Portainer CE..."
    docker volume create portainer_data >/dev/null
    docker run -d -p 9443:9443 --name portainer --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
      portainer/portainer-ce:latest
  fi

  HOST_IP=$(hostname -I | awk '{print $1}')
  echo "✅ Portainer is (should be) available at: https://${HOST_IP}:9443"
}

if confirm; then
  install_portainer
else
  echo "Skipping Portainer installation."
fi
