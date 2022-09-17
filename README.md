# dotfiles

[![Test dotfiles](https://github.com/l50/dotfiles/actions/workflows/test.yaml/badge.svg)](https://github.com/l50/dotfiles/actions/workflows/test.yaml)
[![Run Pre-Commit hooks](https://github.com/l50/dotfiles/actions/workflows/pre-commit.yaml/badge.svg)](https://github.com/l50/dotfiles/actions/workflows/pre-commit.yaml)
[![License](https://img.shields.io/github/license/l50/dotfiles?label=license&style=flat&color=blue&logo=github)](https://github.com/l50/dotfiles/blob/master/LICENSE)

These are my dotfiles. Please feel free to check them out
and see if anything can be adopted for your own.

## Installation

### Linux Dependencies

```bash
sudo apt-get update
sudo apt-get install -y curl zsh
# Fix permissions to avoid annoying message
sudo chmod -R 755 /usr/share/zsh
sudo chmod -R 755 /usr/share/zsh/vendor-completions
# If you need to change your shell manually, run this command:
sudo chsh -s /bin/zsh
brew install shfmt
```

### MacOS Dependencies

```bash
# Install homebrew
brew install cask google-cloud-sdk
```

### oh-my-zsh

```bash
bash -c "$(curl -fsSL \
    https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Dotfiles

```bash
bash install_dot_files.sh
```
