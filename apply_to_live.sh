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

# Import-cache verification. A committed *.png.import receipt points at a binary
# res://.import/<name>-<md5>.stex that is LOCAL-ONLY and never travels; if the
# editor pass above did not regenerate it, the texture silently fails to load
# ("No loader found for resource"). This turns that into a loud, fixable error.
echo "== 3b/4 import cache verify =="
python3 - "$LIVE" <<'IMPORTCHECK'
import os, re, sys
live = sys.argv[1]
missing, orphans = [], []
for root, dirs, files in os.walk(live):
    dirs[:] = [d for d in dirs if d not in (".git", ".import")]
    for f in files:
        if not f.endswith(".import"):
            continue
        path = os.path.join(root, f)
        try:
            text = open(path).read()
        except Exception:
            continue
        rel = os.path.relpath(path, live)
        if not os.path.exists(path[:-len(".import")]):
            orphans.append(rel)          # renamed/deleted art: harmless leftover
            continue
        for stex in re.findall(r'res://(\.import/[^"]+)', text):
            if not os.path.exists(os.path.join(live, stex)):
                missing.append(rel)      # REAL breakage: texture will not load
                break
if orphans:
    print("note: %d orphan import receipt(s) with no source file (safe to delete)" % len(orphans))
if missing:
    print("FAIL: %d texture(s) have an import receipt but NO cached .stex:" % len(missing))
    for m in missing[:12]:
        print("   ", m)
    print("REMEDY: delete the stale cache and re-import:")
    print("   rm -rf '%s/.import'   then rerun ./apply_to_live.sh" % live)
    print("   (Godot rebuilds every texture; slower but bulletproof)")
    sys.exit(1)
print("import cache OK: every texture with a receipt has its cached data")
IMPORTCHECK

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
