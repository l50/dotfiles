#!/bin/bash
# Retrieves Ansible Vault password from 1Password

# Return dummy password in CI environments or if op is not available
if [ -n "$CI" ] || ! command -v op &> /dev/null; then
    echo "dummy-vault-password-for-ci"
    exit 0
fi

op read "op://Automation/Ansible Vault/password"
