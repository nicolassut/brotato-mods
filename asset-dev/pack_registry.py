#!/usr/bin/env python3
"""The ONE way builders register content post-ecosystem (ECOSYSTEM.md Phase 2+).

Custom content registration lives in packs/<id>/pack_data.tres (applied at boot
by the Packs autoload), NOT in item_service.tscn. Every builder that used to
patch the tscn now calls register() here instead. Idempotent by path: content
already present in its pack is a no-op, so builder reruns are always safe.

Also the shared discovery surface: registered_paths(array) unions the vanilla
tscn array with every pack's array - use this instead of reading the tscn.
"""
import os, re

DEC = os.path.expanduser("~/brotato-decompiled")
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ARRAYS = ["characters", "items", "weapons", "foods", "stats", "sets", "upgrades"]
PACKS = ["food", "forge", "ledger", "roster"]  # fortune merged into forge (2026-08-18)

# canonical character -> pack map (ECOSYSTEM.md partition). Builders and the
# migration tool both read THIS - never duplicate it.
CHAR_PACKS = {
    "gourmet": "food", "butcher": "food", "ruminant": "food", "comp_eater": "food",
    "dishwasher": "food", "picky_eater": "food", "girly": "food", "snail": "food",
    "p2w": "forge",   # fortune merged into forge - P2W and Blacksmith are both the 8-tier system
    "blacksmith": "forge",
    "test_debt": "ledger",
    "mime": "roster", "mole": "roster", "zombie": "roster", "tourist": "roster",
    "juggler": "roster", "minimalist": "roster", "freeloader": "roster", "special": "roster",
}
# items that do not belong to the food pack
ITEM_PACK_OVERRIDES = {"credit_card": "ledger", "bank_loan": "ledger"}


def _pack_paths(pack_id):
    return [f"{REPO}/game-src/packs/{pack_id}/pack_data.tres", f"{DEC}/packs/{pack_id}/pack_data.tres"]


def _parse(text):
    ids = [int(i) for i in re.findall(r'\[ext_resource path="res://[^"]+" type="[^"]+" id=(\d+)\]', text)]
    return max(ids) if ids else 1


def is_registered(pack_id, res_path):
    """res_path is repo-relative like items/custom/foo/foo_data.tres"""
    text = open(_pack_paths(pack_id)[0]).read()
    return f'path="res://{res_path}"' in text


def register(pack_id, array, res_path, quiet=False):
    """Idempotently add res_path to the pack's array. Returns True if added."""
    assert array in ARRAYS, array
    assert pack_id in PACKS, pack_id
    mirror, live = _pack_paths(pack_id)
    text = open(mirror).read()
    if f'path="res://{res_path}"' in text:
        return False
    next_id = _parse(text) + 1
    ext_line = '[ext_resource path="res://%s" type="Resource" id=%d]' % (res_path, next_id)
    # insert the ext_resource before the [resource] block
    text = text.replace("\n[resource]", "\n%s\n[resource]" % ext_line, 1)
    # bump load_steps
    m = re.search(r"load_steps=(\d+)", text)
    text = text.replace("load_steps=%s" % m.group(1), "load_steps=%d" % (int(m.group(1)) + 1), 1)
    # append into the array
    am = re.search(r"^%s = \[(.*?)\]$" % array, text, re.M | re.S)
    inner = am.group(1).strip()
    new_inner = (" %s, ExtResource( %d ) " % (inner.rstrip(), next_id)) if inner else (" ExtResource( %d ) " % next_id)
    text = text[:am.start()] + "%s = [%s]" % (array, new_inner) + text[am.end():]
    open(mirror, "w").write(text)
    open(live, "w").write(text)
    if not quiet:
        print(f"pack_registry: {pack_id}.{array} += {res_path}")
    return True


def registered_paths(array):
    """Union of the vanilla tscn array and every pack's array (repo-relative paths)."""
    result = set()
    tscn = open(f"{DEC}/singletons/item_service.tscn").read()
    id2path = {i: p for p, i in re.findall(r'\[ext_resource path="res://([^"]+)"[^\]]*id=(\d+)\]', tscn)}
    m = re.search(r"^%s = \[(.*?)\]$" % array, tscn, re.M | re.S)
    if m:
        for i in re.findall(r"ExtResource\( (\d+) \)", m.group(1)):
            if i in id2path:
                result.add(id2path[i])
    for pack_id in PACKS:
        text = open(_pack_paths(pack_id)[0]).read()
        pid2path = {i: p for p, i in re.findall(r'\[ext_resource path="res://([^"]+)"[^\]]*id=(\d+)\]', text)}
        pm = re.search(r"^%s = \[(.*?)\]$" % array, text, re.M | re.S)
        if pm:
            for i in re.findall(r"ExtResource\( (\d+) \)", pm.group(1)):
                if i in pid2path:
                    result.add(pid2path[i])
    return result
