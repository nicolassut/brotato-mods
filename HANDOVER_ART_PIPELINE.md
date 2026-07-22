# HANDOVER — The Brotato Art Pipeline (PixelLab → edit → vectorize → in-game)

Read this WHOLE file before generating a single image. This pipeline was refined over many
painful iterations; every rule below exists because breaking it produced garbage the user had
to catch. The user's #1 recurring complaint: presenting images WITHOUT looking at them first.
That is the cardinal sin here. Its counterpart: destructively "improving" an image that was
already fine.

## 0. The pipeline in one paragraph

Generate on PixelLab with a carefully written prompt → LOOK at the result and judge it against
real game assets → if unusable, regenerate (1-2 at a time, new prompt angles, soft cap ~10
tries per subject before rethinking the approach) → when promising, post-process yourself
(line thickness, cutting out the usable part, cleanup) → mock it in its real in-game context →
double-check EVERYTHING → deliver the final PIXEL version to the user → the USER runs it
through vectorizer.ai and drops the result in the vectorized folder → you integrate
(scale/composite/install via the builders) → you judge the in-game result together → adjust
placement/processing, or regenerate if it fundamentally doesn't work.

## 1. The style law (what "usable" means)

Brotato's icons/pieces have **iconically THICK black outlines**, flat cartoon colors, and
minimal soft shading. Before making anything, pull 3-4 REAL examples of the same asset
category from `/Users/nicolassutcliffe/brotato-decompiled` and view them side by side with
your candidate. Judge line weight against the potato body itself when making character pieces.

**The vibe law (learned the hard way, 2026-07-20 Appetite icon redo).** A technically clean
icon is still WRONG if it is a straight-on symmetric product shot. Real Brotato item icons
are: TILTED or three-quarter view (nothing faces dead-on), lumpy hand-drawn wonky shapes,
often with a silly face on an object that should not have one (ugly tooth, lucky coin,
adrenaline brain), and grungy details (cracks, stains, tears, sweat). Bake this into the
prompt: "tilted at an angle, wonky hand-drawn shape, very thick chunky black outline" plus
one silly beat per item (sauce splat, derpy face, chicken leg in the pill). The user WILL
reject polite/generic versions.

**Outline weight is MEASURED, not eyeballed**: real item icons run 6-10px median black
outline at 96x96 (measure by scanning dark-run lengths inward from the silhouette edge; a
session script exists). PixelLab output lands at 2-5px after downscale, so basically every
icon needs a dilate-under pass (W=3-4 at 192px source) to hit the target. Verify the final
number.

Category targets (all researched, don't re-derive):
- **Character select icons**: 96×96. Content fills ~0.76W × 0.88H, bottom-anchored on a
  common baseline. Our baker does this: `asset-dev/characters/build_roster.py` `bake()`
  (FRAC=0.92, BASELINE=90, body anchors BODY_CX=74.5 / BODY_BOTTOM=107).
- **Character appearance pieces** (eyes/mouths/hats/props): **150×150 full-frame overlays**,
  pre-aligned to the potato body (`entities/units/player/potato.png`, head bbox ≈
  (45,38)-(104,107), face centre x≈74-75, faces look slightly to the viewer's RIGHT, cluster
  centre ≈ x81). A piece must fit the head IN CONTEXT — always mock with
  `build_roster.py place_c()` onto the potato before judging. Tall headwear needs the dome to
  CAP the crown (squash tall generations ×0.68-0.72 — the bowler needed it).
- **Item icons**: 96×96, content fill ~0.8-0.9, thick outline, flat colors (all existing
  custom items in `items/custom/*/` are correct references).
- **Stat icons are the EXCEPTION**: NO outline at all — smooth, gradient-shaded, lineless
  (see `items/stats/engineering.png`, `harvesting.png`). Vectorizing suits them great.
- **Food/consumable ground sprites** (upcoming): fruit-scale, instantly readable silhouette —
  reference `items/consumables/` fruit sprite for size.
- **Weapons** (future pass): side-profile held orientation, one sprite reused across tiers.

## 2. PixelLab specifics

- Connection: HTTP MCP, token hardcoded in `~/brotato-mods/.mcp.json` (git-ignored). Memory
  file `reference_pixellab_token.md` has the current secret. Check `get_balance` at session
  start (~1900 generations remain; generous, not infinite).
- **Workhorse tool: `create_1_direction_object`, view "sidescroller", size 180.**
  CRITICAL: sizes ≤170 auto-produce candidate BATCHES (≤42→64, ≤85→16, ≤170→4) that cost a
  fortune and violate the iterate-one-at-a-time rule. Size ≥171 = single candidate. Never
  fire a same-prompt batch; generate ONE (max two variants), evaluate, adjust the prompt.
- `create_map_object` renders SOFT/realistic (no bold outline) — WRONG for outlined pieces
  (it produced the rejected grey bowler). Only consider it (with `outline: lineless`) for
  stat-icon-style smooth art.
- Prompt formula that works: concrete subject + composition + "isolated object on transparent
  background, thick bold black outline, flat cartoon colors" + EXPLICIT exclusions when
  PixelLab keeps adding context ("empty hat with no head and no face inside"). PixelLab
  habitually attaches whole heads/bodies to accessories — either prompt it away or plan to
  CUT the part you need (the snail eyestalks were cut from a full snail; that is a valid
  route when the part itself is good).
- **Style-image recipe (the breakthrough for the Appetite icons)**: pass a REAL Brotato icon
  as `style_images` (base64 PNG). Upscale it to 192x192 NEAREST first — output size = largest
  style image, and 192 > 170 keeps it a single candidate (a raw 96px style image would
  trigger a 16-candidate batch). Pick a style icon that shares traits with the subject
  (piggy_bank for round pink things, ugly_tooth for faces/grunge, toolbox for grey metal,
  lucky_coin for shiny metal, banner for torn paper/cloth). This transfers the wonk, cel
  shading, and line character far better than prompt words alone.
- **Transparent-hole gotcha**: PixelLab "white" areas and dither "light" pixels are sometimes
  ALPHA-0 HOLES, not paint (tapeworm dither, recipe-card paper). They look white in previews
  and turn into the background color in-game. Check alpha before judging; fix by flood-fill
  from outside → any unreached transparent pixel is an interior hole → paint it.
- **Sketchy motion arcs/swooshes fuse into black blobs when dilated.** If a generation has
  detached double-stroke motion lines, either keep them un-dilated or delete those components
  outright (belly, teeth bounce-arcs); a face or pose usually carries the motion idea anyway.
- Ops: results take 30s-10min (queue varies wildly); poll with `get_object` after a
  background sleep; rate limit is 8 concurrent jobs. Download via:
  `TOKEN=$(python3 -c "import json;print(json.load(open('.mcp.json'))['mcpServers']['pixellab']['headers']['Authorization'])")`
  then `curl -H "Authorization: $TOKEN" -o out.png <download url>`. Raw downloads go under
  `asset-dev/<category>/raw/`.
- **Before regenerating anything, run `list_objects`** — 8 already-paid item-icon generations
  from the Appetite batch (bib, rumbling belly, family recipe, growth spurt sprout, tapeworm,
  cloche platter, nutrient paste tube, capsule pill) were queued and possibly never collected.
- Budget etiquette: credits are plentiful but the user notices waste. 1-2 gens at a time,
  evaluate every one, don't exceed ~10 on a single subject without changing strategy
  (different tool, different composition, cut-from-larger, or code-drawn if truly simple).

## 3. The editing toolkit (proven recipes, all PIL; scipy is NOT installed)

- **Pad BEFORE growing, crop tight AFTER.** Any outline-thickening on a tight-cropped image
  clips at the canvas edge (the bowler brim shipped clipped once). Recipe: crop to bbox →
  paste onto canvas with 20-26px padding → process → crop to bbox again.
- **Thicken outlines by dilating UNDER, never eroding IN.** Correct: silhouette (alpha>40) →
  `ImageFilter.MaxFilter(2*W+1)` → paint that black as an UNDER-layer → composite the
  original on top. W≈2-3 for delicate shapes, up to 7 for chunky ones. The erode-interior
  approach destroyed the fork's tines — never again.
- **Do NOT "clean" already-clean art.** The single worst habit. If a generation is already
  flat/hard-edged/outlined, ship it raw. Destructive flatten/dilate on a good image made
  garbage twice (fork, first bowler pass). Decide per-image by LOOKING.
- **Flatten to solid regions ONLY when needed for vectorizing**: the vectorizer traces
  everything — double outlines become double traced lines, leftover shading becomes blotches,
  anti-alias fuzz becomes noise. When a piece needs it, rebuild as ~3 flat colors + one bold
  outline (bowler final recipe). Merge charcoal interiors into the black outline mass to kill
  "hollow arch" reads.
- **Cutting parts out**: crop box + alpha-taper the cut edge (fade the last ~20% of rows to
  alpha 0) so no flat "cut line" shows — that fixed the snail eyestalks' bottom line.
- **Stray speck removal**: keep-largest-component via pure-numpy BFS (session scripts have
  it) — never assume clean.
- **Proportion fixes**: vertical squash (resize height ×0.68-0.75) for too-tall generations;
  measure dome-vs-brim ratios programmatically instead of guessing sizes.
- **Placement tuning**: render an option GRID (2-3 candidate positions/scales via place_c),
  look at it, pick, and verify the chosen one baked.
- Measure, don't eyeball, the final: content bbox fill fraction vs the category target
  (e.g. icons W≈0.76/H≈0.88).
- **Vector-prep deliverable (for vectorizer.ai input; rewritten 2026-07-20 after the first
  recipe DESTROYED dark icons)**: source from the RAW generation (192px, no added border,
  no downscale fringe) — never from the processed 96 final, except icons whose final had
  components surgically removed (then use the final). Recipe: binarize alpha at 110; snap
  ONLY true near-blacks (lum<45) to pure #000000; upscale x4 NEAREST; ONE MedianFilter(9);
  re-binarize alpha. Stage as `Brotato Icons/items_to_vectorize/<slug>_vecprep.png`.
  The failure to never repeat: globally blackening lum<90 plus MedianFilter(13) twice on
  border-thickened finals turned every dark-toned icon (oven, cookbook, market) into a
  black blob with detail islands — and it passed a lazy glance at small scale. Verify
  vecprep output LARGE, per icon, dark icons especially. Border treatment for game finals
  is applied at INTEGRATION time, never baked into vectorizer input.

## 3b. The proven sweep loop (user-endorsed 2026-07-20, "almost perfect" — do not drift)

The working scripts live in `asset-dev/pipeline/` (sweep_jobs.py = job table + queue,
process_gen.py = thicken/downscale/install/vecprep, poll_ids.sh = batch poller,
pixellab_mcp.py = MCP-over-HTTP client for when the MCP server isn't loaded). The loop:

1. Add the item to the JOBS table in sweep_jobs.py: style-ref icon chosen by material/trait
   + prompt = subject + tilt + ONE silly beat + the standard tail. Queue in batches of 4.
2. When a batch lands, VIEW every generation at 2-3x and give an honest per-image verdict in
   concrete words (what is where, what reads, what doesn't). Two named checks:
   - the vibe law (tilted? wonky? personality? grungy?)
   - PHYSICAL LOGIC: does the object make real-world sense (a bone cannot poke through a
     closed bag; meat must hang ON the hook, not float next to it). AI art fails this
     constantly and it is exactly what the user catches.
3. Ship only what beats the current installed version. For a flawed image, write a redo
   prompt that names the SPECIFIC fix (bone out of the OPEN top; hook PIERCED THROUGH the
   meat) instead of re-rolling blind. PixelLab fails ~1 in 8 server-side; retrying the
   same prompt is fine for those.
4. process_gen.py per keeper: auto dilate-under (W=3, bump until median outline >= 6px),
   LANCZOS to 96 at 88 fill, then `final_cleanup` (added 2026-07-20 after user caught dirty
   borders): kill alpha<110 fringe speckle, normalize true near-blacks (lum<45) everywhere
   plus lum<90 within the 2px edge band to PURE #000000. The band limit matters — a global
   lum<90 normalize eats legitimate dark-grey shading (it destroyed the iron lung's rivets
   on the first try). Install to the pack's source folder AND the live game PNG, vecprep
   copy to `Brotato Icons/items_to_vectorize/`. It prints measured outline + bbox — read
   those numbers.
   Prompt gotcha: words inviting irregularity on SURFACES ("mismatched", "crooked" pips)
   plus a heavily-textured style ref (gambling_token) produced the corrupted noisy dice
   face. Faces/surfaces that must read clean need "clean solid X with plain Y" in the
   prompt and a flat-shaded style ref.
5. Verify the batch at 96 (2x + 1x strip) before calling it done; check fine details
   survived (dither resolves fine, sub-2px sketch lines often do not).

## 3c. Pipeline v2 fixes (2026-07-20 evening redo session, after user rejected 3 icons)

The user caught three failures in the endorsed sweep loop; process_gen.py was patched so
they cannot recur. What changed and why:
- final_cleanup and vector_prep are now SATURATION-AWARE. Only unsaturated darks snap to
  black (maxc < 50 global; edge band lum < 90 needs sat < 40 too). The old lum-only rule
  blackened saturated dark tones (chili shadows, dark red stripes) and made the chili
  greenhouse read dirty. Saturated dark pixels are paint, not stroke.
- thicken() dilates the MAIN component(s) only (area >= 250 at 192px). Small detached
  bits (sweat drops, sparkles) got W-thick black halos and turned into blobs; that plus
  the auto W bump is what buried the chattering teeth in border. If outline_med still
  reads high on an icon whose frame doubles as outline (greenhouse), drop W manually and
  judge by eye; the greenhouse shipped at W=1, 8px median.
- fill_holes() runs automatically on every final and vecprep (interior alpha holes filled
  with the median of solid neighbours). The market awning stripes were alpha-0 holes.
- All three scripts honor a BROTATO_SCRATCH env var for the working dir (they had a dead
  session's scratchpad hardcoded). Export it before running from a new session.
- Redo etiquette learned again: PixelLab drifts concept on re-rolls (the teeth came back
  as a full skull WITH AN EYE). Name every exclusion explicitly in redo prompts: "just
  two disembodied denture jaws and nothing else, no skull, no eyes, no face, no head".

## 3d. despeckle: kill white border dots (2026-07-21, user re-flagged twice)

The recurring "white dots on the borders" complaint (pan, whisk) is now a permanent pipeline
step. `despeckle()` in process_gen.py runs at the end of BOTH `final_cleanup` (96px live art)
and `vector_prep` (vecpreps), and there is a standalone `clean_edges.py <files...>` that
despeckles delivered files in place (backs up to `Brotato Icons/_pre_despeckle_backup/`).
How it decides what is a dot, so it never eats real art:
- A dot is a SMALL isolated light blob (<=12px, 8-connected). Long thin features (whisk
  wires) and large highlights are big components and survive.
- It sweeps SEVERAL absolute luminance thresholds (72/118/168), because a grey-on-black rim
  dot and a white-on-grey dot separate from their body at different luminances - one global
  threshold cannot catch both. This was the key bug in the first two attempts.
- Second gate: keep a blob only if its ring of neighbours is dark or transparent (median lum
  < 82) - i.e. it sits IN the black outline, not on a lit surface. This is what spares the
  whisk's wire shine (surrounded by grey) while removing pan rim dots (surrounded by black).
- Saturation guard (sat < 70) spares gold sparkles, corn kernels, egg, chili.
- Each kept dot is inpainted from its kept neighbours: a rim dot becomes black, a dot buried
  in a wire outline becomes that outline's black. NEVER a blanket delete (would break wires).
Validate by eye at 6x before/after; the pan should lose its rim freckles but KEEP the curved
shine streak on the bowl. A whole-weapon-set sweep changed 20 live icons + vecpreps + the
640px vectorized masters; most had 5-260 stray px.

## 3e. Weapons are HELD in one hand (2026-07-21, user rejected full cannons)

A weapon icon/sprite must read as something the character grips alongside other weapons. A
cannon on a wheeled carriage is absurd as a held item - the user rejected both cannons for
it. Cannons = just the BARREL TUBE (galley: naval tube with breech knob + brass rings; corn:
a hand-cannon whose barrel is a giant corn cob, small wooden grip). Two sprites per weapon:
tilted ICON (96px, process_weapon.py) and horizontal in-hand SPRITE pointing RIGHT sized to
the template's sprite canvas (process_weapon_sprite.py, SIZES table). weapon_ranged /
weapon_melee (192px real Brotato icons) are the style refs. Gun-grip phrasing ("like a squirt
gun", "held sideways like a blaster") pulls generations back into looking like a pistol - say
"NO pistol grip, NO trigger" for bottles/cannons that must not be guns.

## 4. The double-check ritual (non-negotiable, every single image)

Before ANY image is presented, and again before it's installed:
1. `Read` the ACTUAL final file (upscale ×4-8 NEAREST for small art). Not the intermediate,
   not the pre-edit version — the exact bytes being delivered.
2. Mock it in context: pieces on the potato head; icons next to 3 real game icons of the same
   category; foods next to the fruit sprite. Look at the mock too.
3. Interrogate it: anything cut off at any edge? double outline? stray blobs? background
   contamination? detail merged into mush? line weight matching the reference? does the
   CONCEPT still read at game size? does it make sense for how it'll be used (a hat must look
   WORN, not floating)?
4. Only then present. If you edited something, say what you changed. If it has a known
   weakness, name it yourself before the user finds it.

## 5. The handoff loop with the user

- You deliver the final PIXEL version. Staging folder for pieces awaiting vectorization:
  `Brotato Icons/character_pieces_to_vectorize/`.
- The USER vectorizes (vectorizer.ai) and drops results into
  `Brotato Icons/character_pieces_vectorized/` with timestamped names — newest file = theirs.
  ALWAYS view the vectorized file before integrating (their output can surface flaws too;
  vectorized is also sometimes better than your "cleaned" pixel version — compare).
- Some clean flat pixel art can skip vectorizing entirely — offer the choice.
- Integration is via the builders, never ad-hoc: character pieces get wired into
  `asset-dev/characters/build_roster.py` (load, squash/flatten helpers, place_c recipe,
  appearance export) then `build_characters.py` installs icons + 150×150 appearances into the
  game; item icons go to the folder the relevant item builder reads (e.g.
  `asset-dev/items_appetite/final/<slug>.png` for `build_appetite_items.py`, which
  self-skips items whose icon is missing). Delete stale `*_effect_*.tres` before rebuilding
  characters. The tinted characters (zombie/snail/mole) auto-derive skins + leg tints.
- After install: render a verification sheet (roster/comparison) AND remind the user that
  in-game checks need a fresh game process; the editor re-imports new PNGs when it regains
  focus. Then judge in-game together; iterate placement first, regenerate only if the asset
  itself is wrong.
- Do not touch the user's computer unless they explicitly hand over control.

## 6. Current art debt (what this pipeline will be used for)

- 10 Appetite-item icons not yet done: the 8 possibly-retrievable generations above + Nervous
  Wreck + Gastric Band (never queued).
- After the food system lands: 20 food ground-sprites + 20 spawner item icons (spawner icons
  depict the MACHINE/SOURCE, not the food, so the two stay visually distinct), Butcher's
  steak reskins (fruit→raw steak, tree→steak pile, Garden→Meat Locker, Pruner variant),
  Ice Cream Truck structure sprite.
- Eventually: 20 Culinary weapon sprites + ~6 projectiles, Culinary class icon, Appetite
  upgrade icons. Character art is DONE (all 14 icons + appearances + the vectorized bowler,
  cutlery stat icon) — reference those as house style.

## 7. Session-history context worth knowing

The user has vetoed: unchecked deliveries, perfect-circle "blood splats" with thin borders,
pieces that ignore how they sit on the head, code-drawn art where the pipeline was expected
(the first bowler), 16-candidate batch generations, and any redesign of specified content.
When they say a piece looks wrong, they are almost always right — go LOOK at the thing at
scale in context before arguing. `HANDOVER_FOOD_SYSTEM.md` covers the systems side;
`asset-dev/characters/CHARACTER_SPECS.md` is design law. House rule for text in files: no
em-dashes.

## 3f. Weapon projectiles (2026-07-22)

Each ranged Culinary weapon fires its own shot. build_weapons.py wire_projectile() clones the
template's projectile .tscn (PROJ_BY_TEMPLATE maps template -> scene + the sprite-texture paths
to swap) into weapons/ranged/<slug>/<slug>_projectile.tscn with the weapon's projectile PNG
swapped in, then repoints stats.projectile_scene at it. Pistol-type weapons have NO
projectile_scene in stats (WeaponService falls back to projectiles/bullet/bullet_projectile.tscn),
so for those wire_projectile ADDS the ext_resource + projectile_scene line + bumps load_steps.
Sprites come from proj_jobs.py (fruit_food style ref, "flying/round" prompts) and install via
process_projectile.py (SIZES = per-weapon canvas matching the template projectile so in-game
scale is unchanged; directional shots point RIGHT, round shots fill less so they are not giant).

## 3g. Enclosed black gaps in see-through structures (2026-07-22, 4th recurrence)

Open structures (whisk wires, tapeworm coil, meat rack frame, apron neck strap, cork wire
cage) keep shipping with BLACK POOLS filling the gaps that should show the arena through.
Permanent tool: `open_enclosed_black(img, rim, stroke, lumk)` in process_gen.py. A black
pixel survives if within `rim` px of colour (that is the outline hugging parts) OR within
`stroke` px of transparency (keeps thin isolated strokes like hanging hooks - the apron
taught this guard). Pool interiors are far from both and get erased. Tuning that worked:
rim is roughly HALF the outline thickness (96px art rim 3, 225px world rim 4, 640px master
rim 9); lumk 70 normally, RAISE it (92-118) when the pooled "black" is actually dark brown
(champagne cork cage). Always verify at 1:1 on a mid-dark background - and check EVERY
see-through generation for this before presenting, it is a standing user complaint.

AMENDMENT (same day, after the vectorized meat rack came back with EATEN hooks/joints):
the distance method removes connective black EMBEDDED in pools (hanging hooks died - they
are black inside black, invisible to distance rules). Second tool: `remove_black_pools
(img, m, rim, lumk)` - erode black by m so only thick pool CORES survive (thin strokes
vanish from the removal set even when embedded), regrow cores m+1, subtract. Pick per
sprite, they are NOT interchangeable:
- v2 remove_black_pools: thin-lined sprites with big pools (meat rack icon m=3, world
  m=5, 200-256px vecpreps m=6). Keeps embedded hooks.
- v1 open_enclosed_black: thick-outlined small sprites (apron, cork). v2 cores thick
  OUTLINES as if they were pools and shreds the sprite (it destroyed both in testing).
The per-sprite choice table lives in pipeline/process_butcher.py GAP_FIX.
Vecprep sizes: DETAILED item icons now go at 200px (user rule 2026-07-22; VEC_200 set),
simple icons stay 128, structures/world 256. After ANY gap fix, re-verify the vectorizer
INPUT files match the fixed live art - a stale whisk vecprep shipped once.
