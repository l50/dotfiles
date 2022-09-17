#!/bin/bash

if [[ -z $1 ]]; then
    echo "Usage: $0 <Name of APK>"
fi

APK_PATH="$(adb shell pm path "$1")"
echo "${APK_PATH#*:}"
APK_PATH=${APK_PATH#*:}
adb pull "${APK_PATH}"

# Make sure we successfully pulled down an APK before renaming it
if [[ -f base.apk ]]; then
    mv base.apk "${1}".apk
fi

# Open in JADX-GUI if you specify
if [[ "${2}" == "--jadx" ]] || [[ "${2}" == "-j" ]]; then
    "$(command -v jadx-gui) ${1}.apk"
fi
