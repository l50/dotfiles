#!/bin/bash
set -ex

# Loop through all arguments
for file in "$@"; do
    shfmt -i 4 -bn -ci -sr -kp -w "$file"
done
