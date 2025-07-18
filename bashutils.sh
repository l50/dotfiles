#!/usr/bin/env bash
set -o pipefail

# The `process_terminator` function takes a process name as an argument
# and checks for the process's existence in the system. If it finds the process,
# it terminates it, hence the name 'process_terminator'. The function is case-insensitive
# meaning it can match and terminate processes regardless of how the process name case is written.
#
# Usage:
#   process_terminator [process_name]
#
# Output:
#   If the process was found and terminated, it outputs "Process [process_name] has been terminated.".
#   If no process was found with the given name, the function outputs "No processes found with the name: [process_name]".
#
# Example(s):
#   process_terminator "chrome"
#   process_terminator "python"
process_terminator() {
    if pgrep -i "$1" > /dev/null; then
        pkill -i "$1"
        echo "Process $1 has been terminated."
    else
        echo "No processes found with the name: $1"
    fi
}

# An abstraction to get content from various compressed files.
#
# Usage:
#   extract [file] [directory]
#
# Output:
#   Extracts the content of the specified compressed file.
#
# Example(s):
#   extract archive.tar.gz
extract() {
    if [ -f "$1" ]; then
        dir=${2:-.} # If no directory specified, use current directory
        case "$1" in
            *.tar.bz2) tar xvjf "$1" -C "$dir" ;;
            *.tar.gz) tar xvzf "$1" -C "$dir" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) rar x "$1" "$dir" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xvf "$1" -C "$dir" ;;
            *.tbz2) tar xvjf "$1" -C "$dir" ;;
            *.tgz) tar xvzf "$1" -C "$dir" ;;
            *.zip) unzip "$1" -d "$dir" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" -o"$dir" ;;
            *) echo "don't know how to extract '$1'..." ;;
        esac
    else
        echo "'$1' is not a valid file!"
    fi
}

# Determines the size of a file or total size of a directory.
#
# Usage:
#   fs [file|directory]
#
# Output:
#   Prints the size of the specified file or total size of the specified directory.
#
# Example(s):
#   fs myfile.txt
#   fs mydirectory
fs() {
    if du -b /dev/null > /dev/null 2>&1; then
        local arg=-sbh
    else
        local arg=-sh
    fi
    if [[ -n $* ]]; then
        for file in "$@"; do
            du "$arg" -- "./$file"
        done
    else
        du "$arg" ./*[^.]* -- *
    fi
}

# Changes the current directory to the root of the current Git repository.
#
# Usage:
#   repo_root
#
# Output:
#   Changes the current directory to the root of the current Git repository. If
#   the current directory is not part of a Git repository, prints an error message.
#
# Example(s):
#   # Example of using repo_root in a script to change directory to the repo root
#   repo_root
#
#   # Example of how to use repo_root in a one-liner to change directory to the repo root
#   wget -qO- https://raw.githubusercontent.com/l50/dotfiles/main/bashutils \
#     | source /dev/stdin \
#     && repo_root
#   # Returns to the original directory
repo_root() {
    local root
    root=$(git rev-parse --show-toplevel 2> /dev/null)
    if [[ -n "${root}" ]]; then
        cd "${root}" || exit 1
    else
        echo "Current directory is not part of a git repository."
        exit 1
    fi
}

# Add shorthand alternative to repo_root
rr() {
    repo_root "$@"
}

# Extracts only the comments from the contents of the specified file or from stdin.
# It supports extracting single-line comments that start with // or #, as
# well as multi-line comments that start with /* and end with */.
# The extracted comments are then printed to stdout, with each comment on a separate line.
#
# Usage:
#   onlycomments [file_path]
#   echo 'code with // comments' | onlycomments
#
# Output
#   Only the comments extracted from the file or stdin, with each comment on a separate line.
#
# Example(s):
#   onlycomments "file.go"
#   echo 'code with // comments' | onlycomments
onlycomments() {
    if [ $# -eq 0 ]; then
        grep -E '(//.*|/\*.*\*/|#.*)$'
    else
        file_path="$1"
        grep -E '(//.*|/\*.*\*/|#.*)$' "$file_path"
    fi
}

# The `nocomment` function processes input from stdin and removes
# comments. It supports stripping shell-style (#) and C++ style (//) single-line
# comments. Blank lines resulting from comment removal are also omitted.
# The output is sent to stdout.
#
# Usage:
#   nocomment
#   echo 'code with comments' | nocomment
#
# Output:
#   The input contents with all comments removed.
#
# Example(s):
#   nocomment < "script.sh"
#   echo 'code with // comments' | nocomment
nocomment() {
    sed -E '
        # Preserve variable blocks and their entire contents (including validation blocks)
        /^[[:space:]]*variable[[:space:]]+/,/^}/b

        # Remove comments and empty lines
        /^[[:space:]]*#/d
        /^[[:space:]]*$/d
        /^[[:space:]]*\/\//d
    '
}

# Installs oh-my-zsh if it's not already installed.
#
# Usage:
#   install_oh_my_zsh
install_oh_my_zsh() {
    # Check if oh-my-zsh is installed
    if [ ! -d "${HOME}/.oh-my-zsh" ]; then
        echo -e "${BLUE}Installing oh-my-zsh, please wait...${RESET}"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo -e "${YELLOW}oh-my-zsh is already installed.${RESET}"
    fi
}

# Returns a list of tmux sessions and the processes running in each pane.
#
# Usage:
#   tmux_sessions
#
# Output:
#   Prints the name of each tmux session and the processes running in each pane.
#
tmux_sessions() {
    for s in $(tmux list-sessions -F '#{session_name}'); do
        echo -e "\ntmux session name: $s\n--------------------"
        for p in $(tmux list-panes -s -F '#{pane_pid}' -t "$s"); do
            pstree -p -a "$p"
        done
    done
}

# Run tmux source-file ~/.tmux.conf on all panes
source_tmux_conf() {
    session=$(tmux display-message -p "#S")

    for pane in $(tmux list-panes -s -F "#{pane_id}"); do
        tmux send-keys -t "$session.$pane" "tmux source-file ~/.tmux.conf" C-m
    done
}

# Monitor ICMP traffic - great for OOB testing.
icmpMonitor() {
    tcpdump -i "$1" 'icmp and icmp[icmptype]=icmp-echo'
}

# get a line from a particular file
# input line number and file
# example: get_line 200 output.txt
get_line() {
    sed "$1q;d" "$2"
}

# Check spelling of markdown files in the current directory
spell-check-md() {
    for file in *.md; do
        aspell check --mode=markdown --lang=en "${file}"
    done
}

alias randommacaddrwifi="sudo spoof-mac randomize wi-fi"
alias diff="colordiff"

# Used to clone a web site - takes a website as the parameter
alias cloneSite="wget --mirror --convert-links --adjust-extension --page-requisites --no-parent"

# Get public IPv4 and IPv6
alias publicIP="echo 'IPv4:'; curl -4 icanhazip.com; echo 'IPv6:'; curl -6 icanhazip.com"

# If we are not on a macOS system
if [[ $(uname) != 'Darwin' ]]; then
    alias open="xdg-open"
    alias openPorts="netstat -ntlp | grep LISTEN"
    # Largest files in the current directory and below
    alias largestFilesAndFolders="du -Sh | sort -rh | head -5"
    alias totalDisk='fdisk -l | grep Disk'
    # Find alias with zsh
    if test "$(which zsh)"; then
        alias zshAliasLocation="PS4='+%x:%I>' zsh -i -x -c '' |& grep"
    fi
    alias l.='ls -d .* --color=auto'
fi

# Rsync Transfer
# Synchronizes files between two directories, with an optional exclusion list.
#
# Usage:
#   rsync_xfer [source_directory] [target_directory] [optional_exclude_pattern]
#
# Parameters:
#   source_directory: The directory from which files are transferred.
#   target_directory: The directory to which files are transferred.
#   optional_exclude_pattern: An optional pattern to exclude files or directories (e.g., '.git/').
#
# Output:
#   No output, but copies files from source directory to target directory, optionally excluding specified patterns.
#
# Example(s):
#   rsync_xfer "/path/to/src" "/path/to/dest"
#   rsync_xfer "/path/to/src" "/path/to/dest" ".git/"
rsync_xfer() {
    # Check if both directories exist
    if [[ -d "$1" ]] && [[ -d "$2" ]]; then
        # Set up the base rsync command
        local rsync_command="rsync -av"

        # If an exclude list is provided, append it to the rsync command
        if [[ -n "$3" ]]; then
            rsync_command+=" --exclude='$3'"
        fi

        # Execute the rsync command
        "$rsync_command" "$1/" "$2/"
        echo "Transfer from $1 to $2 complete."
    else
        echo "One or both directories do not exist. Please check the paths and try again."
    fi
}

# Get JSON Keys
# Fetches all the keys from a JSON file using jq.
#
# Usage:
#   getJSONKeys [json_file]
#
# Output:
#   Prints all the keys present in the JSON file.
#
# Example(s):
#   getJSONKeys "/path/to/jsonfile.json"
getJSONKeys() {
    jq 'keys' "$1"
}

# Get JSON Values
# Fetches all the values of array objects from a JSON file using jq.
#
# Usage:
#   getJSONValues [json_file]
#
# Output:
#   Prints all the values present in the JSON array objects.
#
# Example(s):
#   getJSONValues "/path/to/jsonfile.json"
getJSONValues() {
    jq '.[] | values' "$1"
}

# Downloads and installs a specific version of a tool from Github using the gh CLI tool or curl.
# The function fetches a binary tool from a GitHub releases page, filters releases based on the
# current system's architecture and OS, downloads the relevant release, extracts the downloaded
# archive, and moves the extracted binary to the specified destination directory (default: $HOME/.local/bin).
# Optionally, a GitHub token can be used if authenticated access is required.
#
# Usage:
#   fetchFromGithub [author] [repository_name] [version] [binary_name] [destination_directory]
#
# Output:
#   Downloads the relevant tool for the specified version, extracts the binary and moves it
#   to the specified destination directory or $HOME/.local/bin if not provided. Prints the success message and the name of the copied
#   file if the process was successful.
#
# Example(s):
#   fetchFromGithub "CowDogMoo" "Guacinator" "v1.0.0" "guacinator" # Downloads and installs v1.0.0 of the guacinator
#   fetchFromGithub "yourgithubname" "yourprivategithubrepo" "v0.0.1" "desiredbinname" "/custom/path" # Specifies a custom path for the binary
#
# Note:
#   The function requires jq and curl to be installed. The GITHUB_TOKEN environment variable can be set optionally for authenticated access.
#   If the function fails to find a relevant release for the system's OS and architecture, or if
#   the dependencies are not found, it will print an error message and return a non-zero status code.
fetchFromGithub() {
    AUTHOR="$1"
    REPO_NAME="$2"
    VERSION="$3"
    BIN_NAME="$4"
    DEST_DIR="${5:-$HOME/.local/bin}"

    # Ensure the destination directory exists
    mkdir -p "$DEST_DIR"

    os=$(uname | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    if [[ "$arch" == "x86_64" ]]; then arch="amd64"; fi
    if [[ "$arch" == "aarch64" ]]; then arch="arm64"; fi

    REPO="$AUTHOR/$REPO_NAME"

    # Check if curl is installed
    if ! command -v curl > /dev/null 2>&1; then
        echo "Error: curl is not installed. Please install curl and try again."
        return 1
    fi

    # Check if jq is installed
    if ! command -v jq > /dev/null 2>&1; then
        echo "Error: jq is not installed. Please install jq and try again."
        return 1
    fi

    if [[ -n "$GITHUB_TOKEN" ]] && command -v gh > /dev/null 2>&1; then
        echo "$GITHUB_TOKEN" | gh auth login --with-token
        if ! assets_json=$(gh release view "$VERSION" --repo "$REPO" --json assets); then
            echo "No relevant release found for OS: $os, architecture: $arch"
            return 1
        fi
        assets=$(echo "$assets_json" | jq -r '.assets[].name')
    else
        assets=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
            | jq -r '.assets[].browser_download_url')
    fi

    # Read assets into an array
    assets_array=()
    while IFS=$'\n' read -r line; do
        assets_array+=("$line")
    done <<< "$assets"

    # Flag to check if a matching asset was found
    asset_found=false
    # Iterate over the array and search for a match
    for asset in "${assets_array[@]}"; do
        if [[ $asset == *"$os"* && $asset == *"$arch"* ]]; then
            asset_found=true
            if [[ -n "$GITHUB_TOKEN" ]] && command -v gh > /dev/null 2>&1; then
                gh release download "$VERSION" --repo "$REPO" --pattern "$asset" -D "/tmp"
            else
                curl -sLo "/tmp/$(basename "$asset")" "$asset"
            fi
            echo "Download of $REPO_NAME release $VERSION from GitHub is complete."

            # Make sure the destination directory exists
            mkdir -p "$DEST_DIR"

            # Extract the tarball
            pushd "/tmp" || exit
            extract "$(basename "$asset")"

            # Only process the extracted files from the current asset
            for file in *; do
                if [[ "$file" == "$BIN_NAME" ]]; then
                    cp "$file" "$DEST_DIR/$BIN_NAME"
                    echo "Copied $file to $DEST_DIR/ as $BIN_NAME"
                    break # Exit the loop once the file is found and copied
                fi
            done
        fi
    done

    popd || exit
    if [ "$asset_found" = false ]; then
        echo "No relevant release found for OS: $os, architecture: $arch"
        return 1
    fi
}

# Checks if there is enough available disk space on the root partition.
# The function takes a required space value in megabytes as input and
# compares it with the available space. If there isn't enough space,
# it exits with an error.
#
# Usage:
#   check_disk_space [required_space_in_mb]
#
# Output:
#   If there isn't enough space, prints an error message and exits with status 1.
#   Otherwise, continues silently.
#
# Example(s):
#   check_disk_space 1000  # Check if 1GB space is available
#   check_disk_space 500   # Check if 500MB space is available
check_disk_space() {
    local required_space_mb="$1"
    local available_space_kb
    local available_space_mb

    if [[ -z "$required_space_mb" ]]; then
        echo "Error: Required space in MB must be provided"
        exit 1
    fi

    if ! [[ "$required_space_mb" =~ ^[0-9]+$ ]]; then
        echo "Error: Required space must be a positive integer"
        exit 1
    fi

    available_space_kb=$(df / | tail -1 | awk '{print $4}')
    available_space_mb=$((available_space_kb / 1024))

    if [[ "$available_space_mb" -lt "$required_space_mb" ]]; then
        echo "Error: Not enough disk space. Required: ${required_space_mb}MB, Available: ${available_space_mb}MB"
        exit 1
    fi
}

# Checks the permissions of the provided GitHub token by attempting to list the repositories of a user or an organization.
# A valid token will return a list of repositories in a JSON format, which are then printed to stdout.
# An invalid token will print "Invalid GitHub token." to stderr.
# A valid token with no repository access will print "No repositories found. The token might not have the necessary permissions." to stderr.
#
# Usage:
#   check_gh_token_perms [organization]
#
# Output:
#   Prints a list of repositories in JSON format to stdout, or an error message to stderr.
#
# Example(s):
#   check_gh_token_perms
#   check_gh_token_perms "some-organization"
#
# Note:
#   The function requires the GITHUB_TOKEN environment variable to be set and jq and curl to be installed.
#   If jq or curl is not installed, an error message will be printed to stderr and a non-zero status code will be returned.
check_gh_token_perms() {
    ORG=$1
    REQUIRED_TOOLS=("jq" "curl")
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            echo "Error: $tool is not installed. Please install $tool and try again." >&2
            return 1
        fi
    done

    [[ -z "$GITHUB_TOKEN" ]] && {
        echo "GITHUB_TOKEN is not set. Please set it and try again." >&2
        return 1
    }

    local endpoint=${ORG:-user}
    repos=$(curl -sH "Authorization: token $GITHUB_TOKEN" "https://api.github.com/${endpoint}/repos")

    case "$repos" in
        *'"message"'*"Bad credentials"*)
            echo "Invalid GitHub token." >&2
            return 1
            ;;
        *'"message"'*"Not Found"* | "")
            echo "No repositories found. The token might not have the necessary permissions." >&2
            return 1
            ;;
        *)
            echo "$repos" | jq -r .
            ;;
    esac
}

# Inspects the file type of the provided file and prints its contents to stdout if it's a text file.
# If the file is an image, it prints "Image file" to stdout.
# For binary or non-text files, it prints "Binary or non-text file" to stdout.
#
# Usage:
#   print_file_content [file]
#
# Output:
#   Prints the file path and its contents to stdout if it's a text file, or a message indicating the file type to stdout if it's an image or binary/non-text file.
#
# Example(s):
#   print_file_content "some-text-file.txt"
#   print_file_content "some-image-file.png"
#
# Note:
#   The function requires the `file` command to be available on the system to determine the file type.
#   If the `file` command is not available, the function may not behave as expected.
print_file_content() {
    local file
    file=$1

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    # Checking the file extension
    case "$file" in
        *.jpg | *.jpeg | *.png | *.gif | *.bmp | *.tiff)
            echo "$file: Image file"
            echo ""
            ;;
        *)
            # Getting MIME type of the file
            local mime_type
            mime_type=$(file --mime-type -b "$file")
            # Checking if the MIME type is text
            if [[ $mime_type == text/* ]]; then
                echo "$file:"
                echo ""
                echo "\`\`\`"
                while IFS= read -r line; do
                    echo "$line"
                done < "$file"
                echo "\`\`\`"
                echo ""
            else
                echo "$file: Binary or non-text file"
                echo ""
            fi
            ;;
    esac
}

# Processes a list of files from stdin and prints their contents using print_file_content function
#
# Usage:
#   some_command | process_and_print_files
#
# Example:
#   git diff --name-only <commit> | grep '\.yaml$' | process_and_print_files
process_and_print_files() {
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            print_file_content "$file"
        else
            echo "File not found: $file"
        fi
    done
}

# Process files based on patterns and print their contents
#
# Usage:
#   process_files <base_path> <exclude_patterns>
#
# Arguments:
#   base_path: The base path to search for files.
#   exclude_patterns: Patterns to exclude from the search.
#
# Output:
#   Processes files based on patterns and prints their contents.
#
# Example(s):
#   process_files "." "*.txt" "*.md"
process_files() {
    local base_path=$1
    shift                            # First argument is the base path, rest are patterns
    local -a exclude_patterns=("$@") # Array of patterns to exclude

    # Construct the find command using an array to properly handle spaces and special characters
    local -a find_command=(find "$base_path" -type f)

    # Add exclude patterns to the find command
    for pattern in "${exclude_patterns[@]}"; do
        find_command+=(! -path "$pattern")
    done

    # Execute the find command and check its exit status
    "${find_command[@]}" | while IFS= read -r file; do
        print_file_content "$file"
    done
}

# Checks if the input from stdin is a file path.
#
# Usage:
#   is_filepath
#
# Output:
#   Prints "Input is a file path." if the input is a file path,
#   or "Input is not a file path." otherwise.
#
# Example(s):
#   echo "/path/to/file" | is_filepath
#   cat filelist.txt | while read line; do echo "$line" | is_filepath; done
is_filepath() {
    while IFS= read -r input; do
        if [ -f "$input" ]; then
            echo "Input is a file path."
        else
            echo "Input is not a file path."
        fi
    done
}

# Reads file patterns from a configuration file and processes files
# matching those patterns. This function is designed to work with a
# config file where each line specifies a pattern of files to process.
#
# Usage:
#   process_files_from_config <config_file>
#
# Arguments:
#   config_file: Path to the configuration file containing file patterns.
#
# Output:
#   Processes files based on patterns specified in the config file and
#   pipes the output to 'nocomment' and then to 'pbcopy'.
#
# Example(s):
#   process_files_from_config "file_patterns.conf"
#
# Config File Format Example (file_patterns.conf):
#   ./.git/*
#   ./.hooks/*
#   ./.github/*
#   ./magefiles/*
#   ./changelogs/*
#   ./*.md
process_files_from_config() {
    local config_file="$1"
    local debug=false

    # Check if the config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Config file not found: $config_file"
        return 1
    fi

    if [[ "$debug" = true ]]; then
        echo "Debug: Reading config file: $config_file"
    fi
    local args=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        args+=("$line")
        if [[ "$debug" = true ]]; then
            echo "Debug: Config line: $line"
        fi
    done < "$config_file"

    if [[ "$debug" = true ]]; then
        echo "Debug: Processing files with patterns: ${args[*]}"
    fi

    if [[ $(uname) == 'Darwin' ]]; then
        process_files "." "${args[@]}" | nocomment | pbcopy
    else
        if command -v xclip > /dev/null 2>&1; then
            process_files "." "${args[@]}" | nocomment | xclip -selection clipboard
        else
            echo "xclip is not installed. Please install xclip and try again."
            return 1
        fi
    fi
}

# Checks the authentication status and token permissions associated with the GitHub CLI (gh).
# It uses the `gh auth status` command to retrieve the authentication status
# and the token permissions. If the GH_TOKEN is not set, it prints a reminder
# to set the token and returns with a non-zero status code. This function
# requires the GH_TOKEN environment variable to be set and uses the
# `gh auth status` command to retrieve the token information.
# The function checks for the presence of the GitHub CLI (gh) and ensures it's
# installed before attempting to check the token status.
#
# Usage:
#   gh_token_perms
#
# Output:
#   Prints the authentication status and the list of scopes associated
#   with the GH_TOKEN to stdout, or an error message to stderr if the
#   GitHub CLI is not installed or GH_TOKEN is not set.
#
# Example(s):
#   gh_token_perms
#
# Note:
#   Ensure that the GH_TOKEN environment variable is correctly set and the
#   GitHub CLI (gh) is installed before calling this function.
gh_token_perms() {
    if [[ -z "$GH_TOKEN" ]]; then
        echo "GH_TOKEN is not set. Please set it and try again."
        return 1
    fi

    # Check if curl is installed
    if ! command -v gh > /dev/null 2>&1; then
        echo "Error: gh is not installed. Please install gh cli and try again."
        return 1
    fi

    gh auth status --show-token
}

# Create a zip file containing only files with a specific extension from a directory.
#
# Usage:
#   create_zip_with_extension [directory] [zipfile] [extension]
#
# Parameters:
#   directory: The directory containing files to be zipped.
#   zipfile: The name of the zip file to be created.
#   extension: The file extension to filter files by.
#
# Output:
#   Creates a zip file containing only files with the specified extension from the directory.
#
# Example(s):
#   create_zip_with_extension "/path/to/directory" "files.zip" "go"
create_zip_with_extension() {
    local DIRECTORY="$1"
    local ZIPFILE="$2"
    local EXTENSION="$3"

    # Validate input
    if [ -z "$DIRECTORY" ] || [ -z "$ZIPFILE" ] || [ -z "$EXTENSION" ]; then
        echo "Error: Missing arguments. Usage: create_zip_with_extension [directory] [zipfile] [extension]"
        return 1
    fi

    # Check if directory exists
    if [ ! -d "$DIRECTORY" ]; then
        echo "Error: Directory '$DIRECTORY' does not exist."
        return 1
    fi

    # Create the zip file with only files of the specified extension
    if ! find "$DIRECTORY" -type f -name "*.${EXTENSION}" | zip -@ "$ZIPFILE"; then
        echo "Error: Failed to create zip file '$ZIPFILE'."
        return 1
    fi

    echo "Created '$ZIPFILE' containing ${EXTENSION} files from '$DIRECTORY'."
}

# Split a git diff output into separate files, each with at most 500 lines.
#
# Usage:
#   git_diff_split
#
# Output:
#   Creates n files named git_diff_part_{0..n-1}.diff containing the split diff output.
#
# Example(s):
#   git_diff_split
#
# Note:
#   Ensure that you are in a git repository and have made changes to split.
git_diff_split() {
    # Run the git diff command and get the output as a string
    local diff_output
    diff_output=$(git diff 1.9.1)

    # Split the diff output into chunks of 500 lines each and write them to files
    echo "$diff_output" | split -l 500 - "git_diff_part_"

    # Rename the output files to .diff
    for file in git_diff_part_*; do
        mv "$file" "${file}.diff"
    done

    echo "Files generated:" git_diff_part_*.diff
}

# Lists files with specified extensions changed in a specific commit.
#
# Usage:
#   process_files_in_commit <commit> <extensions...>
#
# Arguments:
#   commit: The commit hash or reference.
#   extensions: One or more file extensions (e.g., '*.yaml' '*.yml').
#
# Output:
#   Prints the names of files with specified extensions changed in the specified commit.
#
# Example(s):
#   process_files_in_commit 47d0835bb58af3b5598df329b2d8039db7944888 '*.yaml' '*.yml'
process_files_in_commit() {
    local commit="$1"
    shift
    local extensions=("$@")

    if [[ -z "$commit" || ${#extensions[@]} -eq 0 ]]; then
        echo "Usage: process_files_in_commit <commit> <extensions...>" >&2
        echo "Example: process_files_in_commit 47d0835bb58af3b5598df329b2d8039db7944888 '*.yaml' '*.yml'" >&2
        return 1
    fi

    # Build the grep pattern from the wildcard patterns
    local grep_pattern=""
    for ext in "${extensions[@]}"; do
        # Remove the leading asterisk if present
        ext="${ext#\*}"
        # Escape dots in the extension
        ext="${ext//./\\.}"
        grep_pattern="${grep_pattern:+$grep_pattern|}${ext}$"
    done

    # Use git show to list files changed in the specified commit and filter with grep
    git show --name-only --pretty="" "$commit" | grep "\.$grep_pattern"
}

alias networkedComputers="arp -a |grep -oP '\d+\.\d+\.\d+\.\d+'"

# If gshuf and cowsay are installed, then evolve our vocab with cowsay
# https://www.quora.com/What-is-the-most-interesting-shell-script-you-have-ever-written
if hash cowsay 2> /dev/null && hash gshuf 2> /dev/null; then
    gshuf -n 1 "$HOME/.dotfiles/files/gre" | cowsay
fi

# Set alias for nmap if it's installed
# https://github.com/hriesco/dotfiles/blob/master/.aliases
if hash nmap 2> /dev/null; then
    alias nmap="nmap --reason --open --stats-every 3m --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit"
fi

alias ipaddr="ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'"

# Create Claude friendly variables to avoid copy-paste hell
alias claudyvars="sed 's/{{\./{./g; s/}}/}/g'"
