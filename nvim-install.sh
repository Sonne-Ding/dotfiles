#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_NVIM="$SCRIPT_DIR/nvim"
TARGET_NVIM="$HOME/.config/nvim"
BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
PLATFORM=''

log() {
  printf '[nvim] %s\n' "$*"
}

die() {
  printf '[nvim] error: %s\n' "$*" >&2
  exit 1
}

detect_platform() {
  case "$(uname -s)" in
    Linux)
      [[ -r /etc/os-release ]] || die "Unable to detect Linux distribution."
      # shellcheck disable=SC1091
      source /etc/os-release
      case "${ID:-} ${ID_LIKE:-}" in
        *debian*|*ubuntu*) PLATFORM='linux' ;;
        *) die "Linux is only supported on Ubuntu/Debian." ;;
      esac
      ;;
    Darwin)
      PLATFORM='macos'
      ;;
    *)
      die "Only Ubuntu/Debian and macOS are supported."
      ;;
  esac
}

run_apt() {
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get "$@"
  else
    die "Installing system packages requires root privileges or sudo."
  fi
}

run_brew() {
  command -v brew >/dev/null 2>&1 ||
    die "Homebrew is missing. Install it manually from https://brew.sh/, then rerun this script."
  brew install "$@"
}

install_dependencies() {
  local -a packages=()

  command -v nvim >/dev/null 2>&1 || packages+=(neovim)
  command -v rsync >/dev/null 2>&1 || packages+=(rsync)

  if ((${#packages[@]} > 0)); then
    log "Installing dependencies: ${packages[*]}"
    if [[ "$PLATFORM" == 'linux' ]]; then
      run_apt update
      run_apt install -y "${packages[@]}"
    else
      run_brew "${packages[@]}"
    fi
  else
    log "System dependencies are already installed."
  fi
}

deploy_config_dir() {
  local source_dir="$1"
  local target_dir="$2"
  local name
  name="$(basename "$target_dir")"

  [[ -d "$source_dir" ]] || die "Repository config not found: $source_dir"

  mkdir -p "$(dirname "$target_dir")"

  if [[ -d "$target_dir" && ! -L "$target_dir" ]] &&
    diff -rq "$source_dir" "$target_dir" >/dev/null 2>&1; then
    log "$name is already up to date."
    return
  fi

  if [[ -e "$target_dir" || -L "$target_dir" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_dir" "$BACKUP_DIR/$name"
    log "Backed up $target_dir to $BACKUP_DIR/$name"
  fi

  mkdir -p "$target_dir"
  rsync -a --delete "$source_dir/" "$target_dir/"
  log "Copied $name to $target_dir"
}

main() {
  detect_platform
  install_dependencies
  deploy_config_dir "$SOURCE_NVIM" "$TARGET_NVIM"
  log "nvim setup complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
