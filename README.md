# Features
**Custom configuration files for:**
- [yabai](https://github.com/koekeishiya/yabai)
- [skhd](https://github.com/koekeishiya/skhd)
- [borders](https://github.com/FelixKratz/JankyBorders)
- [sketchybar](https://github.com/FelixKratz/SketchyBar)
- [nvim](https://neovim.io/)
- [kitty](https://sw.kovidgoyal.net/kitty/)
- [lf](https://github.com/gokcehan/lf)
- [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- and more...

**ZSH enhancements:**
- [starship](https://github.com/catppuccin/starship) or [agkozak-zsh-prompt](https://github.com/agkozak/agkozak-zsh-prompt)
- auto syntax highlighting & suggestions
- [autojump](https://github.com/wting/autojump)
- aliases (refer to .zshrc)

**Optional auto installations for:**
- python
- node.js
- [armadillo](https://arma.sourceforge.net/download.html) (C++ library for linear algebra and scientific computing)
- [mono](https://gitlab.winehq.org/mono/mono) (Cross platform .NET framework)
- [iina](https://iina.io/)
- middleclick (three-finger click for middle click on touchpad)
- command-x (cut & paste support for Finder)
- linearmouse (better mouse settings)
- yellowdot (hides pesky dot in top right corner when screen is being recorded, microphone is being accessed, etc.)

**Other:**
- Fonts and symbols installations
- Automatic MacOS default system settings override

# Installation
### Installation Script
<pre lang="markdown">zsh <(curl -sL https://raw.githubusercontent.com/sbrothers7/dotfiles/main/install.sh)</pre>
Run the script in terminal. It asks for your password once at the start and allows passwordless `sudo` only while it runs, so the install can run unattended.

Programs that are already installed are greyed out in the menu. After picking programs, choose how dotfiles are applied: **Use dotfiles** links `.zshrc` and the configs of installed programs, **Select programs to use dotfiles** links only the ones you tick, and **Don't use dotfiles** leaves your existing config alone (only the needed lines are added to your own `~/.zshrc`).

While installing, a loading screen shows the current step, the package being installed and a progress bar. Press `l` to switch to the raw log and back, or turn the loading screen off in the main menu. The full log is saved to `~/.cache/sbro7dots-install.log`.

If the install is interrupted or a step fails, run the script again and choose **Resume**: finished steps are skipped and only the rest runs. When everything succeeds, third-party taps that no installed formula needs are untapped.

### Arch Linux
The same command works on Arch Linux. The script detects Arch and shows its own menus for the Hyprland desktop, shell, utilities, apps, system services and theming:
<pre lang="markdown">zsh <(curl -sL https://raw.githubusercontent.com/sbrothers7/dotfiles/main/install.sh)</pre>
Run it as your normal user (it uses `sudo` where needed). It updates the system, installs [yay](https://github.com/Jguer/yay) if missing, and installs repo and AUR packages with it. Steam turns on the `multilib` repository. Services for Bluetooth, NetworkManager, printing and SDDM are enabled but only start on the next boot, so nothing takes over the running session. The NVIDIA driver is preselected when an NVIDIA card is found.

The Arch configs live in `arch/`, a separate stow package, so they never mix with the macOS ones. Linking backs up anything in the way to `~/sbro7dots-backups/` first.

### Test mode
Try the menus, loading screen and resume without installing or changing anything:
<pre lang="markdown">zsh install.sh --test</pre>
Test mode skips sudo and keeps its own state in `~/.cache/sbro7dots-test`. To see a failure and **Resume**, make one fake install fail, for example `TEST_FAIL=stow zsh install.sh --test`.

### Notes
- yabai top padding is set for a Macbook Pro 14" with Apple Silicon and MacOS 13.x+. For devices that do not have a notch, adjust the top padding value. It is located at ```~/sbro7dots/.config/yabai/yabairc```.

### Installer layout
`install.sh` checks compatibility, handles sudo and resume, and loads the rest from `install/`. When run through `curl`, it downloads the repo to a temporary folder first.
- `core.zsh`: steps, resume and the install run, shared by macOS and Arch
- `config.zsh`: menu items, defaults, taps, paths
- `ui.zsh`: output helpers, menu widgets, main menu
- `selection.zsh`: selections and detection of installed programs
- `presets.zsh`: macOS defaults presets
- `steps.zsh`: install steps, resume and the install sequence
- `dotfiles.zsh`: download, `~/.zshrc.local` and stow linking
- `overlay.zsh`: loading screen shown during install
- `test.zsh`: fake install steps for `--test`
- `arch/`: the Arch Linux versions of `config.zsh`, `selection.zsh`, `steps.zsh`, `dotfiles.zsh` and `test.zsh`. `ui.zsh`, `overlay.zsh` and `core.zsh` are shared.

# Updating
Simply pull from the repository.
<pre lang="markdown">git pull https://github.com/sbrothers7/dotfiles</pre>

# Troubleshooting
### Shell Hasn't Changed After Install
Reload ZSH config manually:
<pre lang="markdown">source .zshrc</pre>

### ```stow``` Issues
If there aren't symlinked dotfiles in your home folder:
- Navigate to the home folder (```cd ~```)
- Move away any duplicates (```.zshrc```, folders inside ```.config```, etc.)
- Make sure ```~/.config``` is a real folder, not a link (```mkdir -p ~/.config```)
- Navigate to dotfiles folder (```cd sbro7dots```)
- Stow files using command below:
<pre lang="markdown">stow .</pre>

Shell plugins, prompt and aliases live in ```~/.zshrc.local```, which the script rewrites on every run. It loads whatever is installed, so a run with fewer selections never turns plugins off.
