#!/usr/bin/env bash
set -euo pipefail

# Abort any in-progress am session
if [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
  git am --abort || true
fi

# Sync main
git fetch origin main
git switch main
git reset --hard origin/main

# Apply patch series
for p in patches/*.patch; do
  echo "Applying $p"
  git am --3way "$p"
done

# Assemble microcode
python3 scripts/assemble_uops.py

# Convert BIOS stub
xxd -p fw/rp2040/build/bootstub.bin > rtl/bus/bootstub.hex

# Run simulation
fusesoc run --target=sim --tool=verilator phoenix86
