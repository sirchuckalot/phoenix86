# Patch Workflow
Recap of the final workflow

From here on out you’ve got a fully automated, error‑resilient patch workflow.

## 1. Fetch + clean state (only needed if you ever get out of sync)

```bash
git fetch origin main
git switch main
git reset --hard origin/main
git clean -fdx
```

## 2. Stage your changes

```bash
git add <files>
```

## 3. Generate a patch

```bash
scripts/make-patch.sh "Describe what you changed"
```
↪ writes patches/000N-Describe-what-you-changed.patch

## 4. Apply & push

```bash
scripts/apply-patches.sh
```
↪ resets to origin/main, git am-s each patch, then git push

---
