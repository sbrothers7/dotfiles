# Installation
### Before Install
Install [homebrew](https://brew.sh) before running!

### Installation Script
<pre lang="markdown">zsh <(curl -sL https://raw.githubusercontent.com/sbrothers7/dotfiles/main/install.sh)</pre>
Run the script in terminal. It will ask for the mac user password when trying to install some casks.

### Notes
- yabai top padding is set for a Macbook Pro 14". For devices that do not have a notch, adjust the top padding value. It is located at ```~/dotfiles/.config/yabai/yabairc```.

# Troubleshooting
#### ```Shell Hasn't Changed After Install
Reload ZSH config manually:
<pre lang="markdown">source .zshrc</pre>

#### ```stow``` Issues
If there aren't symlinked dotfiles in your home folder:
- Navigate to the home folder (```cd ~```)
- Delete any duplicates (```.zshrc```, ```.zprofile```, etc.)
- Navigate to dotfiles folder (```cd dotfiles```)
- Stow files using command below:
<pre lang="markdown">stow .</pre>
