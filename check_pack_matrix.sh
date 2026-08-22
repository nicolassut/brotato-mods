#!/bin/bash
# Boot matrix for the pack system: 4 canonical combinations, each must boot with
# zero script errors and a passing PackService VERIFY. Run when touching packs,
# registration, or engine seams (slower than check_all.sh - 4 real boots).
set -euo pipefail
LIVE="$HOME/brotato-decompiled"
# Godot binary resolution (cross-platform - the other machine is Windows/git-bash
# and the old hardcoded macOS path made apply_to_live's IMPORT step unrunnable
# there, which is why new PNGs arrived unimported. Override with:  export GODOT=...)
if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then
  :
elif [ -x "$HOME/Applications/Godot3.app/Contents/MacOS/Godot" ]; then
  GODOT="$HOME/Applications/Godot3.app/Contents/MacOS/Godot"
elif [ -x "/Applications/Godot3.app/Contents/MacOS/Godot" ]; then
  GODOT="/Applications/Godot3.app/Contents/MacOS/Godot"
elif command -v godot3 >/dev/null 2>&1; then
  GODOT="$(command -v godot3)"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
else
  GODOT="$(ls -1 "/c/Program Files/Godot"/Godot_v3*.exe "$HOME/scoop/apps/godot/current/godot.exe" \
      "$LOCALAPPDATA/Programs/Godot/Godot_v3"*.exe 2>/dev/null | head -1)"
fi
if [ -z "${GODOT:-}" ] || [ ! -x "$GODOT" ]; then
  echo "FAIL: Godot 3 binary not found. Set it once for this shell, e.g.:"
  echo "  export GODOT='/c/Program Files/Godot/Godot_v3.6-stable_win64.exe'"
  echo "  (add that line to ~/.bashrc so every run picks it up)"
  exit 1
fi
expect_for() {
  case "$1" in
    all)           echo 'enabled=\[food, forge, ledger, roster\]' ;;
    none)          echo 'enabled=\[\]' ;;
    food)          echo 'enabled=\[food\]' ;;
    forge)         echo 'enabled=\[forge\]' ;;
    fortune)       echo 'enabled=\[forge\]' ;;
  esac
}
expect_synergy() {
  case "$1" in
    all)           echo 'active=\[mystery_meal\] hidden=\[\]' ;;
    none)          echo 'active=\[\] hidden=\[mystery_meal\]' ;;
    food)          echo 'active=\[\] hidden=\[mystery_meal\]' ;;
    forge)         echo 'active=\[\] hidden=\[mystery_meal\]' ;;
    fortune)       echo 'active=\[\] hidden=\[mystery_meal\]' ;;
  esac
}
# "fortune" combo boots the MERGED-ID ALIAS path (--packs=fortune must
# resolve to forge - saved runs and settings carry the old id)
for COMBO in all none food forge fortune; do
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
  if ! grep -qE "$(expect_synergy "$COMBO")" "$SMOKE"; then
    echo "FAIL($COMBO): synergy state mismatch:"; grep "synergies:" "$SMOKE"; exit 1
  fi
  echo "PASS($COMBO): $(grep 'PackService:' "$SMOKE" | head -1)"
done
echo "PACK MATRIX PASSED (all, none, food, forge, fortune-alias)"
