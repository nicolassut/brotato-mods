#!/usr/bin/env python3
"""One-shot (idempotent) fixer: strip res://dlcs/ ext_resource refs from
weapon tres. Baked DLC-set refs break every install without the DLC (the
ext_resource fails and the whole pack tres cascade dies - clone gate
2026-08-18). PackService._attach_dlc_sets re-attaches them at runtime when
the DLC is present; build_weapons.py no longer bakes them."""
import os, re, sys

DEC = os.path.expanduser("~/brotato-decompiled")
fixed = 0
for root, dirs, files in os.walk(os.path.join(DEC, "weapons")):
    for f in files:
        if not f.endswith(".tres"):
            continue
        p = os.path.join(root, f)
        t = open(p).read()
        m = re.search(r'\[ext_resource path="res://dlcs/[^"]+" type="Resource" id=(\d+)\]\n', t)
        if not m:
            continue
        ext_id = m.group(1)
        t2 = t.replace(m.group(0), "", 1)
        # remove the array element (with either neighboring separator)
        for pat in (f"ExtResource( {ext_id} ), ", f", ExtResource( {ext_id} )",
                    f"ExtResource( {ext_id} )"):
            if pat in t2:
                t2 = t2.replace(pat, "", 1)
                break
        assert f"ExtResource( {ext_id} )" not in t2, p
        open(p, "w").write(t2)
        fixed += 1
        print("stripped:", os.path.relpath(p, DEC))
print("fixed", fixed, "tres")
