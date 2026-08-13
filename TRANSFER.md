# Cross-machine transfer - the one true procedure

Two machines work on this mod. Each has its own local-only live tree at
`~/brotato-decompiled`; the repo is the ONLY thing that travels. A transfer is
always: **push commits from machine A -> pull on machine B -> run
`./apply_to_live.sh` on B.** Nothing else. No manual copying of icons, no
re-deriving state, no rebuilding "the entire game".

Why past transfers were slow and lossy, and what fixed each cause:

1. Commits were not pushed, so the receiving machine reconstructed changes by
   guesswork. Fix: push after every session (`git push origin main`).
2. Art was installed into the live tree but its canonical final was never
   tracked, so the other machine could not regenerate it. Fix:
   `check_sync.py` now gates every commit - if it passes, EVERY live texture
   installs from a tracked `asset-dev/*/final/` file.
3. There was no deterministic installer, so each machine improvised builder
   runs. Fix: `apply_to_live.sh` - builders, mirror copy, editor import
   session, and all verification gates in one command.

## Paste-ready prompt for the Claude on the receiving machine

---

I need you to cleanly merge and install the latest mod work from the other
computer. The repo is `~/brotato-mods`, the live game tree is
`~/brotato-decompiled`. Read `CLAUDE.md` and `PIPELINE.md` first and follow
their git-safety rules exactly (no destructive git commands, no `git add -A`,
explicit paths only).

Steps, in order:

1. `git -C ~/brotato-mods status --short` - if THIS machine has uncommitted
   work (my local character changes or anything else), commit it now on main
   with explicit paths and a clear message. Nothing may be stashed, reset, or
   checked out.
2. `git -C ~/brotato-mods fetch origin`, then `git -C ~/brotato-mods merge
   origin/main`. If there are conflicts, resolve them by intent: keep BOTH this
   machine's changes (mainly characters) and everything incoming - the incoming
   work includes the P2W character (chests, reel ceremony), tri-color gumballs,
   HUD buff grid, rarity spread hand-edits, and many engine fixes. When a
   conflict touches `item_service.tscn` or `custom_translations.csv`, the
   union of both sides is almost always correct (registrations and translation
   rows are additive). After resolving, `python3 asset-dev/check_cards.py`
   must exit clean before you commit the merge.
3. `cd ~/brotato-mods && ./apply_to_live.sh` - this runs the current builders,
   copies the game-src mirror over the live tree, runs a 35-second Godot
   EDITOR session so new textures import, and then runs every verification
   gate. It must end with "ALL GATES PASSED".
   Do NOT run build_mod_items.py or build_decompiled_items.py (legacy,
   1-indexed tiers, corrupts data).
4. If this machine's own character changes touched files under `game-src/`,
   they are already in the live tree via the mirror copy. If they exist ONLY
   in the live tree (never mirrored), copy them into `game-src/` now, verify
   with the drift check in CLAUDE.md, and commit.
5. `git push origin main` so the other machine can pull this machine's
   character work next time.
6. Launch the game and confirm it boots to the character select.

Report exactly what merged, any conflicts and how you resolved them, and the
gate outputs.

---

## Notes for whoever runs this

- The push/pull direction is symmetric: BOTH machines should end every session
  with a push, then the next transfer is a 2-minute pull + script run.
- `apply_to_live.sh` is idempotent - running it twice is harmless.
- The live tree's `.import` cache never travels and never needs to; the editor
  session in the script rebuilds it.
