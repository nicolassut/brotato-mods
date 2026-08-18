#!/usr/bin/env python3
"""Hub geometry gate: parses the Rect2/Vector2 constants out of
game-src/ui/lobby/lobby.gd and asserts the HUB_ART_SPEC geometry laws:
zero overlaps between object rects, band continuity, stairs = exactly
landing+run+apron across the cliff, everything inside the playable area,
spawn point clear. Run by check_all; run manually after ANY rect change."""
import re, os, sys

SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game-src/ui/lobby/lobby.gd")
t = open(SRC).read()

def rect_const(name):
    m = re.search(r'const %s: = Rect2\(([-\d]+), ([-\d]+), ([\d]+), ([\d]+)\)' % name, t)
    assert m, "missing " + name
    x, y, w, h = map(int, m.groups())
    return (x, y, x + w, y + h)

deck, cliff, plaza = rect_const("DECK_RECT"), rect_const("CLIFF_RECT"), rect_const("PLAZA_RECT")
objs = {n: rect_const(n) for n in
        ("STAIR_WEST", "STAIR_EAST", "SHUTTLE_PAD_RECT", "SHRINE_RECT",
         "BOARD_RECT", "BOOTH_RECT", "FOUNTAIN_RECT", "GATE_RECT")}
m = re.search(r'const SLOT_SIZE: = Vector2\((\d+), (\d+)\)', t)
sw, sh = int(m.group(1)), int(m.group(2))
for i, sm in enumerate(re.finditer(r'Vector2\(([-\d]+), ([-\d]+)\),?\s*\n?', 
        t[t.index("const SLOT_POSITIONS"):t.index("]", t.index("const SLOT_POSITIONS"))])):
    cx, cy = int(sm.group(1)), int(sm.group(2))
    objs["slot_%d" % (i + 1)] = (cx - sw // 2, cy - sh // 2, cx + sw // 2, cy + sh // 2)
assert sum(1 for k in objs if k.startswith("slot_")) == 6, "expected 6 slots"

bad = []
ks = list(objs)
for i in range(len(ks)):
    for j in range(i + 1, len(ks)):
        a, b = objs[ks[i]], objs[ks[j]]
        if a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]:
            bad.append((ks[i], ks[j]))
assert not bad, "OVERLAPS: %s" % bad
assert deck[3] == cliff[1] and cliff[3] == plaza[1], "band discontinuity"
for s in ("STAIR_WEST", "STAIR_EAST"):
    r = objs[s]
    assert cliff[1] - r[1] == 96 and r[3] - cliff[3] == 96, s + " landing/apron != 96"
for k, r in objs.items():
    lim_b = plaza[3] + 120 if k == "GATE_RECT" else plaza[3]
    lim_t = cliff[1] if k == "BOOTH_RECT" else deck[1]
    assert deck[0] <= r[0] and r[2] <= deck[2] and lim_t <= r[1] and r[3] <= lim_b, (k, r)
m = re.search(r'const SPAWN_POINT: = Vector2\(([-\d]+), ([-\d]+)\)', t)
sx, sy = int(m.group(1)), int(m.group(2))
for k, r in objs.items():
    assert not (r[0] <= sx <= r[2] and r[1] <= sy <= r[3]), "spawn inside " + k
print("hub geometry OK: %d object rects, zero overlaps, bands continuous, stairs 96+%d+96"
      % (len(objs), cliff[3] - cliff[1]))
