#!/bin/bash
# The FULL verification suite - one command, run before EVERY commit that touches
# engine files, builders, packs, or registration. Static gates alone are NOT
# proof (2026-08-17 lesson: they were green while save-resume was broken); this
# script also boots the real game, with whatever save exists, and requires the
# runtime self-test to pass.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/brotato-decompiled"
GODOT="$HOME/Applications/Godot3.app/Contents/MacOS/Godot"
cd "$REPO"

echo "== gate 1/5: card contract =="
python3 asset-dev/check_cards.py

echo "== gate 2/5: pack registration integrity =="
python3 asset-dev/check_packs.py

echo "== gate 3/5: art sync =="
python3 asset-dev/check_sync.py

echo "== gate 4/5: mirror drift =="
DRIFT=0
while IFS= read -r f; do
  rel="${f#game-src/}"
  [ "$rel" = "README.md" ] && continue
  cmp -s "$f" "$LIVE/$rel" || { echo "DRIFT: $rel"; DRIFT=1; }
done < <(find game-src -type f)
[ "$DRIFT" = "0" ] || { echo "FAIL: mirror drift"; exit 1; }
echo "mirror clean"

echo "== gate 5/5: runtime boot (loads the real save) =="
SMOKE="$(mktemp)"
"$GODOT" --path "$LIVE" --quit > "$SMOKE" 2>&1 || { echo "BOOT FAILED"; tail -30 "$SMOKE"; exit 1; }
if grep -qiE "parse error|script error" "$SMOKE"; then
  echo "BOOT ERRORS:"; grep -iE "parse error|script error" "$SMOKE" | head -20; exit 1
fi
grep -q "PackService VERIFY: OK" "$SMOKE" || { echo "FAIL: PackService runtime VERIFY did not pass:"; grep "PackService" "$SMOKE" || true; exit 1; }
grep "PackService" "$SMOKE"

echo ""
echo "ALL 5 GATES PASSED (static + runtime)."
