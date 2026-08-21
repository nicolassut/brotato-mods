"""Register the generated Blacksmith weapon tiers into singletons/item_service.tscn.

Run AFTER build_blacksmith_tiers.py. Idempotent: re-running will not duplicate
entries, so it is safe to run alongside the other builders.

item_service.tscn is the file whose failure takes the whole game down - a single
bad ext_resource there stops ItemService autoloading and every character, item and
weapon disappears. So this only ever appends, verifies each path exists on disk
first, and re-checks the result before writing.
"""
import os, re

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
TSCN = os.path.join(DEC, "singletons/item_service.tscn")


def main():
    txt = open(TSCN, encoding="utf-8", errors="replace").read()

    # every generated blacksmith tier resource, in ladder order per family
    new_paths = []
    for kind in ("melee", "ranged"):
        root = os.path.join(DEC, "weapons", kind)
        if not os.path.isdir(root):
            continue
        for slug in sorted(os.listdir(root)):
            for key in ("bs2", "bs4", "bs7", "bs8"):
                rel = f"weapons/{kind}/{slug}/{key}/{slug}_{key}_data.tres"
                if os.path.isfile(os.path.join(DEC, rel)):
                    new_paths.append("res://" + rel)

    # Ecosystem Phase 2+: the ladder weapons register in the FORGE pack, never
    # in item_service.tscn. Idempotent by path - reruns are safe.
    import sys as _sys
    _sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from pack_registry import register as pack_register
    added = 0
    for p in new_paths:
        rel = p.replace("res://", "")
        assert os.path.exists(os.path.join(DEC, rel)), f"missing file {p}"
        if pack_register("forge", "weapons", rel, quiet=True):
            added += 1
    print(f"forge pack: +{added} ladder weapons" if added else f"all {len(new_paths)} ladder weapons already pack-registered")


main()
