# The Special - modifier pool (character #17, design draft 2026-07-29)

User-specced concept: a character whose every wave is jumbled by random modifiers, party-game
style. Real mechanical changes, not stat nudges.

## Settled rules (user, 2026-07-29)
- **Wave 1 rolls nothing.** From then on the **shop shows a pop-up previewing the NEXT wave's
  modifiers**, so you shop knowing what is coming. Reveal-then-shop, deliberately: the chaos is
  a puzzle you are given tools to answer.
- **Jagged curve.** Climbs to **4-6 by wave 20** and does not go much higher in endless. Some
  waves deliberately dip low so there are breathers.
- **A wave can roll all bad, or all good.** You never know. **The pool contains more bad than
  good.**
- **Never double-trigger a system the wave was already going to run.** Check the existing wave
  flags before rolling: `_is_fog_wave`, `_is_bullet_hell_wave`, `_is_elite_wave`,
  `RunData.is_elite_wave(EliteType.HORDE)`. Two fog of wars is nonsense.
- **Conflicts must be handled carefully.** Tag every modifier and forbid contradictory pairs.

## Settled rules, round 2 (user, 2026-07-29)
- **Weighting drifts with wave number.** Good modifiers get *slightly* rarer as waves climb,
  and bad ones start *slightly* less common than they end up. A drift, not a cliff.
- **Cards show name AND numbers.** Big readable name as the header, exact stats underneath.
  The name has to be scannable at a glance; the numbers have to be there to play around.
- **EVERY modifier is temporary.** No exceptions in the wave-scoped tier.
- **Endless repeats modifiers.** The pool does not exhaust.

## THE SAFETY LAW (this is the one that matters)

**Express every modifier as a reversible DELTA. Never as an object transformation.**

Proven the hard way: "Blunt Instruments - all weapons become tier 1" is **impossible**.
28 weapons have no tier-1 variant on disk, including every tier-4-only weapon
(excalibur, scythe, chain_gun, gatling_laser, nuclear_launcher, obliterator, drill,
dextroyer, golden_spatula). Those are precisely the weapons a player holds at wave 20,
which is when the modifier would matter. Checked with `ls weapons/*/*/[0-9]`.

So it becomes **"your weapons deal tier-1 damage"** - a stat multiplier, perfectly
reversible - instead of "your weapons become tier 1", an irreversible object swap.

Apply the same test to every modifier before it ships: *can this be undone exactly, with
one subtraction, without needing an asset that may not exist?* If not, rewrite it as a delta.

### The other landmines in the same class
1. **There are TWO lifetimes, not one.** Wave-scoped modifiers tear down at wave end.
   But Comped / Fire Sale / Blood Money / Bare Cupboard / Cash Only / Clearance / Sticky
   Fingers are **NEXT-SHOP scoped** - they must survive wave end and die after the shop
   closes. Build one lifetime and every shop modifier silently does nothing.
2. **Never serialise modifier state.** This project has already been burned: run saves
   serialise resources, so a player who quits mid-modified-wave would make the temporary
   state permanent. Strip modifiers before save, re-apply after load.
3. **Stash originals, never mutate them.** Butterfingers (`weapon_slot 0` with six weapons
   equipped) must BENCH the weapons and restore **the exact same instances**, not fresh
   copies, or per-weapon upgrade and curse state is silently lost.
4. **Teardown must run on death and on run end**, not just on clean wave end, or the
   end-of-run screen shows a corrupted build.
5. **Flag permanent residue explicitly.** Spoiled (lose an item) and Foraging (gain one) are
   *deliberately* permanent. Without an explicit per-modifier flag someone will later
   "fix" the wrong one as a bug.
6. **Food buff timers must not outlive the wave.** A buff gained under Sugar Rush (doubled
   magnitude) must not persist doubled into the next wave through the shared-timer stacking.
7. **Dedupe against the wave's own events** before rolling: `_is_fog_wave`,
   `_is_bullet_hell_wave`, `_is_elite_wave`, `RunData.is_elite_wave(EliteType.HORDE)`.
8. **Prefer the proven apply/unapply path.** `add_item` / `remove_item` already applies and
   cleanly unapplies an effect set, resetting the stat cache and LinkedStats. Anything
   routed through that is symmetric by construction. Direct stat writes are where the bugs
   will live.

## THE COMPENSATION LAW (user, 2026-07-29)

**Any modifier that removes a core capability must ship its compensation on the same card,
and the compensation must SCALE with the wave.** A flat +10 anything is meaningless by
wave 20. A bad modifier should be painful and survivable, never an unwinnable wave: a loss
screen is not a modifier.

`hit_protection` is the "shield" key (free-hit counter, `player.gd:357`). It is read fresh
at wave start from the player effect, so it **already refills every wave** with no teardown
needed. Ideal for exactly this.

### Butterfingers needs THREE things, not one
Removing weapons is only a third of the Bull. His real kit is
`weapon_slot 0` + `explode_on_hit` + **`stat_max_hp 20`, `stat_hp_regeneration 15`,
`stat_armor 10`, `effect_increase_stat_gains 50`**. Take only the first half and you have a
death sentence.
1. **Survivability** so contact is affordable: `hit_protection` ~12 plus armour and regen.
2. **Explosion damage that SCALES with the wave.** This is the one that would silently kill
   the modifier. Bull's explosion rides on his own stat investment; a player who is not Bull
   has none, so at wave 14 Butterfingers would do pathetic damage and lose the wave through
   no fault of play. The modifier has to grant the explosion power itself, scaled.
3. The weapon removal, with originals **stashed not destroyed** (see the safety law).

Starting numbers to playtest from, not gospel: `hit_protection` 12, `stat_armor` +15
(above Bull's 10, because this is one wave with no weapon safety net),
`stat_hp_regeneration` +15, explosion damage scaled off current wave.

### Other modifiers that owe compensation
- **One Pan** (only first weapon works) - needs a big damage multiplier on that weapon.
- **Blunt Instruments** (tier-1 damage) - same problem, same fix.
- **Full Belly** / **Intermittent Fasting** - in a food mod these remove a whole layer.
- **Front of House / Back of House** - see eligibility below, this one is worse.

## ELIGIBILITY PREDICATES (separate from conflict tags)

Conflict tags stop two modifiers colliding with each other. **Eligibility stops a modifier
colliding with the PLAYER'S CURRENT STATE**, which is a different problem and just as fatal.

- **Back of House** (ranged disabled) must not roll if the player has no melee weapons.
  Otherwise it is not a hard wave, it is zero damage output and a guaranteed loss.
- **Front of House** (melee disabled) likewise if they have no ranged.
- **One Pan** is pointless with one weapon equipped and brutal with six.
- **86'd** (disable a random item) needs the player to actually own items.
- **Spoiled** (lose a random item) same.
- **Clearance** (weapons-only shop) is dead if weapon slots are full.

Every modifier needs an `is_eligible(player_index) -> bool` alongside its conflict tags.

## Cost key
- **FREE** = an existing effect key or an existing system, pure data or a trigger call
- **CHEAP** = small new hook on top of something that already exists
- **NEW** = genuinely new code

## Conflict tags
Tag each modifier with the axes it touches, then forbid a roll that would pick two on the same
axis, or a nullifying pair (WEAPONS_OFF + attack-speed buff is a dead roll).
Axes: `ENEMY_COUNT` `ENEMY_STATS` `ARENA_SIZE` `VISION` `WEAPONS` `WEAPON_STATS` `SPEED`
`HP` `HEAL` `DODGE` `LOOT` `SHOP` `FOOD` `WAVE_LENGTH` `IDENTITY`

---

## 1. Enemy composition  (ENEMY_COUNT)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| Full House | +50% enemy count | BAD | FREE `number_of_enemies` |
| Slow Night | -40% enemy count | GOOD | FREE |
| Two Star Review | +1 extra elite | BAD | FREE `init_elite_group` |
| Health Inspection | +2 extra elites | BAD | FREE |
| The Rush | this wave becomes a horde wave | BAD | FREE |
| Dead Shift | no elites at all | GOOD | FREE |
| Table for One | one enormous elite, almost no trash | MIXED | CHEAP |
| Regulars | every enemy this wave is the same single type | MIXED | CHEAP |
| Understaffed | enemies spawn 50% faster with half HP | MIXED | CHEAP |
| Last Orders | enemies stop spawning halfway through | GOOD | CHEAP |
| Walk-Ins | enemies spawn in bursts instead of a stream | MIXED | CHEAP |

## 2. Enemy stats and behaviour  (ENEMY_STATS)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| Well Done | +50% enemy health | BAD | FREE `enemy_health` |
| Rare | -30% enemy health | GOOD | FREE |
| Hot Plate | +30% enemy speed | BAD | FREE `enemy_speed` |
| Cold Storage | -30% enemy speed | GOOD | FREE |
| Sharp Knives | +40% enemy damage | BAD | FREE `enemy_damage` |
| Blunt | -40% enemy damage | GOOD | FREE |
| Cursed Service | half of all enemies spawn cursed | BAD | CHEAP (curse system) |
| Split the Bill | enemies split into two smaller ones on death | BAD | NEW |
| Grease Fire | enemies leave a burning patch where they die | BAD | CHEAP |
| Sticky Floor | enemies leave slowing puddles | BAD | CHEAP (Slug trail, inverted) |
| Stage Fright | enemies flee once below 25% HP | MIXED | NEW |
| Tenderised | enemies take +100% damage but hit twice as hard | MIXED | FREE |
| Armoured Up | enemies take flat reduced damage | BAD | FREE |

## 3. Arena and environment  (ARENA_SIZE / VISION)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| Kitchen Fire | bullet hell active this wave | BAD | FREE `ZoneService.bullets_hell` |
| Blackout | fog of war | BAD | FREE (Mole / `_is_fog_wave`) |
| Walk-In Freezer | arena at half size | MIXED | FREE `map_size` |
| Banquet Hall | arena at double size | MIXED | FREE |
| Overgrown | the arena fills with trees | MIXED | FREE `trees` |
| Wall Ovens | the walls fire projectiles inward on a timer | BAD | CHEAP (reuse bullet hell) |
| Mopped Floors | reduced friction, you slide | BAD | NEW |
| Grease Trap | random floor patches damage you | BAD | CHEAP |
| Lights Out | the arena darkens progressively across the wave | BAD | CHEAP |
| Dumbwaiter | a crate drops at a random spot every 10s | GOOD | CHEAP |
| Spilled Stock | you leave a slime trail that slows enemies | GOOD | FREE (Slug) |
| Dinner Rush | the wave is 30% shorter | GOOD | CHEAP (WAVE_LENGTH) |
| Overtime | the wave is 50% longer, rewards scale with it | MIXED | CHEAP |

## 4. Your weapons  (WEAPONS / WEAPON_STATS)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| Butterfingers | 0 weapons, you damage by touch like the Bull | MIXED | FREE `weapon_slot 0` + `explode_on_hit` |
| One Pan | only your first weapon works | BAD | CHEAP |
| Mise en Place | weapons fire in sequence, Juggler style | MIXED | FREE (Juggler) |
| Front of House | melee weapons disabled | BAD | FREE `no_melee_weapons` |
| Back of House | ranged weapons disabled | BAD | FREE `no_ranged_weapons` |
| Sharpened | +50% damage | GOOD | FREE |
| Dull Blades | -30% damage | BAD | FREE |
| Rapid Service | +50% attack speed | GOOD | FREE |
| Slow Service | -40% attack speed | BAD | FREE |
| Long Reach | +100% range | GOOD | FREE |
| Cramped | -50% range | BAD | FREE |
| Skewered | all projectiles pierce | GOOD | FREE `piercing` |
| Shaky Hands | -50% accuracy | BAD | FREE `accuracy` |
| Double Portion | +2 projectiles | GOOD | FREE `projectiles` |
| Borrowed Knives | your weapons are swapped for random ones of the same tier | MIXED | CHEAP |
| Blunt Instruments | every weapon becomes tier 1 this wave | BAD | CHEAP `max_weapon_tier` |
| Top Shelf | every weapon becomes max tier this wave | GOOD | CHEAP `min_weapon_tier` |

## 5. Your body  (SPEED / HP / HEAL / DODGE)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| Padded | +100% armour, -50% speed | MIXED | FREE |
| Featherweight | +50% speed, -50% max HP | MIXED | FREE |
| Food Coma | -40% speed | BAD | FREE |
| Caffeinated | +40% speed | GOOD | FREE |
| Nine Lives | survive one lethal hit | GOOD | FREE (item exists) |
| Glass | you die in one hit, but +200% damage | MIXED | FREE `die_in_one_hit` |
| Bleeding Out | lose HP per second | BAD | FREE `lose_hp_per_second` |
| Iron Stomach | immune to damage over time | GOOD | CHEAP |
| Nil By Mouth | no healing of any kind | BAD | FREE `no_heal` |
| Second Wind | +5 HP regen | GOOD | FREE |
| Butterfingered | dodge capped at 0 | BAD | FREE `dodge_cap` |
| Slippery | +30 dodge | GOOD | FREE |
| Growth Spurt | you are 50% bigger, hitbox included | BAD | CHEAP |
| Bite Size | you are 40% smaller | GOOD | CHEAP |
| Panic Attack | you teleport to safety on every hit, Girly style | MIXED | FREE (Girly) |
| Thick Skin | flat damage reduction, but -50% pickup range | MIXED | FREE |

## 6. Loot and economy  (LOOT / SHOP)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| The Golden Goose | one random enemy drops 20x loot | GOOD | CHEAP |
| Stiffed | enemies drop no materials | BAD | FREE `gold_drops` |
| Generous Tips | +100% materials | GOOD | FREE |
| Comped | next shop is free | GOOD | FREE (Freeloader) |
| Surge Pricing | next shop costs double | BAD | FREE `items_price` |
| Blood Money | next shop costs HP | BAD | FREE `hp_shop` |
| Cash Only | no rerolls next shop | BAD | FREE `reroll_price` |
| Fire Sale | next shop shows 8 items | GOOD | FREE (Freeloader) |
| Bare Cupboard | next shop shows 2 items | BAD | FREE |
| Clearance | next shop is weapons only | MIXED | FREE (Blacksmith) |
| Spoiled | you lose a random item at the end of this wave | BAD | CHEAP |
| Foraging | a free item drops at the end of this wave | GOOD | CHEAP |
| Sticky Fingers | you may steal one shop item next shop | GOOD | FREE (steal exists) |

## 7. The food layer  (FOOD - mod specific, our strongest content)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| All You Can Eat | food buffs last the entire wave | GOOD | CHEAP |
| Intermittent Fasting | no food spawns at all | BAD | FREE (item exists) |
| Feeding Frenzy | all food spawns doubled | GOOD | FREE `second_helping` |
| Spoiled Batch | all food is poisoned and damages you | BAD | CHEAP (Druid `poisoned_fruit`) |
| Chews Twice | every food triggers twice, Ruminant style | GOOD | FREE (Ruminant) |
| Crash Diet | food buffs halved | BAD | CHEAP |
| Sugar Rush | food buffs doubled, duration halved | MIXED | FREE (Comp Eater) |
| Mystery Meat | you cannot see which food is which | MIXED | CHEAP |
| Full Belly | you cannot eat this wave | BAD | CHEAP |
| Michelin Night | every food that spawns is a Golden Apple | GOOD | CHEAP |
| Butcher's Shift | all fruit becomes steak, +1% damage per steak | GOOD | FREE (Butcher) |

## 8. Borrowed identities  (IDENTITY - whole kits for one wave)
Cheap because `add_item`/`remove_item` cleanly apply and unapply a character's effects, proven
in the Understudy investigation. Only ever roll ONE of these per wave.
| Name | Effect | G/B |
|---|---|---|
| Zombie Shift | cannot heal, +50% damage | MIXED |
| Mime Shift | next shop contains a Magic Mirror | GOOD |
| Mole Shift | fog of war, +30% damage, -50% range | MIXED |
| Blacksmith Shift | next shop is weapons only, forging enabled | MIXED |
| Demon Shift | shop costs HP, extra starting materials | MIXED |
| Wounded Shift | die in one hit, big speed bonus | MIXED |
| Pacifist Shift | big payout for every enemy left alive at wave end | MIXED |
| Streamer Shift | materials tick up while standing still | MIXED |

## 9. Pure chaos  (roll rarely, these are the party pieces)
| Name | Effect | G/B | Cost |
|---|---|---|---|
| Health Code Violation | one modifier on this wave is applied twice | MIXED | CHEAP |
| Rotating Menu | modifiers reroll halfway through the wave | MIXED | CHEAP |
| Sealed Envelope | one of this wave's modifiers stays hidden until it fires | BAD | CHEAP |
| 86'd | one random item in your inventory is disabled | BAD | CHEAP |
| Off Menu | a random vanilla character's whole kit is applied | MIXED | CHEAP |
| Double Booked | next wave's enemies spawn too, then that wave is skipped | MIXED | NEW |
| Staff Meal | you start the wave with a random food buff already active | GOOD | CHEAP |
| Word of Mouth | this wave's modifiers carry over into the next one too | MIXED | CHEAP |

---

## Counts
~105 modifiers. Roughly 30 GOOD, 45 BAD, 30 MIXED, which lands the "more bad than good" skew
while keeping MIXED as the interesting middle (most MIXED are bad indirectly, which is what
the user asked for).

About 55 are FREE, 40 CHEAP, 6 NEW. The pool can ship in stages: FREE tier alone is already
~55 modifiers and a complete character.

## Open design questions
1. Do GOOD modifiers get rarer as waves climb, or does only the COUNT change?
2. Should the player see modifier names only, or names plus exact numbers?
3. Do any modifiers persist across waves, or is every wave a clean slate (Word of Mouth aside)?
4. Endless mode: does the pool exhaust, or can modifiers repeat?
