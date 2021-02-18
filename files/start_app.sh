if [[ -z $1 ]]; then
    echo "Usage: $0 <Name of APK to start>"
fi
adb shell am start -n $1
