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
- [starship](https://github.com/catppuccin/starship) theme
- auto syntax highlighting & suggestions
- [autojump](https://github.com/wting/autojump)
- aliases (refer to .zshrc)

**Optional auto installations for:**
- python
- node.js
- [armadillo](https://arma.sourceforge.net/download.html) (C++ library for linear algebra and scientific computing)
- [mono](https://gitlab.winehq.org/mono/mono) (Cross platform .NET framework)
- [mpv](https://mpv.io/)
- zoom
- sol (MacOS spotlight alternative)
- slimhud (MacOS volume, brightness adjustment HUD alternative)
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
Run the script in terminal. It will ask for the mac user password when trying to install some of the casks. During the installation process, you will be prompted whether to install a set of programs or to not. Note that the config may not work with some of the program omitted. 

### Notes
- yabai top padding is set for a Macbook Pro 14" with Apple Silicon and MacOS 13.x+. For devices that do not have a notch, adjust the top padding value. It is located at ```~/dotfiles/.config/yabai/yabairc```.

# Updating
Simply pull from the repository.
<pre lang="markdown">git pull https://github.com/sbrothers7/dotfiles</pre>

# Troubleshooting
### Shell Hasn't Changed After Install
Reload ZSH config manually:
<pre lang="markdown">source .zshrc</pre>

### `stow` Issues
If there aren't symlinked dotfiles in your home folder:
- Navigate to the home folder (`cd ~`)
- Delete any duplicates (`.zshrc`, `.zprofile`, etc.)
- Navigate to dotfiles folder (`cd dotfiles`)
- Stow files using command below:
<pre lang="markdown">stow .</pre>

### Using PIP
A virtual environment needs to be set up and activated when needed when python is installed via homebrew. The install script creates an alias for this named 'pyinit', but for it to function, **the virtual environment must be located at the home directory and named** `.pyvenv`.
Refer to [here](https://docs.python.org/3/library/venv.html) for more information.
