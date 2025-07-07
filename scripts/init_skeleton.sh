#!/usr/bin/env bash
set -euo pipefail

# Abort any in-progress git am session
if [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; then
  echo "Aborting in-progress am session..."
  git am --abort || true
fi

# Sync local main branch to origin/main
git fetch origin main
git switch main
git reset --hard origin/main

# Create directories
dirs=(
  cores
  doc
  rtl/cpu
  rtl/bus
  rtl/peripherals/vga_text
  rtl/peripherals/uart_16550
  rtl/peripherals/pic8259
  rtl/peripherals/pit8253
  rtl/peripherals/sd_ide_emu
  sim/models
  sim/ci
  scripts
  patches
  fw/rp2040/src
  fw/rp2040/include
  fw/rp2040/build
)
for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

# Add .gitkeep in empty directories
for d in "${dirs[@]}"; do
  touch "$d/.gitkeep"
done

# Write .gitignore
cat > .gitignore << 'EOF'
# Ignore build artifacts
*.o
*.hex
*.uf2
*.bin
*.log
*.fst
*.vcd
build/
sim/build/
fw/rp2040/build/

# Editor files
*.swp
*.bak
*~

# Generated core files
*.core
EOF

# Write Makefile
cat > Makefile << 'EOF'
.PHONY: all sim clean

all: sim

sim:
	./run_sim.sh

clean:
	rm -rf build sim/build waves
EOF

# Write run_sim.sh
cat > run_sim.sh << 'EOF'
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
EOF
chmod +x run_sim.sh

# Write FuseSoC core file
cat > cores/phoenix86.core << 'EOF'
CAPI=2:

name: phoenix86
description: "Phoenix86 microcoded 8086 CPU + Wishbone system"

filesets:
  rtl:
    files:
      - rtl/cpu/*.v
      - rtl/bus/*.v
      - rtl/peripherals/**/*.v
    file_type: verilogSource

  sim:
    files:
      - sim/tb_system.sv
      - sim/models/*.sv
    file_type: verilogSource

targets:
  default:
    filesets: [rtl]

  sim:
    depends: [default, sim]
    top_module: tb_system
    simulator: verilator
    parameters:
      VERILATOR_ARGS: ["-Wall", "--trace", "-O2"]

tools:
  verilator:
    targets: [sim]
EOF

# Write documentation placeholders
for f in doc/architecture_overview.md doc/memory_map.md doc/io_map.md doc/uop_encoding.md doc/x86_translation_table.md; do
  cat > "$f" << 'EOF'
# Placeholder
*TODO: Fill in*
EOF
done

# Write scripts
cat > scripts/apply-patches.sh << 'EOF'
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
EOF
chmod +x scripts/apply-patches.sh

cat > scripts/assemble_uops.py << 'EOF'
#!/usr/bin/env python3
# Generate microcode ROM init file (TODO).
pass
EOF

cat > scripts/convert_bios_hex.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

xxd -p bios.bin > rtl/bus/bios.hex
EOF
chmod +x scripts/convert_bios_hex.sh

# Write README.md
cat > README.md << 'EOF'
# Phoenix86 Microcoded 8086 PC System

## Overview
This repo contains RTL, docs, and simulation for the Phoenix86 core.

See \`Makefile\` and \`run_sim.sh\` for build instructions.
EOF

echo "Scaffold complete. Review and commit."
