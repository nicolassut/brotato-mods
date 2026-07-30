# brotato-mods - rules for every Claude session

**Several Claude sessions work in this repo at the same time, and work sits uncommitted for
hours.** Everything below follows from that. These rules are not style preferences; each one
exists because ignoring it has already cost work.

## Git

**1. Commit early and often.** Commit each coherent chunk the moment it builds and verifies -
do not batch a whole session into one commit at the end. `git commit` can never lose work; it
only records the tree. Uncommitted work is unprotected work.

**2. Never run a git command that rewrites the working tree.** Specifically:

```
git checkout <file>     git restore <file>     git reset --hard
git stash               git clean
```

These silently destroy uncommitted changes - yours *and* whatever another session has in
flight - and uncommitted changes are not in the object database, so nothing can bring them
back. On 2026-07-29 a single `git checkout` on `game-src/singletons/run_data.gd` wiped ~16
uncommitted edits; it was recoverable only because `~/brotato-decompiled/` happened to hold a
synced copy. To undo one file, restore it from `~/brotato-decompiled/` or from a backup.

**3. Stage explicit paths, never `git add -A` / `git add .`** unless you have just confirmed
the working tree holds nothing but your own edits (`git status --short`, then check mtimes).
Another session is probably mid-feature; sweeping their half-finished files into your commit
entangles their work with yours.

**4. Before anything risky, back up physically:**

```bash
rsync -a --exclude '.git' ~/brotato-mods/ ~/brotato-mods-backups/$(date +%Y%m%d-%H%M%S)/
```

`~/brotato-decompiled/` now has a **local-only** safety-net repo (source files only; art and
`.import` are gitignored). It is never pushed. The Godot editor writes straight into that tree,
and a single stray keystroke saved into an autoload takes down startup. That happened twice in
one day. Before blaming the mod for a crash, check there first:

```bash
git -C ~/brotato-decompiled diff                    # what changed under me?
git -C ~/brotato-decompiled checkout -- <file>      # undo an accidental edit
```

Commit a baseline there after any deliberate engine change, or real edits pile up as noise and
hide the next accident.

**5. Commit author email** must be `127490046+nicolassut@users.noreply.github.com` (matches the
existing history). Do not push unless asked.

## The two trees

- `~/brotato-decompiled/` - the live game. Local-only safety-net repo, source files only.
- `game-src/` - a mirror of the ~49 hand-edited live files that nothing regenerates. **This is
  the only copy of those files that has history.**

Edit either, but **re-sync and verify before you commit**, or the mirror silently goes stale:

```bash
cd ~/brotato-mods && while IFS= read -r f; do rel="${f#game-src/}"; [ "$rel" = "README.md" ] && continue; cmp -s "$f" "$HOME/brotato-decompiled/$rel" || echo "DRIFT: $rel"; done < <(find game-src -type f)
```

`game-src/items/custom/custom_translations.csv` is in the mirror on purpose: 55 of its rows
exist nowhere else and no builder can regenerate them. Never treat it as generated output.

## Before committing card, text, food or item changes

```bash
python3 asset-dev/check_cards.py
```

It enforces the card contract (scaling-arg counts, food naming, display effects, tracker
chains, duration agreement) across every registered card. It must exit clean. If you change
`items/global/effect.gd` or `ui/menus/shop/item_description.gd`, update `check_cards.py` in the
same commit or it will start lying.

Builders write into `~/brotato-decompiled/`. After running any of them, confirm
`singletons/item_service.tscn` did not drift - a builder re-registering items that were
deliberately deregistered is a known failure mode.
