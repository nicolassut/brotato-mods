# HUB_PLAN.md - the walkable Hub, fully planned before anything is built

User-approved plan (2026-08-18). This document is the single source of truth for
Phase 7 remainder: theme, map, stations, run flow, multiplayer, art inventory,
build order. ECOSYSTEM.md's lobby spec still governs the framework laws
(FocusEmulator, PackData.lobby_npcs, hidden-when-disabled); this file is the
concrete design that fills it in. Change this file first, code second.

## 1. Theme - crash-site survivor outpost

Brotato canon: potatoes stranded on a hostile alien planet, surviving waves,
waiting for rescue. The Hub is the outpost the survivors built from wreckage:

- scrap-metal walls and platforms, alien dirt/rock underfoot, salvaged neon
  signage; the Gourmet identity comes from the outpost forming around its galley
- the DEPARTURE SHUTTLE on the upper deck is a small FLYING craft (not the
  crashed hull) - starting a run = flying out on a sortie
- center monument: fountain/statue (subject TBD - "the First Potato" heroic
  statue is the working idea; final gag TBD with the user)
- ART LAW: heavy inspiration from what the base game already shows of potato
  tech and style - the codex UI panels, title-screen background, crate/turret
  sprites, the flat top-down zone look (single ground color + sparse props).
  HANDOVER_ART_PIPELINE.md + HANDOVER_CHARACTER_ART_STYLE.md are mandatory
  reading before generating a single image.

## 2. Map - two tiers, twin staircases, ~2 screens, camera follows

```
        +--------------------------------------------------+
        |  UPPER DECK (drawn north, behind a scrap ledge)   |
        |  [Mode shrine]   [DEPARTURE SHUTTLE]  [Unlock bd] |
        +--[stairs L]--[CHANGING BOOTH]----------[stairs R]-+
        |  LOWER PLAZA                                      |
        |  [slot: smithy ]                  [slot: diner  ] |
        |  [slot: bank   ]    (FOUNTAIN)    [slot: gremlin] |
        |  [slot: RESERVED]                 [slot: bunkhs ] |
        |                  [HUB ENTRANCE]                   |
        +--------------------------------------------------+
```

- Elevation is FAKED, Brotato-style: the deck is a raised band at the top of
  the map behind a wall edge; stairs are walkable ramps gated by collision.
- The CHANGING BOOTH sits against the back wall between the two staircases
  (PvZ Garden Warfare 2 style) - visible from the whole plaza.
- The ENTRANCE is at the bottom center; you walk in facing the fountain with
  the shuttle visible at the top - the whole pre-flight path reads at a glance.
- Scene ~2 screens; Camera2D follows (solo: the player; coop: midpoint
  of all avatars, clamped to map bounds).

### The SLOT SYSTEM (expandability law)

Pack buildings are NOT hardcoded set-dressing. The plaza has FIXED SLOT
ANCHORS (Position2D markers in lobby.tscn, slot_1..slot_6 today, trivially
extensible). A registry maps pack_id -> slot index; at hub load each slot:
- pack installed + enabled  -> that pack's building scene (via
  PackData.lobby_npcs: building scene + interaction)
- pack missing/disabled     -> VACANT BUILDING art (boarded-up)
- unassigned slot           -> RESERVED building art (future content)

Current assignment: slot 1 smithy (forge), slot 2 bank (ledger),
slot 3 RESERVED, slot 4 diner (food), slot 5 gremlin den (fortune),
slot 6 bunkhouse (roster). New packs claim free slots by registry entry only -
no scene surgery. Buildings must fit a COMMON FOOTPRINT (uniform anchor size)
so any building drops into any slot.

## 3. Run flow (amends the 2026-08-18 flow law - user-approved)

The Hub is functionally ETG's Breach: your hub character IS your run character.

- ENTER HUB: each player's avatar wears their LAST-PLAYED character's
  appearance, persisted across sessions per player slot
  (settings.last_played_characters[4]; stamped at run start in
  difficulty_selection, the existing choke point, next to the enabled_dlcs
  snapshot). Never played anything -> spawn as character_well_rounded.
- CHANGING BOOTH (plaza): any player interacts -> opens the UNCHANGED vanilla
  character-selection screen for ALL players. Coop join happens THERE, exactly
  like vanilla (join button on the select screen); newly joined players get hub
  avatars on return. Back -> hub. Selecting updates every avatar immediately.
- DEPARTURE SHUTTLE (deck): any player interacts -> enters the run flow at
  WEAPON select (characters already determined by hub state), then difficulty,
  then the run. Back from weapon select -> hub. difficulty_selection remains
  the single RunData configuration point (characters, weapons, modes, packs
  snapshot all stamped there).
- The vanilla Start path stays 100% vanilla (character -> weapon -> difficulty)
  and never touches the Hub. Law unchanged.
- MULTIPLAYER IS FIRST-CLASS EVERYWHERE: every station below defines its coop
  behavior explicitly. 2-4 avatars, shared camera, any player interacts.

## 4. Stations - the full inventory

| Station | Pack | Interaction | Coop behavior | Despawn |
|---|---|---|---|---|
| Departure shuttle | core | enter run flow at weapon select | any player triggers; vanilla coop weapon/difficulty UIs carry consensus | never |
| Changing booth (back wall) | core | opens vanilla character select (all players) | the select screen is the coop join point, as vanilla | never |
| OFF DUTY corner (replaces mode shrine) | core | chillout hangout: mode-guy characters lounge around a campfire; talking to one opens their TICK-BOX dialog (see 4c). Run-wide, multi-select, persisted, stamped at run start | opener controls (run-wide) | guys appear only while their pack/DLC is enabled |
| Unlock board | core | read-only unlock/challenge progress (reads challenges_completed, reuses unlock ceremony art) | opener controls; others keep walking | never |
| Chef's diner (slot 4) | food | food/spawner showcase dialog | opener controls | vacant building |
| Chest gremlin den (slot 5) | fortune | chest odds preview (RUNG_BY_ID live data) | opener controls | vacant building |
| The smithy (slot 1) | forge | tier-ladder gallery (8 rungs) | opener controls | vacant building |
| The bank (slot 2) | ledger | debt economy explainer / stats | opener controls | vacant building |
| The bunkhouse (slot 6) | roster | roster cast showcase; cast members idle around it, small barks | opener controls | vacant building |
| Reserved (slot 3) | - | none yet ("something else in the future" - user) | - | reserved building art |
| Fountain | core | scenery (maybe a gag interact later) | n/a | never |

No bar in v1 (user call). The Proprietor full-collection capstone still exists
as a CONCEPT (ECOSYSTEM) but has no home yet - candidate for the reserved slot
or a fountain-side NPC later; parked in open decisions.

Coop popup policy (default, user can veto): a station dialog captures ONLY the
opening player's input; other players keep walking. Mode shrine is the
exception (per-player pages). Every popup registers as a FocusEmulator focus
base - the controller-nav law is non-negotiable.

## 4c. OFF DUTY corner - the mode shrine redesign (user, 2026-08-20)

The shrine stone becomes a crash-site BREAK AREA in the deck's west corner:
oil-drum campfire (vanilla torch_burning_particles - tech proof committed
d02a3a8), salvaged seats/crates, sagging work-light string, chalkboard
showing active mode count. MODE GUYS - characters reusing their existing
bodies (zero new character art; vanilla hosts wear vanilla appearance
pieces) - lounge around it. Interact with a guy -> his tick-box dialog.

PURPOSE LAW: modes let you play a character's SIGNATURE SYSTEM while
playing anyone else. UN-GATE LAW: mode guys never add systems - they
remove the "that character must be present" gate on systems their pack
already installs. requires_packs gates the guy's presence: pack disabled ->
he simply is not at the campfire.

TICK-BOX GRAMMAR (three interaction patterns, reuse for future guys):
- SUPERSEDE: an "everything" tick greys out its smaller siblings
- EXCLUSIVE PAIR: two ticks auto-cancel each other (radio-like)
- LINKED SWITCH: one underlying setting mirrored live across two guys'
  dialogs (drawn with a chain-link marker)

V1 LINEUP (6 guys + 1 sleeper seat + 1 empty seat):
1. THE GOURMET "House Menu" (food): [] all fruit becomes steak (Butcher's
   law) / [] all fruit becomes food (EXCLUSIVE PAIR with steak) / [] 30%
   chance the shop stocks a food spawner
2. THE P2W "Lootboxes" (forge): [] all crates are lootboxes / [] lootboxes
   appear in the shop / [] EVERYTHING is lootboxes (SUPERSEDE) / [] full
   8-tier ladder (LINKED with Blacksmith)
3. THE BLACKSMITH "Open Forge" (forge): [] forging enabled for everyone /
   [] loose forge - merges may ignore class (SUPERSEDE over strict) /
   [] elites drop a forgeable weapon / [] full 8-tier ladder (LINKED)
4. THE WILDCARD "Rules" (roster): [] roll a modifier every wave (=existing
   wildcard_rules) / [] double roll (SUPERSEDE) / [] sticky rules: each
   boss wave one modifier becomes permanent
5. THE MOLE "Lights Out" (roster): [] fog on boss waves only / [] fog
   every wave (SUPERSEDE) / [] thick fog (stacks with either)
6. THE DEMON "Blood Market" (vanilla): [] short on materials? pay the
   difference in Max HP / [] everything costs Max HP (SUPERSEDE)

TIER-LADDER LAW (user, 2026-08-20): with the linked ladder switch OFF,
un-gated forging/lootboxes operate in VANILLA tiers (two blue T2s forge a
purple T3, ceiling red T4; chests roll vanilla tiers per the ECOSYSTEM
degrade law). Switch ON -> both ride the full 8-rung ladder (teal
intermediates, RUNG_BY_ID chest spread). The Blacksmith CHARACTER always
forges on the ladder - the switch governs mode-borrowed forging only.
All ticks (ladder included) stamp at run start; never flip mid-run.

BENCH (future seats, in rough priority): King "Royal Visit" (scheduled
elites + elite loot), Saver "Potato Bank" (interest), Loud "Loud & Proud"
(+enemies/+materials), Gardener "Orchard" (tree spawns; trees-drop-food
tick cross-gated on food pack), Zombie "Iron Stomach" (no-heal challenge),
Mime "Hall of Mirrors" (Abyssal-gated), Cursed "Cursed Cargo"
(Abyssal-gated). The sleeper seat: a character asleep - interacting gets a
snore bark - reads as "reserved" diegetically.

RESERVED FOR THE MULTIPLAYER DLC (ecosystem law): the Juggler's "Hot
Potato" (weapons shuffle between players every wave) ships with the future
multiplayer pack, not here.

## 4b. Dialog follow-ups (user, 2026-08-18 walkthrough - build AFTER art starts)
- Dialogs become INTERACTIVE: per-menu activate/deactivate toggles - e.g. the
  Diner can turn OFF food items appearing in the pool (play vanilla item pool
  while keeping the pack installed). Effectively per-content-class toggles on
  top of pack enable/disable - needs design (what is toggleable per station).
- Unlock board grows toward a codex-like browser (stylish variant of the
  codex, its own interaction flow), not just a text list.
- Dialog CONTENTS are a baseline; layout/wording to be redesigned with the
  codex-register UI skin.

## 5. Art - PLACEHOLDER LAW first, generation last

**PLACEHOLDER LAW (user, 2026-08-18): nothing is generated until the hub works
end-to-end on placeholders.** Placeholders are, in preference order:
1. existing in-game sprites (street_vendor, crates, turret stands, codex
   panels - the current lobby already does this for door/shrine)
2. simple authored SVG/PNG shapes (flat fills in the target palette, correct
   FOOTPRINT SIZES so real art swaps in without layout changes)
Placeholders must respect the final footprint dimensions - they are stand-ins,
not throwaways: every collision shape, slot anchor and interaction area is
final from step 1.

Generation inventory (only at step 6, art handovers read first; style anchors:
codex UI, title background, turret/crate sprites):
1. Ground/background: plaza floor + deck band + scrap wall edge + borders
2. Twin staircases (L/R mirrored)
3. Departure shuttle (a FLYING craft; idle engine-flicker nice-to-have)
4. Fountain/statue centerpiece (subject TBD)
5. Changing booth (curtained booth/pod against the wall)
6. Pack buildings x5 on a COMMON FOOTPRINT: smithy, bank, diner, gremlin den,
   bunkhouse
7. Vacant building + reserved building variants (same footprint)
8. Mode shrine + unlock board (real art pass over placeholders)
9. NPC sprites x4: chef, chest gremlin, blacksmith, banker (roster idlers
   REUSE existing character bodies - zero new art)
10. Signage/props: neon signs, crates, wreckage, benches

## 6. Build order (each step ends with gates green, game shippable)

1. FLOW REWORK on placeholders: last_played_characters[4] persistence +
   well_rounded default; booth -> character_selection wiring (+ coop join
   verified); shuttle -> weapon-select entry; Back paths; camera follow +
   clamp; coop avatars (2-4). Extend check_all gate 6 (lobby smoke) to assert
   booth/shuttle/slot-anchor presence.
2. SLOT SYSTEM: slot anchors in lobby.tscn, registry, PackData.lobby_npcs
   building registration, vacant/reserved fallbacks - all placeholder art.
3. STATION CONTENT: the five pack dialogs + mode shrine pages + unlock board
   data flow - still placeholder art.
4. LAYOUT PROOF: full walkthrough (solo + 4p coop) on placeholders; user
   signs off the map feel BEFORE any generation.
5. COOP POLISH PASS: every station 2-4 players.
6. ART PASS: generate per section 5 inventory (handovers first), install via
   builders, two-tree sync, check_sync green.
7. Workshop packaging: hub ships in Core; regenerate workshop +
   check_workshop.sh after every engine-touching step.

## 7. Open micro-decisions (defaults chosen, user can veto any time)

- Statue subject/gag for the fountain (default: heroic First Potato statue)
- What eventually fills the RESERVED slot 3 ("something else in the future")
- The Proprietor capstone's new home (bar was cut) - reserved slot? fountain?
- Bunkhouse name + exact roster interaction
- Station display names generally (working names)
- Coop popup policy (default: opener-controls, others walk)
- Drop-in join directly in the hub world (v2; v1 joins via booth screen)
- Vacant building flavor (boarded-up vs "for rent" gag)
