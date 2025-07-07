#!/usr/bin/env bash
set -euo pipefail

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

# Apply all patches sequentially
for p in patches/*.patch; do
  echo "Applying patch: $p"
  git am --3way "$p"
done

# Push the resulting commits to remote
echo "Pushing applied patches to origin/main..."
git push origin main

# Restore helper scripts
git stash pop --quiet || true

echo "✅ All patches applied and pushed successfully."
