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
  printf '[zsh] 错误: %s\n' "$*" >&2
  exit 1
}

detect_platform() {
  case "$(uname -s)" in
    Linux)
      [[ -r /etc/os-release ]] || die "无法识别 Linux 发行版。"
      # shellcheck disable=SC1091
      source /etc/os-release
      case "${ID:-} ${ID_LIKE:-}" in
        *debian*|*ubuntu*) PLATFORM='linux' ;;
        *) die "Linux 仅支持 Ubuntu/Debian 系统。" ;;
      esac
      ;;
    Darwin)
      PLATFORM='macos'
      ;;
    *)
      die "仅支持 Ubuntu/Debian 和 macOS。"
      ;;
  esac
}

run_apt() {
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get "$@"
  else
    die "安装系统软件需要 root 权限或 sudo。"
  fi
}

run_brew() {
  command -v brew >/dev/null 2>&1 ||
    die "缺少 Homebrew。请先按照 https://brew.sh/ 的说明手动安装，然后重新运行此脚本。"
  brew install "$@"
}

install_dependencies() {
  local -a packages=()

  command -v zsh >/dev/null 2>&1 || packages+=(zsh)
  command -v git >/dev/null 2>&1 || packages+=(git)
  command -v rsync >/dev/null 2>&1 || packages+=(rsync)

  if ((${#packages[@]} > 0)); then
    log "安装依赖: ${packages[*]}"
    if [[ "$PLATFORM" == 'linux' ]]; then
      run_apt update
      run_apt install -y "${packages[@]}"
    else
      run_brew "${packages[@]}"
    fi
  else
    log "系统依赖已安装。"
  fi
}

deploy_config() {
  local source_file="$1"
  local target_file="$2"
  local name
  name="$(basename "$target_file")"

  [[ -f "$source_file" ]] || die "仓库配置不存在: $source_file"

  if [[ -f "$target_file" && ! -L "$target_file" ]] &&
    cmp -s "$source_file" "$target_file"; then
    log "$name 已是最新版本。"
    return
  fi

  if [[ -e "$target_file" || -L "$target_file" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target_file" "$BACKUP_DIR/$name"
    log "已备份 $target_file 到 $BACKUP_DIR/$name"
  fi

  install -m 0644 "$source_file" "$target_file"
  log "已复制 $name 到 $target_file"
}

install_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "oh-my-zsh 已安装。"
  else
    log "安装 oh-my-zsh。"
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  fi
}

install_zsh_autocomplete() {
  local plugin_dir="$HOME/.oh-my-zsh/plugins/zsh-autocomplete"

  if [[ -d "$plugin_dir" ]]; then
    log "zsh-autocomplete 已安装。"
  else
    log "安装 zsh-autocomplete。"
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
    log "zsh 已是默认 shell。"
    return
  fi

  if [[ "$PLATFORM" == 'macos' ]] &&
    ! grep -Fqx "$zsh_path" /etc/shells; then
    log "将 $zsh_path 添加到 /etc/shells。"
    if [[ "$(id -u)" -eq 0 ]]; then
      printf '%s\n' "$zsh_path" >>/etc/shells
    elif command -v sudo >/dev/null 2>&1; then
      printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    else
      die "修改 /etc/shells 需要 root 权限或 sudo。"
    fi
  fi

  log "将 $current_user 的默认 shell 设置为 $zsh_path。"
  chsh -s "$zsh_path" "$current_user" ||
    die "无法修改默认 shell，请手动执行: chsh -s $zsh_path"
}

main() {
  detect_platform
  install_dependencies
  install_oh_my_zsh
  install_zsh_autocomplete
  deploy_config "$SOURCE_ZSHRC" "$HOME/.zshrc"
  set_default_shell
  log "zsh 配置完成。"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
