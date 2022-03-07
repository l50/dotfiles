#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# start_apk.sh
#
# Start an APIK
#
# Usage: bash start_apk.sh
#
# Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------
# Stop execution of script if an error occurs
set -e

if [[ -z "${1}" ]]; then
	echo "Usage: ${0} <Name of APK to start>"
fi
adb shell am start -n "${1}"
