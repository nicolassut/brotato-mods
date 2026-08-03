"""Add a 6th class-bonus level to every weapon set, ~30% above the 5th.

The Blacksmith's class levels come from summed weapon tiers (4/8/12/16/20/24 -> levels
1-6, see run_data.update_sets), but the sets only ever defined FIVE bonus tiers, so
levels 5 and 6 rendered identically. This authors the missing sixth.

Rules:
  * upsides scale x1.3, then round so the number looks like it belongs to the series:
    values that are a multiple of 5 and >= 10 snap to the nearest 5, everything else
    rounds half-up to the nearest integer.
  * DRAWBACKS (negative values - blunt's -10 Speed, ethereal's -5 Armor, legendary's
    -100 Max HP) are copied UNCHANGED. Scaling them would make the capstone level
    strictly worse, which is the opposite of "30% better".

Two on-disk layouts exist and both are handled:
  * numbered folders   items/sets/<set>/6/set_6_effect_N.tres   -> writes 7/set_7_effect_N.tres
  * flat bonus files   items/sets/culinary/culinary_bonus_6.tres -> writes culinary_bonus_7.tres

Idempotent: re-running detects the level already exists and does nothing.
"""
import os, re, glob, math

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
SETS = os.path.join(DEC, "items/sets")


def scaled(v: int) -> int:
    if v <= 0:
        return v                                   # drawback: leave it alone
    x = v * 1.3
    if v >= 10 and v % 5 == 0:
        return int(math.floor(x / 5.0 + 0.5)) * 5  # keep the "round number" look
    return int(math.floor(x + 0.5))


def rewrite_value(src: str, dst: str) -> tuple:
    txt = open(src, encoding="utf-8", errors="replace").read()
    m = re.search(r"^value = (-?\d+)$", txt, re.M)
    old = int(m.group(1)) if m else 0
    new = scaled(old)
    if m:
        txt = re.sub(r"^value = -?\d+$", f"value = {new}", txt, count=1, flags=re.M)
    open(dst, "w", encoding="utf-8", newline="\n").write(txt)
    return old, new


def register(set_data: str, new_rel_paths: list) -> bool:
    """Add ext_resources for the new effects and append a 6th set_bonuses group."""
    txt = open(set_data, encoding="utf-8", errors="replace").read()
    if any(p in txt for p in new_rel_paths):
        return False

    ids = [int(i) for i in re.findall(r'\[ext_resource path="[^"]*"\s+type="[^"]*"\s+id=(\d+)\]', txt)]
    nid = max(ids) + 1 if ids else 1

    block, used = [], []
    for rel in new_rel_paths:
        block.append(f'[ext_resource path="{rel}" type="Resource" id={nid}]')
        used.append(nid)
        nid += 1

    last = None
    for m in re.finditer(r'^\[ext_resource .*\]$', txt, re.M):
        last = m
    txt = txt[:last.end()] + "\n" + "\n".join(block) + txt[last.end():]

    m = re.search(r'^set_bonuses = \[(.*)\]$', txt, re.M)
    group = "[ " + ", ".join(f"ExtResource( {i} )" for i in used) + " ]"
    txt = txt[:m.start()] + f"set_bonuses = [{m.group(1)}, {group} ]" + txt[m.end():]

    n_ext = len(re.findall(r'^\[ext_resource ', txt, re.M))
    n_sub = len(re.findall(r'^\[sub_resource ', txt, re.M))
    txt = re.sub(r'^\[gd_resource type="Resource" load_steps=\d+',
                 f'[gd_resource type="Resource" load_steps={n_ext + n_sub + 1}', txt, count=1)

    open(set_data, "w", encoding="utf-8", newline="\n").write(txt)
    return True


def main():
    done, skipped = 0, []
    for set_dir in sorted(glob.glob(os.path.join(SETS, "*"))):
        if not os.path.isdir(set_dir):
            continue
        name = os.path.basename(set_dir)
        data = os.path.join(set_dir, f"{name}_set_data.tres")
        if not os.path.isfile(data):
            skipped.append(f"{name}(no set_data)")
            continue

        src_files, dst_files, rels = [], [], []

        top = os.path.join(set_dir, "6")
        if os.path.isdir(top):                                   # numbered-folder layout
            new_dir = os.path.join(set_dir, "7")
            os.makedirs(new_dir, exist_ok=True)
            for f in sorted(glob.glob(os.path.join(top, "set_6_effect_*.tres"))):
                n = os.path.basename(f).split("_")[-1]
                src_files.append(f)
                dst_files.append(os.path.join(new_dir, f"set_7_effect_{n}"))
                rels.append(f"res://items/sets/{name}/7/set_7_effect_{n}")
        else:                                                    # flat bonus-file layout
            f = os.path.join(set_dir, f"{name}_bonus_6.tres")
            if os.path.isfile(f):
                src_files.append(f)
                dst_files.append(os.path.join(set_dir, f"{name}_bonus_7.tres"))
                rels.append(f"res://items/sets/{name}/{name}_bonus_7.tres")

        if not src_files:
            skipped.append(f"{name}(no level-5 bonus found)")
            continue

        # Pure-drawback sets get NO sixth level. `legendary` is only an escalating Max HP
        # cost (-20/-40/-60/-80/-100), the price of stacking legendary weapons - there is
        # no upside to scale, so a sixth level would either be a free freebie or a bigger
        # punishment. It stays exactly as vanilla, and update_sets' bonus_index clamp
        # (min(level - 1, set_bonuses.size() - 1)) caps the Blacksmith at its 5th.
        if all((lambda v: v is not None and v <= 0)(
                (lambda m: int(m.group(1)) if m else None)(
                    re.search(r"^value = (-?\d+)$",
                              open(f, encoding="utf-8", errors="replace").read(), re.M)))
               for f in src_files):
            skipped.append(f"{name}(drawback-only, left at vanilla)")
            continue

        changes = []
        for s, d in zip(src_files, dst_files):
            o, nv = rewrite_value(s, d)
            changes.append(f"{o}->{nv}")

        if register(data, rels):
            print(f"  {name:<12} level 6: {', '.join(changes)}")
            done += 1
        else:
            print(f"  {name:<12} already registered - values refreshed")

    print(f"\nwrote level 6 for {done} sets")
    if skipped:
        print("skipped:", ", ".join(skipped))


main()
