#!/bin/bash
set -ex

# Loop through all arguments
for file in "$@"; do
    # Skip files in the tests directory
    if [[ $file != tests/* ]]; then
        shfmt -i 4 -bn -ci -sr -kp -fn -w "$file"
    else
        echo "Skipping formatting for $file"
    fi
done
