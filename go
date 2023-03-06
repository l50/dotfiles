export FILES="${HOME}/.dotfiles/files"

# get_exported_go_funcs prints a list of all exported functions in the current Go project.
#
# This function uses the Gosh tool to execute a Go one-liner that imports the
# goutils package and calls the FindExportedFunctionsInPackage function on the
# current project directory. It then loops through the results and prints each
# function name and file path.
#
# Usage:
#   get_exported_go_funcs [filepath]
#
# Example(s):
#   get_exported_go_funcs $PWD
#   get_exported_go_funcs ../somegopackage
#   get_exported_go_funcs /Users/someuser/path/to/go/github/someowner/somegorepo
get_exported_go_funcs () {
    if [[ $# -eq 0 ]]
    then
        filepath="."
    else
        filepath="$1"
    fi
    while [[ ! -e "$filepath/go.mod" && "$filepath" != "/" ]]
    do
        filepath="$(dirname "$filepath")"
    done
    if [[ -e "$filepath/go.mod" ]]
    then
        package_path="$(grep -E "^module " "$filepath/go.mod" | awk '{ print $2 }')"
    fi
    current_dir="$(pwd)"
    cd "$filepath" || return 1
    if [[ -n "$package_path" ]]
    then
        goeval -i .=github.com/l50/goutils@v1.2.1 -i github.com/l50/goutils 'funcs, _ := utils.FindExportedFunctionsInPackage("."); for _, f := range funcs { fmt.Printf("Function: %s\nFile: %s\n", f.FuncName, f.FilePath) }'
    else
        echo "Error: go.mod not found in specified directory or its parent directories"
    fi
    cd "$current_dir" || return 1
}

# get_missing_tests() function checks the exported functions in a Go project and
# prints out the names of any exported function that does not have a corresponding
# unit test defined. It uses the `get_exported_go_funcs()` function to obtain a list
# of all exported functions in the project, then looks for unit tests whose names
# match the expected pattern. The function excludes any function whose name contains
# the word "Test" to avoid including test functions themselves in the output.
#
# Usage:
#   get_missing_tests
#
# Output:
#   If there are no missing unit tests, the function prints "All exported functions
#   have corresponding unit tests.". If there are missing unit tests, the function
#   prints "The following exported functions are missing unit tests:" followed by
#   the names of the missing functions.
get_missing_tests() {
    funcs=($(get_exported_go_funcs $1 | awk '{print $2}' | sort -u))
    missing_tests=()
    for func_name in "${funcs[@]}"
    do
        if ! grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -rnw . -e "^func Test${func_name}" | grep -v -E '^./.*_test.go:.*func Test'
        then
            missing_tests+=("$func_name")
        fi
    done
    if [ ${#missing_tests[@]} -eq 0 ]
    then
        echo "All exported functions have corresponding unit tests."
    else
        echo "The following exported functions are missing unit tests:"
        printf "%s\n" "${missing_tests[@]}"
    fi
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
