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
- Max HP modifications −30%; −10% Dodge [DATA: gain_stat_max_hp −30, stat_dodge −10]

## #5 The Butcher
- **Everything fruit becomes steak** — visual/descriptive reskin only: fruit→raw steak,
  trees→steak piles, Garden→Meat Locker, Pruner→butcher variant. Raw steak (healing
  pickup) vs grilled steak (buff food) stay visually distinct; his counter counts both. [FOOD-SYS + textures]
- **+1% Damage per steak eaten this wave** (resets per wave) [FOOD-SYS]
- −15% Speed; Speed modifications −50%; −20% Attack Speed; Attack Speed modifications −25%;
  Ranged damage modifications −100% [DATA: all exist as gain_stat_*/stat_* keys]
- Starts with a **Cleaver** in inventory (Culinary weapon — weapons milestone)

## #6 The Zombie
- **Cannot heal by any means** [DEEP: heal-gate hook in player.gd]
- **Damage modifications +50%** [DATA: gain_stat_percent_damage +50] ✓ already live
- −20% Attack Speed [DATA]
- **Dodge capped at 10%**, and anything that raises the dodge cap is 50% less effective on him [DEEP: dodge cap key exists? verify]
- Starts with **Mosquito Jar** (T0 item: +2 Life Steal, −1 HP Regen — items milestone, simple)

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
- **Only one weapon attacks at a time, cycling left→right; the active weapon attacks +250% faster** [DEEP: weapon-loop control]
- −15% Damage; Armor modifications −50% [DATA]
- Starts with nothing
- (Cooldown floor: engine minimum_weapon_cooldowns is the safety net)

## #14 The Mole
- **Fog of war every wave** — only a radius around the player is visible (engine has fog/visibility hooks) [DEEP]
- +30% Damage; +10 Luck; +15% XP Gain; **+50% Melee damage modifications** [DATA]
- **−50% Range; −25% Ranged damage modifications** [DATA]
- Starts with **Pocket Sand** (T0 item — items milestone)

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
