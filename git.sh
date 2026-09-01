#!/usr/bin/env bash

# pull_repos updates all git repositories found in the given directory by pulling
# changes from the upstream branch using fast-forward only.
#
# Usage:
#   pull_repos [dir]
#
# Example(s):
#   pull_repos
#   pull_repos .
#   pull_repos ~/projects
pull_repos() {
    if ! command -v fd &> /dev/null; then
        echo "error: fd is not installed"
        echo "install it from: https://github.com/sharkdp/fd"
        return 1
    fi
    fd -H -t d '^\.git$' "${1:-.}" -x git -C '{//}' pull --ff-only
    echo "All repositories successfully updated."
}

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

# git_push_remote() prints the remote the current branch should be pushed to,
# preferring the branch's own pushRemote, then remote.pushDefault, then origin.
#
# Usage:
#   git_push_remote
#
# Output:
#   A remote name, defaulting to "origin".
#
# Example:
#   git push -u "$(git_push_remote)" HEAD
#
# Note:
#   In a fork, origin usually points at the read-only upstream and pushes go to
#   the fork remote, so hardcoding origin makes every push fail with a 403. Set
#   the target once per repo with "git config remote.pushDefault <remote>".
git_push_remote() {
    local branch remote
    branch=$(git branch --show-current)
    if [ -n "$branch" ]; then
        remote=$(git config --get "branch.${branch}.pushRemote")
    fi
    [ -n "$remote" ] || remote=$(git config --get remote.pushDefault)
    printf '%s\n' "${remote:-origin}"
}

# git_remote_for_repo() prints the local remote whose URL points at the given
# GitHub <owner>/<name>, defaulting to origin when nothing matches.
#
# Usage:
#   git_remote_for_repo l50/dotfiles
#
# Output:
#   A remote name, defaulting to "origin".
#
# Example:
#   git diff "$(git_remote_for_repo "$(gh repo view --json nameWithOwner --jq .nameWithOwner)")/main...HEAD"
#
# Note:
#   Used to pick a diff base matching the repo a PR is opened against. That is normally
#   origin, but "gh repo set-default" can aim PRs at a fork instead, in which case
#   origin's copy of the base branch is the stale one.
git_remote_for_repo() {
    local repo=$1 remote url
    if [ -n "$repo" ]; then
        # Remote names cannot contain whitespace, so word splitting is safe here.
        # shellcheck disable=SC2013
        for remote in $(git remote); do
            url=$(git remote get-url "$remote" 2> /dev/null) || continue
            case "${url%.git}" in
                *[:/]"$repo")
                    printf '%s\n' "$remote"
                    return
                    ;;
            esac
        done
    fi
    printf '%s\n' "origin"
}

# git_base_branch() prints the branch a new PR from the current branch should
# target, resolved from the repo gh opens PRs against.
#
# Usage:
#   git_base_branch
#
# Output:
#   A branch name, defaulting to "main".
#
# Example:
#   git diff "origin/$(git_base_branch)...HEAD"
#
# Note:
#   Hardcoding main breaks every repo that names its default branch something
#   else (mealie-next, master, develop): the diff range then references a
#   revision that does not exist and the PR aborts before it is written. Falls
#   back to the push remote's HEAD so the lookup still resolves offline, and to
#   main only when nothing else answers.
git_base_branch() {
    local base remote
    base=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2> /dev/null)
    if [ -z "$base" ]; then
        remote=$(git_push_remote)
        base=$(git symbolic-ref --quiet --short "refs/remotes/${remote}/HEAD" 2> /dev/null)
        base=${base#"${remote}/"}
    fi
    printf '%s\n' "${base:-main}"
}

# git_required_pr_headings() prints the "## " headings a repo's pull request
# template marks as required, one per line, newest-first in template order.
#
# Usage:
#   git_required_pr_headings
#
# Output:
#   Zero or more heading lines. Empty when the repo ships no template.
#
# Example:
#   PR_REQUIRED_HEADINGS=$(git_required_pr_headings)
#
# Note:
#   Mirrors the parse mealie-style "Validate PR template" checks run: a heading
#   is required when the next "_(REQUIRED)_" line follows it with no intervening
#   heading. Those checks grep the PR body for each heading as a literal
#   substring, so a generated body that omits them fails CI no matter how good
#   the prose is.
git_required_pr_headings() {
    local root template
    root=$(git rev-parse --show-toplevel 2> /dev/null) || return 0
    for template in \
        "$root/.github/pull_request_template.md" \
        "$root/.github/PULL_REQUEST_TEMPLATE.md"; do
        [ -f "$template" ] || continue
        awk '
            /^## / {
                heading = $0
                sub(/[[:space:]]+$/, "", heading)
                next
            }
            {
                line = $0
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                if (line == "_(REQUIRED)_" && heading != "") {
                    print heading
                    heading = ""
                }
            }
        ' "$template"
        return 0
    done
}

# fabric_branch() generates an idiomatic branch name using fabric AI and
# checks it out. With no arguments, the name is inferred from uncommitted
# changes (diff against HEAD, falling back to git status).
#
# Usage:
#   fabric_branch [description...]
#
# Output:
#   Creates and switches to a new branch with an AI-generated name.
#
# Example:
#   fabric_branch fix auth token expiry issue AUTH-456
#
# Note:
#   Requires the fabric tool and a 'branch' fabric pattern.
fabric_branch() {
    check_fabric || return 1
    local input="$*"
    if [ -z "$input" ]; then
        input=$(git diff HEAD 2> /dev/null)
        if [ -z "$input" ]; then
            input=$(git status --short 2> /dev/null)
        fi
    fi

    if [ -z "$input" ]; then
        echo "error: no description provided and no git changes found" >&2
        return 1
    fi

    local branch_name
    branch_name=$(printf '%s\n' "$input" | fabric --pattern branch | ~/.config/fabric/patterns/branch/filter.sh)

    if [ -z "$(printf '%s' "$branch_name" | tr -d '[:space:]')" ]; then
        echo "error: branch name is empty — fabric call failed; check 'fabric --pattern branch'" >&2
        return 1
    fi

    echo "✓ Checking out branch: $branch_name"
    git checkout -b "$branch_name"
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
    local msg
    msg=$(git ds | fabric --pattern commit | ~/.config/fabric/patterns/commit/filter.sh)
    # git commit --cleanup=verbatim -F - accepts empty stdin, so a failed fabric
    # call (dead API key, no credits) would otherwise create a message-less commit.
    if [ -z "$(printf '%s' "$msg" | tr -d '[:space:]')" ]; then
        echo "error: commit message is empty — fabric call failed; check 'git ds | fabric --pattern commit'" >&2
        return 1
    fi
    # Push with an explicit refspec: a bare "git push" fails when the local
    # branch tracks a differently-named upstream (e.g. after
    # "git checkout -b topic origin/main"), which aborts before pushing.
    printf '%s\n' "$msg" | git commit --cleanup=verbatim -F - && git push -u "$(git_push_remote)" HEAD
}

# fabric_pr() generates a PR title/body using fabric AI and creates or updates
# the branch's PR with gh. If a PR already exists it is updated in place with
# freshly regenerated text (e.g. after a rebase); otherwise a new PR is opened.
# The title/body are ALWAYS fabric output — never hand-write or hand-edit them.
#
# Usage:
#   fabric_pr [gh pr create args...]   # extra args apply only when creating
#
# Output:
#   Creates or updates a GitHub PR with AI-generated title/body from the diff
#   against main. Re-run any time the branch changes to refresh the PR.
#
# Example:
#   fabric_pr --draft
#
# Note:
#   Requires the fabric tool and a 'pr' fabric pattern.
fabric_pr() {
    check_fabric || return 1
    if ! command -v gh &> /dev/null; then
        echo "error: gh is not installed"
        return 1
    fi

    local pr_text
    local title
    local body
    local branch
    local repo

    branch=$(git branch --show-current)
    repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2> /dev/null)

    echo "⏺ Generating PR with Fabric AI..."
    echo

    local base remote base_remote
    # Only an open PR pins the base; a closed/merged PR's base has no bearing
    # on the PR this run creates.
    base=$(gh pr view --json baseRefName,state --jq 'select(.state == "OPEN") | .baseRefName' 2> /dev/null)
    : "${base:=$(git_base_branch)}"
    # Diff against the base branch as it exists in the repo the PR is opened against, not
    # the push remote's copy. That repo is usually origin, but "gh repo set-default" can
    # aim PRs at a fork, and then origin is the stale one and would pad the diff with
    # commits the PR does not contain. Fall back to origin when the resolved remote's copy
    # was never fetched, since a missing revision aborts the diff outright.
    base_remote=$(git_remote_for_repo "$repo")
    if ! git rev-parse --verify --quiet "${base_remote}/${base}" > /dev/null 2>&1; then
        base_remote=origin
    fi
    # Refresh the base before diffing. Remote-tracking refs only move when that
    # branch is fetched, and fetching a feature branch does not touch them, so
    # the local copy of the base drifts behind without any visible signal. A
    # stale base pads the diff with commits already merged upstream and fabric
    # then writes a PR describing someone else's work. Non-fatal so the command
    # still works offline, but warn, since the result is silently wrong.
    if ! git fetch --quiet "$base_remote" "$base" 2> /dev/null; then
        echo "warning: could not refresh ${base_remote}/${base} — diff may include already-merged commits"
        echo
    fi
    local diff_range="${base_remote}/${base}...HEAD"
    local max_diff_bytes=400000
    local pr_input
    pr_input=$(git diff "$diff_range")
    if [ "${#pr_input}" -gt "$max_diff_bytes" ]; then
        pr_input=$(
            git log --oneline "${base_remote}/${base}..HEAD"
            git diff --stat "$diff_range"
        )
    fi
    # A repo whose PR template marks headings required has a CI check grepping the
    # body for them verbatim, so the generated body has to be built around those
    # headings rather than the pattern's default section list. The model needs them
    # in its input; the pattern's filter needs them in the environment, to stop the
    # section merging that would reorder content out from under them.
    local pr_headings
    pr_headings=$(git_required_pr_headings)
    if [ -n "$pr_headings" ]; then
        pr_input=$(printf 'REQUIRED PR TEMPLATE HEADINGS\n%s\n\n---\n\n%s\n' "$pr_headings" "$pr_input")
    fi
    export PR_REQUIRED_HEADINGS="$pr_headings"
    pr_text=$(printf '%s\n' "$pr_input" | fabric --pattern pr | ~/.config/fabric/patterns/pr/filter.sh)
    unset PR_REQUIRED_HEADINGS
    if [ -z "$pr_text" ]; then
        echo "error: PR text is empty"
        return 1
    fi

    # Trim leading blank lines before extracting title/body
    pr_text=$(printf "%s\n" "$pr_text" | sed -n '/[^[:space:]]/,$p')

    title=$(printf "%s\n" "$pr_text" | head -n 1)
    body=$(printf "%s\n" "$pr_text" | tail -n +2)

    if [ -z "$title" ]; then
        echo "error: PR title is empty"
        return 1
    fi
    # A markdown heading in the title position means the model skipped the title line
    # and opened with the body, so the first heading got consumed as the title. Left
    # alone that ships a PR titled "## What this PR does", failing the semantic-title
    # check and dropping a heading the template check needs.
    case "$title" in
        \#*)
            echo "error: PR title is a markdown heading: $title" >&2
            echo "the model omitted the title line; retry, or debug with 'git diff | squad_gen pr'" >&2
            return 1
            ;;
    esac

    echo "  PR Details:"
    echo "  - Title: $title"
    echo "  - Branch: $branch"
    if [ -n "$repo" ]; then
        echo "  - Repo: $repo"
    fi
    echo

    # Push the branch. After a rebase/amend the remote has diverged, so fall
    # back to --force-with-lease (refuses if the remote moved unexpectedly).
    remote=$(git_push_remote)
    if ! git push -u "$remote" HEAD 2> /dev/null; then
        if ! git push --force-with-lease -u "$remote" HEAD; then
            echo "error: Failed to push branch"
            return 1
        fi
    fi
    echo "✓ Pushed branch to remote"
    echo

    local pr_url
    # If an open PR already exists for this branch, update it in place with the
    # freshly generated title/body (e.g. after a rebase) instead of failing.
    # Otherwise create a new PR — gh pr view also resolves closed/merged PRs,
    # and editing one of those rewrites a dead PR instead of opening a fresh
    # one. The body is ALWAYS fabric output, never hand-written. Create-only
    # flags ("$@", e.g. --draft) apply on create.
    if pr_url=$(gh pr view --json url,state --jq 'select(.state == "OPEN") | .url' 2> /dev/null) && [ -n "$pr_url" ]; then
        if gh pr edit --title "$title" --body "$body" > /dev/null; then
            echo "⏺ Updated existing pull request with regenerated title/body!"
            echo
            echo "  Pull Request:"
            echo "  - URL: $pr_url"
            echo "  - Title: $title"
            echo "  - Branch: $branch"
            echo
        else
            echo "error: Failed to update existing PR"
            return 1
        fi
    elif pr_url=$(gh pr create --title "$title" --body "$body" "$@"); then
        if [ -n "$pr_url" ]; then
            echo "⏺ Successfully created pull request!"
            echo
            echo "  Pull Request:"
            echo "  - URL: $pr_url"
            echo "  - Title: $title"
            echo "  - Branch: $branch"
            echo
        else
            echo "error: PR URL is empty"
            return 1
        fi
    else
        echo "error: Failed to create PR"
        return 1
    fi
}

# check_squad() verifies that the squad tool is installed and available.
#
# Usage:
#   check_squad
#
# Output:
#   Returns 0 if squad is installed, exits with error message if not.
#
# Example:
#   check_squad
check_squad() {
    if ! command -v squad &> /dev/null; then
        echo "error: squad is not installed"
        echo "install it from: https://github.com/CowDogMoo/squad"
        return 1
    fi
}

# squad_gen() transforms stdin using a fabric-patterns-hub pattern, run by
# squad's built-in pure-text transform (squad run --system with no --agent)
# on the claude-code provider so the call is billed to the local Claude
# subscription instead of an API key. The pattern's system.md is injected
# via --system and its filter.sh post-processes the output, so pattern
# content stays single-sourced in the hub repo.
#
# Usage:
#   <input> | squad_gen <pattern>
#
# Output:
#   The transformed text on stdout.
#
# Example:
#   git ds | squad_gen commit
#
# Note:
#   Requires squad >= the build that supports agentless --system runs.
#   Override the hub location with FABRIC_PATTERNS_HUB.
squad_gen() {
    local pattern=$1
    local hub="${FABRIC_PATTERNS_HUB:-$HOME/cowdogmoo/fabric-patterns-hub}"
    if [ -z "$pattern" ]; then
        echo "usage: <input> | squad_gen <pattern>" >&2
        [ -d "$hub/patterns" ] && echo "patterns: $(cd "$hub/patterns" && printf '%s ' */ | tr -d '/')" >&2
        return 1
    fi
    local system="$hub/patterns/$pattern/system.md"
    local filter="$hub/patterns/$pattern/filter.sh"
    if [ ! -f "$system" ]; then
        echo "error: pattern not found: $system" >&2
        [ -d "$hub/patterns" ] && echo "patterns: $(cd "$hub/patterns" && printf '%s ' */ | tr -d '/')" >&2
        return 1
    fi
    # squad's info logs (session banner, metrics) go to stderr; suppress them
    # so callers get only the transformed text. Re-run without 2>/dev/null to
    # debug a failing generation.
    local out
    out=$(squad run --provider claude-code --system "$(cat "$system")" 2> /dev/null \
        | "$filter")
    # NO INPUT is the built-in transform's no-stdin sentinel; any line
    # matching it means the model treated the run as inputless (possibly with
    # prose around the sentinel), so fail instead of handing callers the
    # literal string to commit or publish.
    if printf '%s\n' "$out" | grep -qxE '[[:space:]]*NO INPUT[[:space:]]*'; then
        echo "error: squad returned the NO INPUT sentinel — the model saw no usable input; retry or debug with '<input> | squad_gen $pattern'" >&2
        return 1
    fi
    printf '%s\n' "$out"
}

# squad_branch() generates an idiomatic branch name with squad on the Claude
# subscription and checks it out. With no arguments, the name is inferred
# from uncommitted changes (diff against HEAD, falling back to git status).
#
# Usage:
#   squad_branch [description...]
#
# Output:
#   Creates and switches to a new branch with an AI-generated name.
#
# Example:
#   squad_branch fix auth token expiry issue AUTH-456
#
# Note:
#   Subscription-billed twin of fabric_branch; uses the hub 'branch' pattern.
squad_branch() {
    check_squad || return 1
    local input="$*"
    if [ -z "$input" ]; then
        input=$(git diff HEAD 2> /dev/null)
        if [ -z "$input" ]; then
            input=$(git status --short 2> /dev/null)
        fi
    fi

    if [ -z "$input" ]; then
        echo "error: no description provided and no git changes found" >&2
        return 1
    fi

    local branch_name
    branch_name=$(printf '%s\n' "$input" | squad_gen branch)

    if [ -z "$(printf '%s' "$branch_name" | tr -d '[:space:]')" ]; then
        echo "error: branch name is empty — squad call failed; check 'echo <desc> | squad_gen branch'" >&2
        return 1
    fi

    echo "✓ Checking out branch: $branch_name"
    git checkout -b "$branch_name"
}

# squad_commit() generates a commit message with squad on the Claude
# subscription and commits the staged changes, then pushes to remote.
#
# Usage:
#   squad_commit
#
# Output:
#   Commits staged changes with an AI-generated commit message and pushes to remote.
#
# Example:
#   squad_commit
#
# Note:
#   Subscription-billed twin of fabric_commit; uses the hub 'commit' pattern
#   and requires git alias 'ds'.
squad_commit() {
    check_squad || return 1
    local msg
    msg=$(git ds | squad_gen commit)
    # git commit --cleanup=verbatim -F - accepts empty stdin, so a failed
    # generation would otherwise create a message-less commit.
    if [ -z "$(printf '%s' "$msg" | tr -d '[:space:]')" ]; then
        echo "error: commit message is empty — squad call failed; check 'git ds | squad_gen commit'" >&2
        return 1
    fi
    # Push with an explicit refspec: a bare "git push" fails when the local
    # branch tracks a differently-named upstream (e.g. after
    # "git checkout -b topic origin/main"), which aborts before pushing.
    printf '%s\n' "$msg" | git commit --cleanup=verbatim -F - && git push -u "$(git_push_remote)" HEAD
}

# squad_pr() generates a PR title/body with squad on the Claude subscription
# and creates or updates the branch's PR with gh. If a PR already exists it
# is updated in place with freshly regenerated text (e.g. after a rebase);
# otherwise a new PR is opened. The title/body are ALWAYS generated output —
# never hand-write or hand-edit them.
#
# Usage:
#   squad_pr [gh pr create args...]   # extra args apply only when creating
#
# Output:
#   Creates or updates a GitHub PR with AI-generated title/body from the diff
#   against main. Re-run any time the branch changes to refresh the PR.
#
# Example:
#   squad_pr --draft
#
# Note:
#   Subscription-billed twin of fabric_pr; uses the hub 'pr' pattern.
squad_pr() {
    check_squad || return 1
    if ! command -v gh &> /dev/null; then
        echo "error: gh is not installed"
        return 1
    fi

    local pr_text
    local title
    local body
    local branch
    local repo

    branch=$(git branch --show-current)
    repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2> /dev/null)

    echo "⏺ Generating PR with Squad (claude-code)..."
    echo

    local base remote base_remote
    # Only an open PR pins the base; a closed/merged PR's base has no bearing
    # on the PR this run creates.
    base=$(gh pr view --json baseRefName,state --jq 'select(.state == "OPEN") | .baseRefName' 2> /dev/null)
    : "${base:=$(git_base_branch)}"
    # Diff against the base branch as it exists in the repo the PR is opened against, not
    # the push remote's copy. That repo is usually origin, but "gh repo set-default" can
    # aim PRs at a fork, and then origin is the stale one and would pad the diff with
    # commits the PR does not contain. Fall back to origin when the resolved remote's copy
    # was never fetched, since a missing revision aborts the diff outright.
    base_remote=$(git_remote_for_repo "$repo")
    if ! git rev-parse --verify --quiet "${base_remote}/${base}" > /dev/null 2>&1; then
        base_remote=origin
    fi
    # Refresh the base before diffing. Remote-tracking refs only move when that
    # branch is fetched, and fetching a feature branch does not touch them, so
    # the local copy of the base drifts behind without any visible signal. A
    # stale base pads the diff with commits already merged upstream and the
    # model then writes a PR describing someone else's work. Non-fatal so the
    # command still works offline, but warn, since the result is silently wrong.
    if ! git fetch --quiet "$base_remote" "$base" 2> /dev/null; then
        echo "warning: could not refresh ${base_remote}/${base} — diff may include already-merged commits"
        echo
    fi
    local diff_range="${base_remote}/${base}...HEAD"
    local max_diff_bytes=400000
    local pr_input
    pr_input=$(git diff "$diff_range")
    if [ "${#pr_input}" -gt "$max_diff_bytes" ]; then
        pr_input=$(
            git log --oneline "${base_remote}/${base}..HEAD"
            git diff --stat "$diff_range"
        )
    fi
    # A repo whose PR template marks headings required has a CI check grepping the
    # body for them verbatim, so the generated body has to be built around those
    # headings rather than the pattern's default section list. The model needs them
    # in its input; the pattern's filter needs them in the environment, to stop the
    # section merging that would reorder content out from under them.
    local pr_headings
    pr_headings=$(git_required_pr_headings)
    if [ -n "$pr_headings" ]; then
        pr_input=$(printf 'REQUIRED PR TEMPLATE HEADINGS\n%s\n\n---\n\n%s\n' "$pr_headings" "$pr_input")
    fi
    export PR_REQUIRED_HEADINGS="$pr_headings"
    pr_text=$(printf '%s\n' "$pr_input" | squad_gen pr)
    unset PR_REQUIRED_HEADINGS
    if [ -z "$pr_text" ]; then
        echo "error: PR text is empty"
        return 1
    fi

    # Trim leading blank lines before extracting title/body
    pr_text=$(printf "%s\n" "$pr_text" | sed -n '/[^[:space:]]/,$p')

    title=$(printf "%s\n" "$pr_text" | head -n 1)
    body=$(printf "%s\n" "$pr_text" | tail -n +2)

    if [ -z "$title" ]; then
        echo "error: PR title is empty"
        return 1
    fi
    # A markdown heading in the title position means the model skipped the title line
    # and opened with the body, so the first heading got consumed as the title. Left
    # alone that ships a PR titled "## What this PR does", failing the semantic-title
    # check and dropping a heading the template check needs.
    case "$title" in
        \#*)
            echo "error: PR title is a markdown heading: $title" >&2
            echo "the model omitted the title line; retry, or debug with 'git diff | squad_gen pr'" >&2
            return 1
            ;;
    esac

    echo "  PR Details:"
    echo "  - Title: $title"
    echo "  - Branch: $branch"
    if [ -n "$repo" ]; then
        echo "  - Repo: $repo"
    fi
    echo

    # Push the branch. After a rebase/amend the remote has diverged, so fall
    # back to --force-with-lease (refuses if the remote moved unexpectedly).
    remote=$(git_push_remote)
    if ! git push -u "$remote" HEAD 2> /dev/null; then
        if ! git push --force-with-lease -u "$remote" HEAD; then
            echo "error: Failed to push branch"
            return 1
        fi
    fi
    echo "✓ Pushed branch to remote"
    echo

    local pr_url
    # If an open PR already exists for this branch, update it in place with the
    # freshly generated title/body (e.g. after a rebase) instead of failing.
    # Otherwise create a new PR — gh pr view also resolves closed/merged PRs,
    # and editing one of those rewrites a dead PR instead of opening a fresh
    # one. The body is ALWAYS generated output, never hand-written. Create-only
    # flags ("$@", e.g. --draft) apply on create.
    if pr_url=$(gh pr view --json url,state --jq 'select(.state == "OPEN") | .url' 2> /dev/null) && [ -n "$pr_url" ]; then
        if gh pr edit --title "$title" --body "$body" > /dev/null; then
            echo "⏺ Updated existing pull request with regenerated title/body!"
            echo
            echo "  Pull Request:"
            echo "  - URL: $pr_url"
            echo "  - Title: $title"
            echo "  - Branch: $branch"
            echo
        else
            echo "error: Failed to update existing PR"
            return 1
        fi
    elif pr_url=$(gh pr create --title "$title" --body "$body" "$@"); then
        if [ -n "$pr_url" ]; then
            echo "⏺ Successfully created pull request!"
            echo
            echo "  Pull Request:"
            echo "  - URL: $pr_url"
            echo "  - Title: $title"
            echo "  - Branch: $branch"
            echo
        else
            echo "error: PR URL is empty"
            return 1
        fi
    else
        echo "error: Failed to create PR"
        return 1
    fi
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
