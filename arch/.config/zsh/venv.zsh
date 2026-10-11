# ~/.config/zsh/venv.zsh
# Add to ~/.zshrc:   source ~/.config/zsh/venv.zsh
#
#   ve    activate ./.venv or ./venv; deactivate if already active and neither exists here

ve() {
  local dir
  for dir in .venv venv; do
    if [[ -f "$dir/bin/activate" ]]; then
      source "$dir/bin/activate"
      return 0
    fi
  done
  if [[ -n $VIRTUAL_ENV ]]; then
    deactivate
    return 0
  fi
  print -u2 "ve: no .venv/ or venv/ in $PWD"
  return 1
}
