#!/bin/bash
# Block merging a base branch (develop / main) into a feature branch —
# enforce rebase instead.
# Detection: git has not written MERGE_HEAD yet when pre-merge-commit runs,
# so GIT_REFLOG_ACTION ("merge develop", "merge origin/main", "pull origin
# develop") is the reliable signal. MERGE_HEAD is a native-hook fallback.

current=$(git branch --show-current)
base_re='^(develop|main|master)$'

# Allow merges *on* base branches themselves (e.g. PR merges into develop/main)
if [ -z "$current" ] || [[ "$current" =~ $base_re ]]; then
    exit 0
fi

base=""

# Primary signal: the merge/pull invocation recorded by git
read -ra toks <<< "${GIT_REFLOG_ACTION:-}"
if [[ "${toks[0]}" == merge || "${toks[0]}" == pull ]]; then
    for t in "${toks[@]:1}"; do
        name="${t##*/}"
        [[ "$name" =~ $base_re ]] && base="$name"
    done
fi

# Fallback: native pre-merge-commit hook, where MERGE_HEAD is set
merge_head=$(git rev-parse --verify --quiet MERGE_HEAD)
if [ -z "$base" ] && [ -n "$merge_head" ]; then
    for ref in develop origin/develop main origin/main master origin/master; do
        git rev-parse --verify --quiet "$ref" >/dev/null || continue
        if [ "$(git rev-parse "$ref")" = "$merge_head" ]; then
            base="${ref##*/}"
            break
        fi
    done
fi

if [ -n "$base" ]; then
    echo "ERROR: Merging $base into '$current' is blocked — rebase instead:"
    echo ""
    echo "    git merge --abort"
    echo "    git fetch origin"
    echo "    git rebase origin/$base"
    echo ""
    echo "       Bypass (discouraged): git merge --no-verify"
    exit 1
fi

exit 0
