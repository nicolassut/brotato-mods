#!/usr/bin/env python3
"""Ecosystem gate: pack registration integrity (ECOSYSTEM.md dev-process law).

Verifies, against the immutable pre-split snapshot (packs_snapshot.json):
  A. every snapshot path is registered by EXACTLY ONE pack (no loss, no duplicates)
  B. item_service.tscn no longer references any pack-owned path (no double registration)
  C. every pack tres parses, its pack_id matches its directory, and every
     requires_packs entry names a known pack
  D. new content (paths in packs but not in the snapshot) is reported as info -
     the snapshot only guards the MIGRATED set; growth is expected

Exit 1 on any violation. Run from anywhere.
"""
import os, re, json, glob, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEC = os.path.expanduser("~/brotato-decompiled")
SNAPSHOT = os.path.join(HERE, "packs_snapshot.json")
ARRAYS = ["characters", "items", "weapons", "foods", "stats", "sets", "upgrades"]

errors = []
def err(msg): errors.append(msg)

snap = json.load(open(SNAPSHOT))
packs = {}
for tres in sorted(glob.glob(f"{DEC}/packs/*/pack_data.tres")):
    pack_dir = os.path.basename(os.path.dirname(tres))
    text = open(tres).read()
    m = re.search(r'^pack_id = "([a-z_]+)"$', text, re.M)
    if not m:
        err(f"{pack_dir}: no pack_id in pack_data.tres"); continue
    if m.group(1) != pack_dir:
        err(f"{pack_dir}: pack_id '{m.group(1)}' does not match directory name")
    id2path = {i: p for p, i in re.findall(r'\[ext_resource path="res://([^"]+)"[^\]]*id=(\d+)\]', text)}
    content = {}
    for arr in ARRAYS:
        am = re.search(r"^%s = \[(.*?)\]$" % arr, text, re.M | re.S)
        content[arr] = [id2path[i] for i in re.findall(r"ExtResource\( (\d+) \)", am.group(1)) if i in id2path] if am else []
    rm = re.search(r'requires_packs = PoolStringArray\(([^)]*)\)', text)
    requires = [s.strip().strip('"') for s in rm.group(1).split(",") if s.strip()] if rm else []
    packs[pack_dir] = {"content": content, "requires": requires}

known = set(packs.keys())
for pid, p in packs.items():
    for req in p["requires"]:
        if req not in known:
            err(f"{pid}: requires unknown pack '{req}'")

# A: exactly-one ownership + full coverage of the snapshot
new_content = []
for arr in ARRAYS:
    owners = {}
    for pid, p in packs.items():
        for path in p["content"][arr]:
            owners.setdefault(path, []).append(pid)
    for path, who in owners.items():
        if len(who) > 1:
            err(f"{arr}: '{path}' registered by multiple packs: {who}")
    snap_set = set(snap.get(arr, []))
    pack_set = set(owners.keys())
    for missing in sorted(snap_set - pack_set):
        err(f"{arr}: snapshot path LOST (in no pack): {missing}")
    new_content += sorted(pack_set - snap_set)

# B: the scene file must not double-register pack-owned paths
tscn = open(f"{DEC}/singletons/item_service.tscn").read()
for arr in ARRAYS:
    for pid, p in packs.items():
        for path in p["content"][arr]:
            if f'path="res://{path}"' in tscn:
                err(f"item_service.tscn still references pack-owned '{path}' ({pid})")

if errors:
    for e in errors:
        print("FAIL:", e)
    sys.exit(1)
counts = {pid: sum(len(v) for v in p["content"].values()) for pid, p in packs.items()}
print("packs OK: " + ", ".join(f"{pid}:{n}" for pid, n in sorted(counts.items()))
      + (f"; {len(new_content)} post-snapshot additions" if new_content else "; snapshot fully covered"))
