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

echo "== gate 1/6: card contract =="
python3 asset-dev/check_cards.py

echo "== gate 2/6: pack registration integrity =="
python3 asset-dev/check_packs.py

echo "== gate 3/6: art sync =="
python3 asset-dev/check_sync.py

echo "== gate 4/6: mirror drift =="
DRIFT=0
while IFS= read -r f; do
  rel="${f#game-src/}"
  [ "$rel" = "README.md" ] && continue
  cmp -s "$f" "$LIVE/$rel" || { echo "DRIFT: $rel"; DRIFT=1; }
done < <(find game-src -type f)
[ "$DRIFT" = "0" ] || { echo "FAIL: mirror drift"; exit 1; }
echo "mirror clean"

echo "== gate 4a: hub geometry =="
python3 asset-dev/check_hub_geometry.py

echo "== gate 4b: parse every hand-edited script (lazily-loaded scenes included) =="
PARSE_LIST=$(cd "$REPO/game-src" && find . -name '*.gd' | sed 's|^\./||' | grep -v '^README')
GOURMET_PARSE_LIST="$PARSE_LIST" "$GODOT" --path "$LIVE" -s "$REPO/asset-dev/check_parse.gd" 2>&1 | grep "PARSE" | tee /tmp/parse_gate.out
grep -q "PARSE GATE: all" /tmp/parse_gate.out || { echo "FAIL: parse gate"; exit 1; }

echo "== gate 5/6: runtime boot (loads the real save) =="
SMOKE="$(mktemp)"
"$GODOT" --path "$LIVE" --quit > "$SMOKE" 2>&1 || { echo "BOOT FAILED"; tail -30 "$SMOKE"; exit 1; }
if grep -qiE "parse error|script error" "$SMOKE"; then
  echo "BOOT ERRORS:"; grep -iE "parse error|script error" "$SMOKE" | head -20; exit 1
fi
grep -q "PackService VERIFY: OK" "$SMOKE" || { echo "FAIL: PackService runtime VERIFY did not pass:"; grep "PackService" "$SMOKE" || true; exit 1; }
grep "PackService" "$SMOKE"

echo "== gate 6/6: lobby scene smoke =="
LSMOKE="$(mktemp)"
"$GODOT" --path "$LIVE" res://ui/lobby/lobby.tscn --quit > "$LSMOKE" 2>&1 || { echo "LOBBY SCENE FAILED"; tail -20 "$LSMOKE"; exit 1; }
if grep -qiE "parse error|script error" "$LSMOKE"; then
  echo "LOBBY ERRORS:"; grep -iE "parse error|script error" "$LSMOKE" | head -10; exit 1
fi
grep -q "Lobby ready: 4 station(s), 4 building(s), 6 slots" "$LSMOKE" || { echo "FAIL: lobby ready line wrong (want 4 stations (shuttle+booth+shrine+board), 4 pack buildings all-on (fortune merged into forge), 6 slot anchors)"; grep "Lobby ready" "$LSMOKE" || tail -10 "$LSMOKE"; exit 1; }
grep "Lobby ready:" "$LSMOKE"

echo ""
echo "ALL 6 GATES PASSED (static + runtime)."
