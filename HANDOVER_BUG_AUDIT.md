# Handoff: full adversarial bug audit of the Brotato "Gourmet" mod

Do a comprehensive, adversarial BUG AUDIT of everything my Gourmet mod adds to Brotato,
comparing every custom thing against how the BASE GAME handles the same pattern, and finding
discrepancies/bugs. This is an AUDIT: find, verify, and report — do NOT fix anything without
my approval (a big blind fix pass would be worse than the bugs). Produce a prioritized,
deduplicated report of VERIFIED findings (severity, file:line, concrete repro, and the
base-game contrast). Adversarially verify each finding before you report it — I do not want
plausible-but-wrong findings.

This audit is large. Fan out with subagents/a workflow (say "use a workflow" if you want the
orchestrated version). Split by subsystem, verify findings independently, then synthesize.

## Where everything is
- Game (decompiled, **Godot 3.x**, config_version=4): `~/brotato-decompiled`. NOT a git repo.
  Testing needs a REPACK (the user does that); you can't easily run the game.
- Mod builders (git `nicolassut/brotato-mods`, public): `~/brotato-mods/asset-dev/`.
- Card text: `~/brotato-decompiled/items/custom/custom_translations.csv` (key,en).
- Content registration (ecosystem Phase 2+): `packs/<id>/pack_data.tres` (tscn is vanilla-only).

## Read first (context)
- Memory (auto-loaded index MEMORY.md), esp: `feedback_brotato_formula_and_food_display`,
  `feedback_brotato_perma_stat_tracking`, `feedback_brotato_json_float_counters`,
  `feedback_gourmet_character_rules_override_items`, `feedback_brotato_finalized_worn_piece_standard`.
- Issue STATEs under `~/.claude/issues/brotato-mods/`: `character-spec-audit`,
  `food-limits-and-buff-ui`, `formula-food-tracking-consistency`.
- `~/brotato-mods/asset-dev/characters/CHARACTER_SPECS.md`, `~/brotato-mods/HANDOVER_NEW_ITEMS.md`.

## The audit surface (everything the mod added)
- **14 characters** (`items/custom_characters/`): gourmet, picky_eater, dishwasher, comp_eater,
  butcher, zombie, minimalist, mime, tourist, ruminant, snail, blacksmith, juggler, mole — plus
  runtime hooks scattered through `entities/units/player/player.gd`, `main.gd`, `singletons/*`.
  (`test_armory` is a leftover DEBUG character still in the roster — flag it.)
- **~20 food spawners + 21 foods** and the whole buff engine: `player.gd` `_apply_food_buff`,
  `_grant_food_buff_stack`, `_grant_wave_buff_stack`, `_food_buff_add_magnitudes`,
  `_on_food_buff_expired`, HUD `ui/hud/food_buffs_display.gd`, `items/foods/food_data.gd`.
- **~79 custom items** (`items/custom/`) incl. appetite items, food-system items (Soul Food,
  Doggy Bag, Compost Bin, Grease Fire, Snack Break, etc.), and mechanic items rewritten by
  `asset-dev/fix_mechanic_items.py` (overtime_pay, second_mortgage, vampire_fang).
- **~20 culinary weapons** (`weapons/melee|ranged/`) + projectiles + explode/proc mechanics
  (corn_cannon popcorn drop, galley_cannon, sauce_blaster burn, etc.).
- **Card/tracking systems:** `ui/menus/shop/item_description.gd`, `items/global/effect.gd`
  (live formula render + EFFECT_FOOD_ branch), tracking via `RunData.tracked_item_effects` +
  `init_tracked_items` seed + `add_tracked_value`.
- **Butcher meat reskin:** `singletons/butcher_skin.gd` (swaps fruit/tree/garden textures + text).

## KNOWN BUG CLASSES — hunt these everywhere (each already bit us at least once)
1. **Save/resume JSON-float `%` crash.** Resume turns saved effect-dict ints into floats; `%`
   or typed-int reads on a float hard-crash. Any NEW effect-dict counter must int-cast at read
   or be in `player_run_data._deserialize_effects` normalization. Audit every custom counter
   (soul_food_streak, per-food eaten x20, the 5 new trackers, gourmet_foods_eaten, banked_*,
   selected_spawner, etc.) for resume safety.
2. **Array-valued key seeded in `init_stats()` instead of `init_effects()`.** Makes
   `is_stat_key()` true, so `apply_item_effects` (run_data.gd) does `Array - Array` and crashes
   on item purchase (this was the Food Fight crash). Check EVERY `[]`-valued key in
   `player_run_data.init_stats` — none used as a direct item-effect `key` should live there.
3. **Unseeded tracked key = silent no-op.** Every `add_tracked_value(...)` key MUST be in
   `run_data.init_tracked_items` or the counter silently never updates.
4. **GDScript builtin-name collision.** A var/param named `ease`/`lerp`/`range`/`str`/`hash`/
   `seed`/`min`/`max`/`floor`/etc. crashes the whole script on load. Hand-scan every custom .gd
   (the installed `godot` is v4 and FALSE-FLAGS this Godot-3 project — `--check-only` reports
   `yield` errors that are not real; do NOT trust it. yield is correct here.)
5. **CSV unquoted comma / malformed row.** A value with a comma must be quoted or it becomes a
   3-column row that breaks Godot's translation import and makes EVERY key after it render as
   its raw KEY in-game (this hid WEAPON_CLASS_CULINARY). Validate the whole CSV parses to exactly
   2 columns per row; check for raw-key symptoms.
6. **Description <-> code mismatch.** Vague scaling ("scales with X"), wrong coefficients,
   claims the code doesn't do ("permanent" that uses wave-temp stats — Overtime Pay was this),
   or effects whose stated mechanic isn't wired. Cross-check each card line against the runtime.
7. **TempStats vs RunData.add_stat.** Wave-temp stats are wiped at wave start; "permanent"
   claims must use RunData.add_stat. (I just changed Overtime Pay to permanent — verify that's
   correct + not double-applying.)
8. **Timerless / wave buffs.** Any reader of `player._food_buffs` that touches `["timer"]`
   without `.has("timer")` crashes on rest-of-wave buffs. Check all readers.
9. **Effect wiring integrity.** For every custom item/weapon/character tres: effects array
   references existing tres, no dangling ExtResource ids, load_steps correct, custom_key/
   storage_method/text_key match the intended behavior, granted starting items use
   `custom_key=starting_item/starting_weapon` + `text_key=EFFECT_HIDDEN`.
10. **Order/identity-dependent state.** UI holding a different object instance than RunData
    (this was the Blacksmith forge "just-bought weapon can't be armed" bug). Look for identity
    (`==`/`in`) comparisons on weapon/item instances.
11. **Reskin text/mechanic drift** (Butcher): every fruit/tree/garden key swap resolves, no
    leftover fruit wording, no missing meat variant.
12. **Stat/mechanic-cap & interaction bugs:** stack caps, max_nb, dodge cap + halving, speed
    cap, comp_eater double-magnitude with the new stack cap, ruminant echo with stack cap,
    Mint refresh skipping wave buffs, Picky/Set-Menu spawner selection, Mime merge-to-fit
    (known-incomplete), Minimalist inventory. Verify each still holds after this session's changes.

## Specific suspect leads to chase (flagged this session, not fully verified)
- Grease Fire: card says "plus 50% Elemental Damage" — verify the manual BurningData actually
  folds Elemental before the tick (`unit.gd` apply_burning/tick), else the 50% is a lie.
- Overtime Pay now permanent (RunData.add_stat) — verify it accumulates correctly and its
  tracker matches; confirm it's not stronger than intended.
- Slug trail is 7.5s (main.gd) vs the 2.5s spec — intended deviation or bug?
- `mage_burning_data.tres` shows as a fake "character" in the codex — extractor globs a
  weapon burning-data file; confirm it's only a codex-extract glitch, not a game issue.
- Food Fight `projectiles_on_eat` was moved from init_stats to init_effects — verify it still
  fires projectiles on eat and buying it no longer crashes.
- `test_armory` debug character still registered — should be removed.
- Verify the new stack-cap + timerless-wave-buff + per-food-eaten changes didn't regress the
  comp_eater / ruminant / picky / mint / soul_food interactions.

## Method
For each custom thing: read its data.tres + effects, its CSV card text, and its runtime code;
find the base-game equivalent (`items/all/`, `items/characters/`, vanilla `weapons/`,
`.assets/resources/translations/translations.csv`) and diff the convention. Prefer proving a
bug with a concrete input->wrong-output than pattern-matching. Structural checks you CAN run
without the game: tres ext-id/load_steps validity, CSV 2-column validity, GDScript
builtin-name scans, tracked-key seeding, init_stats vs init_effects placement, effect
custom_key/storage_method sanity.

## Deliverable
A single prioritized report: most-severe first (crashes/save-loss > wrong mechanics >
description mismatches > cosmetic), each with file:line, a concrete repro or the exact code
path, the base-game contrast, and a suggested fix (but do NOT apply fixes until I approve).
Empty categories are fine — I want signal, not filler.
