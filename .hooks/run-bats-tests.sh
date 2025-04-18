#!/bin/bash
set -eo pipefail

# Set TERM variable to avoid errors
export TERM=xterm

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Run bats with pretty formatter and real-time output
bats --formatter pretty "tests/"*.bats | while IFS= read -r line; do
    if [[ $line =~ ^not\ ok ]]; then
        echo -e "${RED}${line}${NC}"
    elif [[ $line =~ ^ok ]]; then
        echo -e "${GREEN}${line}${NC}"
    elif [[ $line =~ ^#.*failed ]]; then
        echo -e "${RED}${line}${NC}"
    else
        echo "$line"
    fi
done

# Get the test exit code
exit "${PIPESTATUS[0]}"
