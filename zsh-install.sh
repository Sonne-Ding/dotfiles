#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ZSHRC="$SCRIPT_DIR/.zshrc"
BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
PLATFORM=''
SELECTED_PLUGINS=()

log() {
  printf '[zsh] %s\n' "$*"
}

die() {
  printf '[zsh] error: %s\n' "$*" >&2
  exit 1
}

ask_yes_no() {
  local prompt="$1"
  local answer

  while true; do
    if ! read -r -p "$prompt [yes/no]: " answer; then
      printf '\nInput ended; installation aborted.\n' >&2
      exit 1
    fi

    case "$answer" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 1 ;;
      *) printf 'Please enter yes or no.\n' ;;
    esac
  done
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

ask_and_install_plugins() {
  local zsh_custom="$HOME/.oh-my-zsh/custom"
  local -a plugin_defs=(
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
    "fast-syntax-highlighting|https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    "zsh-autocomplete|https://github.com/marlonrichert/zsh-autocomplete.git"
  )
  local def name repo path

  mkdir -p "$zsh_custom/plugins"
  SELECTED_PLUGINS=()

  for def in "${plugin_defs[@]}"; do
    name="${def%%|*}"
    repo="${def#*|}"
    path="$zsh_custom/plugins/$name"

    if ask_yes_no "Install $name?"; then
      if [[ -d "$path" ]]; then
        log "$name is already installed."
      else
        log "Installing $name."
        git clone --depth 1 -- "$repo" "$path"
      fi
      SELECTED_PLUGINS+=("$name")
    fi
  done
}

update_plugins_in_zshrc() {
  local target_file="$1"
  shift
  local -a selected_plugins=("$@")
  local tmp in_block=false line

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "plugins=(" ]]; then
      printf 'plugins=(\n' >>"$tmp"
      for plugin in "${selected_plugins[@]}"; do
        printf '%s\n' "$plugin" >>"$tmp"
      done
      printf ')\n' >>"$tmp"
      in_block=true
      continue
    fi

    if [[ "$in_block" == true && "$line" == ")" ]]; then
      in_block=false
      continue
    fi

    if [[ "$in_block" == false ]]; then
      printf '%s\n' "$line" >>"$tmp"
    fi
  done <"$target_file"

  mv "$tmp" "$target_file"
}

deploy_config_and_update_plugins() {
  deploy_config "$SOURCE_ZSHRC" "$HOME/.zshrc"
  update_plugins_in_zshrc "$HOME/.zshrc" "${SELECTED_PLUGINS[@]}"

  if ((${#SELECTED_PLUGINS[@]} > 0)); then
    log "Updated plugins in ~/.zshrc: ${SELECTED_PLUGINS[*]}"
  else
    log "No optional plugins selected."
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
  ask_and_install_plugins
  deploy_config_and_update_plugins
  set_default_shell
  log "zsh setup complete."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
