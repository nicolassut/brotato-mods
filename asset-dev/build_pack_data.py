#!/usr/bin/env python3
"""Ecosystem Phase 2 - split the scene-baked custom registrations into PackDatas.

Reads item_service.tscn, takes every custom ext_resource (ids 800-1295), assigns it
to its pack per ECOSYSTEM.md's partition, and:
  1. writes packs/<id>/pack_data.tres for each pack (game-src + live)
  2. writes asset-dev/packs_snapshot.json - the pre-split registered-set snapshot that
     check_packs.py uses to prove the union never changes
  3. with --prune: removes those entries from item_service.tscn (both trees), fixing
     load_steps. Run WITHOUT --prune first, boot, verify double-registration guard,
     then prune.

Pack assignment is by ext id + path, per the ECOSYSTEM.md partition:
  characters by slug; credit_card/bank_loan -> ledger; bs weapons -> forge;
  everything else custom -> food. Fortune = P2W character (chests are unregistered
  by design and ride p2w_data.gd).
"""
import os, re, json, sys

DEC = os.path.expanduser("~/brotato-decompiled")
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TSCN_LIVE = f"{DEC}/singletons/item_service.tscn"
TSCN_MIRROR = f"{REPO}/game-src/singletons/item_service.tscn"
SNAPSHOT = f"{HERE}/packs_snapshot.json"

CUSTOM_MIN, CUSTOM_MAX = 800, 1295
ARRAYS = ["characters", "items", "weapons", "foods", "stats", "sets", "upgrades"]
PACK_ORDER = ["food", "forge", "ledger", "roster"]  # fortune merged into forge (2026-08-18)

CHAR_PACKS = {
    "gourmet": "food", "butcher": "food", "ruminant": "food", "comp_eater": "food",
    "dishwasher": "food", "picky_eater": "food", "girly": "food", "snail": "food",
    "p2w": "forge",
    "blacksmith": "forge",
    "test_debt": "ledger",
    "mime": "roster", "mole": "roster", "zombie": "roster", "tourist": "roster",
    "juggler": "roster", "minimalist": "roster", "freeloader": "roster", "special": "roster",
}
LEDGER_ITEMS = {"credit_card", "bank_loan"}


def pack_of(array, path, ext_id):
    if array == "characters":
        m = re.search(r"custom_characters/([a-z_0-9]+)/", path)
        slug = m.group(1) if m else ""
        assert slug in CHAR_PACKS, f"unassigned character: {path}"
        return CHAR_PACKS[slug]
    if array == "items":
        m = re.search(r"items/custom/([a-z_0-9]+)/", path)
        if m and m.group(1) in LEDGER_ITEMS:
            return "ledger"
        return "food"
    if array == "weapons":
        if re.search(r"/bs[0-9]+/", path) or 1013 <= ext_id <= 1292:
            return "forge"
        return "food"  # culinary
    # foods, stats (appetite), sets (culinary), upgrades (appetite levels)
    return "food"


def parse_tscn(text):
    ext = {}  # id -> path
    for m in re.finditer(r'\[ext_resource path="res://([^"]+)" type="[^"]+" id=(\d+)\]', text):
        ext[int(m.group(2))] = m.group(1)
    arrays = {}
    for arr in ARRAYS:
        m = re.search(r"^%s = \[(.*?)\]$" % arr, text, re.M | re.S)
        arrays[arr] = [int(i) for i in re.findall(r"ExtResource\( (\d+) \)", m.group(1))] if m else []
    return ext, arrays


def main():
    prune = "--prune" in sys.argv
    text = open(TSCN_LIVE).read()
    ext, arrays = parse_tscn(text)

    # ONE-SHOT MIGRATION GUARD: after the prune, the tscn holds no custom ids -
    # rerunning would regenerate EMPTY pack files and wipe the registration.
    # This script's job is done; content changes now edit the pack tres directly
    # (or future pack-aware builders do).
    n_custom_probe = sum(1 for arr in ARRAYS for i in arrays[arr] if CUSTOM_MIN <= i <= CUSTOM_MAX)
    if n_custom_probe == 0 and os.path.exists(SNAPSHOT):
        print("migration already done (tscn pruned); pack tres left untouched")
        return

    # collect custom entries per pack, preserving tscn order within each array
    packs = {p: {a: [] for a in ARRAYS} for p in PACK_ORDER}
    custom_ids = set()
    for arr in ARRAYS:
        for ext_id in arrays[arr]:
            if CUSTOM_MIN <= ext_id <= CUSTOM_MAX and ext_id in ext:
                pack = pack_of(arr, ext[ext_id], ext_id)
                packs[pack][arr].append(ext[ext_id])
                custom_ids.add(ext_id)

    # snapshot BEFORE any prune (only write if absent: it is the immutable baseline)
    if not os.path.exists(SNAPSHOT):
        snap = {a: sorted(p for i, p in ((i, ext[i]) for i in arrays[a] if i in custom_ids)) for a in ARRAYS}
        json.dump(snap, open(SNAPSHOT, "w"), indent=1)
        print(f"snapshot written: {SNAPSHOT}")

    # write pack tres files (game-src + live)
    for pack in PACK_ORDER:
        content = packs[pack]
        n_ext = sum(len(v) for v in content.values())
        lines = ['[gd_resource type="Resource" load_steps=%d format=2]' % (n_ext + 2), "",
                 '[ext_resource path="res://packs/pack_data.gd" type="Script" id=1]']
        next_id = 2
        refs = {a: [] for a in ARRAYS}
        for arr in ARRAYS:
            for path in content[arr]:
                lines.append('[ext_resource path="res://%s" type="Resource" id=%d]' % (path, next_id))
                refs[arr].append("ExtResource( %d )" % next_id)
                next_id += 1
        lines += ["", "[resource]", "script = ExtResource( 1 )",
                  'my_id = "pack_%s"' % pack, 'pack_id = "%s"' % pack,
                  'display_name = "%s"' % pack.capitalize(),
                  "requires_packs = PoolStringArray(  )", "synergies = [  ]"]
        for arr in ARRAYS:
            lines.append("%s = [ %s ]" % (arr, ", ".join(refs[arr])) if refs[arr] else "%s = [  ]" % arr)
        tres = "\n".join(lines) + "\n"
        for root in (f"{REPO}/game-src/packs", f"{DEC}/packs"):
            os.makedirs(f"{root}/{pack}", exist_ok=True)
            open(f"{root}/{pack}/pack_data.tres", "w").write(tres)
        print(f"pack {pack}: " + " ".join(f"{a}:{len(content[a])}" for a in ARRAYS if content[a]))

    if prune:
        removed = 0
        for arr in ARRAYS:
            def strip_arr(m):
                inner = m.group(1)
                kept = [i for i in re.findall(r"ExtResource\( (\d+) \)", inner) if int(i) not in custom_ids]
                return "%s = [ %s ]" % (arr, ", ".join("ExtResource( %s )" % i for i in kept)) if kept else "%s = [  ]" % arr
            text = re.sub(r"^%s = \[(.*?)\]$" % arr, strip_arr, text, flags=re.M | re.S)
        for ext_id in sorted(custom_ids):
            pattern = r'\[ext_resource path="res://[^"]+" type="[^"]+" id=%d\]\n' % ext_id
            text, n = re.subn(pattern, "", text)
            removed += n
        m = re.search(r"load_steps=(\d+)", text)
        text = text.replace("load_steps=%s" % m.group(1), "load_steps=%d" % (int(m.group(1)) - removed), 1)
        open(TSCN_LIVE, "w").write(text)
        open(TSCN_MIRROR, "w").write(text)
        print(f"pruned {removed} ext_resources ({len(custom_ids)} custom ids) from item_service.tscn (both trees)")


if __name__ == "__main__":
    main()
