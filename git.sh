#!/usr/bin/env bash

# check_fabric() verifies that the fabric tool is installed and available.
#
# Usage:
#   check_fabric
#
# Output:
#   Returns 0 if fabric is installed, exits with error message if not.
#
# Example:
#   check_fabric
check_fabric() {
    if ! command -v fabric &> /dev/null; then
        echo "error: fabric is not installed"
        echo "install it from: https://github.com/danielmiessler/fabric"
        return 1
    fi
}

# fabric_commit() generates a commit message using fabric AI and commits
# the staged changes, then pushes to remote.
#
# Usage:
#   fabric_commit
#
# Output:
#   Commits staged changes with an AI-generated commit message and pushes to remote.
#
# Example:
#   fabric_commit
#
# Note:
#   Requires git alias 'ds' and the fabric tool to be installed.
fabric_commit() {
    check_fabric || return 1
    git ds | fabric --pattern commit | ~/.config/fabric/patterns/commit/filter.sh | git commit --cleanup=verbatim -F - && git push
}

# gh_cancel() cancels a GitHub workflow run by ID, or the most recent run.
#
# Usage:
#   gh_cancel [RUN_ID]
#
# Arguments:
#   RUN_ID - Optional workflow run ID to cancel. If omitted, cancels the most recent run.
#
# Example:
#   gh_cancel 20865803201
#   gh_cancel  # cancels the most recent run
gh_cancel() {
    if [ -n "$1" ]; then
        gh run cancel "$1"
    else
        local run_id
        run_id=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
        if [ -n "$run_id" ]; then
            echo "Canceling most recent run: $run_id"
            gh run cancel "$run_id"
        else
            echo "No runs found"
            return 1
        fi
    fi
}

# gh_trigger() triggers a GitHub workflow on the current branch.
#
# Usage:
#   gh_trigger WORKFLOW_NAME
#
# Arguments:
#   WORKFLOW_NAME - Name or filename of the workflow to trigger
#
# Example:
#   gh_trigger "Build and Push Templates"
#   gh_trigger build-and-push-templates.yaml
gh_trigger() {
    if [ -z "$1" ]; then
        echo "Usage: gh_trigger WORKFLOW_NAME"
        return 1
    fi

    local branch
    local repo
    branch=$(git branch --show-current)
    repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

    echo "Triggering workflow '$1' on branch '$branch' in repo '$repo'"
    gh workflow run "$1" --repo "$repo" --ref "$branch"
}

# gh_runs() lists GitHub workflow runs.
#
# Usage:
#   gh_runs [WORKFLOW_NAME]
#
# Arguments:
#   WORKFLOW_NAME - Optional workflow name or filename to filter by
#
# Example:
#   gh_runs
#   gh_runs "Build and Push Templates"
#   gh_runs build-and-push-templates.yaml
gh_runs() {
    if [ -n "$1" ]; then
        gh run list --workflow="$1"
    else
        gh run list
    fi
}

# gh_restart() cancels the most recent run and triggers a new one.
#
# Usage:
#   gh_restart WORKFLOW_NAME
#
# Arguments:
#   WORKFLOW_NAME - Name or filename of the workflow to restart
#
# Example:
#   gh_restart "Build and Push Templates"
gh_restart() {
    if [ -z "$1" ]; then
        echo "Usage: gh_restart WORKFLOW_NAME"
        return 1
    fi

    echo "Looking for most recent run of '$1'..."
    local run_id
    run_id=$(gh run list --workflow="$1" --limit 1 --json databaseId --jq '.[0].databaseId')

    if [ -n "$run_id" ]; then
        echo "Canceling run: $run_id"
        gh run cancel "$run_id"
        sleep 2
    fi

    gh_trigger "$1"
}
