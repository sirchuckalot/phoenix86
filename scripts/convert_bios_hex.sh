#!/usr/bin/env bash
set -euo pipefail

xxd -p bios.bin > rtl/bus/bios.hex
