# Handover: full audit of EVERY item & weapon description (Gourmet mod)

Paste this whole file into a fresh chat. It is the complete brief.

## What I want

A **thorough, exhaustive audit of every single item and weapon description** in my Brotato
"Gourmet" mod, checking each one against ALL of my card-formatting rules. Over many build
sessions a lot of descriptions were written lazily or have drifted out of date, and I want a
complete sweep that finds every violation. Specifically I keep seeing:

- **Vague scaling** — "Scales with X", "increases with X", "more with Appetite", or any
  hand-wave instead of the exact formula.
- **Bad stat formatting** — missing the green/red coloring (wrong sign), missing the live
  `{base} ({current})` variable, value not reflecting **curse** scaling, **wrong formula**,
  or a static string where it should be using the live formula renderer.
- **Missing tracking** — accumulators / permanent-stat grants with no run counter on the card.
- **Outdated text** — the mechanic changed in code but the description was never updated, so
  the card now lies about what the item does.

I want you to **investigate deeply and produce a complete findings report** (every item + every
weapon, one row each, defects categorized, with the corrected text and the exact files to
change). Do NOT start mass-editing until I approve the report — audit first.

## Orchestration constraint (important)

**You are running as Fable 5 and Fable 5 stays the composer/orchestrator.** This is a big
read-heavy sweep, so fan it out — but **the worker agents must be Opus or Sonnet, never Fable
5.** If you use the Agent tool, pass `model: "opus"` (or `"sonnet"`). If you author a Workflow,
set every `agent(...)` call's `model: 'opus'` / `'sonnet'`. Fable 5 only composes/synthesizes;
it must not be the grunt-work reader. Adversarially verify flagged defects (a second agent
re-reads the runtime code) before putting them in the final report.

## Where everything lives

- **Game (decompiled, Godot 3.x, config_version=4):** `~/brotato-decompiled`. NOT a git repo.
  Card text changes need a **REPACK** (the user does that) before they show in-game; the codex
  reads the .tres directly (no repack needed for it).
- **Card text (the strings):** `~/brotato-decompiled/items/custom/custom_translations.csv`
  (format: `KEY,English text`). This is where most fixes land.
- **Effect resources (.tres):** each item/weapon/food/character owns effect `.tres` files that
  set `key`, `text_key`, `value`, `custom_key`, `effect_sign`, `storage_method`. The
  `effect_sign` is what drives the green/red/neutral color (0 positive/green, 1 negative/red,
  2/neutral, 3 auto-from-value).
- **Live-formula rendering:** `~/brotato-decompiled/items/global/effect.gd::get_text`. Two ways
  a scaling value is shown live:
  - `_scaling_formula_text(text_key, base, stat_hash, ratio, player_index, colored)` for plain
    additive `base + ratio*stat` scaling (renders the `{base} ({current})` parenthetical).
  - a bespoke `if text_key == "...":` branch that computes the live value by hand (examples
    already in the file: `EFFECT_W_CORN_POPCORN`, `EFFECT_GREASE_FIRE`, `EFFECT_JUGGLER_TEMPO`,
    `EFFECT_MINIMALIST_ALL`). Foods auto-render through the `EFFECT_FOOD_*` branch.
  A description that changes with a stat but is NOT wired through one of these (just a static
  string) is a violation.
- **Card assembly / extra lines:** `~/brotato-decompiled/ui/menus/shop/item_description.gd`
  (appends food max-stacks + eaten lines, tracking line, etc.).
- **Runtime that defines the REAL formula** (derive the correct text from here, never guess):
  `entities/units/player/player.gd`, `main.gd`, `singletons/run_data.gd`,
  `weapons/weapon_service.gd`, and per-effect scripts under `effects/`.
- **Registration:** `~/brotato-decompiled/singletons/item_service.tscn` (characters / weapons /
  items / foods arrays).
- **Builders (mirror EVERY live change here or a rebuild reverts it):**
  `~/brotato-mods/asset-dev/` — `build_pantry_items.py`, `build_food_system.py`,
  `build_weapons.py`, `build_mod_items.py`, `build_appetite_items.py`, `fix_mechanic_items.py`,
  `characters/build_characters.py`. Note: `overtime_pay` / `second_mortgage` / `vampire_fang`
  are re-written LAST by `fix_mechanic_items.py`, not `build_mod_items`.
- **Codex (regenerate after fixes):** `asset-dev/extract_codex.py` -> `codex.json` ->
  `build_codex_html.py` -> `gourmet_codex.html`; published artifact
  `https://claude.ai/code/artifact/5e25de6c-9e70-43b4-b2c3-83980805013a`.

## Read these FIRST (context + the rules, verbatim)

- `~/brotato-mods/HANDOVER_NEW_ITEMS.md` — file map, build recipes, the non-negotiable rules.
- Memory files: `feedback_brotato_formula_and_food_display` (the master rule),
  `feedback_brotato_perma_stat_tracking`, `feedback_brotato_json_float_counters`.
- `~/.claude/issues/brotato-mods/formula-food-tracking-consistency/STATE.md` — a PARTIAL version
  of this audit was already done (Corn Cannon, Street Vendor, Grease Fire, Slug trail, 5
  trackers). **Read it so you don't re-flag what's fixed, and reuse its patterns.** This new
  pass is the thorough follow-up that catches everything it missed.
- `asset-dev/characters/CHARACTER_SPECS.md` — current mechanics (some changed recently: Juggler
  metronome, Comp Eater momentum, Butcher food-doubling, Zombie, new char Girly).

## Scope — audit EVERY one of these

1. **All custom items** — everything under `~/brotato-decompiled/items/custom/*/` (general
   items, the 20 food spawners, appetite items, food-system items, mechanic items). ~80 items.
2. **All custom weapons** — the ~20 culinary weapons under `weapons/melee/*` and
   `weapons/ranged/*` (ladle, cleaver, corn_cannon, galley_cannon, sauce_blaster, etc.),
   including their special/proc lines (e.g. Corn Cannon popcorn, Dinner Bell, Galley pierce).
3. **All foods** — `items/foods/*/` `EFFECT_FOOD_*` lines (buff formula, stacks wording).
4. **Character cards** (secondary) — their effect lines can have the same issues; flag any but
   note characters were separately audited in `character-spec-audit/STATE.md`.

## Per-item checklist (apply to every single one)

For each item/weapon, pull its live card text (custom_translations.csv), its effect `.tres`
(sign, keys), and the runtime code that implements it, then check:

1. **No vague scaling** — any value that changes with a stat MUST show the exact formula (base
   AND per-point coefficient). Flag "scales with", "increases with", "more with X", etc.
2. **Formula is correct** — the numbers shown actually match what the runtime computes. Derive
   the real formula from code; flag mismatches.
3. **Uses the live renderer** — scaling values render via `_scaling_formula_text` or a bespoke
   effect.gd case (the `{base} ({current})` live parenthetical), not a dead static string.
4. **Sign / color correct** — `effect_sign` makes positives green, negatives red, neutrals
   white. Flag wrong-colored or sign-less lines.
5. **Curse-aware** — for cursable/cursed items, the shown value should reflect curse scaling
   (the live computed value includes curse). Flag descriptions that hardcode a number curse
   would change.
6. **Tracking present** — anything that grants permanent stats or counts occurrences needs
   `tracking_text` + a `<KEY>,Label: {0}` CSV row + `RunData.add_tracked_value(...)` + the key
   SEEDED in `run_data.gd init_tracked_items` (unseeded = silent no-op). Flag missing.
7. **Food-source display** — any item/weapon/character that spawns a food must show the food's
   effect + max stacks + eaten (the `EFFECT_FOOD_<X>` / `custom_key=consumable_food_<x>`
   display-effect pattern). Flag missing.
8. **Not outdated** — cross-check against current runtime; flag text describing an old mechanic.
9. **Formatting hygiene** — %/s units, vanilla `+{0}% ({1})` convention, no typos.

**Exception:** some lines intentionally mirror vanilla's own vague wording (fruit/tree reskins
like Fruit Basket, Tree, Garden). Those match vanilla on purpose — note them but don't "fix"
them to a formula vanilla itself doesn't use. Distinguish OUR content (must follow the rules)
from vanilla-reskin text.

## Deliverable

A single comprehensive report: one row per item/weapon, columns =
`name | category | current card text | defect(s) [tagged: vague-scaling / wrong-formula /
not-live / bad-sign / curse / missing-tracking / missing-food-display / outdated / hygiene] |
root-cause code location (file:line) | corrected text | files to change (CSV / .tres sign /
effect.gd case / builder to mirror / tracking seed)`. Rank by severity (wrong/outdated worst,
hygiene least). Also list the clean ones briefly so I know coverage is total. **Verify each
flagged defect against the actual code before including it** (adversarial second-read). Then
stop and show me the report — I'll approve before any fixes. When we do fix: change live +
mirror the builder + reseed trackers + regenerate the codex, and it needs a repack to verify
in-game (rule: verify against the real in-game card, not the doc).
