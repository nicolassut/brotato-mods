# HUB_ART_SPEC.md - every generated image, exactly, before anything is generated

User law (2026-08-18): the layout is DERIVED from this spec, not the other way
around. Every asset below has final in-game pixel dimensions, a placement rect
on the map, and a generation recipe. No asset gets generated until the
placeholder layout built from these exact footprints is signed off in play
(HUB_PLAN step 4). HANDOVER_ART_PIPELINE.md governs all generation mechanics
(thick-outline law, vibe law, style-image recipe, vectorize flow).

## 0. Scale calibration (measured, don't re-derive)

- Player: potato.png 150x150 canvas, ~110px tall on screen with legs
- Food-stand world sprites: 96-115px | vanilla turret 80x100 | tree 225x225
- Design resolution 1920x1080; map ~2 screens (user, v3); avatar 430 px/s
- A hub BUILDING should read ~3x player height: ~350px tall
- Vector masters make final size flexible - the sizes below are the IN-GAME
  target px the vectorized art gets scaled to; generate at PixelLab >=171
  single-candidate sizes, vectorize, scale.

## 1. The map, exactly (origin at center; all rects x,y,w,h)

```
canvas: 2880 x 2480  (x -1440..1440, y -1240..1240) - ~2 SCREENS (user, v3)
perimeter wall ring: 64px thick, all four sides
DECK        floor: -1376,-1176 .. 1376,-616   (2752 x 560, metal)
CLIFF FACE  strip: -1376,-616  .. 1376,-232   (2752 x 384) <- stairs run this
PLAZA       floor: -1376,-232  .. 1376, 1112  (2752 x 1344, alien dirt)
bottom wall: y 1112..1176, ENTRANCE GATE 384x160 at (-192,1064)
STAIR WEST : rect -672,-712 .. -416,-136  (256 x 576: 96 landing + 384 run + 96 apron)
STAIR EAST : rect  416,-712 ..  672,-136  (mirrored)
SHUTTLE PAD: rect -280,-1176 .. 280,-792  (560 x 384, flush with the TOP wall)
SHUTTLE    : 420 x 300, parked on the pad, center (0,-984)
MODE SHRINE: 192 x 224 rect (-976,-1000)
UNLOCK BOARD: 384 x 224 rect (688,-1000)
BOOTH      : 224 x 256 rect (-112,-340), backs onto the cliff face
FOUNTAIN   : 384 x 320 rect (-192,180)
SLOTS (common footprint 416 x 352, 2+2+2):
  slot_1 (-1140, 80)  slot_2 (-1140, 520)  slot_3 (-550, 800)   west + southwest
  slot_4 ( 1140, 80)  slot_5 ( 1140, 520)  slot_6 ( 550, 800)   east + southeast
SPAWN      : (0, 1000), avatars fan out +-90px per player
camera limits: x +-1440, y -1240..1176
GEOMETRY LAW: rect changes re-run the overlap/alignment checker
(asset-dev/check_hub_geometry.py) - zero overlaps, band continuity, stairs
exactly landing+run+apron, everything inside the playable area.
```

Stairs are LONG on purpose: a 576px run (96 top landing + 384 cliff descent +
96 bottom apron) - over 5 player-heights of staircase, reads as a real
climb. The cliff strip exists so the stairs have something to descend.

## 2. Asset inventory - the complete generation list

Ground rule from the base game: GROUND is flat color + sparse decals (no
tiles-with-seams anywhere in Brotato); OBJECTS get the thick-outline cartoon
treatment. Two render classes: [O] = outlined object (create_1_direction_object,
view sidescroller, size >=171, style_images = real Brotato props upscaled 192
nearest), [G] = ground/soft (lineless, low contrast - map_object route or
heavy post-process; NEVER outline ground).

| # | asset | file (final px) | class | placement | prompt core (+ standard suffix*) |
|---|---|---|---|---|---|
| 1 | cliff face segment | cliff_seg.png 256x256, tiles horizontally | G | cliff strip, ~8 tiles + stairs replace 2 each side | "sheer retaining wall built from riveted scrap metal plates and girders, seen front-on, dark rusted steel, horizontal seam lines, subtle top edge lip, tileable left-right, muted colors, no outline" |
| 2 | staircase west | stairs_w.png 256x576 (east = mirror) | O | STAIR rects | "long straight industrial staircase descending toward viewer, wide flat metal steps with scrap plate risers, side rails of welded pipes, seen front-on slight top-down, thick black outline on rails and step edges" |
| 3 | shuttle pad | shuttle_pad.png 560x384 | G | deck center | "circular rocket landing pad painted on metal deck, worn yellow-black hazard ring, scorch marks radiating from center, bolt seams, seen from above, flat muted colors, no outline" |
| 4 | the shuttle | shuttle.png 420x300 | O | on pad, nose up-right | "small stout cartoon spaceship shuttle parked at an angle, round cockpit window, dented hull plates with rivets, two stubby landing legs, slight three-quarter view, wonky hand-drawn shape, thick chunky black outline, flat cartoon colors" |
| 5 | changing booth | booth.png 224x256 | O | cliff base center | "narrow fairground changing booth with drawn curtain, scrap metal frame, small marquee light bulbs on top, front-facing slight top-down, wonky hand-drawn, thick black outline, flat cartoon colors" |
| 6 | mode shrine | shrine.png 192x224 | O | deck west | "small strange alien altar made of stacked scrap and one glowing dial, front-facing, wonky, thick black outline, flat cartoon colors" |
| 7 | unlock board | board.png 384x224 | O | deck east | "wide notice board made of welded scrap with pinned papers and one cracked screen, on two girder legs, front-facing, thick black outline, flat cartoon colors" |
| 8 | fountain | fountain.png 384x320 | O | plaza center | "round scrap-metal fountain basin, heroic cartoon potato statue on pedestal in the center holding a tiny flag, dribbling liquid, slight three-quarter view, wonky, thick black outline, flat cartoon colors" |
| 9-13 | pack buildings x5 | bldg_smithy/bank/diner/gremlin/bunkhouse.png each 416x352 | O | slots per registry | shared frame: "squat front-facing shack built from ship wreckage, [IDENTITY], big hand-painted sign, slight top-down, wonky hand-drawn, thick chunky black outline, flat cartoon colors". IDENTITY per pack: smithy "open forge glow, anvil, chimney"; bank "barred teller window, vault door, coin sign"; diner "serving hatch, steam, giant fork sign"; gremlin den "purple tent-shack, stacked lootboxes, keyhole sign"; bunkhouse "triple bunk visible through door, laundry line with tiny capes" |
| 14 | vacant building | bldg_vacant.png 416x352 | O | any empty pack slot | same frame: "boarded-up shack, planks over window, faded FOR RENT sign" |
| 15 | reserved building | bldg_reserved.png 416x352 | O | slot 3 | same frame: "shack under construction, scaffolding, tarp, COMING SOON sign" |
| 16 | entrance gate | gate.png 384x160 | O | bottom wall center | "wide open gate frame of two girder pylons and a battered arch sign, front-facing, thick black outline, flat cartoon colors" |
| 17 | plaza decals x6 | decal_[crack/cables/stain/crates/barrels/scrap].png 128x128 | G | scattered, fixed seeds | each: single ground detail, top-down, muted, no outline |
| 18 | deck edge lip | deck_lip.png 256x32, tiles | G | deck/cliff boundary | "thin metal edge trim with hazard stripe, tileable" |

*standard [O] suffix: "isolated object on transparent background". Every
generation judged against 3-4 REAL neighbors per the handover before
acceptance. STYLE-ANCHOR LAW (user, 2026-08-18): reference/style images and
judging neighbors must be VANILLA assets only (~/brotato-vanilla-reference) -
never our own modded art, which may itself drift from the dev style. Vanilla
anchors: turret.png, landmine.png, parachute.png, tree.png, item icons,
crash_zone_background.png.

Explicitly NOT generated (reuse/none): avatar bodies (real player pieces),
roster idlers (existing character appearances), floor colors (flat fills),
perimeter walls (flat fill + decals from #17).
Optional later pass: shuttle engine flicker (2nd frame), fountain dribble
(2nd frame), ambient critter 64x64.

## 3. Placeholder mapping (live NOW, exact same rects)

Placeholders occupy the EXACT rects above: flat ColorRects for ground classes,
existing sprites for objects (street_vendor = shuttle, espresso_machine =
booth, special_icon = shrine) centered on the same anchors. Collision and
interaction areas are already final. Real art lands as a pure texture swap.

## 4. Sign-off gates before generating

1. HUB_PLAN step 4 walkthrough on this layout (solo + coop) - user approves
   spacing/feel with these exact footprints.
2. Then generation proceeds ASSET BY ASSET in the handover's loop (generate ->
   judge vs real neighbors -> mock IN the hub scene screenshot -> user approves
   -> vectorize -> install). Never batch-generate the whole list blind.
