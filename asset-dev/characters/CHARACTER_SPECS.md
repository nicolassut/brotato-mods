# Brotato: Gourmet — THE 14 CHARACTERS (authoritative spec)

Recovered verbatim from the design session transcript (lines ~5666-5735). This file is
the single source of truth for character mechanics. The stat kits currently in
`items/custom_characters/` are PROVISIONAL stand-ins and must converge to this spec.
Do not redesign anything here without the user's say-so.

Legend: [FOOD-SYS] = needs the food/buff system (foods, spawners, shared-timer stacking)
        [DEEP] = custom engine system, standalone of food
        [DATA] = expressible with existing effect keys today
        ⚓ = requires Abyssal Terrors

## IMPLEMENTATION STATUS (updated 2026-07-22, full code audit, file:line verified)
Audit note: the 2026-07-20 claim "every mechanic is now in code" was WRONG. A 3-agent
line-by-line audit against the actual code found the following. Everything not listed as a
gap below IS fully wired (data tres + runtime hook + card text), including all starting
item/weapon grants (Ladle, Cleaver, Doggy Bag, Chicken Soup, Mosquito Jar, Magnifying
Glass, Fondue Set, Pocket Sand, Anvil), the shared-timer stacking law, and the Appetite
duration law. Full evidence: ~/.claude/issues/brotato-mods/character-spec-audit/STATE.md.

GAPS (as of 2026-07-22, none fixed yet):
1. CompEater: off-spec +3 Appetite on card (comp_eater_effect_0); the real double-stack/
   half-duration mechanic IS coded (player.gd:1211-1214) but has NO card text.
2. Tourist: "XP Gain modifications -50%" MISSING entirely (engine has no gain_xp key).
3. Tourist: card omits the implemented +5% enemy attack speed per Danger.
4. Mime: auto-merge-to-fit for mirror weapon duplicates NOT implemented (no cascading
   merges, full-inventory no-op, single non-cascading combine, add_element drift risk).
5. Soul Food T3 item (system law): entirely MISSING.
6. Minimalist: 6-cap + recycle coded; dedicated inventory VISUAL (slot frames) absent.
7. Minimalist: 4 off-spec extras wired (reroll +100, items_price +25, harvesting -25,
   gain harvesting -50), keep-or-cut is a user call.
DEVIATIONS (code+card agree, spec differs): Slug trail 7.5s not 2.5s, slow scales
+2%/level to 90%; Zombie card omits the (implemented) cap-raiser halving rule.
DONE SINCE 2026-07-20: Ladle + Cleaver grants live; Butcher steak/tree/Garden reskin
live (butcher_skin.gd autoload); test character removed from the roster (2026-07-22).

---

## #1 The Gourmet
- All fruit becomes food; **+1 permanent Appetite per 10 foods eaten** [FOOD-SYS]
- Cannot heal from consumables; HP Regen modifications −50%; −5% Speed [DATA: gain_stat_hp_regeneration −50, stat_speed −5; no-consumable-heal needs small hook]
- Starts with **Ladle** (Culinary weapon — weapons milestone)

## #2 The Picky Eater
- **One food spawner active at a time, its food +100% stronger** [FOOD-SYS]
- **Food spawner items cost −25% in the shop** (user range 15–35%, settled 25) [DATA-ish: current food_items_price hook approximates until spawners exist, then must target spawner items]
- −15% Damage while no food buff is active [FOOD-SYS]
- Luck modifications −50% [DATA: gain_stat_luck −50]

## #3 The Dishwasher
- **Leftovers doubled; expired food refunds** [FOOD-SYS]
- **Food expires 50% faster** (the "negative" that secretly feeds Leftovers) [FOOD-SYS]
- −1 weapon slot; −10% Damage; item prices +5% [DATA: weapon_slot −1, stat_percent_damage −10, items_price +5]
- Starts with **Doggy Bag** (T2 ⋄ item — items milestone)
- **Cooler Box is a banned item for him** (banned_items field)

## #4 The Competitive Eater
- **Food buffs stack twice as much, durations halved** [FOOD-SYS]
- **Momentum (user redesign 2026-07-24): every food buff he actually gains grants
  +5% Speed and +5% Pickup Range until the end of the wave** (capped/no-gain eats
  do not count; wave-fresh, nothing persists) [FOOD-SYS: player.gd _gain_comp_momentum]
- Max HP modifications −30%; −10% Dodge [DATA: gain_stat_max_hp −30, stat_dodge −10]

## #5 The Butcher
- **Everything fruit becomes steak** — visual/descriptive reskin only: fruit→raw steak,
  trees→steak piles, Garden→Meat Locker, Pruner→butcher variant. Raw steak (healing
  pickup) vs grilled steak (buff food) stay visually distinct; his counter counts both. [FOOD-SYS + textures]
- **+1% Damage per steak eaten this wave** (resets per wave) [FOOD-SYS]
- **+25% base chance food spawns are doubled, his fruit-Steaks included (user
  addition 2026-07-24)** [DATA: second_helping key on his tres, stacks with the
  Second Helping item; enemy-drop food path rolls it too via main.gd hook. His
  card also carries the consumable_food_steak display effect (rule 2)]
- −15% Speed; Speed modifications −50%; −20% Attack Speed; Attack Speed modifications −25%;
  Ranged damage modifications −100% [DATA: all exist as gain_stat_*/stat_* keys]
- Starts with a **Cleaver** in inventory (Culinary weapon — weapons milestone)

## #6 The Zombie
- **Cannot heal by any means** [DEEP: heal-gate hook in player.gd]
- **Damage modifications +50%** [DATA: gain_stat_percent_damage +50] ✓ already live
- −20% Attack Speed [DATA]
- −20% Speed (user change 2026-07-24) [DATA: stat_speed −20]
- **Dodge capped at 10%**, and anything that raises the dodge cap is 50% less effective on him [DEEP: dodge cap key exists? verify]
- Starts with **Growling Stomach** (not Mosquito Jar — swapped in the build; +4 Appetite,
  and its no-consumable-heal downside is free on a character that already cannot heal)
- Starts with **Nine Lives** (user change 2026-07-24; T3, survive lethal damage at 1 HP,
  once per wave / 9 per run, and the item's own −15% Damage rides along). Works despite
  `no_heal`: player.gd writes `current_stats.health = 1` directly rather than calling
  `heal()`, so the Zombie's heal gate never sees it.

## #7 The Minimalist
- Starts with NOTHING; only **Fist** selectable as starting weapon
- **6 item slots** — items are slot-limited like weapons, shown as an inventory [DEEP: major UI+inventory system]
- **Can recycle items** exactly like weapons [DEEP]
- **+8% ALL stats per item held; +12% per item if every held item is max tier (tier 3)** [DEEP]
- −1 weapon slot [DATA]

## #8 The Mime ⚓ (Abyssal owners only — bonus character)
- **Every shop contains exactly one Magic Mirror** (Abyssal T2 duplicate-next-purchase item) [DEEP: shop injection]
- **Mirrors work on weapons too**; auto-merge to make room as if buying repeatedly; can't buy if it can't fit [DEEP]
- Magic Mirrors cost −50%; rerolls +50%; enemies +15% health and +15% attack speed [DATA-ish: reroll_price +50; enemy scaling keys exist (enemy_health/enemy_speed family); mirror pricing DEEP]
- Mirror-on-mirror: 2→3→4 (each works once, not doubling)
- Mirrors refuse ⋄ unique items

## #9 The Tourist
- **+10% to ALL stat modifications per current run's Danger level** (D0=+0 … D6=+60%) [DEEP: run-start hook writing gain_stat_* per danger]
- −20% XP Gain; XP Gain modifications −50% [DATA: xp_gain −20, gain over xp? verify gain_xp key]
- **+5% enemy Attack Speed and HP SCALING per Danger** [DEEP: enemy scaling hook]
- Starts with **Magnifying Glass** (T1 item: +5% crit vs elites, +15% pickup range — items milestone)

## #10 The Ruminant
- **Every food buff triggers a second time at 50% strength, 5 seconds later** ("chews twice") [FOOD-SYS]
- (Mint's refresh does NOT echo — balance law)
- −20% Speed; Speed modifications −25%; −2 Armor [DATA]
- Starts with **Chicken Soup** (T0 item — items milestone)

## #11 The Snail (display name: "Slug")
- **Slime trail that slows enemies 30%** [DEEP: trail entity]
- +6 Armor; +20 Max HP [DATA]
- **Speed hard-capped at −20%** (cannot be brought above it) [DEEP: speed cap]
- Dodge modifications −100% [DATA: gain_stat_dodge −100]
- Starts with **Fondue Set** (T1 food spawner — food milestone)
- Easter egg: eating Escargot as the Snail grants +1 extra Armor

## #12 The Blacksmith
- **Class-based forging**: merge two same-tier weapons sharing a class → random weapon of
  the NEXT tier within that class; if the pair shares BOTH classes, result rolls from
  weapons carrying either or both. Forge pool = unlocked weapons only. [DEEP: shop/combine system]
- Weapon prices +25% (note: this is a PRICE INCREASE, not the −25% I wrongly shipped) [DATA: weapons_price +25]
- Elemental damage modifications −50%; −5% Speed [DATA]
- Starts with an **Anvil** (base-game item)

## #13 The Juggler
- **Only one weapon attacks at a time, cycling left→right, on a fixed metronome
  (user redesign 2026-07-24): each weapon fires 0.3s after the previous one,
  IGNORING its own cooldown. Attack Speed divides the interval: 0.3s / (1 +
  Attack Speed/100), clamped to [0.05s, 3s] as a safety net.** [DEEP:
  weapon.gd edge-triggered gate; live card formula = effect.gd
  EFFECT_JUGGLER_TEMPO. The old "+250% on the active weapon" is GONE.]
- −15% Damage; Armor modifications −50%; Attack Speed modifications −25% [DATA]
- Starts with nothing

## #14 The Mole
- **Fog of war every wave** — only a radius around the player is visible (engine has fog/visibility hooks) [DEEP]
- +30% Damage; +10 Luck; +15% XP Gain; **+50% Melee damage modifications** [DATA]
- **−50% Range; −25% Ranged damage modifications** [DATA]
- Starts with **Pocket Sand** (T0 item — items milestone)

## #15 Girly (added 2026-07-24, user spec) [DEEP + FOOD-SYS]
- **Panics when hit** — on ANY hit, INCLUDING dodged / armor-nullified damage, a
  pink "PANIC" floating text pops and she **teleports to the point furthest from
  every enemy** (9x9 grid over the zone rect, maximising nearest-enemy distance).
  **10-second cooldown.** [DEEP: main.gd girly_panic_teleport, hooked in
  _on_player_took_damage_food BEFORE its dodge/protected return; cooldown via the
  _food_trigger_cooldowns dict keyed by generate_hash("girly_panic")]
- **After teleporting, spawns 2 Fries + 2 Fried Rice around her** [FOOD-SYS: she is
  a food source, so her card carries FOODDISP lines for BOTH foods = each food's
  buff + max stacks + eaten count, per rule 2]. (Original design was a +Speed/+Regen
  self-buff; changed to the food burst 2026-07-24 to fit the mod.)
- +10 Max HP; +10% Map Size; +50% Items Price; Luck modifications −30% [DATA:
  stat_max_hp +10, map_size +10, items_price +50 (NEG), gain_stat_luck −30]
- wanted_tags = [stat_dodge] (dodged hits still trigger her panic, so dodge synergises)
- Starting weapon pool: pistol, smg, wand, slingshot, taser, scissors, knife,
  medical_gun, pizza_cutter, champagne_popper (kite-and-shoot). No starting item.
- Counter: GIRLY_PANICS "Panics: {0}" (per panic, seeded in init_tracked_items).
- ext id 998 (base+i would collide with stat_appetite id=825; EXT_IDS override in
  build_characters.py). Placeholder art (icon + face piece) - needs an art pass.

## #16 The Freeloader ⚓ (added 2026-07-29, user spec) [DEEP]
Abyssal owners only, same as the Mime: the curse clause is entirely `dlcs/dlc_1` content.
`ProgressData.get_dlc_data()` returns null for non-owners, so it degrades quietly.

A draft character. He hijacks acquisition the way Mime hijacks the shop's contents,
Minimalist the inventory, and Blacksmith weapon progression.
- **Shop shows 8 items; level up offers 8 upgrades** (was NB_SHOP_ITEMS=4 and a bare
  literal 4) [DEEP: ItemService.get_nb_shop_items / get_nb_upgrade_options, plus runtime
  card cloning in shop_items_container + upgrades_ui_player_container]
- **Everything in the shop is free** [DEEP: shop_item.set_shop_item forces value 0 last,
  after every price modifier, all of which floor at 1]
- **Exactly ONE purchase per shop**, item or weapon [DEEP: gated in
  shop_items_container.on_shop_item_buy_button_pressed, the single entry point both
  categories route through; flag on RunData.freeloader_bought_this_shop, reset by
  base_shop.fill_shop_items on entry]
- **Cannot reroll** (shop or level up) and **cannot lock** [DEEP]
- **No items from crates**, suppressed at the drop site in main.gd so he never walks to an
  empty box. Food and fruit are untouched: they are consumables, not item boxes [DEEP]
- **Materials grant XP but no currency.** Permanently at 0 materials [DEEP: single
  early-return in RunData.add_gold kills all 18 call sites and takes Overtime Pay and
  Second Mortgage with it]. **Harvesting grants nothing either** (main.gd manage_harvesting
  skips him entirely) - without that, the add_xp paired with the gold would have made
  Harvesting his best stat by accident
- **Weapons in his shop are minimum tier 2** (user wording; `tier >= 1` 0-indexed) [DATA:
  min_weapon_tier = 1 as a REPLACE effect, the vanilla Knight pattern, clamped in
  item_service._get_rand_item_for_wave]
- **Every shop offering has a flat 25% chance to be cursed**, ignoring his own stat_curse
  AND the game's `max_curse_item_chance` = 0.15 ceiling that no other character can pass
  [DEEP: dlc_1_data.update_item_effects]. He still accumulates stat_curse from cursed items
  he takes, which is the entire cost: cursed items are STRICTLY STRONGER (every effect
  boosted by `40 + 2*min(20,wave-1) +/- 30` percent), so curse is opt-in power he can dodge,
  paid for with a permanently more cursed enemy pool. Cursed enemies compensate in gold,
  which he cannot use, so they are pure cost for him alone
- **Luck modifications +50%** [DATA: gain_stat_luck +50]
- Economy-only items should never appear in his shop. **NOT YET IMPLEMENTED** (see
  issues/brotato-mods/freeloader-character/STATE.md). Until it lands he is occasionally
  offered dead cards
- ext id 1004. Placeholder art (icon + face piece), needs a PixelLab pass like Girly's
- No tracking_text yet. "Cursed items taken" is the obvious counter and is unbuilt

---

## System laws that touch characters (from the same session)
- **Shared-timer stacking**: one buff instance per food type; magnitude stacks; timer shared.
  Stack 2 adds +50% of base duration, stack 3 +25%, floor +25% per stack from there.
  All percentage-based; duration modifiers scale base AND extensions; round down.
- **Soul Food** (T3 ⋄ item): every 20th consecutive food buff becomes permanent;
  each food has (5 − 0.1×Luck)% chance its buff turns negative permanently. Only stat-buff foods count.
- Balance law fixes: Dishwasher bans Cooler Box; mirrors refuse ⋄; forge pool = unlocked only;
  Leftovers exempt from stack clock; Appetite duration bonus is +10% per 10 App (percent, not flat).
- Unlock economy: 14 win-rewards needed (5 unlock weapons + 5 ⋄ items reserved; 4 more TBD).
- Starting weapon POOLS per character still to be defined (separate from starts-with-item).
