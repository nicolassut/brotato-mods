#!/bin/bash
# Boot matrix for the pack system: 4 canonical combinations, each must boot with
# zero script errors and a passing PackService VERIFY. Run when touching packs,
# registration, or engine seams (slower than check_all.sh - 4 real boots).
set -euo pipefail
LIVE="$HOME/brotato-decompiled"
GODOT="$HOME/Applications/Godot3.app/Contents/MacOS/Godot"
expect_for() {
  case "$1" in
    all)           echo 'enabled=\[food, forge, fortune, ledger, roster\]' ;;
    none)          echo 'enabled=\[\]' ;;
    food)          echo 'enabled=\[food\]' ;;
    fortune,forge) echo 'enabled=\[forge, fortune\]' ;;
  esac
}
for COMBO in all none food fortune,forge; do
  SMOKE="$(mktemp)"
  "$GODOT" --path "$LIVE" --packs="$COMBO" --quit > "$SMOKE" 2>&1 || { echo "FAIL($COMBO): boot died"; tail -20 "$SMOKE"; exit 1; }
  if grep -qiE "parse error|script error" "$SMOKE"; then
    echo "FAIL($COMBO): script errors"; grep -iE "parse error|script error" "$SMOKE" | head -10; exit 1
  fi
  if ! grep -q "PackService VERIFY: OK" "$SMOKE"; then
    echo "FAIL($COMBO): VERIFY missing/failed"; grep "PackService" "$SMOKE" || true; exit 1
  fi
  if ! grep -qE "$(expect_for "$COMBO")" "$SMOKE"; then
    echo "FAIL($COMBO): enabled set mismatch:"; grep "PackService:" "$SMOKE"; exit 1
  fi
  echo "PASS($COMBO): $(grep 'PackService:' "$SMOKE" | head -1)"
done
echo "PACK MATRIX PASSED (all, none, food, fortune+forge)"
