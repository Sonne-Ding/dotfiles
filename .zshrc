export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="af-magic"

plugins=(
zsh-autocomplete	
)
source ~/.oh-my-zsh/oh-my-zsh.sh
zstyle -e ':autocomplete:*:*' list-lines 'reply=( 8 )'

# Setting environment variables
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

alias cp-clean='rsync -avh \
  --exclude=".DS_Store" \
  --exclude="._*" \
  --exclude=".Spotlight-*" \
  --exclude=".Trashes" \
  --exclude="Thumbs.db" \
  --exclude="~$*" \
  --exclude="System Volume Information" \
  --exclude="$RECYCLE.BIN" \
  --exclude="__pycache__" \
  --exclude="*.pyc" \
  --exclude="*.pyo" \
  --exclude=".pytest_cache" \
  --exclude=".mypy_cache" \
  --exclude="*.swp" \
  --exclude="*.swo"'
