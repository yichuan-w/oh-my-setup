# Development Environment Setup

A guide for setting up a modern development environment with zsh, oh-my-zsh, GitHub, and Claude Code.

## Prerequisites

Install zsh if not already installed:
```bash
sudo apt install zsh -y
```

## Oh-My-Zsh Installation

Install oh-my-zsh:
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## Zsh Plugins

Install the following plugins to enhance your shell experience:

```bash
# Autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Syntax highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

# Fast syntax highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting

# Autocomplete
git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git $ZSH_CUSTOM/plugins/zsh-autocomplete
```

### Enable Plugins

1. Open your zsh configuration:
```bash
nvim ~/.zshrc
```

2. Find the line that says `plugins=(git)`

3. Replace it with:
```bash
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)
```

4. Reload your configuration:
```bash
source ~/.zshrc
```

## GitHub Setup

### Configure Git

Set your Git identity:
```bash
git config --global user.name "yichuan-w"
git config --global user.email "yichuan_wang@berkeley.edu"
```

### Add SSH Key to GitHub

1. Copy your public SSH key:
```bash
cat ~/.ssh/id_ed25519_github.pub
```

2. Navigate to [GitHub SSH Settings](https://github.com/settings/keys)

3. Click **New SSH key**

4. Paste the public key and save

### Test GitHub Connection

Verify your SSH connection:
```bash
ssh -T git@github.com
```

You should see a message confirming successful authentication.

## Claude Code Installation

Install Claude Code CLI:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```