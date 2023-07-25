# Get helper func from setup_asdf.sh
# shellcheck source=/dev/null
source "${HOME}/.dotfiles/files/setup_asdf.sh"
source "$HOME/.asdf/asdf.sh"

# Define go version from global .tool-versions file
setup_language "golang" "global"

# Set and export environment variables
GOPATH=$(go env GOPATH)
GOROOT=$(go env GOROOT)
FILES="${HOME}/.dotfiles/files"

export GOPATH GOROOT FILES
export PATH=$PATH:$GOPATH/bin:$GOROOT/bin

# pull_repos updates all git repositories found in the given directory by pulling changes from the upstream branch.
# It looks for repositories by finding directories with a ".git" subdirectory.
# If a repository is not on the default branch, it will switch to the default branch before pulling changes.
#
# Usage:
#   pull_repos [dir]
#
# Example(s):
#   pull_repos
#   pull_repos .
#   pull_repos $PWD
pull_repos() {
    if [[ $# -eq 0 ]]
    then
        filepath="."

        goeval -i git=github.com/l50/goutils/v2/git@latest \
            'fmt.Println(git.PullRepos("'"${PWD}"'"))'
    else
        filepath="$1"
        pushd $filepath || return 1
        goeval -i git=github.com/l50/goutils/v2/git@latest \
            'fmt.Println(git.PullRepos("'"${PWD}"'"))'
        popd || return 1
    fi

    echo "All repositories successfully updated."
}

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
        goeval -i mageutils=github.com/l50/goutils/v2/dev/mage@latest \
            'funcs, _ := mageutils.FindExportedFunctionsInPackage("."); '\
            'for _, f := range funcs { fmt.Printf("Function: %s\nFile: %s\n", f.FuncName, f.FilePath) }'
    else
        echo "error: go.mod not found in specified directory or its parent directories"
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
#   get_missing_tests [filepath]
#
# Output:
#   If there are no missing unit tests, the function prints "All exported functions
#   have corresponding unit tests.". If there are missing unit tests, the function
#   prints "The following exported functions are missing unit tests:" followed by
#   the names of the missing functions.
#
# Example(s):
#   get_missing_tests $PWD
#   get_missing_tests ../somegopackage
#   get_missing_tests /Users/someuser/path/to/go/github/someowner/somegorepo
get_missing_tests() {

    if [[ $# -eq 0 ]]; then
        filepath="${PWD}"
    else
        filepath="$1"
    fi

    # Get the list of exported functions without corresponding tests
    missing=$(goeval -i mageutils=github.com/l50/goutils/v2/dev/mage@latest \
        "fmt.Println(mageutils.FindExportedFuncsWithoutTests(\"$filepath\"))")

    # Read into array
    IFS=$'\n' read -ra missing_tests <<< "$missing"

    # Print results
    if [ ${#missing_tests[@]} -eq 0 ]; then
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

# Get build path from executable
#
# Example: import-path godoc
# golang.org/x/tools/cmd/godoc
#
# https://forum.golangbridge.org/t/your-best-shell-aliases/1335/11
import_path() {
	[[ -z "$1" ]] && {
		echo "usage: import_path EXECUTABLE" >&2
		return 1
	}
	go tool objdump -s main.main "$(which $1)" |
		grep -E '^TEXT main.main' | cut -d' ' -f3 |
		sed -E -e 's/.\/src\/(.).*\/\1//'
}

### Mage Autocomplete ###
# This section will not run during a bats test.
if [[ $RUNNING_BATS_TEST != 1 ]]; then
    # The functions below are required for mage autocomplete
    _get_comp_words_by_ref() {
        # Some function body here. If you don't have one, use `:`
        :
    }
    __ltrim_colon_completions() {
        # Some function body here. If you don't have one, use `:`
        :
    }
    source "${FILES}/mage_completion.sh"
fi

add_cobra_init

# Install lf if it's not already installed
if ! command -v lf &> /dev/null; then
    env CGO_ENABLED=0 go install -ldflags="-s -w" github.com/gokcehan/lf@latest
fi
