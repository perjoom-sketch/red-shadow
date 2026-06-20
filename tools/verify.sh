#!/usr/bin/env bash
# tools/verify.sh — run BEFORE you commit/push. Local mirror of the CI guard.
# Usage: bash tools/verify.sh
set -euo pipefail

git fetch origin main --quiet
BASE=origin/main

echo "== files changed vs $BASE =="
git diff --stat "$BASE"...HEAD

echo ""
echo "== Gate 1: uid =="
BAD=$(git diff "$BASE"...HEAD -- '*.tscn' '*.tres' | grep -E '^-.*uid://' || true)
if [ -n "$BAD" ]; then
  echo "FAIL: uid:// removed/changed in a scene/resource (Godot re-serialization)."
  printf '%s\n' "$BAD"
  exit 1
fi
echo "OK: no uid regeneration."

# Gate 2 runs only if godot is on PATH (skipped otherwise; CI still enforces it).
if command -v godot >/dev/null 2>&1; then
  echo ""
  echo "== Gate 2: parse (local godot) =="
  godot --headless --import --path . >/tmp/import.log 2>&1 || true
  if grep -E 'SCRIPT ERROR|Parse Error|Cannot infer|Failed to load' /tmp/import.log; then
    echo "FAIL: Godot parse/import errors."
    exit 1
  fi
  echo "OK: parse clean."
fi

echo ""
echo "ALL GATES PASSED. Now stage EXPLICIT paths only:  git add <path1> <path2>"
echo "(never 'git add -A' / 'git add .')"
