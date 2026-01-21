#!/usr/bin/env bash

# Functions for working with Android devices

# Run the autoapk helper script if adb is available.
#
# Usage:
#   autoapk
#
# Output:
#   Runs ~/.android_sec_tools/autoapk.sh or prints an error if adb is missing.
#
# Example(s):
#   autoapk
autoapk() {
    if ! command -v adb > /dev/null 2>&1; then
        echo "Error: adb not found in PATH"
        return 1
    fi
    bash "${HOME}/.android_sec_tools/autoapk.sh"
}

# Run the start_app helper script if adb is available.
#
# Usage:
#   start_app
#
# Output:
#   Runs ~/.android_sec_tools/start_app.sh or prints an error if adb is missing.
#
# Example(s):
#   start_app
start_app() {
    if ! command -v adb > /dev/null 2>&1; then
        echo "Error: adb not found in PATH"
        return 1
    fi
    bash "${HOME}/.android_sec_tools/start_app.sh"
}

# List installed package names from the connected device.
#
# Usage:
#   adbpkgs
#
# Output:
#   Prints package names, one per line.
#
# Example(s):
#   adbpkgs
adbpkgs() {
    if ! command -v adb > /dev/null 2>&1; then
        echo "Error: adb not found in PATH"
        return 1
    fi
    adb shell pm list packages | awk -F':' '{print $2}'
}
