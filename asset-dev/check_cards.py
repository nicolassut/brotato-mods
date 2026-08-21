#!/usr/bin/env python3
"""Card contract checker for the Gourmet DLC. Run this LAST in the build.

Every card defect this catches has shipped at least once. The rules below are derived from
items/global/effect.gd and ui/menus/shop/item_description.gd -- if you change either, change
this file in the same commit or it will start lying too.

THE CONTRACT
  A. A scaling number pushes TWO args when its ratio != 0 (value + "+rate icon") and ONE when
     the ratio is 0. Duration pushes 2 when duration_app_ratio != 0 and 0 otherwise.
     Arg order: buff_stats, duration, wave_stats, heal (only if heal_base > 0), permanent_stats.
  B. A CSV row must contain exactly one placeholder per pushed arg, numbered contiguously
     from {0}. Too few args leaves a literal "{N}" on the card; too many silently drops data.
  C. Every EFFECT_FOOD_* row names its food ("Eating a Steak grants...", not "Eating grants").
  D. Every card that spawns a specific food carries that food's display effect, which is also
     what drives the "Max buff stacks" / "<Food> eaten" counters.
  E. Every non-empty tracking_text resolves to a CSV row with {0} AND a seeded tracking key.
  F. No food row hardcodes a duration that disagrees with the food's buff_duration.

Only REGISTERED content is checked (vanilla item_service.tscn arrays UNION the
packs/*/pack_data.tres arrays - ecosystem Phase 2); unregistered .tres on disk is dead
weight and is reported separately as info.

Exit code 1 on any violation, with the offending slug and row.
"""
import os, re, sys, glob, csv

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
SRC = os.path.dirname(os.path.abspath(__file__))
GAME_SRC = os.path.join(os.path.dirname(SRC), "game-src")
TSCN = f"{DEC}/singletons/item_service.tscn"
CSV_PATH = f"{DEC}/items/custom/custom_translations.csv"
BASE_CSV = f"{DEC}/.assets/resources/translations/translations.csv"

errors, infos = [], []
def err(where, msg): errors.append((where, msg))
def info(msg): infos.append(msg)


# ---------- loaders ----------
def props(path):
    t = open(path).read()
    body = t.split("[resource]")[-1]
    d = {}
    for k, v in re.findall(r"^(\w+) = (.+)$", body, re.M):
        d[k] = v.strip()
    d["__path"] = path
    return d

def unquote(v):
    return (v or '""').strip('"')

def load_rows(path, key_col=0, val_col=1):
    out = {}
    with open(path, newline="", encoding="utf-8-sig") as f:
        rd = csv.reader(f)
        next(rd, None)
        for row in rd:
            if row and row[key_col]:
                out[row[key_col].strip()] = row[val_col] if len(row) > val_col else ""
    return out

TR = load_rows(BASE_CSV)
TR.update(load_rows(CSV_PATH))

TSCN_TEXT = open(TSCN).read()
REGISTERED_PATHS = set(re.findall(r'\[ext_resource path="res://([^"]+)" type="Resource"', TSCN_TEXT))
_arrays = {}
for name in ("items", "weapons", "foods", "characters"):
    m = re.search(r"^%s = \[(.*)\]$" % name, TSCN_TEXT, re.M)
    _arrays[name] = set(re.findall(r"ExtResource\(\s*(\d+)\s*\)", m.group(1))) if m else set()
_ID_TO_PATH = {i: p for p, i in re.findall(r'\[ext_resource path="res://([^"]+)"[^\]]*id=(\d+)\]', TSCN_TEXT)}

# Ecosystem Phase 2: custom content registers at runtime through the PackData
# resources under res://packs/ - "registered" = tscn arrays UNION pack arrays.
_PACK_PATHS = {name: set() for name in ("items", "weapons", "foods", "characters", "stats", "sets", "upgrades")}
for _pack_tres in glob.glob(f"{DEC}/packs/*/pack_data.tres"):
    _pt = open(_pack_tres).read()
    _pid2path = {i: p for p, i in re.findall(r'\[ext_resource path="res://([^"]+)"[^\]]*id=(\d+)\]', _pt)}
    REGISTERED_PATHS.update(p for p in _pid2path.values())
    for name in _PACK_PATHS:
        m = re.search(r"^%s = \[(.*)\]$" % name, _pt, re.M)
        if m:
            for i in re.findall(r"ExtResource\(\s*(\d+)\s*\)", m.group(1)):
                if i in _pid2path:
                    _PACK_PATHS[name].add(_pid2path[i])

def registered_paths(kind):
    return {_ID_TO_PATH[i] for i in _arrays[kind] if i in _ID_TO_PATH} | _PACK_PATHS.get(kind, set())


# ---------- food data ----------
FOODS = {}
for p in glob.glob(f"{DEC}/items/foods/*/*_data.tres"):
    d = props(p)
    FOODS[unquote(d.get("my_id"))] = d

TRIPLES = re.compile(r'\[ "(\w+)", ([\d.\-]+), ([\d.\-]+) \]')
PAIRS = re.compile(r'\[ "(\w+)", ([\d.\-]+) \]')

def fnum(d, key, default=0.0):
    try: return float(d.get(key, default))
    except ValueError: return default

def expected_args(food):
    """Mirror of the EFFECT_FOOD_ branch in effect.gd. Returns the arg count."""
    n = 0
    for _k, _b, r in TRIPLES.findall(food.get("buff_stats", "")):
        n += 2 if float(r) != 0.0 else 1
    if fnum(food, "duration_app_ratio") != 0.0:
        n += 2
    for _k, _b, r in TRIPLES.findall(food.get("wave_stats", "")):
        n += 2 if float(r) != 0.0 else 1
    if fnum(food, "heal_base") > 0.0:
        n += 2 if fnum(food, "heal_app_ratio") != 0.0 else 1
    for _k, _b in PAIRS.findall(food.get("permanent_stats", "")):
        n += 2 if fnum(food, "permanent_app_ratio") != 0.0 else 1
    return n

def placeholders(text):
    idx = {int(m) for m in re.findall(r"\{(\d+)\}", text)}
    return idx


# ---------- rule A/B/C/F: food rows ----------
def check_food_rows():
    for my_id, food in sorted(FOODS.items()):
        slug = my_id[len("consumable_food_"):]
        rel = food["__path"][len(DEC) + 1:]
        if rel not in REGISTERED_PATHS:
            info(f"unregistered food on disk: {slug}")
            continue
        text_key = "EFFECT_FOOD_" + slug.upper()
        row = TR.get(text_key)
        if row is None:
            err(slug, f"no CSV row for {text_key}")
            continue

        # B: placeholder count must equal arg count, numbered contiguously from 0
        want = expected_args(food)
        have = placeholders(row)
        if have != set(range(want)):
            err(slug, f"{text_key} has placeholders {sorted(have) or 'none'} but the renderer "
                      f"pushes {want} args -> expected exactly {sorted(range(want)) or 'none'}\n"
                      f"        row: {row}")

        # C: the row must name its food
        name = unquote(food.get("name", ""))
        if name and name.lower() not in row.lower():
            err(slug, f"{text_key} does not name '{name}' -> a card reading '{row[:48]}...' "
                      f"has no referent when shown on a weapon or spawner")

        # F: a hardcoded duration must match buff_duration
        dur = int(fnum(food, "buff_duration"))
        for stated in (int(x) for x in re.findall(r"for (\d+) seconds", row)):
            if stated != dur:
                err(slug, f"{text_key} states '{stated} seconds' but buff_duration is {dur}")


# ---------- rule D: food sources carry a display effect ----------
def effects_of(data_path):
    """Resolve an item/weapon/character's effect .tres paths from its own ext_resources."""
    t = open(data_path).read()
    ext = {i: p for p, i in re.findall(r'\[ext_resource path="res://([^"]+)"[^\]]*id=(\d+)\]', t)}
    m = re.search(r"^effects = \[(.*)\]$", t, re.M)
    if not m:
        return []
    out = []
    for i in re.findall(r"ExtResource\(\s*(\d+)\s*\)", m.group(1)):
        p = ext.get(i)
        if p and p.endswith(".tres"):
            full = f"{DEC}/{p}"
            if os.path.exists(full):
                out.append(props(full))
    return out

def check_spawn_counts():
    """Curse multiplies a plain spawn effect's `value`, which IS the per-fire food count
    (dlc_1_data.gd _boost_effect_value_positively). If the row hardcodes the number instead of
    using {0}, a cursed spawner silently produces more food than its card admits -- a cursed
    Espresso Machine spawned 4 while advertising 2. Structure spawners are exempt: curse takes
    a different branch there and shortens spawn_cooldown, which turret_effect renders live."""
    for rel in sorted(registered_paths("items")):
        full = f"{DEC}/{rel}"
        if not os.path.exists(full):
            continue
        slug = unquote(props(full).get("my_id", rel))
        for e in effects_of(full):
            key, ck = unquote(e.get("key")), unquote(e.get("custom_key"))
            text_key = unquote(e.get("text_key"))
            # a trigger spawn effect: key is the food, custom_key is the *_foods trigger
            if not (key.startswith("consumable_food_") and ck.endswith("_foods")):
                continue
            if text_key in ("", "EFFECT_HIDDEN"):
                continue
            row = TR.get(text_key, "")
            if not placeholders(row):
                err(slug, f"{text_key} hardcodes its spawn count -> a cursed copy fires "
                          f"value={unquote(e.get('value','?'))} but the card cannot show it. "
                          f"Use {{0}}.\n        row: {row}")


def check_food_sources():
    for kind in ("items", "weapons", "characters"):
        for rel in sorted(registered_paths(kind)):
            full = f"{DEC}/{rel}"
            if not os.path.exists(full):
                continue
            effs = effects_of(full)
            slug = unquote(props(full).get("my_id", rel))
            produced, displayed = set(), set()
            for e in effs:
                ck, key = unquote(e.get("custom_key")), unquote(e.get("key"))
                if ck.startswith("consumable_food_"):
                    displayed.add(ck)
                if ck.startswith("food_drop:"):
                    produced.add(ck[len("food_drop:"):])
                if key.startswith("consumable_food_"):
                    produced.add(key)
            missing = produced - displayed
            for food_id in sorted(missing):
                err(slug, f"produces {food_id} but has no display effect for it -> its buffs are "
                          f"undocumented AND it gets no 'Max buff stacks' / 'eaten' counters")


# ---------- rule E: tracker chains ----------
def mod_weapon_slugs():
    """Slugs owned by build_weapons.py. Mod weapons live in the same folders as vanilla ones,
    so the builder's own table is the only reliable way to tell them apart."""
    src = open(f"{SRC}/build_weapons.py").read()
    block = src[src.index("WEAPONS = ["):src.index("CSV_ROWS = [")]
    return set(re.findall(r'^ w\("([a-z_]+)"', block, re.M))

_MOD_WEAPONS = mod_weapon_slugs()

def is_mod_owned(rel_path):
    """Vanilla tracking keys (stats_gained, fruit_count, bonus_damage...) live in a compiled
    PHashTranslation this script cannot read, so only mod-owned cards get the CSV check."""
    if rel_path.startswith(("items/custom/", "items/custom_characters/", "items/foods/")):
        return True
    m = re.match(r"weapons/(?:melee|ranged)/([a-z_]+)/", rel_path)
    return bool(m and m.group(1) in _MOD_WEAPONS)


def check_trackers():
    run_data = open(f"{GAME_SRC}/singletons/run_data.gd").read()
    seed_block = run_data.split("var init_tracked_items: = {")[1].split("\n}")[0]
    seeded = set(re.findall(r'generate_hash\("([^"]+)"\)', seed_block))

    feeds = set()
    for gd in glob.glob(f"{GAME_SRC}/**/*.gd", recursive=True):
        body = open(gd).read()
        for m in re.finditer(r'add_tracked_value\([^,]+,\s*Keys\.generate_hash\("([^"]+)"\)', body):
            feeds.add(m.group(1))

    for name in sorted(feeds - seeded):
        err(name, "add_tracked_value() is called with this key but it is NOT seeded in "
                  "init_tracked_items -> RunData prints and silently drops every write")

    for kind in ("items", "weapons", "characters"):
        for rel in sorted(registered_paths(kind)):
            full = f"{DEC}/{rel}"
            if not os.path.exists(full):
                continue
            if not is_mod_owned(rel):
                continue
            d = props(full)
            tracking = unquote(d.get("tracking_text", ""))
            if tracking in ("", "[EMPTY]"):
                continue
            slug = unquote(d.get("my_id", rel))
            row = TR.get(tracking)
            if row is None:
                err(slug, f'tracking_text "{tracking}" has no CSV row')
            elif "{0}" not in row:
                err(slug, f'tracking_text "{tracking}" row has no {{0}} -> the count never prints')


def main():
    check_food_rows()
    check_spawn_counts()
    check_food_sources()
    check_trackers()

    for msg in infos:
        print(f"  info: {msg}")
    if errors:
        print(f"\n{len(errors)} CARD CONTRACT VIOLATION(S):\n")
        for where, msg in errors:
            print(f"  [{where}] {msg}")
        print()
        return 1
    print(f"\ncard contract OK: {len(FOODS)} foods, "
          f"{sum(len(registered_paths(k)) for k in ('items', 'weapons', 'characters'))} registered cards\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
