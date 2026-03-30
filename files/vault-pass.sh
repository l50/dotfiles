#!/bin/bash
# Retrieves Ansible Vault password from 1Password

# Return dummy password in CI environments or if op is not available
if [ -n "$CI" ] || ! command -v op &> /dev/null; then
    echo "dummy-vault-password-for-ci"
    exit 0
fi

# Skip op when called from ansible-lint to avoid approval prompts
_pid=$$
while [ "$_pid" -gt 1 ]; do
    _pid=$(ps -o ppid= -p "$_pid" 2> /dev/null | tr -d ' ')
    [ -z "$_pid" ] && break
    if ps -o args= -p "$_pid" 2> /dev/null | grep -q 'ansible-lint\|ansible\.lint'; then
        echo "dummy-vault-password-for-lint"
        exit 0
    fi
done

op read "op://Automation/Ansible Vault/password"
