#!/usr/bin/env bash
# tools/verify.sh — run BEFORE you commit/push. Local mirror of the CI guard.
# Usage: bash tools/verify.sh
set -euo pipefail

git fetch origin main --quiet
BASE=origin/main

echo "== files changed vs $BASE =="
git diff --stat "$BASE"...HEAD

echo ""
echo "== Gate 1: uid (re-serialization only; add/remove of resources is allowed) =="
# A uid is "bad" only when the SAME path keeps existing but its uid CHANGED
# (that is the Godot whole-scene re-serialization signature, e.g. the 188-line incident).
# Removing a resource outright (path+uid gone, not re-added) is legitimate and allowed.
DIFF=$(git diff "$BASE"...HEAD -- '*.tscn' '*.tres')
BAD=""
removed=$(printf '%s\n' "$DIFF" | grep -E '^-.*uid://.*path=' || true)
while IFS= read -r line; do
  [ -z "$line" ] && continue
  p=$(printf '%s' "$line" | grep -oE 'path="[^"]+"')
  u=$(printf '%s' "$line" | grep -oE 'uid://[a-z0-9]+')
  [ -z "$p" ] && continue
  added=$(printf '%s\n' "$DIFF" | grep -F "$p" | grep -E '^\+.*uid://' || true)
  if [ -n "$added" ]; then
    au=$(printf '%s' "$added" | grep -oE 'uid://[a-z0-9]+' | head -1)
    [ "$au" != "$u" ] && BAD="${BAD}${p}: uid ${u} -> ${au}\n"
  fi
done < <(printf '%s\n' "$removed")
if [ -n "$BAD" ]; then
  echo "FAIL: uid changed for an existing resource (same path, new uid = Godot re-serialization)."
  printf '%b' "$BAD"
  echo "Fix: edit the .tscn as TEXT; never re-save the scene through the editor for a change."
  exit 1
fi
echo "OK: no uid re-serialization (adding/removing resources is fine)."

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
