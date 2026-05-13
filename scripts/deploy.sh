#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run this script as root (installs packages and starts Docker), e.g.:" >&2
    echo "  sudo $0" >&2
    exit 1
  fi
}

require_root

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found; installing Docker Engine (Rocky Linux 9 / dnf)..."
  dnf install -y dnf-plugins-core
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Installing docker compose plugin..."
  dnf install -y docker-compose-plugin
fi

mkdir -p config data/headscale data/headplane

docker compose -f "${ROOT}/compose.yml" up -d

echo
echo "Stack is up. Headplane: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo localhost):3000/admin"
echo "See README.md for API key login and config edits."
