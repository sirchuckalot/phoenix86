#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Abort any in-progress operations
echo "Cleaning up in-progress Git operations..."
git merge --abort 2>/dev/null || true
git rebase --abort 2>/dev/null || true
git am --abort 2>/dev/null || true

# Sync main
echo "Syncing main with origin/main..."
git fetch origin main
git switch main
git reset --hard origin/main

# Apply patches if any
patches=(patches/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches to apply."
  exit 0
fi

for p in "${patches[@]}"; do
  echo "Applying patch: $p"
  if git am --3way "$p"; then
    echo "✅ Applied via git am: $p"
  else
    echo "⚠️ git am failed for $p, trying git apply..."
    git am --abort || true
    if git apply --index "$p"; then
      commit_msg=$(sed -n 's/^Subject: //p' "$p" | head -n1)
      git commit -m "$commit_msg"
      echo "✅ Applied via git apply: $p"
    else
      echo "❌ Failed to apply patch $p"
      exit 1
    fi
  fi
done

# Push
echo "Pushing changes to origin/main..."
git push origin main
echo "✅ All patches applied and pushed."
