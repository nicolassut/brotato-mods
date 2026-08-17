# Handoff: plan & build a few new Gourmet-DLC items

I want to add a small batch of new content to my Brotato "Gourmet" mod: a couple more food
**spawners** (each with its paired food), a couple of general **items**, and maybe **1-2 new
characters**. PLAN FIRST — propose designs and let me approve before you build. When we build,
every rule below is mandatory (I have re-explained some of these many times; they are not
suggestions).

## Read these first (context you must load before proposing anything)
- Memory files (auto-loaded index is MEMORY.md): especially
  `feedback_brotato_formula_and_food_display`, `feedback_brotato_perma_stat_tracking`,
  `feedback_brotato_json_float_counters`, `feedback_finalized_worn_piece_standard` (art),
  `project_lovable_exodus` is unrelated — ignore.
- Issue states: `~/.claude/issues/brotato-mods/formula-food-tracking-consistency/STATE.md`,
  `.../food-limits-and-buff-ui/STATE.md`, `.../character-spec-audit/STATE.md`, and
  `~/.claude/issues/brotato-mods/ACTIVE_WORK.md`.
- Spec: `~/brotato-mods/asset-dev/characters/CHARACTER_SPECS.md`.

## Where everything lives
- **Game (decompiled, Godot 3.x, config_version=4):** `~/brotato-decompiled`. NOT a git repo.
  Game changes require a REPACK (I do that) before they show in-game.
- **Mod dev workspace (git `nicolassut/brotato-mods`, PUBLIC):** `~/brotato-mods`. Builders in
  `~/brotato-mods/asset-dev/`. Every game change MUST be mirrored in the builder that generates
  it or a rebuild reverts it.
- **Content registration (ecosystem Phase 2+):** `packs/<id>/pack_data.tres` via
  `asset-dev/pack_registry.py` (the tscn is vanilla-only)
  (`characters`/`weapons`/`items`/`foods` arrays; highest ext id currently ~992 — new content
  takes the next ids). Card text: `items/custom/custom_translations.csv` (key,en).
- **Codex** (browsable data site): `asset-dev/extract_codex.py` -> `codex.json` ->
  `build_codex_html.py` -> writes `gourmet_codex.html` AND `index.html`. Published artifact
  `https://claude.ai/code/artifact/5e25de6c-9e70-43b4-b2c3-83980805013a` + Vercel
  `brotato-mods.vercel.app`. Regenerate it after adding content.

## NON-NEGOTIABLE RULES (0 exceptions)
1. **No vague scaling — ever.** Any value that changes with a stat MUST show the exact formula:
   the base AND the per-point coefficient, in the game's live `{base} ({current})` style. The
   live parenthetical is rendered in `items/global/effect.gd::get_text` — either
   `_scaling_formula_text(text_key, base, stat_hash, ratio, ...)` for additive `base+ratio*stat`
   scaling, or a bespoke `if text_key == "..."` case (see EFFECT_W_CORN_POPCORN there). Foods
   auto-render via the `EFFECT_FOOD_*` branch. NEVER write "scales with X" / "increases with".
2. **Every food source shows food effect + max stacks + eaten.** ANY item/gun/character that can
   produce a food must, on its card, show (a) the food's buff line, (b) its max buff stacks, and
   (c) how many the player has eaten. Implementation: attach ONE display-only effect with
   `text_key="EFFECT_FOOD_<FOOD>"` and `custom_key="consumable_food_<food>"`, `key=""`,
   `effect_sign=2`. That single effect drives all three via `ui/menus/shop/item_description.gd`
   (`_get_spawner_food`). Weapons use `build_weapons.py`'s `food_key=` param. Random-food
   producers (like Gourmet) are the ONLY exception — no single food, so show a total-eaten count
   instead, never fake one food's stats.
3. **Every accumulator gets a card counter.** Anything that grants permanent stats or counts
   occurrences needs: `tracking_text="<KEY>"` on the data.tres + a `<KEY>,<label>: {0}` CSV row +
   `RunData.add_tracked_value(player_index, <owner_my_id_hash>, amount)` at the accumulation
   site + the key SEEDED in `run_data.gd init_tracked_items` (unseeded keys make add_tracked_value
   a silent no-op).
4. **Food buff stack cap** (`FoodData.buff_stack_cap`, ceiling 20, strong foods lower). At the
   cap, eating again extends the shared timer but adds no more magnitude / stacks. Wave-long
   (`wave_stats`) foods show in the top-left HUD as a timerless chip.
5. **Spawner ownership limits (`max_nb`)**: no spawner is unique; strongest ≈2, mid ≈3
   (Grandma's Cookbook + Beehive are 3), weakest ≈4. Pick per power.
6. **Save/resume int rule:** any new effect-dict counter used with `%` or for-iteration must be
   int-cast at read or added to `player_run_data._deserialize_effects` normalization (JSON turns
   saved ints into floats and `%` on a float hard-crashes on resume).
7. **GDScript gotchas:** tabs not spaces; `yield` is correct (Godot 3); the installed `godot`
   binary is v4 and FALSE-FLAGS this project (can't use --check-only) — instead hand-scan every
   new var/param against GDScript builtins (`ease`, `lerp`, `range`, `str`, `hash`, `seed`,
   `min`, `max`, etc. are reserved and crash if used as identifiers — this already bit us once).
8. **Verify against the actual in-game card, not the doc.** Mirror every change in the builder.
   Game changes need a repack; codex reads the tres directly (no repack needed for it).

## How to add each content type (recipes)
NOTE (2026-07-24): both builders now take an explicit `ext_id` per entry for content added
after their original id blocks filled up (food pairs after index 19, pantry items after
917; 991-997 used by content batch 2, next free id is 998). Both also write .png.import
sidecars and NEVER overwrite an existing live png that has no final/ source (vectorized
art installed in place survives rebuilds).
- **Spawner + its food** — `asset-dev/build_food_system.py`. Add paired entries to `SPAWNERS`
  and `FOODS` (same index). Spawner dict: `slug,name,tier,value,tags,max_nb,` a trigger
  (`trigger="<bucket>_foods"` for an event bucket, or `structure=`/`anchor_structure=` for a
  placed structure, or `wave_start`/`count`), and `text_key`. Food: `food(slug,name,
  "EFFECT_FOOD_X", buff=[(stat,base,app_ratio)], dur=, stack_cap=, wave=, perm=, heal=,
  special=)`. Existing trigger buckets: kill/crit/explosion/material/level_up/burning_kill/
  burning_tick/standstill_timer/step/consumable_count/damage_taken/mid_wave/random_times/
  elite_kill/reroll_banked/wave_start. A NEW trigger needs a hook in `main.gd`. The builder
  writes both tres, registers in the food pack, and adds CSV rows.
- **General item** — `asset-dev/build_pantry_items.py`: `item(slug,name,tier,value, kit=[...],
  tags, max_nb, tracking="")`. kit entries: `("stat",key,val)` or `("key",key,val,text_key,
  sign)` (custom-key SUM effect w/ card text) or `("proj",text_key)`. Its CSV_ROWS are
  "update-or-append" (they OVERWRITE the live row) so put final text there. (Note: mechanic
  items overtime_pay/second_mortgage/vampire_fang are re-written LAST by `fix_mechanic_items.py`,
  not build_mod_items.)
- **Character** — `asset-dev/characters/build_characters.py`: add to `CHARS` (slug,name,my_id,
  wanted_tags, effects-list, starting-items), `POOLS` (starting weapon pool), `TRACKING` (if it
  accumulates), `BANNED` (banned items). Grant pattern: a granted starting item/weapon is an
  effect with `custom_key="starting_item"`/`"starting_weapon"`, `storage_method=1`, and
  `text_key="EFFECT_HIDDEN"` (NOT "effect_starting_item" - that renders an ugly "You start with
  X" line; vanilla never shows starting items, they just are in the loadout).
  `CharacterData.starting_items` is the weapon-SELECT list, NOT a grant. Runtime character logic
  goes in player.gd/main.gd behind a `character_id == "character_<slug>"` check. (Design: never
  give heal/lifesteal starting items to Zombie - he can't heal; he now starts with Growling
  Stomach whose no-consumable-heal downside is free for him.)
- **Food-spawning weapon** — `asset-dev/build_weapons.py`: `w(... food_key="consumable_food_X")`.

## Current inventory (don't duplicate; match the style)
- **14 characters:** gourmet, picky_eater, dishwasher, comp_eater, butcher, zombie, minimalist,
  mime, tourist, ruminant, snail (Slug), blacksmith, juggler, mole. (`test_armory` is a leftover
  DEBUG character still in the roster + codex — should be removed; flag/remove it.)
- **20 spawners** (each with a paired food): espresso_machine, butchers_hook, bakers_oven,
  beehive, wok_station, popcorn_machine, deep_fryer, sushi_bar, grandmas_cookbook,
  pizza_delivery, victory_feast, street_vendor, fondue_set, gym_membership, fancy_restaurant,
  farmers_market, after_dinner_mints, chili_greenhouse, doggy_bag, ice_cream_truck.
- **~21 foods, ~79 custom items** (incl. Soul Food T3, appetite items, food-system items),
  **~20 culinary weapons** (corn_cannon, sauce_blaster, ice_cream_scoop, ladle, cleaver, whisk,
  dinner_bell, frying_pan, galley_cannon, etc.).

## What I want from you this session
1. Read the context above.
2. Propose ~2 new spawners (+foods), ~2 new items, and 1-2 new character concepts — each with
   its exact stat kit, formula-correct card text, food/stack/max_nb/tracking details spelled out
   per the rules. Show me the plan.
3. On my approval, build them (tres + builders + CSV + item_service registration + trackers +
   card display), verify structurally, regenerate the codex, and tell me it needs a repack.
