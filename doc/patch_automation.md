# Interactive Patch Workflow and Helper Scripts

This document provides a self-contained guide for another ChatGPT session (or any user) to understand and reproduce the interactive scripting process used to generate, apply, and push patches in the Phoenix86 repository.

## Overview

We maintain a set of helper scripts under `scripts/` to automate patch creation and application:

- **`scripts/make-patch.sh`**: Generates Git-format patches from staged changes.
- **`scripts/apply-patches.sh`**: Applies patches in the `patches/` directory to `main`, with multiple fallback strategies for malformed or delete+create patches, then pushes.

All `.patch` files are stored in the `patches/` directory and are applied in numerical order.

## Repo Layout

```
phoenix86/
├── doc/
│   ├── patch_workflow.md       # Workflow summary
│   └── patch_automation.md     # This file
├── patches/
└── scripts/
    ├── make-patch.sh
    └── apply-patches.sh
```

## Usage Summary

1. **Stage your changes**  
   ```bash
   git add <files>
   ```

2. **Generate a patch**  
   ```bash
   scripts/make-patch.sh "Your commit message"
   ```

3. **Apply & push**  
   ```bash
   scripts/apply-patches.sh
   ```

Consult `patch_workflow.md` for the detailed, step-by-step flow.
