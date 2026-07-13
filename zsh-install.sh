#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ZSHRC="$SCRIPT_DIR/.zshrc"
BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
PLATFORM=''

log() {
  printf '[zsh] %s\n' "$*"
}

die() {
  printf '[zsh] error: %s\n' "$*" >&2
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

  command -v zsh >/dev/null 2>&1 || packages+=(zsh)
  command -v git >/dev/null 2>&1 || packages+=(git)
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

install_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "oh-my-zsh is already installed."
  else
    log "Installing oh-my-zsh."
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  fi
}

install_zsh_autocomplete() {
  local plugin_dir="$HOME/.oh-my-zsh/plugins/zsh-autocomplete"

  if [[ -d "$plugin_dir" ]]; then
    log "zsh-autocomplete is already installed."
  else
    log "Installing zsh-autocomplete."
    git clone --depth 1 -- \
      https://github.com/marlonrichert/zsh-autocomplete.git \
      "$plugin_dir"
  fi
}

set_default_shell() {
  local zsh_path current_user current_shell
  zsh_path="$(command -v zsh)"
  current_user="${SUDO_USER:-${USER:-$(id -un)}}"

  if [[ "$PLATFORM" == 'linux' ]]; then
    current_shell="$(getent passwd "$current_user" 2>/dev/null | cut -d: -f7 || true)"
  else
    current_shell="$(
      dscl . -read "/Users/$current_user" UserShell 2>/dev/null |
        awk '{print $2}' || true
    )"
    current_shell="${current_shell:-${SHELL:-}}"
  fi

  if [[ "$current_shell" == "$zsh_path" ]]; then
    log "zsh is already the default shell."
    return
  fi

  if [[ "$PLATFORM" == 'macos' ]] &&
    ! grep -Fqx "$zsh_path" /etc/shells; then
    log "Adding $zsh_path to /etc/shells."
    if [[ "$(id -u)" -eq 0 ]]; then
      printf '%s\n' "$zsh_path" >>/etc/shells
    elif command -v sudo >/dev/null 2>&1; then
      printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    else
      die "Updating /etc/shells requires root privileges or sudo."
    fi
  fi

  log "Setting default shell for $current_user to $zsh_path."
  chsh -s "$zsh_path" "$current_user" ||
    die "Unable to change default shell. Run manually: chsh -s $zsh_path"
}

main() {
  detect_platform
  install_dependencies
  install_oh_my_zsh
  install_zsh_autocomplete
  deploy_config "$SOURCE_ZSHRC" "$HOME/.zshrc"
  set_default_shell
  log "zsh setup complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
