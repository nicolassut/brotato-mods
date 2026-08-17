# PIPELINE.md — build a character / item / food / weapon 1:1 in ONE pass

**Read this whole file before building ANY content.** It exists because the same steps keep
getting missed and re-explained (card UI, stats, icons, registration). Follow the recipe for
your content type, then tick every box in its **Definition of Done**. A thing is not "done"
until every box is ticked and the **Verification gate** passes — no exceptions, no "I'll do the
card text later." One pass, perfect 1:1.

Specialist docs go DEEPER; this doc is the spine that makes sure nothing is skipped:
`HANDOVER_ART_PIPELINE.md` (art gen/edit/vectorize), `HANDOVER_CHARACTER_ICONS.md` (icon+body
compositing), `HANDOVER_FOOD_SYSTEM.md` (food internals), `HANDOVER_NEW_ITEMS.md` (item recipes),
`asset-dev/characters/CHARACTER_SPECS.md` (character design law).

---

## 0-bis. THE PACK LAW (ecosystem rule - read ECOSYSTEM.md first)

The mod is becoming an ecosystem of optional packs (`core`, `food`, `fortune`, `forge`,
`ledger`, `roster` - see `ECOSYSTEM.md` for the partition and architecture). From now on:

1. **Every piece of content declares its pack.** Before building, decide which pack it
   belongs to (or that it is synergy content with `requires_packs`). State it in the plan,
   record it in the builder entry. Content with no declared pack does not ship.
2. **Ext ids come from your pack's range.** Current allocations (formalized from history):

   | range | owner |
   |---|---|
   | 800-809 | food (first 10 custom items) |
   | 811-824 | characters (mixed packs - split lands in ecosystem Phase 2) |
   | 825-839 | food (Appetite stat + items) |
   | 840-1003 | food (spawners/foods/pantry/culinary + late characters 998/1004/1005/1008) |
   | 1006-1007 | ledger (credit_card, bank_loan) |
   | 1009-1012 | food (Appetite upgrades) |
   | 1013-1292 | forge (Blacksmith ladder weapons) |
   | 1293-1295 | fortune (P2W char) + food (gumball colours) |
   | **1296+** | NEW content: claim the next id AND note the owning pack in the builder |

   Known hazard: 824/825 collision (documented in build_characters.py) - never assume
   `base+i` is free; check the map.
3. **New engine hooks are small NAMED functions.** Never inline a feature branch into the
   middle of a vanilla function; add `_gourmet_<thing>()` (or `if Packs.<id>:` once
   PackService exists) and call it from one seam line. This is what makes the eventual
   ModLoader script-extension packaging (ECOSYSTEM.md Phase 8) mechanical instead of a
   rewrite.
4. **Synergy content** (requires 2+ packs) must be hidden-when-incomplete: registered only
   when all required packs are enabled, never grayed out or degraded.

---

## 0. The two trees + where everything lives (orient first)

- **`~/brotato-decompiled/`** — the LIVE game (Godot 3.6, runs from here). NOT the mod repo.
- **`~/brotato-mods/`** — the git repo. `game-src/` mirrors the ~65 hand-edited engine files;
  `asset-dev/` holds the Python builders; `Brotato Icons/` holds art.
- **Builders write into `~/brotato-decompiled/`.** Every live engine edit MUST also live in
  `game-src/` (the mirror) or a builder/rebuild reverts it. See CLAUDE.md "The two trees" for
  the drift-check one-liner. After editing an engine file: edit one copy, `cmp` the other, sync.
- **Registration:** `singletons/item_service.tscn` — `characters` / `weapons` / `items` /
  `foods` arrays, each entry an ext_resource with an explicit ext id. New content takes the next
  free id (see each builder's `EXT_IDS`).
- **Card text:** `items/custom/custom_translations.csv` (`KEY,English`).
- **Codex:** `asset-dev/extract_codex.py` → `codex.json` → `build_codex_html.py` → regenerate
  after any content change (reads the .tres directly, no repack needed).

---

## 1. THE CARD CONTRACT (the #1 thing done wrong — non-negotiable)

The item/character card is rendered by `items/global/effect.gd::get_text`. `asset-dev/check_cards.py`
is the machine that enforces this and MUST exit clean before you commit. The rules:

1. **A scaling number is TWO args, a flat number is ONE.** In `_add_food_formula_args`
   (effect.gd): `app_ratio != 0` pushes **2** args — `{n}` = `current | base` and `{n+1}` =
   `+R% <stat icon>`; `app_ratio == 0` pushes **1** flat arg. **The CSV row must contain exactly
   one `{k}` placeholder per pushed arg, numbered contiguously from `{0}`.** Too few → literal
   braces render on the card; too many → silently dropped. This is check B in check_cards.py.
2. **Never write vague scaling.** No "scales with", "increases with". Every stat-dependent value
   shows base + per-point rate in the live `current | base (+rate icon)` idiom. Duration and
   permanent-stat lines use the SAME idiom (that was a bug we fixed — don't reintroduce a bespoke
   `base (current)` form).
3. **Every food line NAMES its food:** "Eating <Food> grants …". A bare "Eating grants +4% Speed"
   is wrong.
4. **Every food SOURCE (item/gun/character that produces a food) carries a food-display effect:**
   `key=""`, `custom_key="consumable_food_<food>"`, `text_key="EFFECT_FOOD_<FOOD>"`, `effect_sign=2`.
   That one effect drives (a) the food's buff line, (b) `Max buff stacks: N`, (c) `<Food> eaten: N`
   via `ui/menus/shop/item_description.gd`. Weapons pass `food_key=` in build_weapons.py. A
   random-food producer (Gourmet) is the only exception: show a total-eaten count, never fake one
   food's stats.
5. **Every accumulator gets a card counter (tracker):** `tracking_text="<KEY>"` on the data.tres +
   a `<KEY>,<label>: {0}` CSV row + `RunData.add_tracked_value(player_index, <owner_id_hash>,
   amount)` at the accumulation site + the key SEEDED in `run_data.gd init_tracked_items`. An
   unseeded key makes `add_tracked_value` a silent no-op AND spams the console. Items read
   `RunData.tracked_item_effects[my_id_hash]`; weapons read a per-instance `tracked_value` — do not
   cross them.
6. **Curse-boosted spawn counts must display the real number** (a cursed spawner that drops 2×
   shows the doubled count, not the base).

> If you touch `effect.gd` or `item_description.gd`, update `check_cards.py` in the SAME commit or
> it starts lying.

---

## 2. DEFINITION OF DONE — CHARACTER

Build in this order; tick every box. Files: `asset-dev/characters/build_characters.py` +
(mechanics) `run_data.gd` / `main.gd` / `player.gd` + icons.

- [ ] **Spec approved.** Identity, one-line fantasy, exact stat kit, and mechanic come from the
      user or `CHARACTER_SPECS.md`. Never invent stats. PLAN and get approval before building.
- [ ] **Roster entry** in `build_characters.py`: `CHARS` (slug, name, `character_<slug>` id,
      wanted_tags, effects-list, starting-items) + `EXT_IDS[slug]=<next free id>` + `POOLS`
      (starting weapon pool) + `TRACKING` (if it accumulates) + `BANNED` (banned items) +
      `SKINNED`/`LEGS_MOD` (only if the body is recolored).
- [ ] **Stats / kit effects** correct: stat effects as `("stat", key, val)`; a granted starting
      item/weapon is an effect with `custom_key="starting_item"`/`"starting_weapon"`,
      `storage_method=1`, `text_key="EFFECT_HIDDEN"` (NOT a visible "You start with X" line).
- [ ] **Card description** (the LINE effects) obey §1: named foods, formula scaling, counters.
      Every `EFFECT_*` LINE has a CSV row whose placeholder count matches its arg count.
- [ ] **Select icon** — `asset-dev/characters/final/<slug>_icon.png`, 96×96, baked to the roster
      law (see §4): content longest side → ~88px (0.92×96), centered at x=48, bottom on baseline
      90, NO cropping. Verify content bbox ≈ `(≥4, 2)-(≤92, 90)`. LOOK at it next to 2–3 vanilla
      icons before accepting.
- [ ] **In-game body** — `final/appearances/<slug>_face.png`, 150×150, covering the potato head
      (head bbox `(45,38)-(104,106)`, centre x≈74.5) with margin so no white shows, bottom ≈ y107
      so the legs poke out. Installed as `<slug>_face_appearance.tres` (position 0 OTHER, depth
      600). Icon and body come from the SAME source art so they can't drift. LOOK at it on the
      potato with legs.
- [ ] **Registration** present in `item_service.tscn` `characters` array (the builder does this;
      confirm it did and did NOT drop or duplicate anything).
- [ ] **Mechanic code** (if any gimmick): a `RunData.is_<slug>(player_index)` gate + hooks behind
      `character.my_id == "character_<slug>"`. Coop-aware (see §7 coop trap). Boot-safe (§7 `:=`).
- [ ] **game-src mirror synced** for every engine file you touched (`cmp` each; drift check clean).
- [ ] **Builders run:** `build_characters.py` (+ any item/food builder you added content to).
      Confirm `item_service.tscn` did not drift.
- [ ] **Verification gate (§6) passes.**

---

## 3. DEFINITION OF DONE — ITEM / SPAWNER+FOOD / WEAPON

Files by type (recipes in §4). Tick every box:

- [ ] **Design approved** (stat kit + formula-correct card text + food/stack/max_nb/tracking
      spelled out).
- [ ] **Builder entry** added with an explicit next-free `ext_id`.
- [ ] **Card contract §1 satisfied**: scaling args = placeholders; food source shows food line +
      max stacks + eaten; every accumulator has a seeded+fed tracker; foods are named.
- [ ] **CSV rows** present and arg-count-correct (pantry rows are update-or-append → put FINAL
      text there).
- [ ] **`max_nb`** set by power (spawners: strongest ≈2, mid ≈3, weakest ≈4; nothing unique
      unless intended).
- [ ] **Icon** delivered per `HANDOVER_ART_PIPELINE.md` (vectorized, thick outline, fit to the
      item frame). Installed; `.png.import` sidecar written.
- [ ] **Save/resume int rule** (§7) honored for any new %/iterated counter.
- [ ] **Registration** in `item_service.tscn` (right array) confirmed, no drift.
- [ ] **game-src mirror synced**; **builders run**; **Verification gate (§6) passes**; **codex
      regenerated.**

---

## 4. Build recipes (which builder, what fields)

- **Spawner + its paired food** — `asset-dev/build_food_system.py`: add paired entries to
  `SPAWNERS`/`FOODS` (same index). Spawner: `slug,name,tier,value,tags,max_nb,` a trigger
  (`trigger="<bucket>_foods"`, or `structure=`/`anchor_structure=`, or `wave_start`/`count`) +
  `text_key`. Food: `food(slug,name,"EFFECT_FOOD_X", buff=[(stat,base,app_ratio)], dur=,
  stack_cap=, wave=, perm=, heal=, special=)`. A NEW trigger bucket needs a `main.gd` hook.
  Existing food finals are the SOURCE OF TRUTH — the builder now OVERWRITES the live food png from
  `foods/final/<slug>.png` each build (do not reintroduce an "only if missing" guard; that is why
  sprites stopped travelling between machines).
- **General item** — `asset-dev/build_pantry_items.py`: `item(slug,name,tier,value, kit=[...],
  tags, max_nb, tracking="", ext_id=)`. kit: `("stat",key,val)` / `("key",key,val,text_key,sign)`
  (custom-key SUM effect with card text) / `("proj",text_key)`. CSV_ROWS overwrite the live row.
- **Character** — see §2 and `build_characters.py`.
- **Food-spawning weapon** — `asset-dev/build_weapons.py`: `w(... food_key="consumable_food_X")`.

---

## 5. Icons & body — the numbers, inline (details in the art handovers)

- **Select icon bake (roster law):** content-crop the source, scale its LONGEST side to 88px
  (0.92×96), paste into a 96×96 transparent canvas so the content is centred at x=48 and its
  BOTTOM sits on baseline y=90, clamp inside the frame (never crop). Vanilla heads fill ≈
  0.76W × 0.88H — no wasted space.
- **Body overlay (150×150):** the potato base is `entities/units/player/potato.png`; head bbox
  `(45,38)-(104,106)`, centre x≈74.5. Legs are a SEPARATE sprite drawn BEHIND the potato
  (`show_behind_parent`), attach at texture ≈(75,93), and only show BELOW the head bottom (~y106).
  So the overlay must cover the head down to ≥106 (or white shows), and its bottom ≈107 leaves a
  few px of leg. Weapons render in a later sibling node than `Animation`, so a full-body overlay
  never hides your guns.
- **ALWAYS render the final files and LOOK before delivering** — the icon next to vanilla icons,
  the body on the potato with legs. Measure spans; don't nudge-and-hope.

---

## 6. VERIFICATION GATE (must ALL pass before "done" / commit)

1. `cd asset-dev && python3 check_cards.py` → **exits clean** ("card contract OK").
1b. `python3 asset-dev/check_sync.py` → **no HARD ORPHANS** (every live custom texture's art is
    tracked in the repo). Ideally 0 MISPLACED too — an icon at its canonical `final/` so the builder
    re-installs it on any machine. This is the "nothing gets missed cross-machine" guard.
2. **Registry intact:** `item_service.tscn` still registers everything it should and a builder did
   NOT drop a deregistered entry or double-register. Diff it if a builder ran.
3. **All `res://` refs resolve** to real files (icons, appearances, effect tres).
4. **Boot-safety scan** (the game is Godot 3; the `godot` in PATH is v4 and CANNOT check it):
   - No `var x: = <expr>` where the RHS type can't be inferred — a bare autoload/method call feeding
     arithmetic (`var m: = 1.0 + RunData.foo()/2000.0`) crashes the parser on boot. Use plain
     `var x =` or an explicit `var x: Type =`. (This took the game down once this session.)
   - Tabs, not spaces. No reserved word as an identifier (`min max range str hash seed lerp ease`…).
5. **Mirror in sync:** every engine file edited matches between `game-src/` and
   `~/brotato-decompiled/` (drift check clean).
6. **Codex regenerated** (`extract_codex.py` + `build_codex_html.py`) for content changes.
7. **In-game (tell the user):** focus the Godot editor so it re-imports changed/new PNGs, then a
   BRAND-NEW run (not Continue/Restart — those deserialize old resources). Verify the actual card,
   the icon in the roster, and the in-game body.

---

## 7. Landmine catalog (each of these has bitten us — check for ALL)

- **`:=` boot crash.** `var _x: = <untyped/autoload call in an expression>` fails Godot-3 type
  inference and the game won't boot. Plain `var _x =` or explicit type. (§6.4)
- **Registry drift.** Builders can re-register items that were deliberately deregistered, or revert
  a hand-edit. After ANY builder run, confirm `item_service.tscn` did not drift.
- **"Never clobber" traps.** An install guard that only writes "if the live file is missing" means
  updated art/data never reaches another machine. The food-sprite installer now overwrites from
  `final/`; keep it that way.
- **Coop UI inheritance.** `CoopUpgradesUIPlayerContainer extends UpgradesUIPlayerContainer` and the
  coop shop reuses `StatsContainer` — a change to the single-player container/UI silently runs in
  coop too, where the layout differs (this squished coop upgrade cards). Gate coop-specific behavior
  and test both.
- **Editor re-import + fresh run.** PNGs re-import on editor focus; saves/Restart serialize the old
  resource. Always test with a new run.
- **JSON float counters.** Any effect-dict counter used with `%` or for-iteration must be int-cast
  on read or normalized in `player_run_data._deserialize_effects`, or a resumed run hard-crashes.
- **Two builders, one file.** If two entries write the same live file, the last build wins; keep the
  builder the source of truth, not an in-place edit.

---

## 8. Definition of "1:1" (the bar)

A stranger picking your character/item sees: a correct icon in the roster, a matching in-game body,
a card whose every number shows its real value + scaling, every food named with its stacks and
eaten-count, every accumulator counted, the right ownership limit, and it boots, plays, and resumes
without a crash — with **zero** follow-up reminders needed. If any of that is missing, it is not done.
