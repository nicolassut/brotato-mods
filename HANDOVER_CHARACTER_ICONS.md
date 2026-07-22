# HANDOVER: Making Character Icon Sets (the full composite system)

This is the specialist guide for CHARACTER art. Read `HANDOVER_ART_PIPELINE.md` first (the
generation/edit/vectorize bible; its style law, PixelLab rules, editing recipes and the
mandatory double-check ritual all apply here). This file adds everything specific to
characters: what a "set" is, the potato anatomy, the recipe machinery, and the workflow that
produced all 14 existing characters. Follow it exactly; every rule maps to a past failure.

## 1. What one "character icon set" actually is

Every character ships as a matched set derived from ONE composite recipe, so the select-screen
icon and the in-game body can never drift apart:

1. **96×96 selection icon** (`asset-dev/characters/final/<slug>_icon.png`): a baked crop of
   the full composite, framed to vanilla proportions.
2. **150×150 face/features overlay** (`final/appearances/<slug>_face.png`): every layer that
   sits ON TOP of the body (eyes, mouth, hats, props), full-frame, pre-aligned to the potato.
   Installed as `<slug>_face_appearance.tres`: position 0 (OTHER), depth 600, priority 0.
3. **Optional 150×150 full-body skin** (`final/appearances/<slug>_skin.png`) for recolored
   characters (zombie green, slug sage, mole tan): the tinted potato itself. Installed as
   `<slug>_skin_appearance.tres`: position 14 (SKIN), depth 1.0, priority 3 (the vanilla
   Golem/Cyborg pattern).
4. **Leg tint**: recolored bodies need matching feet: `legs_modulate` Color on CharacterData
   (a field we added; applied in `player.gd` ~line 348). The color table lives in
   `build_characters.py` `LEGS_MOD` (roughly body tint × the legs' lighter base, e.g. zombie
   (0.581, 0.961, 0.470)).

## 2. Potato anatomy + the appearance engine (memorize these numbers)

- Base body: `brotato-decompiled/entities/units/player/potato.png`, 150×150.
  **Head bbox ≈ (45,38)-(104,107). Face centre x ≈ 74.5. Body bottom y ≈ 107.**
- Brotato faces are NOT symmetric-front: they look slightly to the viewer's RIGHT. Real
  feature clusters centre around **x ≈ 81-82** (well_rounded pupils sit at x≈68 and x≈96).
  A dead-centred custom face reads wrong next to vanilla (the Mime needed this exact fix).
- Appearance pieces are **150×150 full-frame overlays pre-aligned to the body**. The art is
  positioned inside the canvas, and at runtime `player.gd apply_items_effects()` just stacks
  them as child Sprites of the body at the same origin. There is NO runtime placement.
- `ItemAppearanceData` fields: `position` = slot enum (0 OTHER unlimited stacking, 1
  ABOVE_HEAD, 4 HAT, 5 FOREHEAD, 6 EYES, 7 NOSE, 8 MOUTH, 11 TORSO, 14 SKIN, 15 TAIL...).
  Non-OTHER slots are exclusive: highest `display_priority` wins the slot. `depth` is
  z-order; depth < -1 renders BEHIND the body. We ship the whole face as ONE merged OTHER
  overlay (simple, cannot be displaced by items), and skins at SKIN/1.0/3 so the character's
  body beats item skins.
- **The select screen never crops icons**: 96×96 TextureRect, expand, 1:1, no clipping.
  So nothing gets "cut off by the UI". If something looks cut, the PNG itself is wrong.
- Icon framing law (from measuring vanilla): heads fill ≈ **0.76 W × 0.88 H** of the 96 frame,
  bottom-anchored on a shared baseline. Accessory characters legitimately vary (tall hats
  make the head smaller); the rule is NO WASTED SPACE, not identical head sizes.

## 3. The machinery (two scripts run everything)

### `asset-dev/characters/build_roster.py`, the composer
- `RECIPES`: `name -> (body_tint_or_None, [real part names], [custom placed layers])`.
- `part(sub)` loads a REAL game piece by filename stem from `items/characters/*/`(+
  `/appearances/`) and the Abyssal DLC equivalents. All are 150×150 pre-aligned. This is a
  LIBRARY of ~50 characters × eyes/mouths/hats: **always shop here first**. Known-good picks
  we used: eyes = well_rounded/apprentice/old/brawler/sick/loud/engineer/crazy/generalist/
  arms_dealer; mouths = well_rounded/king/old/hunter/sick/crazy/fisherman(smile)/explorer
  (beard)/loud; hats+props = gangster_app_2 (fedora), chef_app_2 (chef hat+apron),
  hiker_app_2, king_crown, wounded_forehead (bandage). Borrowed parts are free, perfectly
  on-model, and never misaligned.
- Custom pieces come from `Brotato Icons/character_pieces_vectorized/` (user-vectorized,
  timestamp-named). Load pattern: open, crop to bbox, optional repair at load (the bowler:
  merge charcoal interior into solid black so it does not read hollow, then squash height
  ×0.68 because generations run tall) → assign to a constant. Code-draw ONLY simple geometry
  (the Pierrot face, blood splats), and match the house rules (irregular shapes, thick
  borders; "perfect circles with thin borders" was rejected).
- `place_c(piece, cx, cy, w, flip=False)`: content-crop, scale to width w, centre the CONTENT
  at (cx, cy) in the 150 frame. All placement is body-coordinates. Sweep placements with an
  option GRID (2-3 candidates rendered side by side), LOOK, then lock.
- `tint(BODY,(r,g,b))` makes skins. Sample the target color from the piece it must match
  (the slug's stalk green was measured, not guessed: body flesh ≈ (246,246,246), so tint
  factors = target/246).
- `features_of()` produces the face overlay; body+features = the composite; `APP` dict
  exports face/skin PNGs; `bake()` makes the icon: content-crop, scale max dim to 0.92×96, x so BODY_CX(74.5) lands at 48, y so BODY_BOTTOM(107) lands on baseline 90, clamp inside the frame (never crop). It also renders the roster sheet for review.

### `asset-dev/characters/build_characters.py`, the installer
Copies `final/` icons + appearances into `brotato-decompiled/items/custom_characters/<slug>/`,
writes the `_appearance.tres` wrappers, and the CharacterData references them (`SKINNED` set
gates the skin, `LEGS_MOD` writes legs_modulate). Delete stale `*_effect_*.tres` before
re-running. It never needs touching for pure art changes, build_roster then build_characters.

## 4. The workflow for a NEW character set, step by step

1. **Brief.** The design comes from the user / CHARACTER_SPECS.md. Never invent identity.
2. **Decompose the look**: which parts can be BORROWED from the real library (always prefer),
   which need CUSTOM pieces, whether the body is tinted. One or two custom pieces max per
   character is the norm (mime face+beret, cow horns+nose, snail stalks, juggler bowler).
3. **Custom pieces** go through the art pipeline handover: PixelLab (isolated object, thick
   outline, size 180 single candidate; or cut the part from a larger generation like the
   snail eyes), judge, edit, deliver pixel final, user vectorizes, load from the
   vectorized folder. Generate KNOWING the placement: a hat must be drawable as WORN (dome
   caps the crown), not a floating product shot.
4. **Write the recipe** and tune placements with option grids ON THE POTATO. Verify with
   numbers, not eyes alone: print each layer's content span (x/y bbox) and check it against
   the head box and the frame; a piece "barely fitting" means its span stays inside the bake.
   Classic placements for reference: beret place_c(74,43,60,flip), horns (74,36,64), cow nose
   (79,89,30), stalks (74,33,48), bowler (78,48,84 after ×0.68 squash).
5. **Bake + review**: run build_roster.py; view the per-character 4-6× render AND the roster
   sheet WITH 2-3 vanilla icons in the same image for size/style comparison. Checklist:
   same visual language as neighbors, head fills the frame like vanilla, nothing clipped,
   piece reads as attached (not floating), gaze direction matches (viewer-right), line
   weights consistent with the potato outline.
6. **Install + validate**: build_characters.py, then the standard static validation (all
   res:// refs resolve, tabs untouched). Remind the user: editor re-imports PNGs on focus;
   testing needs a fresh game process and a NEW run (saves/Restart serialize old resources).
7. **Iterate from the user's screenshots.** They will click every character. Fix by
   measurement (piece spans, fill fractions), not nudge-and-hope.

## 5. Pitfall catalog (each of these shipped wrong once, check for ALL of them)

- **Piece covers a facial feature** (the cow nose sat on the eye through FIVE fixes: measure
  the eye part's y-span vs the piece's y-span; choose eyes that sit higher if needed).
- **Hat floats or swallows the head**: dome must cap the crown; potato bulging out the sides
  or poking through the brim = wrong width/height; squash tall domes; sweep cy.
- **Piece off-frame**: tall pieces must clear the bake window; verify the baked icon's
  content bbox, not just the 150 composite.
- **Icons too small next to vanilla** (the whole resize saga): the bake targets exist.
  Measure fill W/H of YOUR icon and vanilla's in one script.
- **Straight-on face** on a 3/4-view roster (mime): shift the cluster to x≈81, pupils nudged
  right.
- **Tinted body without matching legs/skin**: SKINNED + LEGS_MOD or the character has white
  feet and a white in-game body.
- **In-game body not matching the icon**: never hand-make an icon without exporting the
  matching face overlay from the SAME composite.
- **Cut-part edges showing a flat line**: alpha-taper the cut (snail stalks).
- **Vectorizer artifacts**: double outlines and residual shading trace badly; deliver clean
  flat regions (but never destructively flatten already-clean art).
- **Presenting without looking**: render the exact final files (icon + mock) and inspect
  before every handoff. No exceptions.

## 6. Where everything lives

- Composer/installer: `brotato-mods/asset-dev/characters/build_roster.py`,
  `build_characters.py`. Outputs: `asset-dev/characters/final/` (+`/appearances/`).
- Custom piece staging: `Brotato Icons/character_pieces_to_vectorize/` (yours, pixel finals)
  → `Brotato Icons/character_pieces_vectorized/` (user's vectorized returns).
- Reference art: vanilla characters `brotato-decompiled/items/characters/<name>/`,
  DLC `dlcs/dlc_1/characters/<name>/`, body `entities/units/player/potato.png`.
- The 14 finished characters are the house-style reference; their recipes in RECIPES are
  worked examples of every technique above.
- Sibling docs: `HANDOVER_ART_PIPELINE.md` (generation/editing bible),
  `HANDOVER_FOOD_SYSTEM.md` (systems side), `asset-dev/characters/CHARACTER_SPECS.md`
  (design law).
