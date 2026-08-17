#!/bin/bash
# Deterministic repo -> live-game install. Run from anywhere; operates on THIS
# clone and $HOME/brotato-decompiled. This is the ONLY supported way to bring a
# machine's live tree up to date after a git pull - no guessing, no manual copying.
#
# What it does, in order:
#   1. Run the CURRENT-generation builders (they write tres/pngs/.import files
#      into the live tree from the repo's tracked canonical finals; registration
#      goes to packs/<id>/pack_data.tres via pack_registry.py - NEVER the tscn).
#   2. Copy the game-src mirror over the live tree (hand-edited engine files,
#      the vanilla-only item_service.tscn, pack files, custom_translations.csv). Mirror runs LAST so
#      the repo's registry/translations are always authoritative.
#   3. A 35s Godot EDITOR session so new/changed textures actually reimport
#      (a plain launch will NOT rescan; "-e --quit" exits before the scan).
#   4. Verification gates: check_cards, check_sync, boot smoke test.
#
# NEVER run the legacy builders build_mod_items.py / build_decompiled_items.py
# (1-indexed tiers, corrupt live data) or patch_item_service.py (dead one-shot,
# hard-disabled).

set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/brotato-decompiled"
GODOT="$HOME/Applications/Godot3.app/Contents/MacOS/Godot"

cd "$REPO"

echo "== 1/4 builders =="
python3 asset-dev/build_food_system.py
python3 asset-dev/characters/build_characters.py
python3 asset-dev/p2w/build_chests.py

echo "== 2/4 mirror game-src -> live =="
while IFS= read -r f; do
  rel="${f#game-src/}"
  [ "$rel" = "README.md" ] && continue
  mkdir -p "$LIVE/$(dirname "$rel")"
  cp "$f" "$LIVE/$rel"
done < <(find game-src -type f)

echo "== 3/4 editor import session (35s, imports new textures) =="
pkill -f "Godot" 2>/dev/null || true; sleep 2
"$GODOT" --path "$LIVE" -e > /dev/null 2>&1 &
GPID=$!
sleep 35
kill "$GPID" 2>/dev/null || true; sleep 2
pkill -f "Godot" 2>/dev/null || true; sleep 1

echo "== 4/4 gates =="
python3 asset-dev/check_cards.py
python3 asset-dev/check_sync.py
python3 asset-dev/check_packs.py
SMOKE="$(mktemp)"
"$GODOT" --path "$LIVE" --quit > "$SMOKE" 2>&1 || { echo "BOOT FAILED"; tail -30 "$SMOKE"; exit 1; }
if grep -qiE "parse error|script error" "$SMOKE"; then
  echo "BOOT ERRORS:"; grep -iE "parse error|script error" "$SMOKE" | head -20; exit 1
fi
echo ""
echo "ALL GATES PASSED - live tree is up to date. Launch the game normally."
