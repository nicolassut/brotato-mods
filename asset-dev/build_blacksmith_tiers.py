"""Generate the Blacksmith's four extra weapon tiers for every weapon family.

The Blacksmith runs an 8-step weapon ladder that interleaves four new rarities with
the vanilla four:

    1 = vanilla T1        5 = vanilla T3
    2 = NEW green         6 = vanilla T4
    3 = vanilla T2        7 = NEW pink
    4 = NEW orange        8 = NEW gold

This is ADDITIVE: no existing vanilla weapon resource is touched, so every other
character is byte-for-byte unaffected. Only the four new tiers are written, into
their own bs2/ bs4/ bs7/ bs8/ folders per family.

Tier numbers on the new resources are 7/8/9/10, NOT 4/5/6 - those integers are
already Tier.DANGER_4 / DANGER_5 / NIGHTMARE and would collide with the danger
colour mapping in item_service.get_color_from_tier.

Scaling (per the spec):
  green  = midpoint(v1, v2)      orange = midpoint(v2, v3)
  pink   = one step above v4     gold   = two steps above v4
Damage/crit/knockback/price extrapolate linearly. Cooldown extrapolates
GEOMETRICALLY (same ratio step as v3->v4) and is floored, because linear
extrapolation on an inverse stat compounds with the damage curve and can reach
zero or negative on families with a steep cooldown ramp.
"""
import os, re, shutil

DEC = "/Users/nicolassutcliffe/brotato-decompiled"

TIER_GREEN, TIER_ORANGE, TIER_PINK, TIER_GOLD = 7, 8, 9, 10
MIN_COOLDOWN = 5

# stats scaled between tiers; everything else is inherited from the template tier
INT_STATS = {"damage", "cooldown", "max_range", "min_range", "knockback",
             "projectile_speed", "recoil"}
FLOAT_STATS = {"crit_chance", "crit_damage", "lifesteal", "accuracy",
               "effect_scale", "knockback_piercing"}
SCALED = INT_STATS | FLOAT_STATS


def tier_files(fam_dir, slug, n):
    """(data_path, stats_path) for tier n, or (None, None).

    Two naming conventions coexist: vanilla leaves tier 1 unnumbered
    (pistol_data.tres) while the mod's own builder numbers every tier
    (cleaver_1_data.tres). Try both.
    """
    d = os.path.join(fam_dir, str(n))
    if not os.path.isdir(d):
        return None, None
    for suffix in (f"_{n}", "" if n == 1 else None):
        if suffix is None:
            continue
        data = os.path.join(d, f"{slug}{suffix}_data.tres")
        stats = os.path.join(d, f"{slug}{suffix}_stats.tres")
        if os.path.isfile(data) and os.path.isfile(stats):
            return data, stats
    return None, None


def read_stats(path):
    out = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^(\w+) = (-?[\d.]+)$", line.strip())
        if m and m.group(1) in SCALED:
            v = m.group(2)
            out[m.group(1)] = float(v) if "." in v else int(v)
    return out


def fmt(key, val):
    if key in INT_STATS:
        return str(int(round(val)))
    return f"{round(val, 4)}"


def blend(a, b, t):
    """Linear blend a->b at fraction t (t=0.5 is the midpoint)."""
    return a + (b - a) * t


def extrapolate(v3, v4, steps, key):
    """One or two steps past v4. Geometric + floored for cooldown."""
    if key == "cooldown":
        if v3 <= 0 or v4 <= 0:
            return v4
        ratio = float(v4) / float(v3)
        return max(MIN_COOLDOWN, v4 * (ratio ** steps))
    return v4 + (v4 - v3) * steps


def write_stats(template_path, out_path, values):
    lines = []
    for line in open(template_path, encoding="utf-8", errors="replace"):
        m = re.match(r"^(\w+) = (-?[\d.]+)$", line.rstrip("\n"))
        if m and m.group(1) in values:
            lines.append(f"{m.group(1)} = {fmt(m.group(1), values[m.group(1)])}\n")
        else:
            lines.append(line)
    open(out_path, "w", encoding="utf-8", newline="\n").writelines(lines)


def write_data(template_path, out_path, slug, key, tier, value, stats_rel,
               upgrades_rel):
    txt = open(template_path, encoding="utf-8", errors="replace").read()

    def repoint(field, new_path):
        """Repoint the ext_resource that `field` actually points at, by id.

        Must be id-driven, never path-pattern driven: a weapon's set resource is
        called e.g. gun_set_data.tres, so matching on "_data.tres" silently
        rewrites or deletes the SET reference instead of the upgrade target and
        leaves `sets = [ ExtResource( n ) ]` dangling.
        """
        m = re.search(r'^' + field + r' = ExtResource\(\s*(\d+)\s*\)$', txt, re.M)
        if not m:
            return None
        rid = m.group(1)
        return re.sub(r'(\[ext_resource path=")[^"]*("\s+type="[^"]*"\s+id=' + rid + r'\])',
                      r'\1' + new_path + r'\2', txt, count=1), rid

    res = repoint("stats", stats_rel)
    if res:
        txt = res[0]

    up = re.search(r'^upgrades_into = ExtResource\(\s*(\d+)\s*\)$', txt, re.M)
    if upgrades_rel and up:
        res = repoint("upgrades_into", upgrades_rel)
        if res:
            txt = res[0]
    elif upgrades_rel and not up:
        # template was a top tier with no upgrade target; nothing to repoint
        pass
    elif up:
        # drop the upgrade: remove the field AND only its own ext_resource line
        rid = up.group(1)
        txt = re.sub(r'\[ext_resource path="[^"]*"\s+type="[^"]*"\s+id=' + rid + r'\]\n',
                     "", txt, count=1)
        txt = re.sub(r'^upgrades_into = .*\n', "", txt, flags=re.M)

    txt = re.sub(r'^my_id = ".*"$', f'my_id = "weapon_{slug}_{key}"', txt, flags=re.M)
    txt = re.sub(r'^tier = .*$', f"tier = {tier}", txt, flags=re.M)
    txt = re.sub(r'^value = .*$', f"value = {int(round(value))}", txt, flags=re.M)
    open(out_path, "w", encoding="utf-8", newline="\n").write(txt)


def median(xs):
    xs = sorted(xs)
    if not xs:
        return 1.0
    n = len(xs)
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2.0


def collect_ratios(families):
    """Median per-stat ratio between adjacent vanilla tiers, across every family
    that actually has both. Used as the fallback step for families that only
    exist at a single tier (Excalibur, Drill, Chain Gun ...), which have no
    neighbour to derive a step from."""
    acc = {"12": {}, "23": {}, "34": {}}
    for sv in families:
        for pair, (a, b) in (("12", (1, 2)), ("23", (2, 3)), ("34", (3, 4))):
            if a not in sv or b not in sv:
                continue
            for k, va in sv[a].items():
                vb = sv[b].get(k)
                if vb is None or va in (0, 0.0):
                    continue
                acc[pair].setdefault(k, []).append(float(vb) / float(va))
    return {p: {k: median(v) for k, v in d.items()} for p, d in acc.items()}


def scan_families():
    """[(kind, slug, fam_dir, {tier: data}, {tier: stats})] for every family."""
    out = []
    for kind in ("melee", "ranged"):
        root = os.path.join(DEC, "weapons", kind)
        if not os.path.isdir(root):
            continue
        for slug in sorted(os.listdir(root)):
            fam = os.path.join(root, slug)
            if not os.path.isdir(fam):
                continue
            data, stats = {}, {}
            for n in (1, 2, 3, 4):
                d, s = tier_files(fam, slug, n)
                if d and s:
                    data[n], stats[n] = d, s
            if data:
                out.append((kind, slug, fam, data, stats))
    return out


def main():
    made, skipped = 0, []
    # pass 1: learn the typical per-tier step from every complete family
    RATIOS = collect_ratios([{n: read_stats(s) for n, s in st.items()}
                             for _, _, _, _, st in scan_families()])
    for kind in ("melee", "ranged"):
        root = os.path.join(DEC, "weapons", kind)
        if not os.path.isdir(root):
            continue
        for slug in sorted(os.listdir(root)):
            fam = os.path.join(root, slug)
            if not os.path.isdir(fam):
                continue

            # Not every family has a full 1-4 ladder: circular_saw starts at 2,
            # baguette at 3, excalibur is tier 4 only. Take whatever exists and
            # generate only the new tiers that are actually derivable from it.
            data, stats = {}, {}
            for n in (1, 2, 3, 4):
                d, s = tier_files(fam, slug, n)
                if d and s:
                    data[n], stats[n] = d, s
            if not data:
                skipped.append(f"{slug}(no tiers)")
                continue

            sv = {n: read_stats(stats[n]) for n in data}
            price = {}
            for n in data:
                m = re.search(r"^value = (\d+)$",
                              open(data[n], encoding="utf-8", errors="replace").read(), re.M)
                price[n] = int(m.group(1)) if m else 10

            # (folder, tier, template_tier, how to derive each stat, price)
            plan = []
            if 1 in data and 2 in data:
                plan.append(("bs2", TIER_GREEN, 1,
                             lambda k: blend(sv[1].get(k, 0), sv[2].get(k, 0), 0.5),
                             blend(price[1], price[2], 0.5), 2))
            if 2 in data and 3 in data:
                plan.append(("bs4", TIER_ORANGE, 2,
                             lambda k: blend(sv[2].get(k, 0), sv[3].get(k, 0), 0.5),
                             blend(price[2], price[3], 0.5), 3))
            if 3 in data and 4 in data:
                plan.append(("bs7", TIER_PINK, 4,
                             lambda k: extrapolate(sv[3].get(k, 0), sv[4].get(k, 0), 1, k),
                             price[4] + (price[4] - price[3]), None))
                plan.append(("bs8", TIER_GOLD, 4,
                             lambda k: extrapolate(sv[3].get(k, 0), sv[4].get(k, 0), 2, k),
                             price[4] + (price[4] - price[3]) * 2, None))
            # Fallbacks for families that exist at a single tier only, so there is
            # no adjacent tier to derive a step from. Use the median step learned
            # from every complete family instead of inventing numbers.
            if 4 in data and 3 not in data:
                r = RATIOS["34"]
                plan.append(("bs7", TIER_PINK, 4,
                             lambda k: sv[4].get(k, 0) * r.get(k, 1.0),
                             price[4] * 1.5, None))
                plan.append(("bs8", TIER_GOLD, 4,
                             lambda k: sv[4].get(k, 0) * (r.get(k, 1.0) ** 2),
                             price[4] * 2.0, None))
            if 1 in data and 2 not in data:
                r = RATIOS["12"]
                plan.append(("bs2", TIER_GREEN, 1,
                             lambda k: sv[1].get(k, 0) * (1 + (r.get(k, 1.0) - 1) * 0.5),
                             price[1] * 1.5, None))

            if not plan:
                skipped.append(f"{slug}(tiers {sorted(data)})")
                continue

            for key, tier, tmpl, calc, val, up_tier in plan:
                out_dir = os.path.join(fam, key)
                os.makedirs(out_dir, exist_ok=True)
                stats_out = os.path.join(out_dir, f"{slug}_{key}_stats.tres")
                data_out = os.path.join(out_dir, f"{slug}_{key}_data.tres")

                vals = {k: calc(k) for k in sv[tmpl] if k in SCALED}
                write_stats(stats[tmpl], stats_out, vals)

                stats_rel = f"res://weapons/{kind}/{slug}/{key}/{slug}_{key}_stats.tres"
                if up_tier is not None:
                    suffix = "" if up_tier == 1 else f"_{up_tier}"
                    up_rel = f"res://weapons/{kind}/{slug}/{up_tier}/{slug}{suffix}_data.tres"
                elif key == "bs7":
                    up_rel = f"res://weapons/{kind}/{slug}/bs8/{slug}_bs8_data.tres"
                else:
                    up_rel = None

                write_data(data[tmpl], data_out, slug, key, tier, val, stats_rel, up_rel)
                made += 2

    print(f"wrote {made} files across the weapon families")
    if skipped:
        print(f"skipped {len(skipped)} without a full 1-4 ladder: {', '.join(skipped[:12])}"
              + (" ..." if len(skipped) > 12 else ""))


main()
