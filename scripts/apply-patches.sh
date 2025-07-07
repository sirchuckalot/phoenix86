#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Abort any in-progress operations
git merge --abort 2>/dev/null || true
git rebase --abort 2>/dev/null || true
git am --abort 2>/dev/null || true

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
  echo "Processing patch: $p"

  # First try git am
  if git am --3way "$p"; then
    echo "✅ git am success: $p"
    continue
  fi

  echo "⚠️ git am failed, aborting and trying git apply..."
  git am --abort 2>/dev/null || true

  # Try git apply with index
  if git apply --index "$p"; then
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
    git commit -m "$subject"
    echo "✅ git apply --index success: $p"
    continue
  fi

  echo "⚠️ git apply --index failed, trying patch fallback..."
  # Fallback to patch -p1 with fuzz
  if patch -p1 --fuzz=3 --verbose < "$p"; then
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p1 fallback success: $p"
    continue
  fi

  echo "❌ All apply methods failed for patch: $p"
  exit 1
done

# Push changes
echo "Pushing changes to origin/main..."
git push origin main

echo "✅ All patches applied and pushed successfully."
