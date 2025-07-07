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
patch_array=(patches/*.patch)
if [ ${#patch_array[@]} -eq 0 ]; then
  echo "No patches to apply."
  exit 0
fi

for p in "${patch_array[@]}"; do
  echo "Processing patch: $p"

  # If patch adds a new file, delete existing target first
  if grep -q '^new file mode' "$p"; then
    target=$(grep -m1 '^+++ b/' "$p" | cut -d' ' -f2)
    echo "🔄 Removing existing $target before applying new file"
    git rm --ignore-unmatch "$target" || rm -f "$target"
  fi

  # Attempt git am
  if git am --3way "$p"; then
    echo "✅ git am success: $p"
    continue
  fi

  echo "⚠️ git am failed, aborting..."
  git am --abort 2>/dev/null || true

  # Attempt git apply with index and 3way
  echo "🔄 Trying git apply --3way..."
  if git apply --index --3way "$p"; then
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
    git commit -m "$subject"
    echo "✅ git apply --index --3way success: $p"
    continue
  fi

  # Attempt git apply with index
  echo "🔄 Trying git apply --index..."
  if git apply --index "$p"; then
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
    git commit -m "$subject"
    echo "✅ git apply --index success: $p"
    continue
  fi

  # Fallback patch -p1
  echo "🔄 Trying patch -p1 with fuzz..."
  if patch -p1 --fuzz=3 < "$p"; then
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p1 fallback success: $p"
    continue
  fi

  # Fallback patch -p0
  echo "🔄 Trying patch -p0 with fuzz..."
  if patch -p0 --fuzz=3 < "$p"; then
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p0 fallback success: $p"
    continue
  fi

  echo "❌ All apply methods failed for patch: $p"
  exit 1
done

# Push commits
echo "Pushing changes to origin/main..."
git push origin main
echo "✅ All patches applied and pushed successfully."
