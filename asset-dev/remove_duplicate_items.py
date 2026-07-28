#!/usr/bin/env python3
"""Deregister the vanilla items that duplicate our Gourmet foods from the shop pool.
We turned these concepts into foods (Espresso, Fried Rice, Honey Drop, Cake Slice,
Steak), so the vanilla item versions are redundant. Removes them from item_service.tscn's
`items` array ONLY (keeps the ext_resource declaration so get_element + the stat
recommendation lists in item_service.gd still resolve). Idempotent. Builders never re-add
vanilla items, so this is durable. NOT removed: fruit_basket + lemonade (used by the
Butcher meat reskin, singletons/butcher_skin.gd)."""
import re

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
TSCN = f"{DEC}/singletons/item_service.tscn"

# vanilla item -> our food that replaced it (ext ids in item_service.tscn)
DUPES = {210: "coffee (-> Espresso)", 557: "fried_rice (-> Fried Rice)",
         556: "honey (-> Honey Drop)", 263: "cake (-> Cake Slice)",
         622: "fresh_meat (-> Steak)"}

s = open(TSCN).read()
m = re.search(r'^items = \[ (.*?) \]$', s, re.M)
assert m, "items array not found"
refs = re.findall(r'ExtResource\(\s*(\d+)\s*\)', m.group(1))
kept = [r for r in refs if int(r) not in DUPES]
removed = [int(r) for r in refs if int(r) in DUPES]
if removed:
    new_arr = "items = [ " + ", ".join(f"ExtResource( {r} )" for r in kept) + " ]"
    s = s[:m.start()] + new_arr + s[m.end():]
    open(TSCN, "w").write(s)
    print("removed from shop pool:", [DUPES[i] for i in removed])
else:
    print("already removed (idempotent no-op)")
