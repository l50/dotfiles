# If rvm is installed, add RVM to PATH for scripting.
if hash rvm 2>/dev/null; then
  export PATH="$PATH:$HOME/.rvm/bin"
fi
