#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { echo -e "\033[0;32m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

require_os_release() {
  if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect Linux distribution (/etc/os-release missing)."
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

as_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  elif has_cmd sudo; then
    sudo "$@"
  else
    error "Need root privileges. Re-run as root or install sudo."
  fi
}

ensure_base_tools() {
  case "$PKG_FAMILY" in
    apt)
      as_root apt-get update -y
      as_root apt-get install -y ca-certificates curl gnupg lsb-release git bash
      ;;
    dnf)
      as_root dnf -y install ca-certificates curl gnupg2 git bash dnf-plugins-core
      ;;
    yum)
      as_root yum -y install ca-certificates curl gnupg2 git bash yum-utils
      ;;
    pacman)
      as_root pacman -Syu --noconfirm
      as_root pacman -S --noconfirm ca-certificates curl gnupg git bash
      ;;
    zypper)
      as_root zypper --non-interactive refresh
      as_root zypper --non-interactive install ca-certificates curl gpg2 git bash
      ;;
    apk)
      as_root apk update
      as_root apk add ca-certificates curl gnupg git bash
      ;;
    *)
      error "Unsupported package family: $PKG_FAMILY"
      ;;
  esac
}

install_docker_apt() {
  local arch codename
  arch="$(dpkg --print-architecture)"
  codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  [[ -n "$codename" ]] || error "Cannot detect Debian/Ubuntu codename."

  as_root install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  as_root chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${codename} stable" | as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

  as_root apt-get update -y
  as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_rhel_like() {
  if [[ "$PKG_FAMILY" == "dnf" ]]; then
    as_root dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    as_root dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    as_root yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    as_root yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
}

install_docker_arch() {
  as_root pacman -S --noconfirm docker docker-compose
}

install_docker_suse() {
  as_root zypper --non-interactive install docker docker-compose
}

install_docker_alpine() {
  as_root apk add docker docker-cli-compose
}

enable_docker_service() {
  if has_cmd systemctl; then
    as_root systemctl enable --now docker
  elif has_cmd rc-update; then
    as_root rc-update add docker default || true
    as_root service docker start || true
  else
    warn "No service manager detected. Start Docker daemon manually before running setup."
  fi
}

ensure_docker_group_access() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    return
  fi

  if getent group docker >/dev/null 2>&1; then
    if ! id -nG "$USER" | grep -qw docker; then
      warn "Adding user '$USER' to docker group."
      as_root usermod -aG docker "$USER"
      warn "Log out and log back in for docker group to apply, or run: newgrp docker"
    fi
  fi
}

detect_pkg_family() {
  case "${ID,,}" in
    ubuntu|debian)
      PKG_FAMILY="apt"
      ;;
    rhel|centos|rocky|almalinux|fedora)
      if has_cmd dnf; then
        PKG_FAMILY="dnf"
      else
        PKG_FAMILY="yum"
      fi
      ;;
    arch|manjaro)
      PKG_FAMILY="pacman"
      ;;
    opensuse*|sles)
      PKG_FAMILY="zypper"
      ;;
    alpine)
      PKG_FAMILY="apk"
      ;;
    *)
      case "${ID_LIKE,,}" in
        *debian*) PKG_FAMILY="apt" ;;
        *rhel*|*fedora*) PKG_FAMILY="dnf" ;;
        *suse*) PKG_FAMILY="zypper" ;;
        *) PKG_FAMILY="unknown" ;;
      esac
      ;;
  esac
}

install_docker_if_missing() {
  if has_cmd docker && (docker compose version >/dev/null 2>&1 || has_cmd docker-compose); then
    info "Docker and Compose already installed. Skipping installation."
    return
  fi

  info "Installing Docker Engine and Docker Compose for ${ID}..."
  case "$PKG_FAMILY" in
    apt)
      install_docker_apt
      ;;
    dnf|yum)
      install_docker_rhel_like
      ;;
    pacman)
      install_docker_arch
      ;;
    zypper)
      install_docker_suse
      ;;
    apk)
      install_docker_alpine
      ;;
    *)
      error "Unsupported distro family for automatic Docker install. Install Docker manually then run scripts/setup.sh"
      ;;
  esac

  enable_docker_service
  ensure_docker_group_access
}

verify_installation() {
  has_cmd docker || error "Docker installation failed (docker not found)."
  if ! docker compose version >/dev/null 2>&1 && ! has_cmd docker-compose; then
    error "Docker Compose installation failed."
  fi
  info "Docker version: $(docker --version)"
  if docker compose version >/dev/null 2>&1; then
    info "Compose version: $(docker compose version)"
  else
    info "Compose version: $(docker-compose --version)"
  fi
}

main() {
  info "=== Ariba NOC Center Auto Installer ==="
  require_os_release
  detect_pkg_family

  [[ "$PKG_FAMILY" != "unknown" ]] || error "Unsupported Linux distro (${ID})."

  info "Detected distro: ${PRETTY_NAME} (${PKG_FAMILY})"
  ensure_base_tools
  install_docker_if_missing
  verify_installation

  info "Running project setup..."
  cd "$PROJECT_DIR"
  bash scripts/setup.sh

  info "Installation flow completed."
}

main "$@"