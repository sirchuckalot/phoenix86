#!/usr/bin/env bash
set -euo pipefail

# Enable nullglob to handle empty patches directory
shopt -s nullglob

# Abort any in-progress git am session
if [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
  echo "Aborting existing apply session..."
  git am --abort
fi

# Sync main
echo "Syncing main with origin/main..."
git fetch origin main
git switch main
git reset --hard origin/main

# Apply patches
patches=(patches/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches to apply."
  exit 0
fi

for p in "${patches[@]}"; do
  echo "Applying patch $p"
  if git am --3way "$p"; then
    echo "Applied via git am: $p"
  else
    echo "git am failed for $p, attempting git apply..."
    git am --abort
    if git apply --index "$p"; then
      subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
      git commit -m "$subject"
      echo "Applied via git apply: $p"
    else
      echo "Failed to apply patch: $p"
      exit 1
    fi
  fi
done

# Push
echo "Pushing commits..."
git push origin main
