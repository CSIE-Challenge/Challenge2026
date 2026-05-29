#!/bin/bash
# Prevent re-entrant execution when we do `git checkout -` internally
if [ -n "$BRANCH_CHECK_RUNNING" ]; then
    exit 0
fi
export BRANCH_CHECK_RUNNING=1

branch=$(git branch --show-current)

# Skip detached HEAD and base branches
if [ -z "$branch" ] || [[ "$branch" =~ ^(main|master|develop)$ ]]; then
    exit 0
fi

allowed="^(feat|fix|chore|docs|style|refactor|test|perf)/[a-z0-9]+(-[a-z0-9]+)*$"

if [[ "$branch" =~ $allowed ]]; then
    exit 0
fi

echo "ERROR: Branch '$branch' does not match naming convention."
echo "       Required prefix: feat/ fix/ chore/ docs/ style/ refactor/ test/ perf/"
echo ""

# Switch back to previous branch before deleting
git checkout - 2>/dev/null || git checkout develop 2>/dev/null || git checkout main 2>/dev/null

# Delete bad local branch
git branch -D "$branch"

# Delete remote branch only if it exists
if git ls-remote --exit-code origin "$branch" &>/dev/null; then
    echo "Deleting remote branch origin/$branch..."
    git push origin --delete "$branch"
fi

exit 1
