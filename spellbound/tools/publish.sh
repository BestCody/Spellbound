#!/usr/bin/env bash
# Publish as a NEW repository; never overwrite or force-push an existing one.
set -euo pipefail
cd "$(dirname "$0")/.."
name="${1:-spellbound}"
visibility="${2:-public}"
[[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid repository name' >&2; exit 2; }
[[ "$visibility" == public || "$visibility" == private ]] || { echo 'Use public or private' >&2; exit 2; }
command -v git >/dev/null || { echo 'Install Git first' >&2; exit 2; }
command -v gh >/dev/null || { echo 'Install GitHub CLI and run gh auth login' >&2; exit 2; }
gh auth status
owner="$(gh api user --jq .login)"
id="$(gh api user --jq .id)"
if gh repo view "$owner/$name" --json nameWithOwner >/dev/null 2>&1; then
  echo "$owner/$name already exists. Choose a new name; no changes made." >&2; exit 1
fi
[[ -e .git ]] || git init -b main
if git remote get-url origin >/dev/null 2>&1; then
  echo 'origin already exists; refusing to replace it.' >&2; exit 1
fi
git add --all
if ! git diff --cached --quiet; then
  git -c "user.name=$owner" -c "user.email=$id+$owner@users.noreply.github.com" commit -m 'Implement Spellbound badge duels'
fi
gh repo create "$owner/$name" "--$visibility" --source . --remote origin --push \
  --description 'Teachable motion-controlled spellcasting duels for the Hack the North 2026 badge'
gh repo view --json url --jq .url
