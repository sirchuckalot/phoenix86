#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

abort_inflight() {
  git merge --abort     2>/dev/null || true
  git rebase --abort    2>/dev/null || true
  git am --abort        2>/dev/null || true
}

apply_manual() {
  local p="$1" subject target
  subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')
  target=$(grep -m1 '^+++ b/' "$p" | cut -d' ' -f2 | sed 's:^b/::')
  echo "🔄 Creating new file $target from patch"
  git rm --ignore-unmatch "$target" >/dev/null 2>&1 || rm -f "$target"
  # Extract new-file content: skip up to first hunk, strip '+' and remove any hunk headers
  sed -n '1,/^@@/d' "$p" | sed 's/^+//' | sed '/^@@/d' > "$target"
  git add "$target"
  git commit -m "$subject"
  echo "✅ Manual create+commit for $target"
}

echo "Cleaning up in-progress operations..."
abort_inflight

echo "Syncing main with origin/main..."
git fetch origin main
git switch main
git reset --hard origin/main

# Gather patches
patches=(patches/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches to apply."
  exit 0
fi

# Normalize line endings/BOM
for p in "${patches[@]}"; do
  echo "🔄 Normalizing patch $p"
  sed -i 's/\r$//' "$p"
  sed -i '1s/^\xEF\xBB\xBF//' "$p"
done

for p in "${patches[@]}"; do
  echo "Processing patch: $p"
  subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject: //')

  # Skip if already applied
  if git apply --check "$p" >/dev/null 2>&1; then
    echo "✅ Patch already applied, skipping: $p"
    continue
  fi

  # Handle delete+new-file patches
  if grep -q '^deleted file mode' "$p" && grep -q '^new file mode' "$p"; then
    apply_manual "$p"
    continue
  fi

  # Handle new-file only patches
  if grep -q '^new file mode' "$p" && ! grep -q '^deleted file mode' "$p"; then
    apply_manual "$p"
    continue
  fi

  # Try git am --3way
  if git am --3way "$p"; then
    echo "✅ git am success: $p"
    continue
  fi
  echo "⚠️ git am failed, aborting..."
  git am --abort 2>/dev/null || true

  # Try git apply --index --3way
  if git apply --index --3way "$p"; then
    git commit -m "$subject"
    echo "✅ git apply --index --3way success: $p"
    continue
  fi

  # Try git apply --index
  if git apply --index "$p"; then
    git commit -m "$subject"
    echo "✅ git apply --index success: $p"
    continue
  fi

  # Try patch -p1
  if patch -p1 --fuzz=3 --batch < "$p"; then
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p1 success: $p"
    continue
  fi

  # Try patch -p0
  if patch -p0 --fuzz=3 --batch < "$p"; then
    git add -A
    git commit -m "$subject"
    echo "✅ patch -p0 success: $p"
    continue
  fi

  echo "❌ Failed to apply patch: $p"
  exit 1
done

echo "Pushing changes to origin/main..."
git push origin main
echo "✅ All patches applied and pushed."
