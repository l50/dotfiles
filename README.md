# dotfiles

[![Test dotfiles](https://github.com/l50/dotfiles/actions/workflows/tests.yaml/badge.svg)](https://github.com/l50/dotfiles/actions/workflows/tests.yaml)
[![Run Pre-Commit hooks](https://github.com/l50/dotfiles/actions/workflows/pre-commit.yaml/badge.svg)](https://github.com/l50/dotfiles/actions/workflows/pre-commit.yaml)
[![License](https://img.shields.io/github/license/l50/dotfiles?label=License&style=flat&color=blue&logo=github)](https://github.com/l50/dotfiles/blob/master/LICENSE)

These are my dotfiles. Please feel free to check them out
and see if anything can be adopted for your own.

## Installation

Install `rvm` and `ruby` (for markdownlint):

```bash
gpg --keyserver keyserver.ubuntu.com \
    --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable --ruby
rvm install ruby-3.2.1
```

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

### Ubuntu Dependencies

```bash
sudo apt-get install -y xclip expect
```

### oh-my-zsh

```bash
bash -c "$(curl -fsSL \
    https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### go-eval

```bash
go install github.com/dolmen-go/goeval@latest
```

### Dotfiles

```bash
bash install_dot_files.sh
```

### Git user config

Create `~/.gitconfig.userparams` with the following:

```bash
[user]
    name = Jayson Grace
    email = jayson.e.grace@gmail.com
    username = l50
```

---

## Test actions locally

```bash
act -P --container-architecture linux/amd64
# macOS
act -P macos-latest=-self-hosted
```
