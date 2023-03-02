export FILES="${HOME}/.dotfiles/files"

# Get all exported functions in the current go project
get_exported_go_funcs() {
    find . -name "*.go" | \
    xargs grep -E -o 'func [A-Z][a-zA-Z0-9_]+\(' | \
    grep -v '_test.go' | \
    grep -v -E 'func [A-Z][a-zA-Z0-9_]+Test\(' | \
    sed -e 's/func //' -e 's/(//' | \
    awk -F: '{printf "Function: %s\nFile: %s\n", $2, $1}'
}

# Add Cobra init adds a cobra init file
# for the system to $COB_CONF_PATH
add_cobra_init() {
	COB_CONF_PATH="${HOME}/.cobra.yaml"
	if [[ ! -f "${COB_CONF_PATH}" ]]; then
		cp "${FILES}/cobra.yaml" \
			"${COB_CONF_PATH}"
	fi
}

# go_create creates a project
# with the input param.
#
# This involves configuring
# go mod, pre-commit, github actions,
# and setting up a basic mage file.
go_create() {
	PROJECT_NAME="${1}"

	if [[ -z "${PROJECT_NAME}" ]]; then
		echo "Usage: $0 projectName"
		return
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

# Get build path from executable
#
# Example: import-path godoc
# golang.org/x/tools/cmd/godoc
#
# https://forum.golangbridge.org/t/your-best-shell-aliases/1335/11
import-path() {
	[[ -z "$1" ]] && {
		echo "usage: import-path EXECUTABLE" >&2
		return 1
	}
	go tool objdump -s main.main "$(which $1)" |
		grep -E '^TEXT main.main' | cut -d' ' -f3 |
		sed -e 's/./src/(.)/[^\/]*/\1/'
}

### For mage completion
# https://github.com/magefile/mage/issues/113
_get_comp_words_by_ref() {
}
__ltrim_colon_completions() {
}
source "${FILES}/mage_completion.sh"

### Install go with GVM
#
# Note that this needs a base version
# of go needs to be installed on the system
# for this to work.
if hash go 2>/dev/null; then
	GO_VER='1.19.2'
	GVM_BIN="${HOME}/.gvm/scripts/gvm"
	if [[ ! -f "${GVM_BIN}" ]]; then
		# Install gvm if it isn't installed
		bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
		source "${GVM_BIN}"
		gvm install "go${GO_VER}"
	fi
	source "${GVM_BIN}"
	gvm use "go${GO_VER}" --default
	# Add go to PATH - so we can run executables from anywhere
	export PATH="${PATH}:${GOPATH}/bin"
fi

add_cobra_init
