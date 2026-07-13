#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

main() {
  local configured=false

  if ask_yes_no "Configure zsh?"; then
    bash "$SCRIPT_DIR/zsh-install.sh"
    configured=true
  fi

  if ask_yes_no "Configure vim?"; then
    bash "$SCRIPT_DIR/vim-install.sh"
    configured=true
  fi

  if [[ "$configured" == true ]]; then
    printf 'Selected configurations have been installed.\n'
  else
    printf 'No configuration selected; nothing was installed.\n'
  fi
}

main "$@"
