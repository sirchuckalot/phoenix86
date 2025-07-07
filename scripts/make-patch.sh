#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

if [ $# -lt 1 ]; then
  echo "Usage: $0 \"Commit message for this patch\""
  exit 1
fi

echo "Fetching origin/main..."
git fetch origin main
git switch main

# Check for staged changes
if git diff --cached --quiet; then
  echo "No staged changes; nothing to patch."
  exit 0
fi

echo "Creating temporary branch..."
tmp="tmp-patch-$(date +%s)"
git switch -c "$tmp"

echo "Committing staged changes..."
git commit -m "$*"

# Generate patch
count=$(ls patches/*.patch 2>/dev/null | wc -l)
next=$(printf "%04d" $((count+1)))
safe=$(echo "$*" | tr ' /' '-')
file="patches/${next}-${safe}.patch"
echo "Generating patch file $file..."
git format-patch origin/main --stdout > "$file"

echo "Patch created: $file"

# Cleanup
git switch main
git branch -D "$tmp"
