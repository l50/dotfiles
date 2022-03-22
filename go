go_create() {
  PROJECT_NAME="${1}"
  FILES="${HOME}/.dotfiles/files"

  if [[ -z "${PROJECT_NAME}" ]]; then
    echo "Usage: $0 projectName"
    exit 1
  fi

  mkdir "${PROJECT_NAME}"
  pushd "${PROJECT_NAME}"
    PROJECT_PATH="$(pwd | grep -oE 'github.*')"
    git init -b main
    go mod init "${PROJECT_PATH}"
    cp -r "${FILES}"/{.pre-commit-config.yaml,.hooks,.github} .
    pre-commit autoupdate
    pre-commit install

    if hash mage 2>/dev/null; then
      mage -init
    fi
  popd
}

if hash go 2>/dev/null; then
  GO_VER=1.18
  GVM_BIN=$HOME/.gvm/scripts/gvm
  export GOPATH=$HOME/programs/go
  if [[ ! -f $GVM_BIN ]]; then
    # Install gvm if it isn't installed
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source $GVM_BIN
    gvm install "go${GO_VER}"
  fi
  source $GVM_BIN
  gvm use "go${GO_VER}" --default
  # Add go to PATH - so we can run executables from anywhere
  export PATH="$PATH:${GOPATH}/bin"
fi
