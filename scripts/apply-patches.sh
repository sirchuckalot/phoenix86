#!/usr/bin/env bash
set -euo pipefail

if [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
  git am --abort || true
fi

git fetch origin main
git switch main
git reset --hard origin/main

for p in patches/*.patch; do
  echo "Applying $p"
  git am --3way "$p"
done

echo "✅ All patches applied."
