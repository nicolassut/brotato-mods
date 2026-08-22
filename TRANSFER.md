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

## Transfer tags - the zero-confusion rule

Every completed transfer ends by tagging the synced commit on BOTH machines'
history: `git tag transfer-YYYYMMDD && git push --tags`. From then on, "what
changed since we last synced" is not a judgement call - it is literally:

    git diff --name-status $(git describe --tags --match 'transfer-*' --abbrev=0)..origin/main

Every file in that list is authoritative from the SENDER - the sender changed
it after the last sync, so the incoming version wins, no matter how it looks.
Art especially: NEVER decide old-vs-new by appearance or file size. The only
exception: if the receiving machine ALSO changed the same file since the tag,
that is a real conflict - STOP, render both versions side by side, and let the
user pick. Record the choice in the commit message.

## Godot binary + the image-import trap (read once per machine)

The scripts (`apply_to_live.sh`, `check_all.sh`, `check_pack_matrix.sh`,
`check_workshop.sh`) auto-detect Godot 3: `$GODOT` if set, then the macOS app
paths, then `godot3`/`godot` on PATH, then common Windows install paths. If none
match they FAIL with instructions. On Windows set it once:

    export GODOT='/c/Program Files/Godot/Godot_v3.6-stable_win64.exe'   # add to ~/.bashrc

**Why this matters for images:** a committed `foo.png.import` is only a RECEIPT
pointing at binary texture data in `<live>/.import/` - and that cache is
local-only, it never travels. The receiving machine rebuilds it in
`apply_to_live.sh` step 3 (the 35s editor session). If Godot cannot be found,
that step is skipped and every new PNG arrives with a receipt but no data, so
textures silently fail to load. Step 3b now verifies this and fails loudly.
If it ever reports missing cache: `rm -rf ~/brotato-decompiled/.import` and
rerun `./apply_to_live.sh` (Godot rebuilds all textures - slower, bulletproof).

## Local-only trees (these NEVER travel through git)

Three things live outside the repo on each machine and must exist locally:

1. `~/brotato-decompiled/` - the live game. Rebuilt from the repo by
   `./apply_to_live.sh`; never copied between machines.
2. `~/brotato-vanilla-reference/` - the PRISTINE 1.1.15.4 decompile, used by the
   workshop tooling to diff mod-vs-vanilla. **`asset-dev/build_workshop.py`,
   `asset-dev/gen_extensions.py` and `check_workshop.sh` HARD-FAIL without it**
   ("no pristine reference found"). `apply_to_live.sh` does NOT need it, so a
   normal transfer is unaffected. To create it on a machine that lacks it:
   download GDRE Tools (GDRETools/gdsdecomp releases, v2.6.0) and run
   `<GDRE> --headless --recover=<Brotato.pck> --output=$HOME/brotato-vanilla-reference`.
   Never edit that tree.
3. The Steam `Brotato.pck` itself (the recovery source).

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
2. `git -C ~/brotato-mods fetch origin`, then compute the authoritative
   change list BEFORE merging:
   `git diff --name-status $(git describe --tags --match 'transfer-*' --abbrev=0)..origin/main`
   Every file in that list is the sender's work since the last sync: the
   INCOMING version wins on any conflict, no matter how it looks - never
   judge art or data by appearance, size, or gut feeling. Then
   `git merge origin/main`. A file is only a genuine decision point if THIS
   machine also changed it since the last transfer tag - in that case stop,
   render both versions side by side, and ask the user to pick. For
   `packs/*/pack_data.tres` and `custom_translations.csv` conflicts, the union of
   both sides is almost always correct (registrations and translation rows
   are additive). After resolving, `python3 asset-dev/check_cards.py` must
   exit clean before you commit the merge.
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
   work next time.
6. Tag the sync point and push it:
   `git tag transfer-$(date +%Y%m%d) && git push --tags`
   (if the tag exists already today, suffix it: transfer-YYYYMMDD-2).
7. Launch the game and confirm it boots to the character select.

Report exactly what merged, any conflicts and how you resolved them, and the
gate outputs.

---

## Notes for whoever runs this

- The push/pull direction is symmetric: BOTH machines should end every session
  with a push, then the next transfer is a 2-minute pull + script run.
- `apply_to_live.sh` is idempotent - running it twice is harmless.
- The live tree's `.import` cache never travels and never needs to; the editor
  session in the script rebuilds it.
