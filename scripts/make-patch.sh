#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 \"Commit message for this patch\""
  exit 1
fi

# Ensure up-to-date
git fetch origin main
git switch main

# Check for staged changes
if git diff --cached --quiet; then
  echo "No staged changes; nothing to patch."
  exit 0
fi

# Stage everything
git add -A

# Create temp branch
tmp="tmp-patch-$(date +%s)"
echo "Creating branch $tmp"
git switch -c "$tmp"

# Commit
git commit -m "$*"

# Generate patch
count=$(ls patches/*.patch 2>/dev/null | wc -l)
next=$(printf "%04d" $((count+1)))
safe=$(echo "$*" | tr ' /' '-')
file="patches/${next}-${safe}.patch"
echo "Writing patch to $file"
git format-patch origin/main --stdout > "$file"

# Cleanup
git switch main
git branch -D "$tmp"

echo "Patch created: $file"
