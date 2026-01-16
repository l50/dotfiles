#!/bin/bash
# Retrieves Ansible Vault password from 1Password

# Skip in CI environments or if op is not available
if [ -n "$CI" ] || ! command -v op &> /dev/null; then
    exit 0
fi

op read "op://Automation/Ansible Vault/password"
