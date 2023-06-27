# Get helper func from setup_asdf.sh
# shellcheck source=/dev/null
source "${HOME}/.dotfiles/files/setup_asdf.sh"
# Define ruby version from global .tool-versions file
setup_language "ruby" "global"
