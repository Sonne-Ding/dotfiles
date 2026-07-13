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
  printf '[vim] 错误: %s\n' "$*" >&2
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

  command -v vim >/dev/null 2>&1 || packages+=(vim)
  command -v curl >/dev/null 2>&1 || packages+=(curl)

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

install_vim_plug() {
  local plug_file="$HOME/.vim/autoload/plug.vim"

  if [[ -f "$plug_file" ]]; then
    log "vim-plug 已安装。"
  else
    log "安装 vim-plug。"
    curl -fLo "$plug_file" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
}

install_vim_plugins() {
  log "安装 .vimrc 中声明的 Vim 插件。"
  vim +PlugInstall +qall
}

main() {
  detect_platform
  install_dependencies
  deploy_config "$SOURCE_VIMRC" "$HOME/.vimrc"
  install_vim_plug
  install_vim_plugins
  log "vim 配置完成。"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
