#!/bin/zsh

ok()    { print -P "%B%F{green}✔ $*%f%b"; }
warn()  { print -P "%F{yellow}$*%f"; }
err()   { print -P "%B%F{red}✖ $*%f%b"; }
info()  { print -P "%B%F{blue}$*%f%b"; }
dim()   { print -P "%F{black}$*%f"; }


# ============ CONFIG ============
typeset -a CATEGORIES=( WM ZSH Utilities Casks Defaults Other Quit )
typeset -a SUBCATS=( ${CATEGORIES:#Quit} )

typeset -a CATEGORY_WM=( "yabai" "skhd" "borders" "sketchybar")
typeset -a CATEGORY_ZSH=( "zsh-syntax-highlighting" "zsh-autosuggestions" "starship" )
typeset -a CATEGORY_Utilities=( "neovim" "fastfetch" "lf" "yt-dlp" "btop" "ffmpeg" "mono" "armadillo" "lazygit" "llvm" "python" "node" "openjdk" "lua" "qemu" )
typeset -a CATEGORY_Casks=( "kitty" "brave-browser" "karabiner-elements" "sol" "middleclick" "linearmouse" "slimhud" "yellowdot" "mpv" "command-x" "alt-tab" "prismlauncher" "bluestacks" "discord" "gimp" "obs" "qutebrowser")
typeset -a CATEGORY_Defaults=( "Minimalist" "No Animations" "Revamped Finder" )
typeset -a CATEGORY_Other=( "Rosetta 2" "Fonts" "KISJ App Bundle")

typeset -a DEFAULT_WM=( 1 2 3 4 )
typeset -a DEFAULT_ZSH=( 1 2 3 )
typeset -a DEFAULT_Utilities=( 1 2 3 4 )
typeset -a DEFAULT_Casks=( 1 2 3 4 5 )
typeset -a DEFAULT_Defaults=( 1 2 )
typeset -a DEFAULT_Other=( 1 2 )

TITLE="Installation Setup"
PROMPT_MAIN="%BEnter number to open a submenu%b\n([c]onfirm, [l]ist, [h]elp, [r]eset all, [q]uit):"
PROMPT_SUB="%BEnter number to toggle selection%b\n([a]ll, [n]one, [l]ist, [h]elp, [b]ack):"

# ============ STATE ============
typeset -a selected_WM selected_ZSH selected_Utilities selected_Casks selected_Defaults selected_Other

init() {
  for cat in "${SUBCATS[@]}"; do
    sel_var="selected_${cat}"
    items_var="CATEGORY_${cat}"
    defs_var="DEFAULT_${cat}"

    eval "$sel_var=()"
    eval "len=\${#${items_var}[@]}"
    for ((i=1; i<=len; i++)); do eval "${sel_var}[$i]=0"; done
    eval 'for d in "${'"$defs_var"'[@]}"; do
            (( d>=1 && d<=len )) && '"${sel_var}"'[$d]=1
          done'
  done

  
}


# ============ MENUS ============
render_main() {
  print -P "%B%F{blue}================================"
  print -P "       $TITLE"
  print -P "================================%f%b"
  local -i i
  for (( i=1; i<=${#CATEGORIES[@]}; i++ )); do
    printf "%2d) %s\n" $i "${CATEGORIES[$i]}"
  done
  print -P "%B%F{blue}--------------------------------%f%b"
  print -Pn -- "$PROMPT_MAIN "
}

render_submenu() {
  local -r cat="$1" buf="$2"
  local -a items; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
  local -a sel;   eval "sel=( \"\${selected_${cat}[@]}\" )"
  print -P "%B%F{blue}============ ${cat} ============%f%b"
  local -i i
  for (( i=1; i<=${#items[@]}; i++ )); do
    local mark='[ ]'; [[ "${sel[$i]}" == "1" ]] && mark='[x]'
    printf "%2d) %s %s\n" $i "$mark" "${items[$i]}"
  done
  print -P "%B%F{blue}--------------------------------%f%b"
  print -Pn -- "$PROMPT_SUB "
  [[ -n "$buf" ]] && print -r -- "$buf"
}

print_all_selections() {
  local cat
  for cat in "${CATEGORIES[@]}"; do
    [[ "$cat" == "Quit" ]] && continue
    local -a items sel; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
    eval "sel=( \"\${selected_${cat}[@]}\" )"
    local -i shown=0 i
    for (( i=1; i<=${#items[@]}; i++ )); do
      if [[ "${sel[$i]}" == "1" ]]; then
        (( shown == 0 )) && info "[$cat]"
        print -r -- "  - ${items[$i]}"
        (( shown++ ))
      fi
    done

    # print -n -- "\nPress any key for next"
    # read -k
    # clear
  done

  print -n -- "\nPress any key to exit"
  read -k
  clear
}

# ============ HELP ============
help_main() {
  cat <<'HLP'
MAIN MENU HELP:

  Number keys       Open category

  c                 Confirm and run installers

  l                 List current selections

  h                 Help
  
  q                 Quit



HLP
  print -n -- "Press any key to exit"
  read -k
  clear
}
help_sub() {
  cat <<'HLP'
SUBMENU HELP:

  Number keys       Toggle item (if < 10 items)
                    (for 10+ items) type digits then 
                    press Enter/Space to toggle

  Backspace         Erase last digit
  Delete  

  a                 Select all in this submenu

  n                 Deselect all in this submenu

  l                 List global selections

  h                 Help

  b                 Back to main menu



HLP
  print -n -- "Press any key to exit"
  read -k
  clear
}

read_key() {
  # Reads one keystroke into global REPLY, no print, immediate
  IFS= read -rk 1 -s
}

is_digit() { [[ "$1" == <-> ]]; }          # single digit 0..9
is_backspace() { [[ "$1" == $'\x7f' || "$1" == $'\b' ]]; }
is_enter() { [[ "$1" == $'\n' || "$1" == $'\r' || "$1" == ' ' ]]; }

# Toggle handler
toggle_item() {
  local -r cat="$1"; local -i idx="$2"
  local -a items; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
  (( idx >= 1 && idx <= ${#items[@]} )) || { print -r -- "Out of range: $idx"; return; }
  local cur; eval "cur=\${selected_${cat}[$idx]}"
  if [[ "$cur" == "1" ]]; then
    eval "selected_${cat}[$idx]=0"
    print -r -- "Deselected: ${items[$idx]}"
  else
    eval "selected_${cat}[$idx]=1"
    print -r -- "Selected:   ${items[$idx]}"
  fi
}

# Submenu loop (instant keys)
submenu_loop() {
  local -r cat="$1"
  local -a items; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
  local buf=""
  while true; do
    render_submenu "$cat" "$buf"
    read_key
    clear

    local k="$REPLY"

    # Fast path: single-digit toggle if <=9 items
    if is_digit "$k" && (( ${#items[@]} <= 9 )); then
      toggle_item "$cat" "$k"
      continue
    fi

    # Build number buffer (for multi-digit indices or any size)
    if is_digit "$k"; then
      buf+="$k"
      # Optional: live toggle when buffer already valid and next char not a digit
      continue
    fi

    # Apply buffered number on Enter/Space
    if is_enter "$k"; then
      if [[ -n "$buf" ]]; then
        toggle_item "$cat" "$buf"
        buf=""
      fi
      continue
    fi

    # Backspace/Delete clears buffer char-by-char
    if is_backspace "$k"; then
      [[ -n "$buf" ]] && buf="${buf[1,-2]}"   # chop last char
      continue
    fi

    case "$k" in
      a) # all
        local -i i; for (( i=1; i<=${#items[@]}; i++ )); do eval "selected_${cat}[$i]=1"; done
        print -r -- "Selected every item."
        ;;
      n) # none
        local -i i; for (( i=1; i<=${#items[@]}; i++ )); do eval "selected_${cat}[$i]=0"; done
        print -r -- "Deselected every item.";
        ;;
      l) print_all_selections ;;
      h) help_sub ;;
      b) return 0 ;;
      q) print -r -- "Exiting."; exit 0 ;;
      *) print;;
    esac
  done
}

install_formula() {
  local formula="$1"
  if brew list --formula --versions "$formula" >/dev/null 2>&1; then
    warn "$formula already installed"
  else
    brew install "$formula"
  fi
}

install_cask() {
  local cask="$1"
  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    warn "$cask already installed"
  else
    brew install --cask "$cask"
  fi
}

gather_pkgs() {
  typeset -ga formulae=() casks=()
  local i cat j items_var sel_var len s

  for i in {1..${#SUBCATS[@]}}; do
    cat="${SUBCATS[$i]}"

    # skip non-brew related
    (( i > 4 )) && continue

    items_var="CATEGORY_${cat}"
    sel_var="selected_${cat}"

    eval "len=\${#${items_var}[@]}"
    for (( j=1; j<=len; j++ )); do
      eval 's="${'"$sel_var"'[$j]}"'
      if [[ "$s" == 1 ]]; then
        if (( i == 4 )); then
          eval 'casks+=( "${'"$items_var"'[$j]}" )'
        else
          eval 'formulae+=( "${'"$items_var"'[$j]}" )'
        fi
      fi
    done
  done

  # Deduplicate in zsh
  typeset -aU formulae=("${formulae[@]}")
  typeset -aU casks=("${casks[@]}")

  # echo "${formulae[@]}"
  # echo "${casks[@]}"
}


# Installers
run_installers() {
  clear

  # Homebrew installation
  info "Checking homebrew installation..."
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is not installed."
    info "Attempting to install homebrew..."
   
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/install_homebrew.sh
    chmod +x /tmp/install_homebrew.sh
    /bin/bash /tmp/install_homebrew.sh

    info "Setting PATH for homebrew..."
    print >> $HOME/.zprofile
    print 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"

    ok "Successfully installed homebrew. Continuing installation..."
  else
    ok "Found homebrew installation. Continuing..."
  fi

  # Install xCode CLI tools
  info "\nChecking command line tools installation..."
  if xcode-select -p &>/dev/null; then
    warn "xCode command line tools is already installed. Continuing..."
  else
    info "Installing xCode command line tools..."
    xcode-select --install
    ok "xCode command line tools successfully installed. Continuing..."
  fi

  gather_pkgs
  
  info "\nInstalling git and stow..."
  install_formula "git"
  install_formula "stow"

  # Formulae
  if (( ${#formulae[@]} )); then
    print
    info "Installing formulae..."
    for f in "${formulae[@]}"; do
      install_formula "$f"
    done
  else
    warn "No formulae selected."
  fi

  # Casks
  if (( ${#casks[@]} )); then
    info "\nInstalling casks..."
    for c in "${casks[@]}"; do
      install_cask "$c"
    done
  else
    warn "No casks selected."
  fi
}

# =============== MAIN LOOP ===============
main_loop() {
  while true; do
    render_main
    read_key
    clear
    local k="$REPLY"

    # Single-digit ( < 10 categories)
    if is_digit "$k" && (( ${#CATEGORIES[@]} <= 9 )); then
      local -i idx=$k
      if (( idx >= 1 && idx <= ${#CATEGORIES[@]} )); then
        local cat="${CATEGORIES[$idx]}"
        [[ "$cat" == "Quit" ]] && { info "Script exited."; exit 0; }
        submenu_loop "$cat"
      fi
      continue
    fi

    case "$k" in
      c)  # confirm
        print_all_selections
        print -Pn -- "%B%F{blue}Proceed with installation? [y/N]: %f%b"
        read_key; local y="$REPLY"
        if [[ "$y" == [yY] ]]; then run_installers; 
          print
          ok "All done!"; exit 0
        else 
          clear
          info "Cancelled."; fi
        ;;
      l) print_all_selections ;;
      r) 
        init 
        ok "Reset selections to default"
        ;;
      h) help_main ;;
      q) info "Script exited."; exit 0 ;;
      $'\n'|$'\r'|' ') ;;  # ignore Enter/space here
      *) ;;                # ignore other keys
    esac
  done
}

clear

compat() {
  if [[ -z "${ZSH_VERSION:-}" ]]; then
    err "This script requires zsh. Please run it with zsh."
    exit 1
  fi

  if [[ "$(uname -m)" == "arm64" ]]; then
    ok "Apple Silicon detected"
  else
    err "intel (x86_64) detected. This script is exclusively for Apple Silicon Macs. Please use a different machine."
    exit 1
  fi

  if [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null)" == "1" ]]; then
    err "Running under Rosetta (x86_64 translation). Please disable Rosetta and run this script again."
    exit 1
  else
    ok "Running natively"
  fi
}

compat

info "Initializing..."
init
ok "Script ready"
print -n -- "Press any key to start"
read -k
clear

main_loop
