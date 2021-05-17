if hash go 2>/dev/null; then
  GVM_BIN=$HOME/.gvm/scripts/gvm
  export GOPATH=$HOME/programs/go
  if [[ ! -f $GVM_BIN ]]; then
    # Install gvm if it isn't installed
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    source $GVM_BIN
    gvm install go1.16.4
  fi
  source $GVM_BIN
  gvm use go1.16.4 --default
  # Add go to PATH - so we can run executables from anywhere
  export PATH="$PATH:${GOPATH}/bin"
fi
