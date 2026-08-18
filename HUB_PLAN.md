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

## 2. Map - two tiers, twin staircases, ~1.5 screens, camera follows

```
        +--------------------------------------------------+
        |  UPPER DECK (drawn north, behind a scrap ledge)   |
        |  [Mode shrine]   [DEPARTURE SHUTTLE]  [Unlock bd] |
        +--[stairs L]----------------------------[stairs R]-+
        |  LOWER PLAZA                                      |
        |  [Smithy ]                            [Diner   ]  |
        |  [Bank   ]        (FOUNTAIN)          [Gremlin ]  |
        |  [Bar    ]     [roster idlers]        [Entrance]  |
        |                [Changing booth]                   |
        +--------------------------------------------------+
```

- Elevation is FAKED, Brotato-style: the deck is a raised band at the top of
  the map behind a wall edge; stairs are walkable ramps gated by collision.
  No new visual language beyond that - the game is flat top-down everywhere.
- Scene ~1.5 screens tall; Camera2D follows the players (solo: the player;
  coop: midpoint of all avatars, clamped to map bounds).
- Stations pair across the plaza (smithy/bank left, diner/gremlin right) so no
  single disabled pack empties a side. A disabled pack's station is replaced by
  a VACANT STALL sprite (boarded-up) - one extra asset that makes every install
  combo look intentional instead of leaving holes. Hidden-when-disabled law
  applies to the NPC + interaction; the vacant prop is scenery, not UI.

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
| Changing booth | core | opens vanilla character select (all players) | the select screen is the coop join point, as vanilla | never |
| Mode shrine | core | per-player game-mode pages (dialog) | one page per active player, FocusEmulator base per popup | never |
| Unlock board | core | read-only unlock/challenge progress (reads challenges_completed, reuses unlock ceremony art) | opener controls; others keep walking | never |
| Chef's diner | food | food/spawner showcase dialog | opener controls | vacant stall |
| Chest gremlin | fortune | chest odds preview (RUNG_BY_ID live data) | opener controls | vacant stall |
| The smithy | forge | tier-ladder gallery (8 rungs) | opener controls | vacant stall |
| The bank | ledger | debt economy explainer / stats | opener controls | vacant stall |
| Roster corner | roster | ambient idlers around the fountain, small barks | n/a (scenery) | absent |
| The bar / Proprietor | core (capstone: all six) | barkeep dialog; with all six packs enabled gains the capstone unlock line; later becomes playable (ECOSYSTEM) | opener controls | never (dialog degrades) |
| Fountain | core | scenery (maybe a gag interact later) | n/a | never |

Coop popup policy (default, user can veto): a station dialog captures ONLY the
opening player's input; other players keep walking. Mode shrine is the
exception (per-player pages). Every popup registers as a FocusEmulator focus
base - the controller-nav law is non-negotiable.

## 5. Art asset inventory (generation comes AFTER this plan is approved)

Ordered roughly by size/importance. All through the existing PixelLab pipeline
+ bake/install scripts; style anchors: codex UI, title background, turret and
crate sprites.

1. Ground/background: lower plaza floor + upper deck band + scrap wall edge +
   map border walls (one large background painting OR tile set - decide at art
   time based on pipeline results; Brotato zones suggest big flat areas + props)
2. Twin staircases (L/R mirrored)
3. Departure shuttle (the flying craft; idle anim nice-to-have: engine flicker)
4. Fountain/statue centerpiece (idle anim nice-to-have: liquid dribble)
5. Changing booth (curtained booth / pod)
6. Station stalls x5: smithy, bank, diner, gremlin den, bar counter
7. Vacant stall variant (boarded-up)
8. Mode shrine (exists as placeholder - real art pass)
9. Unlock board (billboard; reuses unlock-ceremony iconography)
10. NPC sprites x5: chef, chest gremlin, blacksmith, banker, the Proprietor
    (roster idlers REUSE existing character bodies - zero new art)
11. Signage/props: neon signs per stall, crates, wreckage bits, benches
12. Optional: ambient alien critter for life

## 6. Build order (each step ends with gates green, game shippable)

1. FLOW REWORK first, placeholder art: last_played_characters persistence +
   well_rounded default; booth -> character_selection wiring (+ coop join
   verified); shuttle -> weapon-select entry; Back paths; camera follow +
   clamp; coop avatars (2-4). Extend check_all gate 6 (lobby smoke) to assert
   station count + booth/shuttle presence.
2. STATION FRAMEWORK: PackData.lobby_npcs registration (scene + spawn marker +
   requires_packs), vacant-stall fallback, dialogs via popin_manager with
   FocusEmulator bases, mode shrine per-player pages, unlock board data flow.
3. PACK STATION CONTENT: the five pack dialogs (diner/gremlin/smithy/bank) +
   Proprietor dialog + roster idlers.
4. ART PASS: generate per inventory above (art handovers first), install via
   builders, two-tree sync, check_sync green.
5. COOP POLISH PASS: full 2-4 player walkthrough of every station.
6. Workshop packaging: the hub already ships in Core; regenerate workshop +
   check_workshop.sh after every engine-touching step.

## 7. Open micro-decisions (defaults chosen, user can veto any time)

- Statue subject/gag for the fountain (default: heroic First Potato statue)
- Station display names (working names above are placeholders-ish)
- Coop popup policy (default: opener-controls, others walk)
- Drop-in join directly in the hub world (v2 idea; v1 joins via booth screen)
- Vacant stall flavor (boarded-up vs "for rent" sign gag)
- Fountain gag interact (v2)
