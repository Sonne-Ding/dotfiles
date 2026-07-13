#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_VIMRC="$SCRIPT_DIR/.vimrc"
BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
PLATFORM=''

log() {
  printf '[vim] %s\n' "$*"
}

die() {
  printf '[vim] error: %s\n' "$*" >&2
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

  command -v vim >/dev/null 2>&1 || packages+=(vim)
  command -v curl >/dev/null 2>&1 || packages+=(curl)

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

deploy_config() {
  local source_file="$1"
  local target_file="$2"
  local name
  name="$(basename "$target_file")"

  [[ -f "$source_file" ]] || die "Repository config not found: $source_file"

  if [[ -f "$target_file" && ! -L "$target_file" ]] &&
    cmp -s "$source_file" "$target_file"; then
    log "$name is already up to date."
    return
  fi

  if [[ -e "$target_file" || -L "$target_file" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_file" "$BACKUP_DIR/$name"
    log "Backed up $target_file to $BACKUP_DIR/$name"
  fi

  install -m 0644 "$source_file" "$target_file"
  log "Copied $name to $target_file"
}

install_vim_plug() {
  local plug_file="$HOME/.vim/autoload/plug.vim"

  if [[ -f "$plug_file" ]]; then
    log "vim-plug is already installed."
  else
    log "Installing vim-plug."
    curl -fLo "$plug_file" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
}

install_vim_plugins() {
  log "Installing Vim plugins declared in .vimrc."
  vim +PlugInstall +qall
}

main() {
  detect_platform
  install_dependencies
  deploy_config "$SOURCE_VIMRC" "$HOME/.vimrc"
  install_vim_plug
  install_vim_plugins
  log "vim setup complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
