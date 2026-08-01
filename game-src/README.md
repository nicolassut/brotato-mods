# game-src — the Gourmet mod's engine edits

> **`items/custom/custom_translations.csv` lives here too, and it is NOT optional.** The
> builders regenerate most of its rows, but **55 of them exist nowhere else** — including
> `STAT_APPETITE`, the mod's own stat label, and hand-edits like `WEAPON_BAGUETTE,Bat-Guette`
> that no builder knows about. Lose the live file without this mirror and that text is gone
> with no source to rebuild it from. Re-sync it with the rest of this tree.

The mod is developed against a decompiled Brotato at `~/brotato-decompiled`, which is NOT a
git repo and lives outside this one. Everything under `items/custom/`, `items/foods/` and the
per-tier `weapons/*/<slug>/<n>/` folders is GENERATED, so it is reproducible on any machine by
running the builders in `asset-dev/`. These 46 files are not: they are hand-edited GDScript and
scene files, and nothing regenerates them. Without them the mod's mechanics simply are not there.

## Syncing to another machine

1. Get a decompiled Brotato at `~/brotato-decompiled` at the same game version.
2. Copy this whole tree over it, preserving paths (from the repo root):

```bash
rsync -a game-src/ ~/brotato-decompiled/
```

3. Regenerate the content the builders own:

```bash
cd asset-dev && python3 build_food_system.py && python3 build_weapons.py && python3 build_mod_items.py && python3 build_appetite_items.py && python3 build_pantry_items.py && python3 fix_mechanic_items.py && python3 characters/build_characters.py
```

4. Repack the mod and restart the game (the editor re-imports new PNGs on focus, but card
   text and script changes need a fresh process).

## Keeping this folder honest

It is a COPY, so it goes stale the moment someone edits `~/brotato-decompiled` directly.
Re-sync before every commit that touches engine code:

```bash
rsync -a --files-from=/tmp/gourmet_engine_files.txt ~/brotato-decompiled/ game-src/
```

The file list was built by grepping the decompiled tree for the mod's own vocabulary
(`Gourmet DLC`, `GourmetTracker`, `consumable_food_`, `soul_food`, `stat_appetite`,
`is_blacksmith`, the custom character ids, and so on). If you add an engine edit to a file
that carries none of those markers, add it here by hand or it will not travel.
