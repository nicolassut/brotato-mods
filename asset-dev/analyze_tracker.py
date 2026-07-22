#!/usr/bin/env python3
"""Analyze a Gourmet DLC playtest log (user://gourmet_tracker.jsonl) and
cross-check every food-system formula against what actually happened.

Usage: python3 analyze_tracker.py [path-to-log]
Default log: ~/Library/Application Support/Brotato/gourmet_tracker.jsonl"""
import json, sys, os
from collections import defaultdict, Counter

LOG = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Library/Application Support/Brotato/gourmet_tracker.jsonl")

# food -> (list of (base, app_ratio) per buff stat, base_duration, dur_app_ratio, stacks, cap)
FOODS = {
 "consumable_food_espresso":     ([(10, .2)], 6, 0, True, 0),
 "consumable_food_steak":        ([(8, .25)], 5, 0, True, 0),
 "consumable_food_fried_rice":   ([(4, .15)], 6, 0, True, 0),
 "consumable_food_popcorn":      ([(2, .1)], 5, 0, True, 20),
 "consumable_food_fries":        ([(4, .1)], 5, 0, True, 0),
 "consumable_food_sushi_roll":   ([(4, .15)], 6, 0, True, 0),
 "consumable_food_warm_cookie":  ([(1, .1)], 6, 0, True, 0),
 "consumable_food_pizza_slice":  ([(3, 0), (3, 0)], 10, .1, True, 0),
 "consumable_food_golden_apple": ([(8, 0)], 10, 0, True, 0),
 "consumable_food_mystery_meat": ([(10, .3)], 8, 0, True, 0),
 "consumable_food_cheese_cube":  ([(2, .15)], 4, 0, True, 0),
 "consumable_food_protein_shake":([(4, .1), (2, .1)], 6, 0, True, 0),
 "consumable_food_escargot":     ([(3, .15)], 8, 0, True, 0),
 "consumable_food_ice_cream":    ([(2, .2)], 4, 0, True, 0),
 "consumable_food_chili_pepper": ([], 4, 0, False, 0),
}
DURATION_ITEMS = {"item_slow_cooker": 2, "item_sous_vide_machine": 1, "item_preservatives": 4}
STRENGTH_ITEMS = {"item_msg": 50, "item_intermittent_fasting": 100}
THRESHOLDS = {"kill_foods": 40, "burning_kill_foods": 8, "crit_foods": 12,
              "burning_tick_foods": 10, "explosion_foods": 1, "material_foods": 30,
              "level_up_foods": 1, "damage_taken_foods": 1, "elite_kill_foods": 1,
              "consumable_count_foods": 5, "step_foods": 200}

events = []
with open(LOG) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                print("!! unparseable line:", line[:80])

by = defaultdict(list)
for e in events:
    by[e["e"]].append(e)

passes, warns = [], []
def ok(msg): passes.append(msg)
def warn(msg): warns.append(msg)

print(f"=== Gourmet tracker report: {len(events)} events, "
      f"waves {sorted(set(e['w'] for e in events))} ===\n")

# ---- session overview ----
items_by_wave = {}
for e in by["wave_start"]:
    items_by_wave[e["w"]] = e.get("items", [])
    print(f"wave {e['w']} start (p{e['p']} {e.get('ch','')}): "
          f"App={e['s'].get('stat_appetite')} items={len(e.get('items', []))}")
all_items = Counter()
for e in by["purchase"]:
    all_items[e["id"]] += 1
if all_items:
    print("purchases:", dict(all_items))
print()

def items_at_wave(w):
    best = None
    for ww in sorted(items_by_wave):
        if ww <= w:
            best = items_by_wave[ww]
    return best or []

# ---- foods: spawn / pickup / expiry ----
spawns = Counter(e["f"] for e in by["food_spawn"])
pickups = Counter(e["f"] for e in by["food_pickup"])
expiries = Counter(e["f"] for e in by["food_expire"])
bonus = Counter(e["f"] for e in by["food_spawn"] if e.get("b"))
print("--- foods (spawn / pickup / expire / bonus-servings) ---")
for f in sorted(set(spawns) | set(pickups) | set(expiries)):
    short = f.replace("consumable_food_", "")
    print(f"  {short:15} {spawns[f]:4} / {pickups[f]:4} / {expiries[f]:4} / {bonus[f]}")
    if pickups[f] + expiries[f] > spawns[f]:
        warn(f"{short}: pickups+expiries ({pickups[f]}+{expiries[f]}) exceed spawns ({spawns[f]})")
lost = sum(spawns.values()) - sum(pickups.values()) - sum(expiries.values())
if lost > 0:
    print(f"  ({lost} foods still on the ground / lost at wave end - normal)")
print()

# ---- expiry timing ----
spawn_times = defaultdict(list)
for e in by["food_spawn"]:
    spawn_times[(e["w"], e["f"])].append(e["t"])
ages = []
consumed = defaultdict(int)  # FIFO: expiries match the oldest unexpired spawn
for e in by["food_expire"]:
    key = (e["w"], e["f"])
    cands = sorted(t for t in spawn_times.get(key, []) if t < e["t"])
    idx = consumed[key]
    if idx < len(cands):
        ages.append(e["t"] - cands[idx])
        consumed[key] += 1
if ages:
    lo, hi = min(ages), max(ages)
    print(f"--- expiry ages: n={len(ages)} min={lo:.1f}s max={hi:.1f}s "
          f"(expected ~15s base, ~7.5s with Dishwasher; approximate matching) ---\n")
    if hi > 20:
        warn(f"an expiry age of {hi:.1f}s exceeds the 15s base by a lot")

# ---- buff math ----
print("--- buff applications ---")
bad_vals = 0
for e in by["buff_apply"]:
    f = e["f"]
    if f not in FOODS:
        continue
    spec, base_dur, dur_app, _stacks, cap = FOODS[f]
    app = e.get("app", 0)
    strength = e.get("str", 0)
    comp = e.get("comp", False)
    owned = items_at_wave(e["w"])
    exp_strength = sum(v for k, v in STRENGTH_ITEMS.items() if k in owned)
    if strength != exp_strength:
        warn(f"{f}: logged strength {strength} != {exp_strength} expected from items")
    vals = e.get("vals", [])
    if f == "consumable_food_golden_apple":
        expected = [int(8 * (100 + strength) / 100)] if strength else [8]
        expected = [int(v * 2) if comp else v for v in expected]
    else:
        expected = []
        for b, r in spec:
            v = int(b + r * app)
            if comp:
                v *= 2
            if strength:
                v = int(v * (100 + strength) / 100)
            expected.append(v)
    if vals and expected and vals != expected:
        # engine order: comp doubling happens before strength in v3? verify both orders
        alt = []
        for b, r in spec:
            v = int(b + r * app)
            if strength:
                v = int(v * (100 + strength) / 100)
            if comp:
                v *= 2
            alt.append(v)
        if vals != alt:
            bad_vals += 1
            warn(f"{f} w{e['w']}: vals {vals} != expected {expected} (app={app} str={strength} comp={comp})")
    if e.get("stacks") == 1:
        dur_bonus = sum(v * owned.count(k) if False else v for k, v in DURATION_ITEMS.items() if k in owned)
        dur_bonus = sum(v for k, v in DURATION_ITEMS.items() if k in owned)
        exp_dur = int((base_dur + dur_app * app + dur_bonus) * (1 + app / 100.0))
        if comp:
            exp_dur = int((base_dur + dur_app * app + dur_bonus) * (1 + app / 100.0) * 0.5)
        tl = e.get("tl", 0)
        if abs(tl - exp_dur) > 1.2:
            warn(f"{f} w{e['w']}: first-stack duration {tl} != ~{exp_dur} expected")
apps = Counter(e["f"].replace("consumable_food_", "") for e in by["buff_apply"])
exps = Counter(e["f"].replace("consumable_food_", "") for e in by["buff_expire"])
for f in sorted(set(apps) | set(exps)):
    print(f"  {f:15} applies={apps[f]:4} expires={exps[f]}")
if bad_vals == 0 and by["buff_apply"]:
    ok(f"all {len(by['buff_apply'])} buff applications match the formulas")
print()

# ---- trigger cadence ----
prog = Counter()
for e in by["counters"]:
    for k, v in e.get("c", {}).items():
        prog[k] += v
fires = Counter(e["tr"] for e in by["trigger_fire"])
print("--- triggers (progress -> fires, expected threshold) ---")
for tr, thr in THRESHOLDS.items():
    p = prog.get("prog_" + tr, 0)
    fi = fires.get(tr, 0)
    if p or fi:
        eff = p / fi if fi else float("inf")
        note = f"~{eff:.1f}/fire vs {thr}"
        print(f"  {tr:22} progress={p:6} fires={fi:4}  {note}")
        if fi and abs(eff - thr) > thr * 0.3 + 1:
            warn(f"{tr}: effective threshold {eff:.1f} far from {thr} (Michelin owned? "
                 f"{'yes' if any('michelin' in i for w in items_by_wave for i in items_by_wave[w]) else 'no'})")
for tr in fires:
    if tr not in THRESHOLDS:
        print(f"  {tr:22} fires={fires[tr]} (timer/scheduled trigger)")
print()

# ---- specials + item procs ----
print("--- specials and item procs ---")
mystery_bad = len(by["mystery_bad"])
mystery_good = apps.get("mystery_meat", 0)
if mystery_bad + mystery_good:
    total = mystery_bad + mystery_good
    print(f"  mystery meat: {mystery_good} good / {mystery_bad} bad ({100*mystery_bad/total:.0f}% bad)")
    owned_ever = set(i for w in items_by_wave for i in items_by_wave[w])
    if "item_cast_iron_stomach" in owned_ever and mystery_bad > 0:
        after = [e for e in by["mystery_bad"]
                 if "item_cast_iron_stomach" in items_at_wave(e["w"])]
        if after:
            warn(f"mystery meat rolled bad {len(after)}x while Cast-Iron Stomach owned")
gold = Counter(e.get("gold", "") for e in by["buff_apply"] if e.get("gold"))
if gold:
    print(f"  golden apple stats: {dict(gold)}")
for kind, label in [("mint_refresh", "mint refreshes"), ("nine_lives_save", "nine lives saves"),
                    ("buffet_heal", "buffet heals"), ("echo_proc", "echo procs"),
                    ("leftovers_grant", "leftovers grants"), ("escargot_snail", "snail escargots"),
                    ("panic_button", "panic button bursts"),
                    ("space_heater", "space heater changes"), ("snack_break", "snack payouts"),
                    ("gourmet_app_gain", "gourmet appetite gains")]:
    if by[kind]:
        print(f"  {label}: {len(by[kind])}")
for c, label in [("sugar_bursts", "sugar rush bursts"), ("chili_ignites", "chili ignites"),
                 ("grease_ignites", "grease fire ignitions"), ("caltrops_hits", "caltrops hits"),
                 ("static_cling_zaps", "static cling zaps"), ("food_fight_projectiles", "food fight projectiles"),
                 ("ruminant_echoes", "ruminant echoes"), ("fasting_skips", "fasting skips"),
                 ("burp_bursts", "burp knockbacks"), ("pocket_sand_slows", "pocket sand slows")]:
    if prog.get(c):
        print(f"  {label}: {prog[c]}")
print()

# ---- doggy bag / leftovers consistency ----
grants = by["leftovers_grant"]
if grants:
    banks = [e["n"] for e in grants]
    if banks != sorted(banks):
        warn("leftovers bank decreased between waves (should only grow)")
    else:
        ok(f"leftovers bank grew monotonically: {banks}")

# ---- loyalty ----
loyal = [e for e in by["purchase"] if e.get("n", 0) % 5 == 0]
if loyal and any("item_loyalty_card" in items_at_wave(e["w"]) for e in loyal):
    print("--- every-5th purchases (loyalty check: paid should dip ~30%) ---")
    for e in by["purchase"]:
        marker = "  <-- 5th" if e.get("n", 0) % 5 == 0 else ""
        print(f"  w{e['w']} #{e.get('n')}: {e['id']} paid {e['paid']} (base {e.get('base')}){marker}")
    print()

print("=== verdicts ===")
for m in passes:
    print("PASS:", m)
for m in warns:
    print("WARN:", m)
if not warns:
    print("No anomalies detected across", len(events), "events.")
