#!/usr/bin/env bash

# Functions for working with Android devices
autoapk() {
    if ! command -v adb > /dev/null 2>&1; then
        echo "Error: adb not found in PATH"
        return 1
    fi
    bash "${HOME}/.android_sec_tools/autoapk.sh"
}

start_app() {
    if ! command -v adb > /dev/null 2>&1; then
        echo "Error: adb not found in PATH"
        return 1
    fi
    bash "${HOME}/.android_sec_tools/start_app.sh"
}

adbpkgs() {
    if ! command -v adb > /dev/null 2>&1; then
        echo "Error: adb not found in PATH"
        return 1
    fi
    adb shell pm list packages | awk -F':' '{print $2}'
}
