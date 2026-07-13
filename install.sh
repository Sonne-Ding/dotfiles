#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ask_yes_no() {
  local prompt="$1"
  local answer

  while true; do
    if ! read -r -p "$prompt [yes/no]: " answer; then
      printf '\n输入已结束，安装中止。\n' >&2
      exit 1
    fi

    case "$answer" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 1 ;;
      *) printf '请输入 yes 或 no。\n' ;;
    esac
  done
}

main() {
  local configured=false

  if ask_yes_no "是否配置 zsh？"; then
    bash "$SCRIPT_DIR/zsh-install.sh"
    configured=true
  fi

  if ask_yes_no "是否配置 vim？"; then
    bash "$SCRIPT_DIR/vim-install.sh"
    configured=true
  fi

  if [[ "$configured" == true ]]; then
    printf '所选配置已安装完成。\n'
  else
    printf '未选择任何配置，未执行安装。\n'
  fi
}

main "$@"
