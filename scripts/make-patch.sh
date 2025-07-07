#!/usr/bin/env bash
set -euo pipefail

# Stash local modifications to helper scripts
git stash push --include-untracked --quiet -- scripts/apply-patches.sh scripts/make-patch.sh || true

if [ $# -lt 1 ]; then
  echo "Usage: $0 \"Commit message for this patch\""
  exit 1
fi

# Ensure up-to-date with remote
echo "Fetching origin/main..."
git fetch origin main
git switch main

# Stage all changes
echo "Staging changes..."
git add -A

# Create temporary branch for patch
tmp_branch="tmp-patch-$(date +%s)"
echo "Creating temporary branch $tmp_branch..."
git switch -c "$tmp_branch"

# Commit staged changes with provided message
echo "Committing patch changes..."
git commit -m "$*"

# Calculate next patch number
existing=$(ls patches/*.patch 2>/dev/null | wc -l)
next=$(printf "%04d" $((existing+1)))
safe_msg=$(echo "$*" | tr ' /' '-')
filepath="patches/${next}-${safe_msg}.patch"

# Generate the patch file
echo "Generating patch file $filepath..."
git format-patch origin/main --stdout > "$filepath"

# Clean up temporary branch and restore scripts
git switch main
git branch -D "$tmp_branch"
git stash pop --quiet || true

echo "↪ Patch written to $filepath"
