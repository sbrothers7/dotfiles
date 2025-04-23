# Installation
### Before Install
Install [homebrew](https://brew.sh) before running!

### Script for Dependencies
<pre lang="markdown"> curl -L https://raw.githubusercontent.com/sbrothers7/dotfiles/main/install.sh | sh</pre>

### After Install
reload ZSH config manually:
<pre lang="markdown">source .zshrc</pre>

Install p10k font if fonts aren't displaying correctly in your terminal emulator:
<pre lang="markdown">p10k configure</pre>

### Notes
*yabai top padding configurations are for Macbook Pro 14"*

### Troubleshooting
#### ```stow``` Issues
If there aren't symlinked dotfiles in your home folder:
- Navigate into the dotfiles folder
- Delete any duplicates (```.zshrc```, ```.zprofile```, etc.)
- Navigate to dotfiles folder (```cd dotfiles```)
- Stow files using command below:
<pre lang="markdown">stow .</pre>
