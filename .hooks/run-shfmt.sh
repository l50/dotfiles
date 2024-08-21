#!/bin/bash
set -ex

# Ensure the script respects the editorconfig settings
for file in "$@"; do
    shfmt -i 4 -bn -ci -sr -kp -w "$file"
done
