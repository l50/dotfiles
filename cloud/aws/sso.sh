# shellcheck shell=bash

# Login to AWS SSO once for all profiles sharing the same sso-session.
#
# Usage:
#   aws-login
alias aws-login='aws sso login --sso-session organization-sso'
