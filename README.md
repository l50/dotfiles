# dotfiles

[![License](https://img.shields.io/github/license/l50/dotfiles?label=License&style=flat&color=blue&logo=github)](https://github.com/l50/dotfiles/blob/master/LICENSE)
[![Test dotfiles](https://github.com/l50/dotfiles/actions/workflows/tests.yaml/badge.svg)](https://github.com/l50/dotfiles/actions/workflows/tests.yaml)
[![Renovate](https://github.com/l50/dotfiles/actions/workflows/renovate.yaml/badge.svg)](https://github.com/l50/dotfiles/actions/workflows/renovate.yaml)

These are my dotfiles. Please feel free to check them out
and see if anything can be adopted for your own.

## Installation

Clone the repo:

```bash
git clone --recurse-submodules https://github.com/l50/dotfiles.git
```

## Dependencies

- [Install asdf](https://asdf-vm.com/):

  ```bash
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf
  ```

- Install and use asdf plugins to manage go and python for this project:

  ```bash
  source .asdf
  ```

  Alternatively, you can pick and choose which plugins to install:

  ```bash
  # Employ asdf for this project's python:
  source .asdf python
  ```

- [Install pre-commit](https://pre-commit.com/):

  ```bash
  python3 -m pip install --upgrade pip
  python3 -m pip install pre-commit
  ```

- [Install Mage](https://magefile.org/):

  ```bash
  go install github.com/magefile/mage@latest
  ```

### Debian Dependencies

```bash
sudo apt-get update
sudo apt-get install -y curl expect jq xclip zsh
# Fix permissions to avoid annoying message
sudo chmod -R 755 /usr/share/zsh
sudo chmod -R 755 /usr/share/zsh/vendor-completions
# If you need to change your shell manually, run this command:
sudo chsh -s /bin/zsh
curl -sS https://webi.sh/shfmt | sh
npm install -g bats
```

### MacOS Dependencies

```bash
# Install homebrew
brew install bats-core cask shfmt
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
# If it's necessary to test macOS specifically:
act -P macos-latest=-self-hosted
```

---

## Run bash tests

```bash
bash .hooks/run-bats-tests.sh
```

---

## Update submodules

```bash
git submodule update --init --recursive
```
