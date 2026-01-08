#!/usr/bin/env bash
set -euo pipefail

# This script removes a committed `venv` directory from the git index and commits the
# .gitignore change that excludes virtualenvs. It DOES NOT delete your local venv files.
# Run this from the repository root on your machine (not on the droplet):
#   ./scripts/remove_committed_venv.sh

echo "Removing committed venv from git index (won't delete working tree venv)..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  git rm -r --cached venv || true
  git add .gitignore
  if git diff --staged --quiet; then
    echo "No staged changes to commit. If you already removed venv from the index, nothing to do."
  else
    git commit -m "Ignore venv and remove committed virtualenv"
    echo "Committed removal. Now run: git push origin main"
  fi
else
  echo "Not a git repository. Run this from your local repo root."
  exit 1
fi
