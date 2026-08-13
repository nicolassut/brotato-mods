#!/usr/bin/env python3
"""
check_sync.py - "nothing gets missed cross-machine" guard.

The mod's art lives in the LIVE game (~/brotato-decompiled) but only travels to another machine
if it has a git-TRACKED source under asset-dev/*/final/ that a builder re-installs. A live texture
with no tracked final is an orphan: it works here, and silently vanishes on a fresh build elsewhere
(this is how "entire reworks and every texture" got missed).

This scans every custom texture in the live game and confirms it has a tracked final. Run it
before pushing a content change. Exits non-zero if anything would be missed.

Coverage:
  - character icons     live items/custom_characters/<slug>/<slug>_icon.png -> asset-dev/characters/final/<slug>_icon.png
  - character bodies    live .../<slug>_face.png (+ _skin.png)              -> asset-dev/characters/final/appearances/<slug>_face.png
  - foods               live items/foods/<slug>/<slug>.png                 -> asset-dev/foods/final/<slug>.png
  - spawners + items    live items/custom/<slug>/<slug>.png                -> asset-dev/items_food_system/final/<slug>.png
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DEC  = os.path.expanduser("~/brotato-decompiled")

# git-tracked set (relative to the repo)
try:
    TRACKED = set(subprocess.check_output(["git", "-C", REPO, "ls-files"], text=True).splitlines())
except Exception as e:
    print(f"WARN: could not read git ls-files ({e})"); TRACKED = set()
# every tracked basename, so "is this art in the repo AT ALL" is a lookup. A live texture whose
# basename is tracked nowhere is a HARD orphan - it cannot travel and WILL be missed.
TRACKED_BASENAMES = {}
for p in TRACKED:
    TRACKED_BASENAMES.setdefault(os.path.basename(p), []).append(p)

orphans, soft, checked = [], [], 0

def want(live_png, canonical_relpath, label):
    """live_png exists -> ideally at canonical_relpath (where the builder installs it). If the art
    is tracked somewhere else, it's SOFT (travels only if the right builder installs it). If tracked
    nowhere, it's a HARD orphan (will be missed)."""
    global checked
    if not os.path.exists(live_png):
        return
    checked += 1
    base = os.path.basename(live_png)
    if canonical_relpath in TRACKED:
        return  # perfect: builder-installed, tracked
    where = TRACKED_BASENAMES.get(base, [])
    if not where:
        orphans.append((label, f"art tracked NOWHERE in the repo (basename {base})"))
    else:
        soft.append((label, f"not at builder path {canonical_relpath}; tracked instead at: {where[0]}"))

def scan():
    # characters
    cdir = f"{DEC}/items/custom_characters"
    if os.path.isdir(cdir):
        for slug in sorted(os.listdir(cdir)):
            d = f"{cdir}/{slug}"
            if not os.path.isdir(d):
                continue
            want(f"{d}/{slug}_icon.png", f"asset-dev/characters/final/{slug}_icon.png", f"character icon [{slug}]")
            want(f"{d}/{slug}_face.png", f"asset-dev/characters/final/appearances/{slug}_face.png", f"character body [{slug}]")
            if os.path.exists(f"{d}/{slug}_skin.png"):
                want(f"{d}/{slug}_skin.png", f"asset-dev/characters/final/appearances/{slug}_skin.png", f"character skin [{slug}]")
    # foods
    fdir = f"{DEC}/items/foods"
    if os.path.isdir(fdir):
        for slug in sorted(os.listdir(fdir)):
            want(f"{fdir}/{slug}/{slug}.png", f"asset-dev/foods/final/{slug}.png", f"food [{slug}]")
    # spawners + items (share items/custom + the items_food_system/final source)
    idir = f"{DEC}/items/custom"
    if os.path.isdir(idir):
        for slug in sorted(os.listdir(idir)):
            want(f"{idir}/{slug}/{slug}.png", f"asset-dev/items_food_system/final/{slug}.png", f"spawner/item [{slug}]")

def main():
    if not os.path.isdir(DEC):
        print(f"live game not found at {DEC} - run this on a machine that has it"); return 0
    scan()
    if orphans:
        print(f"\nHARD ORPHANS: {len(orphans)} live texture(s) whose art is tracked NOWHERE in the "
              f"repo - these WILL be missed on another machine:\n")
        for label, why in orphans:
            print(f"  - {label}: {why}")
    if soft:
        print(f"\nMISPLACED: {len(soft)} live texture(s) whose art IS in the repo but not where the "
              f"builder installs from (travels only if the matching builder runs; consolidate into "
              f"the canonical final/ dir for reliability):\n")
        for label, why in soft[:80]:
            print(f"  - {label}: {why}")
        if len(soft) > 80:
            print(f"  ... and {len(soft)-80} more")
    if not orphans and not soft:
        print(f"sync OK: {checked} live textures all install from a tracked canonical final - "
              f"nothing will be missed.")
        return 0
    print(f"\nChecked {checked}. Fix: save each texture to its canonical asset-dev/*/final/ path "
          f"and `git add` it so the builder re-installs it everywhere. See PIPELINE.md.")
    return 1 if orphans else 0  # hard orphans fail the gate; misplaced is a warning

if __name__ == "__main__":
    sys.exit(main())
