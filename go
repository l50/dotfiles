if hash go 2>/dev/null; then
  export GOPATH=$HOME/programs/go
  export GOROOT=/usr/local/opt/go/libexec
  # Add go to PATH - so we can run executables from anywhere
  export PATH=$PATH:$GOPATH/bin
  export PATH=$PATH:$GOROOT/bin
  # Set bin directory for go executables
  export GOBIN=$HOME/programs/go/bin
fi