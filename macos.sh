#!/usr/bin/env bash

# sanitize() replaces all provided strings found in the clipboard
# contents with random strings that have the same length.
#
# Usage:
#   sanitize [file_path] [function_name_1] [function_name_2] ...
#   echo 'code with function names to sanitize' | sanitize [function_name_1] [function_name_2] ...
#
# Output:
#   The contents of the file or stdin with specified function names replaced by random strings.
#
# Example(s):
#   sanitize "sysutils.go" "CheckRoot" "timeout" "gopsutil"
#   echo 'code with function names func1 and func2' | sanitize "func1" "func2"
sanitize() {
    # Check if the first argument is a file
    if [ -f "$1" ]; then
        file_path="$1"
        input="$(cat "$file_path")"
        shift
    else
        input="$(cat)"
    fi

    # Loop through arguments and replace wildcard entries with a random string
    for func_name in "$@"; do
        # Generate random string
        random=$(< /dev/urandom tr -dc 'A-Za-z' | head -c ${#func_name})

        # Replace all occurrences of the function name with the random string
        input=$(echo "$input" | gsed "s/\<$func_name\>/$random/gI")
    done

    # Print modified input to stdout
    echo "$input"
}

# Attaches to a running process with the specified PID and traces the write
# system calls made by the process. In a testing environment, it utilizes a
# mock script to simulate the behavior of the lldb debugger, setting a
# breakpoint on the write system call, and then resumes the process execution.
# When a write system call is made by the process, the mock script will simulate
# the halting of the process and display of the details of the call. This can be
# useful for debugging or monitoring the write operations of a process in real-time.
#
# Usage:
#   trace_write <PID>
#
# Arguments:
#   PID: The Process ID of the target process to trace.
#
# Example:
#   trace_write 12345
#
# Output:
#   In a testing environment, displays mock LLDB messages related to the `write`
#   system calls made by the specified process.
#
# Note:
#   This function does not exactly replicate the behavior of strace but provides
#   similar functionality for tracing write system calls. In a testing environment,
#   a mock script is used instead of the actual lldb debugger. The mock script will
#   simulate the behavior of lldb based on the input commands. To ensure accurate
#   testing, ensure the PATH environment variable includes the directory of the mock
#   script.
trace_write() {
    PID=$1
    PATH="./tests:$PATH" ./tests/scripts/mock_lldb.sh -p "${PID}" << EOF
b write
run
EOF
}

# join_wifi attempts to join an input $SSID
# using the specified $PW.
# Resource: https://www.mattcrampton.com/blog/managing_wifi_connections_using_the_mac_osx_terminal_command_line/
join_wifi() {
    SSID=$1
    PW=$2
    if [[ -n $SSID && -n $PW ]]; then
        networksetup -setairportnetwork en0 "$SSID" "$PW"
    else
        echo "error: you must provide an SSID and PW"
        echo "example: join_wifi somessid somepassword"
    fi
}

# largest_files() finds the largest files in the current directory
# and its subdirectories, sorted by size (largest first).
#
# Usage:
#   largest_files [directory] [count] [min_size]
#
# Arguments:
#   directory  - Directory to search (default: current directory)
#   count      - Number of results to show (default: 20)
#   min_size   - Minimum file size in MB (default: 10)
#
# Output:
#   The largest files sorted by size with human-readable sizes.
#
# Example(s):
#   largest_files                    # Top 20 files >= 10MB in current dir
#   largest_files /Users/username    # Top 20 files >= 10MB in specified dir
#   largest_files . 50               # Top 50 files >= 10MB
#   largest_files . 50 100           # Top 50 files >= 100MB
largest_files() {
    local dir="${1:-.}"
    local count="${2:-20}"
    local min_size="${3:-10}"

    # Use find with -ls to get size info, sort numerically by size (7th column),
    # then format output with awk. Much faster than spawning shells per file.
    find "$dir" -type f -size +"${min_size}M" -ls 2> /dev/null \
        | sort -k7 -rn \
        | head -n "$count" \
        | awk '{
            size = $7;
            # Convert bytes to human-readable format
            if (size >= 1073741824) printf "%.1fG", size/1073741824;
            else if (size >= 1048576) printf "%.1fM", size/1048576;
            else if (size >= 1024) printf "%.1fK", size/1024;
            else printf "%dB", size;
            # Print the file path (everything from column 11 onwards)
            printf " ";
            for (i=11; i<=NF; i++) printf "%s%s", $i, (i<NF ? " " : "\n");
        }'
}

# gw() gets the default gateway.
#
# Usage:
#   gw
#
# Output:
#   The default gateway.
gw() {
    route -n get default | grep gateway | awk '{print $2}'
}

# WiFi utils
alias wifils='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport scan'
alias wifidown='networksetup -setairportpower en0 off'
alias wifiup='networksetup -setairportpower en0 on'

alias remountSD='sudo kextunload -b com.apple.driver.AppleSDXC; sudo kextload -b com.apple.driver.AppleSDXC'
alias leaving="guard-my-macbook-when-i-am-away"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

alias updatebrew='brew update && brew upgrade && brew cleanup && brew doctor'

# Start postgres locally
alias pgstart='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
# Stop postgres locally
alias pgstop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

alias openPorts='sudo lsof -iTCP -sTCP:LISTEN -n -P'

# Show accurate APFS disk space (container-level, not per-volume)
alias diskspace="diskutil info / | grep -E 'Container Total Space|Container Free Space'"

# Enable aliases to be sudo'ed
alias sudo='sudo '

# Lock the screen (when going AFK)
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

alias update='sudo softwareupdate -ia; brew update; brew upgrade; brew cleanup'

# Recursively delete .DS_Store files
alias dsCleanup.="find . -type f -name '*.DS_Store' -ls -delete"

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash='sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv "$HOME"/.Trash; sudo rm -rfv /private/var/log/asl/*.asl'

# Show/hide hidden files in Finder
alias showHiddenFinder="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hideHiddenFinder="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# Flush Directory Service cache
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# Colorized output, descending results by date last accessed, add symbols to directories, executables, symlinks, etc.
alias ls='ls -lartGF'

# Insecure Chrome for security testing
alias chromeInsecure="'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --disable-xss-auditor --enable-devtools-experiments --disable-features=enable-automatic-password-saving --disable-web-security"

# chrome_devtools() activates Google Chrome and opens the Developer Tools
# using the Command + Option + I keyboard shortcut.
#
# Usage:
#   chrome_devtools
#
# Output:
#   Opens Chrome Developer Tools in the active Chrome window.
#
# Example:
#   chrome_devtools
chrome_devtools() {
    osascript -e 'tell application "Google Chrome" to activate' \
        && osascript -e 'tell application "System Events" to keystroke "i" using {command down, option down}'
}

alias firefox="open -a /Applications/Firefox.app"

# Use GNU grep
if [[ -f '/usr/local/bin/ggrep' ]]; then
    alias grep='/usr/local/bin/ggrep'
fi

# Restart the SSH service
alias restart-ssh='sudo systemsetup -setremotelogin off; sudo systemsetup -setremotelogin on'

# # Docker completion for macOS
# if uname -a | grep -qi arm; then
#     FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
# else
#     source "/usr/local/share/zsh/site-functions"
# fi
