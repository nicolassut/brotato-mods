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

    already = set(re.findall(r'\[ext_resource path="([^"]+)"', txt))
    todo = [p for p in new_paths if p not in already]
    if not todo:
        print(f"all {len(new_paths)} blacksmith tier resources already registered")
        return

    used_ids = [int(i) for i in re.findall(r'\[ext_resource path="[^"]*"\s+type="[^"]*"\s+id=(\d+)\]', txt)]
    next_id = max(used_ids) + 1 if used_ids else 1

    block, ids = [], []
    for p in todo:
        block.append(f'[ext_resource path="{p}" type="Resource" id={next_id}]')
        ids.append(next_id)
        next_id += 1

    # insert the ext_resource block after the last existing one
    last = None
    for m in re.finditer(r'^\[ext_resource .*\]$', txt, re.M):
        last = m
    if last is None:
        raise SystemExit("no ext_resource block found - aborting rather than guessing")
    txt = txt[:last.end()] + "\n" + "\n".join(block) + txt[last.end():]

    # append to the weapons array
    m = re.search(r'^weapons = \[(.*?)\]$', txt, re.M | re.S)
    if not m:
        raise SystemExit("no weapons array found - aborting")
    inner = m.group(1).rstrip()
    additions = ", ".join(f"ExtResource( {i} )" for i in ids)
    joined = (inner + ", " if inner.strip() else "") + additions
    txt = txt[:m.start()] + f"weapons = [ {joined} ]" + txt[m.end():]

    # load_steps must cover every ext_resource + sub_resource, or Godot truncates
    n_ext = len(re.findall(r'^\[ext_resource ', txt, re.M))
    n_sub = len(re.findall(r'^\[sub_resource ', txt, re.M))
    txt = re.sub(r'^\[gd_scene load_steps=\d+', f"[gd_scene load_steps={n_ext + n_sub + 1}", txt, count=1)

    # re-verify before writing: no dangling ids, every path on disk
    declared = dict(re.findall(r'\[ext_resource path="([^"]+)"\s+type="[^"]*"\s+id=(\d+)\]', txt))
    ids_declared = set(declared.values())
    ids_used = set(re.findall(r'ExtResource\(\s*(\d+)\s*\)', txt))
    dangling = ids_used - ids_declared
    if dangling:
        raise SystemExit(f"refusing to write: dangling ExtResource ids {sorted(dangling)}")
    for path in declared:
        if path.startswith("res://") and not os.path.exists(os.path.join(DEC, path[6:])):
            raise SystemExit(f"refusing to write: missing file {path}")

    open(TSCN, "w", encoding="utf-8", newline="\n").write(txt)
    print(f"registered {len(todo)} blacksmith tier weapons "
          f"(load_steps now {n_ext + n_sub + 1})")


main()
