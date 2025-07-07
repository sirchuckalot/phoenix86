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
  subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')

  # Handle delete+new file scenario
  if grep -q '^deleted file mode' "$p" && grep -q '^new file mode' "$p"; then
    target=$(grep -m1 '^+++ b/' "$p" | cut -d' ' -f2)
    # strip leading b/ if present
    target=${target#b/}
    echo "🔄 Replacing file $target from patch"
    git rm --ignore-unmatch "$target" || rm -f "$target"
    # extract new content: skip header until blank line after diff header
    sed -n '/^@@/,$' "$p" | sed '1d' | sed 's/^+//' > "$target"
    git add "$target"
    git commit -m "$subject"
    echo "✅ Manual replace+commit for $target"
    continue
  fi

  # Try git am
  if git am --3way "$p"; then
    echo "✅ git am success: $p"
    continue
  fi

  echo "⚠️ git am failed, aborting..."
  git am --abort 2>/dev/null || true

  # Try git apply with index and 3way
  echo "🔄 Trying git apply --index --3way..."
  if git apply --index --3way "$p"; then
    git commit -m "$subject"
    echo "✅ git apply --index --3way success: $p"
    continue
  fi

  # Try git apply with index
  echo "🔄 Trying git apply --index..."
  if git apply --index "$p"; then
    git commit -m "$subject"
    echo "✅ git apply --index success: $p"
    continue
  fi

  # Fallback patch -p1 non-interactive
  echo "🔄 Trying patch -p1 with fuzz and batch..."
  if patch -p1 --fuzz=3 --batch < "$p"; then
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p1 batch success: $p"
    continue
  fi

  # Fallback patch -p0 non-interactive
  echo "🔄 Trying patch -p0 with fuzz and batch..."
  if patch -p0 --fuzz=3 --batch < "$p"; then
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p0 batch success: $p"
    continue
  fi

  echo "❌ All apply methods failed for patch: $p"
  exit 1
done

# Push commits
echo "Pushing changes to origin/main..."
git push origin main
echo "✅ All patches applied and pushed successfully."
