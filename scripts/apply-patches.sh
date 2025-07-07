#!/usr/bin/env bash
set -euo pipefail

# Enable nullglob so unmatched globs disappear
shopt -s nullglob

# Stash local modifications to helper scripts
git stash push --include-untracked --quiet -- scripts/apply-patches.sh scripts/make-patch.sh || true

# Abort any in-progress git am session
if [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
  echo "Aborting existing apply session..."
  git am --abort || true
fi

# Sync local main branch with remote
echo "Syncing main branch with origin/main..."
git fetch origin main
git switch main
git reset --hard origin/main

# Find patches
patch_files=(patches/*.patch)
if [ ${#patch_files[@]} -eq 0 ]; then
  echo "No patches to apply."
else
  # Apply all patches sequentially
  for p in "${patch_files[@]}"; do
    echo "Applying patch: $p"
    if git am --3way "$p"; then
      echo "✅ Applied via git am: $p"
    else
      echo "⚠️ git am failed for $p, falling back to git apply..."
      git am --abort || true
      if git apply --index "$p"; then
        subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
        git commit -m "$subject"
        echo "✅ Applied via git apply: $p"
      else
        echo "❌ Both git am and git apply failed for $p"
        exit 1
      fi
    fi
  done
  # Push the resulting commits to remote
  echo "Pushing applied patches to origin/main..."
  git push origin main
  echo "✅ All patches applied and pushed successfully."
fi

# Restore helper scripts
git stash pop --quiet || true
