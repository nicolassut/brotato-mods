# Handover — how to generate art that actually matches the Brotato style (character work)

You are inheriting a workflow the user rates "almost perfect" after many failed attempts by
prior sessions. Your job is not just to run tools, it is to exercise JUDGMENT. Read this
whole file, then HANDOVER_ART_PIPELINE.md (pipeline mechanics, editing recipes, scripts),
then asset-dev/characters/CHARACTER_SPECS.md (design law: never redesign specified
content). Launch from ~/brotato-mods so the PixelLab MCP loads.

## 1. What the style actually is (learn it before generating anything)

Do this first, not as a formality: pull 6-10 REAL assets of the category you are about to
make from ~/brotato-decompiled (character icons, the potato body, hats/eyes/props from
existing characters), build a contact-sheet grid, view it LARGE, and name the traits in
words. When we did this for items, the articulated list was the breakthrough:

- Iconically THICK black outlines. Not "thick-ish": measured 6-10px median at 96x96.
  Outlines are wobbly and hand-drawn, weight varies around the shape.
- NOTHING faces dead-on. Everything is tilted, three-quarter, slumped, mid-motion.
  A symmetric straight-on render is automatically wrong even if technically clean.
- Shapes are lumpy and organic. Perfect circles, straight edges, and geometric symmetry
  read as UI clipart, not Brotato.
- Personality on things that should not have it: googly eyes, buck teeth, grumpy brows,
  sad faces. One eye bigger than the other beats two equal eyes.
- Grunge: cracks, stains, stitches, sweat, drips, patches, missing chunks.
- Flat cel colors, one shadow tone + one highlight, minimal gradients.
- Physical logic HOLDS despite the wonk: a hat sits ON a head, meat hangs ON a hook,
  a bone comes out of an OPENING. AI generations break object logic constantly and the
  user catches it every single time. Check it explicitly on every image.

## 2. How to get PixelLab to produce it

- Tool: create_1_direction_object, view "sidescroller". Size >= 171 for single candidates,
  BUT the real trick is style_images: pass a REAL Brotato asset, upscaled to 192x192
  NEAREST (output size = style image size; 192 keeps it single-candidate, smaller
  triggers 4-16x batches that waste credits). This transfers line weight, cel shading,
  and wonk far better than any prompt words. Pick the style asset by material and trait:
  round pink thing -> piggy bank; face/grunge -> ugly tooth; grey metal -> anvil/toolbox;
  shiny -> lucky coin; cloth/paper -> banner; organic -> bait. For character pieces, use
  an existing character piece or the potato itself.
- Prompt formula: concrete subject + "tilted at an angle" + ONE silly beat (a face, a
  stain, a crack, something mid-action) + "wonky hand-drawn shape, very thick chunky
  black outline, flat cartoon colors, isolated object on transparent background".
- PixelLab habitually attaches heads and bodies to accessories. Either exclude in the
  prompt ("empty hat with no head and no face inside") or plan to cut the good part out
  (alpha-taper the cut edge). It also adds ground lines under standing objects - delete.
- Surfaces that must read clean need "clean solid X with plain Y" - words like
  "mismatched"/"crooked" applied to a SURFACE plus a textured style ref produce corrupted
  noise (the dice lesson).
- ~1 in 8 generations fails server-side; re-queue same prompt. Soft cap ~10 tries per
  subject before changing strategy entirely.

## 3. The judgment loop (this is the part that made it work)

1. LOOK at every generation zoomed 3-4x before forming any opinion. Describe it to
   yourself in concrete words: what is where, what reads, what does not. If you cannot
   name what the pixels show, you have not looked.
2. Two named checks every time: the style traits above, and PHYSICAL LOGIC. Physical
   logic includes COUNTING: chopsticks come in twos, eyes in twos, wheels in fours.
   AI adds extras constantly (a third chopstick shipped once). Count out loud anything
   that has a correct number, and put "exactly two X, only two" in prompts for paired
   objects.
3. Verify at FINAL size too (96 icon / in-place on the potato). Detail that reads at 3x
   can be mush at 1x; dither resolves fine, sub-2px sketch lines do not.
4. Ship only what beats the current installed version. "Good enough" that you have to
   rationalize ("it's grunge, probably") is a rejection - the dice and the first tapeworm
   both got shipped on a rationalization and the user caught both.
5. When something is flawed, write a REDO prompt that names the specific fix ("bone
   sticking out of the OPEN top", "one single continuous body tapering to one tail tip"),
   not a blind re-roll. This is not just good practice, it is mandatory: PixelLab is
   effectively DETERMINISTIC - the same prompt + style image returns the same image
   (two identically-prompted chopsticks jobs produced pixel-identical results). Re-roll
   unchanged prompts only after server-side FAILURES, never after bad results. If a
   composition keeps producing the same mistake, change the COMPOSITION (the crossed-X
   chopsticks kept growing a third stick; the fix was switching to a parallel pair).
6. Measure, never eyeball: outline thickness (dark-run scan), content bbox fill, alpha
   stats. PixelLab "white" can be TRANSPARENT HOLES - always check alpha before judging
   (tapeworm dither and recipe-card paper were both invisible holes).
7. When the user says something looks wrong, they are right. Zoom into the exact spot
   they describe before doing anything else, diagnose the real cause, then fix that
   cause. Do not defend the image.

## 4. Character-specific mechanics (from the researched specs, do not re-derive)

- Select icons: 96x96, content fills ~0.76W x 0.88H, bottom-anchored on a common
  baseline. Bake through build_roster.py bake() (FRAC=0.92, BASELINE=90, BODY_CX=74.5,
  BODY_BOTTOM=107). Never hand-place.
- Appearance pieces (eyes/mouths/hats/props): 150x150 full-frame overlays pre-aligned to
  the potato body (entities/units/player/potato.png, head bbox approx (45,38)-(104,107),
  face centre x~74-75, faces look slightly viewer-RIGHT, cluster centre x~81).
  ALWAYS mock with build_roster.py place_c() onto the potato BEFORE judging - a piece
  that looks great alone and wrong on the head is wrong. A hat must look WORN, not
  floating; tall headwear gets squashed x0.68-0.72 so the dome caps the crown.
- Judge piece line weight against the potato body itself, not against item icons.
- Integration only via the builders (build_roster.py -> build_characters.py); delete
  stale *_effect_*.tres before rebuilding; tinted characters auto-derive skins.
- In-game check needs a fresh game process; the editor re-imports on focus.

## 5. Post-processing discipline (destructive cleanup is the enemy)

- Do NOT clean already-clean art. Decide per-image by looking.
- Thicken outlines by dilating black UNDER the art (pad canvas first, crop after).
  Never erode inward, never blanket-apply a border to something that does not need it.
- Any black-normalization must be tiered: pure-black snap only true near-blacks
  (lum<45) globally; the aggressive threshold (lum<90) ONLY in the outer edge band.
  A global midtone blacken plus heavy median filtering reduced dark icons to blobs
  once - worst failure of the whole project, and it initially passed a lazy small-scale
  glance. Verify cleanup output LARGE, per image, dark art especially.
- Vectorizer input comes from the RAW generation (no added border, binarize alpha,
  snap true blacks to #000000, x4 NEAREST + ONE MedianFilter(9)). Border treatment for
  game assets happens at integration, never baked into vectorizer input.
- PixelLab sometimes draws outlines DITHERED - grey pixels sprinkled through the whole
  black stroke, not just the edge. Rim peels and edge rules barely dent it (three failed
  attempts). The cure is stroke solidification: black-density snap (BoxBlur radius 2 on
  the pure-black mask, snap solid pixels with density >= 0.35 and lum < 170). The
  lum >= 170 guard protects glints, sparkles and kernels. Implemented in
  asset-dev/pipeline/process_gen.py vector_prep.
- VERIFY AT 1:1 OF THE SAVED FILE. A reduced-size or LANCZOS-shrunk preview hides
  exactly the pixel noise you are checking for - a non-fix passed "verification" three
  times in a row that way before the user caught it. Crop the saved file at full
  resolution and look at the actual region.
- Erase stray strokes/ground lines surgically (component analysis, row runs, trapped
  pink-island fills) - the session scripts in asset-dev/pipeline/ have working code for
  all of these. But protect FACES: an indiscriminate fill once painted eye glints black.
  Any post-process touching the face region needs a before/after look at the face.
- EDIT-STACKING LIMIT (user-established 2026-07-20): after 2-3 surgical edits on one
  image, stop. Accumulated fixes degrade art in ways fresh generation does not - a new
  20-credit generation with a corrected prompt beats a fourth round of surgery. The user
  said it directly: "we've done too many changes, they are now worse than just making
  something new."

## 6. Working with this user

- They look closely and they are almost always right. Name weaknesses yourself before
  they find them; call out what you changed on every delivery.
- Budget: ~800 PixelLab generations remain, 20 per generation. Batches of 2-4, review
  between batches. Ask before any run that would eat hundreds.
- No em-dashes in any file. No unchecked deliveries, ever.
- Deliverables: pixel finals installed via builders + a to-vectorize copy staged in
  Brotato Icons/ staging folders; the user runs vectorizer.ai themselves.

## 7. Vecprep median is per-icon, not one-size (audit of 2026-07-20)

MedianFilter(9) is right for bold simple icons but SMEARS dense fine detail: meat
marbling, hand lettering (Ice CReam), wheel spokes, dither shading, packed small objects
(chilis, fries, kernels). Those need med=5 (DETAIL_DENSE list in pipeline
process_gen.py). The only way to assign correctly is the per-icon audit: raw next to
vecprep, look at the detail regions, decide. When raw is already clean, less processing
always beats more - the user proved this with the chili greenhouse comparison.

## 8. In-world STRUCTURE sprites are a different genre from item icons (user, 2026-07-20)

- Structures are FLAT 2D FRONT VIEW, like the vanilla garden tree: no isometric/3D
  reads, at most a slight angle. Item-icon tilt rules do NOT apply here.
- NEVER put creatures on structures (no bee on the beehive): nothing in-game animates
  them, and a frozen creature reads as a bug. Static smoke/steam/fire/drips are fine.
- Keep structures SIMPLER than icons: they read at distance in the arena among chaos.
- 100x100, bottom-anchored (they stand on the floor), style ref = vanilla turret/tree.

## 9. Two more physical-logic checks (pizza clone, 2026-07-20)

- CLONE OBJECTS: PixelLab sometimes hides a duplicate of the subject BEHIND the main
  one (a second pizza slice peeking out). Check silhouette edges for extra crusts,
  limbs, handles that belong to a phantom twin.
- VERIFY GROUND/ARENA SPRITES ON A DARK BACKGROUND. The arena is dark grey; a white
  preview hides clone edges, shadows and fringe that are obvious in-game. The
  white-bg check missed the pizza clone; the user's dark screenshot caught it.
- Clone removal without credits: flood-fill segmentation with COLOR-VERIFIED seeds
  (assert the seed pixel is the material you think it is), keep-only-reachable from
  the main subject's regions grown by outline thickness, then the rim law rebuilds
  the cut edge. Eyeballed polygon cuts kept missing; seeded floods did not.

## 10. [SUPERSEDED BY 11 & 12 - kept only as a cautionary trail]

We first thought UPSCALING (4x vs 8x) was the smoothness lever. It is NOT. The real lever
is absolute output SIZE, and SMALLER wins (sections 11-12: 128px items/foods, 256px
structures). Ignore the "8x" conclusion here; it was a wrong turn on the way to the size
answer. Listed only so you don't re-derive it.

## 11. Vectorizer input SIZE is the master lever - 256px (user-validated 2026-07-20 late)

The A/B/size testing settled it: vectorizer.ai smooths pixel-art into clean curves ONLY
when the pixel blocks are small. Output ~256px and it smooths beautifully; output 1536px
(8x) and it traces every block as geometry = CHUNKY. Same shape, 256 vectorized "a billion
times better" than 1536. This is THE setting - not upscale factor, not median strength, not
AA-vs-hard (hard-binarize won that test). vector_prep now targets target=256, med=3.
Bonus: 256 regenerates all 61 near-instantly (1536 took ~10 min of median filtering).
The canonical to-vectorize set is `Brotato Icons/TO_VECTORIZE_256/` (61 files:
item__ / food__ / structure__ prefixes). The old `items_to_vectorize_OLD_8x_DO_NOT_USE/`
is the wrong-size renders - ignore/delete.

## 12. Vectorize size is PER-TYPE, scaled to shape boldness (user-validated 2026-07-20 late)

vectorizer.ai's smoothness threshold depends on how BOLD the shape is. Delicate shapes
(thin handles, steam swirls, small food objects) need FEWER absolute pixels than bold ones
or they trace chunky. FINAL validated sizes for the to-vectorize inputs (user, 2026-07-20 late):
  - ITEMS: 128px for BOLD-SIMPLE ones; 256px for DETAIL-DENSE ones (deep_fryer's fries+mesh,
    lettering, packed small objects, circuit/marble texture lose too much at 128). The
    detail set is BIG_ITEMS_256 in process_gen.py - grow it as the user flags more.
  - FOODS: 128px   (espresso sweep winner; smaller = smoother, detail loss acceptable)
  - STRUCTURES: 256px  (user: "the structures are fine" - bold buildings vectorize clean at 256)
Net rule: 128 for icons/foods, 256 only for the big structure sprites. Downscaling from the
~192 raws uses LANCZOS (not NEAREST) then re-binarize. Detail-heavy items (lettering,
scribbles) still read fine at 128 - verified.
The canonical folder is `Brotato Icons/TO_VECTORIZE/`: item__ 128px, food__ 128px,
structure__ 256px.
General rule for a NEW asset class: run a downward size sweep (256/224/192/160/128/96) on
one example, vectorize each, pick the smallest that still reads. Don't assume 256.

## 13. Regenerate over surgery, and verify at TRUE DEPLOYED size (echo_chamber, 2026-07-20)

Two failures on one icon, both avoidable:
- I tried to hand-remove messy black between an echo megaphone's soundwaves with a hard
  x-threshold mask. It left a vertical SEAM down the middle. Surgery on a busy region is a
  trap - the fix was to REGENERATE with a simpler prompt (three clean arcs instead of many
  cluttered rings, so there was no dense black to fight). When an image needs more than a
  trivial cleanup, regenerate with a better prompt. This is the edit-stacking rule again:
  the raw generation, re-prompted, beats surgery almost every time.
- I "verified" the surgery ZOOMED and it looked fine; at true 96px icon size the seam was
  glaring. VERIFY AT THE FINAL DEPLOYED SIZE, not just a zoom of the raw. For character
  pieces that means: after building the 150x150 piece, mock it onto the potato AND look at
  the whole character at the size it appears in the roster/in-game - not just the piece
  blown up. Zoom hides seams, downscale-and-mock reveals them. Do both, trust the small one.

## 14. The 90%-first-shot recipe, distilled (what actually works here)

If you do only these, most generations land on the first or second try:
1. STYLE IMAGE, always: pass a real Brotato asset (an existing character piece, or the
   potato body itself) as style_images, upscaled to 192px NEAREST. This is the single
   biggest style-match lever - far more than prompt words. Pick the ref by material/trait.
2. PROMPT = concrete subject + how it sits (a piece must read as WORN on the head, not
   floating) + ONE silly/character beat + "thick chunky black outline, flat cartoon
   colors, isolated on transparent background" + EXPLICIT exclusions PixelLab needs
   ("empty hat, no head and no face inside" - it attaches whole heads to accessories).
3. SIZE >= 171 for a single candidate (<=170 triggers expensive candidate batches).
4. Batches of ~8, and LOOK at every single one at 3-4x before judging. Name what you see.
5. Run the checklist every time: physical logic, COUNT things that have a right number,
   clone-behind-subject, transparent-hole "white", reads at final size.
6. Ship only what beats what is installed. A result you have to rationalize is a reject.
7. Bad result -> change the PROMPT or composition (PixelLab is deterministic; re-rolling
   the same prompt returns the same image). Re-roll unchanged ONLY after a server failure.
8. The working scripts are in asset-dev/pipeline/ (sweep_jobs / process_gen / poll_ids /
   pixellab_mcp / process_food / process_structure / process_newpack). Use them; the
   PixelLab MCP has outages, pixellab_mcp.py is the HTTP fallback, and pollers should be
   resilient to transient DB errors.

## 15. What a FINALIZED worn piece actually looks like (blacksmith goggles, 2026-07-21)

This was learned the hard way over ~8 rejected rounds on ONE pair of goggles. The user's
verdict on the version that finally passed: "THAT is what a finalised character design is
SUPPOSED to look like." Do not ship a worn accessory (goggles, hat, headband, monocle,
camera, mask) until it meets ALL of this. "Close enough" is a reject - the user sees every
flaw and the back-and-forth is far more expensive than doing it right the first time.

A finalized worn piece:
- SITS ON THE HEAD like a real object. Goggles/bands WRAP the head; they never float a few
  pixels above it, never rest-and-dangle off the top. A monocle covers ONE eye (not both). A
  camera hangs BELOW the face on a strap that goes behind the neck (not pasted over the face).
  Blood spills from UNDER the hat. If it defies real-world logic, it is wrong - the user has
  no patience for illogical placement and will call it "bullshit".
- FITS INSIDE THE HEAD SILHOUETTE. It never clips past the head edge and never touches the
  96 frame edge. MEASURE it (head is only ~56px wide at eye level); do not eyeball.
- HAS A BOLD BLACK BORDER matching the potato outline. Add the border at the 150-FRAME scale
  (after place_c) or it gets shrunk to nothing by the downscale; frame_border() in
  build_roster does this. If the piece is vectorized, the border is baked in - do NOT re-add.
- IS SMOOTH. The finished blacksmith used the VECTORIZED goggles (clean curves), not raster.

The pipeline that actually produced it (use this shape for every worn piece):
1. Generate the piece at the CORRECT ANGLE for how it is worn. Goggles worn over the eyes =
   generate a FRONT-ON, level, symmetric pair. Do NOT generate a 3/4 object and rotate it to
   fit - rotating a wrong-angle piece always looks crooked/cluttered (three rounds proved it).
2. Size it to fit inside the silhouette; position it where it sits in real life.
3. clip_body() it to the head silhouette so straps WRAP and cut cleanly at the head edge
   (they read as going behind the head) and it can NEVER clip past the edge. For a "turned /
   looking-right" look, shift the piece so the far side recedes behind the head edge via the
   clip - do not raw-crop (a raw crop leaves an unbordered cut edge).
4. Vectorize for smooth curves (staged in Brotato Icons/character_pieces_to_vectorize/).
5. VERIFY on the ACTUAL SAVED FILE at 1:1: count frame-edge pixels (must be 0) and clip
   pixels outside the head silhouette (must be 0), then LOOK at it. Do this EVERY time before
   saying "done" - the user has told me repeatedly to always check, and checking a mock or a
   claim instead of the real file is how the flaws slipped through.

frame_border() and clip_body() are reusable helpers in build_roster.py - every future headwear
/ wrap-around piece should use them so borders and no-clip are guaranteed by default.
