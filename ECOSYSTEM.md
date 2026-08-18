# ECOSYSTEM.md - the Brotato mod ecosystem constitution

**Read this before building ANY new feature.** Every piece of content and every engine
hook from now on belongs to a declared pack and follows the architecture below. This file
is the single source of truth for the ecosystem design; PIPELINE.md enforces it per
content type.

## Vision

The Gourmet mod becomes a **mod ecosystem**: a set of optional packs. Each pack works
completely on its own; all packs are cross-compatible; combining specific packs unlocks
hidden synergy content (characters, items, chest variants); a Full Collection bundle
enables everything. Eventually the ecosystem ships as Steam Workshop mods via
godot-mod-loader (already integrated in the game). An in-game walkable hub/lobby
(Enter-the-Gungeon-Breach style) fronts the whole thing: NPCs per pack, an unlock board,
and per-player selectable game modes.

Three locked laws (user, 2026-08-17):
1. **Workshop end-goal.** Architecture aims at ModLoader packaging even while we develop
   inside the decompile. No distribution infrastructure yet.
2. **Synergy content is HIDDEN unless all required packs are enabled.** Never grayed-out,
   never degraded - unregistered content simply does not exist.
3. **The lobby is fully specced (below) but built AFTER modularization.**

## Pack partition - 5 packs + core (originally 6; fortune merged into forge 2026-08-18)

A pack = one feature system plus every piece of content that is worthless without it.
System-defining characters ship inside their system's pack.

| id | Name | Contents |
|---|---|---|
| `core` | Gourmet Core | Framework only, never user-facing content: PackService/PackData, engine seam hooks, tier-ladder registry, telemetry tracker, (later) game-mode service + lobby framework, translation merge. |
| `food` | Gourmet | The flagship. Food/spawner/Appetite/buff engine (24 spawners, 27 foods, 21 trigger buckets), Appetite stat + upgrades, pantry items, **culinary weapons** (their set grants Appetite - worthless standalone, so they live here), Butcher meat reskin, food characters: Gourmet, Butcher, Ruminant, Competitive Eater, Picky Eater, Dishwasher, Sweet Potato, Slug (the spawner-biased roster). |
| `forge` | Forge & Fortune | The 8-tier system, both faces (MERGED 2026-08-18, user: Blacksmith and P2W both live on the tier ladder). Forging: 280 ladder weapons, forge logic + UI, Blacksmith. Gambling: P2W lootboxes - 8 chests, reel ceremony, rarity spread (RUNG_BY_ID), The P2W, **Magic Mirror**. Old id `fortune` stays valid via MERGED_PACK_ALIASES (saved runs, settings). |
| `ledger` | Ledger | Debt economy: global enemy debt scaling, Credit Card / Bank Loan, The Debtor. |
| `roster` | Party Roster | System-agnostic characters (the "co-op DLC characters" pack): Mime, Mole, Zombie, Tourist, Juggler, Minimalist, Freeloader, Wildcard. Wildcard's 63 modifiers ship here as content; the modifier ENGINE (`special_modifiers.gd`) is core. |

**Full Collection** = a meta-pack whose activation enables all five. No content of its own.

## Architecture (near-term, inside the decompile)

- **`PackData extends DLCData`** at `res://packs/<id>/pack_data.tres`. The vanilla DLC
  contract (`global/dlc_data.gd`) already provides registration arrays, reversible
  `add_resources()`/`remove_resources()`, translations, tracked_items, and per-item hooks.
  PackData adds: `pack_id`, `requires_packs`, `synergies`, later `lobby_npcs`,
  `game_modes`. Packs deliberately do NOT live in `res://dlcs/` - that scan runs Steam
  entitlement checks packs must never touch.
- **`PackService` autoload** clones ProgressData's DLC lifecycle: scan -> `available_packs`;
  `settings.enabled_packs` (persisted); `activate_pack`/`deactivate_pack` via the DLCData
  add/remove machinery; per-run snapshot `RunData.enabled_packs`; Continue invalidated if
  a save needs a missing pack (clone of `check_dlc_valid_for_saved_run_state`). A cached
  boolean facade gives cheap greppable guards: `if Packs.food:`.
- **Gating strategy - no rewrite.** Unregistered content is invisible content: the ~106
  `my_id == "character_x"` branches and `is_<char>()` gates go dead automatically when
  their pack is off and need NO guards. Only character-independent always-on behavior
  gets `if Packs.x:` guards (~30-60 seams): food ambient/trigger loop entry points,
  debt enemy scaling, chest shop injection, forge UI entry, tracked-items seeding
  (rebuilt from enabled PackDatas' `tracked_items`).
- **Tier ladder**: `BS_TIER_LADDER` becomes a core REGISTRY. Forge registers the 8-tier
  ladder on activation. Fortune standalone rolls vanilla tiers; Fortune+Forge chests roll
  the full ladder (a declared synergy, not a hardcode).
- **Rarity spread**: `RUNG_BY_ID` stays complete (covers all items); chest rolls intersect
  candidates with currently-registered items at roll time. Never regenerate per pack
  combination.
- **Synergies**: `SynergyData { requires_packs, characters/items/weapons/challenges }`,
  owned by exactly one pack. `PackService.evaluate_synergies()` runs at boot and on every
  activation change: registers synergy content only when the FULL requirement set is
  enabled, unregisters otherwise. Hidden = absent from character select, shop pools,
  codex, lobby.
- Existing cross-couplings become declared synergies: chest->bs-weapon drops
  (fortune+forge), chest->food drops (fortune+food), Mirror-duplicates-chests (internal
  to fortune).

## Unlock framework

Synergy characters are delivered as `ChallengeData` (RewardType.CHARACTER) living inside
SynergyData - the challenge only registers when its packs are on. ProgressData unlock
flags persist across pack toggles (disable a pack -> character hidden; re-enable ->
still unlocked). **Engine fix required first**: `progress_data_loader_v3.gd` does not
persist `systems_unlocked` - close that gap before any SYSTEM-reward unlock ships.

Starter synergy ideas (frameworks first, content later; user invents more):
- `fortune+forge` -> **Pit Boss**: weapons only from chests, chests always roll the ladder.
  Unlock: forge a tier-8 weapon that came out of a chest.
- `food+ledger` -> **Deliverer**: debt-financed restaurateur, spawners bought on credit.
  Unlock: end a run with 0 debt and 20+ Appetite.
- `food+fortune` -> **Mystery Meal** chest variant + small item set. Unlock: eat 10
  chest-dropped foods.
- All five -> **The Proprietor**: the lobby barkeep becomes playable. Full-collection capstone.

## Lobby spec (build in Phase 7, after modularization)

- Walkable `ui/lobby/lobby.tscn` (Node2D). `lobby_player.gd` = movement-only
  KinematicBody2D (do NOT reuse full player.gd - it is wired to weapons/waves).
- Insertion (user law 2026-08-18): the Hub is an ALTERNATE main-menu destination - a
  "Hub" button beside Start. The Start path stays vanilla, always. The Hub's Departure
  door enters the unchanged character-select -> weapon -> difficulty flow (Back returns
  to the Hub only when the flow began there, via MenuData.run_flow_from_lobby).
  `difficulty_selection.gd` stays the single RunData configuration choke point and
  additionally consumes lobby-chosen game modes.
- NPC framework: `lobby_npc.gd` = Node2D + proximity Area2D (pattern:
  `item_attract_area.gd`) + interact prompt. NEW input action `interact` (none exists).
  Dialogs via `popin_manager.gd`; every popup registers as a FocusEmulator focus base
  (controller-nav law - violating it makes UI structurally dead on gamepad).
- Packs register NPCs via `PackData.lobby_npcs` (scene + spawn marker + requires_packs).
  NPCs for disabled packs/synergies don't spawn. Sketch: food -> chef; fortune -> chest
  gremlin (odds preview); forge -> blacksmith (tier gallery); ledger -> banker;
  roster -> characters loitering; core -> mode shrine + unlock board (reads
  `challenges_completed`, reuses the existing unlock ceremony UI).
- **Game modes**: `GameModeData {id, name, icon, modifier_ids, allowed_in_coop,
  forbidden_pairs}` + a core `game_mode_service.gd` modeled on `special_modifiers.gd`
  (reversible numeric-delta registry, FORBIDDEN_PAIRS, apply/unapply). **Per-player**
  selection (precedent: per-player OptionButton in character_selection console path),
  stored in `RunData.players_data[i]`, snapshotted for save/resume with the same
  invalidation as enabled_packs. Interim pre-lobby UI: extend `run_options_panel.gd`
  (endless/coop button pattern) so modes can ship in Phase 6 before the lobby exists.
- Co-op: all local players get avatars, shared camera, any player interacts; per-player
  mode pages inside the mode-shrine dialog.

## ModLoader end-game (Phase 8)

- **`GourmetCore`** base Workshop mod: carries ALL vanilla-file diffs as
  `install_script_extension` overrides + PackService/PackData + lobby + game modes.
  Version-pinned against Brotato updates (accepted risk; game patches mean re-diffing
  Core only, packs untouched).
- **Per-pack mods**: nearly pure data - manifest depends on Core, `mod_main.gd` calls
  PackService registration, art ships as `.pck` (the game already supports
  `load_resource_pack` via the DLC loader).
- Working prototypes of both patterns already exist in `mods-unpacked/`
  (Darkly77-ContentLoader, nicolassut-HelloBrotato script-extension example).
- Near-term enablers, baked into every phase from now on:
  1. Funnel every vanilla-file edit through small NAMED hook functions.
  2. Migrate scene-baked registration (`item_service.tscn` ext arrays) to runtime
     `add_resources()` - a .tscn diff can never ship as a Workshop mod.
  3. Nothing generated live-only: every generated file has a repo-tracked source.

## Dev-process law (every future session)

- Every piece of content declares its pack in the builder (`PACK_ID`), enforced by
  PIPELINE.md's Definition of Done.
- Ext-id governance (formalizing the existing 800-1295 map; new ids ONLY from your pack's
  range - see PIPELINE.md table).
- Gates grow with the ecosystem: `check_packs.py` (every registered id in exactly one
  pack, no dangling requires_packs), pack columns in check_cards/check_sync, and a boot
  matrix of 4 canonical combos (all-on, all-off, food-only, fortune+forge).
- Translations: per-pack CSVs merged at build; the 55 hand-authored rows in
  `custom_translations.csv` are sacred (no builder regenerates them).
- The two-tree mirror discipline and TRANSFER.md flow are unchanged; `apply_to_live.sh`
  additionally copies `res://packs/`.

## Roadmap

| Phase | Work | Effort |
|---|---|---|
| 0 | Hygiene: mirror unversioned engine files, p2w_data.gd under repo control (DONE with this commit) | done |
| 1 | PackService + PackData scaffolding; one "everything" pack; zero behavior change | 1-2d |
| 2 | Split into 6 PackDatas; registration -> runtime add_resources(); debug toggle UI | 3-5d |
| 3 | Engine seam guards; ladder registry; RunData.enabled_packs + Continue safety; solo-pack boot tests | 5-8d |
| 4 | Synergy layer + systems_unlocked persistence fix + first synergy challenges | 2-4d |
| 5 | Builder/gate pack-awareness (PACK_ID, check_packs.py, per-pack codex/translations) | 2-3d |
| 6 | Game modes (engine + pre-lobby UI via run_options_panel) | 3-5d |
| 7 | Lobby (scene, NPCs, interact action, mode shrine, unlock board) | 8-15d |
| 8 | ModLoader packaging (Core script extensions, per-pack mods, manifests) | large |

Every phase ends with all gates green and the game shippable.

## Open cleanup items (flagged, not yet executed)

- `test_debt` (The Debtor debug entry, ext 1008) is marked delete-before-ship but fully
  registered; its `is_debtor()` gate owns the debt economy. Resolve when Ledger pack forms.
- 10 deregistered Appetite items still on disk (`build_appetite_items.py` DEREGISTERED
  set); decide revive-into-food-pack vs delete during Phase 2.
- Verify the unregistered-content invariant (save-resume, codex, run-stats screens all
  tolerate a missing character) before Phase 3 signs off - this is the load-bearing
  assumption of the no-rewrite gating strategy.

## Riskiest decisions (accepted, watch them)

1. Parallel pack lifecycle (`res://packs/` + `RunData.enabled_packs`) instead of
   piggybacking the DLC system - touches save format; a mistake corrupts Continue/resume.
2. Leaving the 106 character branches ungated relies on the unregistered-content
   invariant (see cleanup item above).
3. The version-pinned GourmetCore base-mod bet for Workshop shipping - deep systems
   (food engine, forge) ship as whole-function script extensions; fragile against game
   patches, minimized by the named-hook rule.
