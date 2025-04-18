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
# and its subdirectories.
#
# Usage:
#   largest_files [directory]
#
# Output:
#   The largest files in the current directory and its subdirectories.
#
# Example(s):
#   largest_files
#   largest_files /Users/username
#
# Resource:
#   https://www.fonepaw.com/eraser/find-large-files-mac.html
largest_files() {
    if [ -z "$1" ]; then
        find . -type f -size +100000k -exec sh -c 'ls -lh "$1" | awk "{ print \$9 \": \" \$5 }"' sh {} \;
    else
        find "$1" -type f -size +100000k -exec sh -c 'ls -lh "$1" | awk "{ print \$9 \": \" \$5 }"' sh {} \;
    fi
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

# Enable aliases to be sudo’ed
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
