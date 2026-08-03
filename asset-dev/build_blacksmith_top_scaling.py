"""Give tier 8 (gold) a genuinely new step of every weapon's special scaling.

Run AFTER build_blacksmith_tiers.py.

Weapons carry effects that step per tier and are NOT plain stats - slingshot/champagne
bounces, galley cannon shots, the food-drop chance on Gourmet weapons, cleaver bleed,
and so on. The tier mapping the mod uses is:

    mod 1,2 -> vanilla 1     mod 5   -> vanilla 3     mod 8 -> a NEW step above vanilla 4
    mod 3,4 -> vanilla 2     mod 6,7 -> vanilla 4

Tiers 2/4/7 already satisfy that for free: build_blacksmith_tiers.py generates them from
the vanilla 1/2/4 templates, so they reference those tiers' effect resources directly.
Only tier 8 needs new values, continuing each family's OWN increment - galley cannon
[3,4,5,6] becomes 7, corn cannon food drop [1,2,3,4] becomes 5.

Idempotent: re-running recomputes from the vanilla tiers and rewrites the same values.
"""
import os, re, glob

DEC = "/Users/nicolassutcliffe/brotato-decompiled"

# stats that step per tier but are deliberately NOT interpolated by the main generator
SPECIAL_STATS = ["piercing", "bounce", "nb_projectiles", "projectile_spread",
                 "piercing_dmg_reduction"]
INT_SPECIAL = {"piercing", "bounce", "nb_projectiles"}


def read_num(path, key):
    if not path or not os.path.isfile(path):
        return None
    m = re.search(rf"^{key} = (-?[\d.]+)$", open(path, encoding="utf-8", errors="replace").read(), re.M)
    return float(m.group(1)) if m else None


def stats_path(fam, slug, n):
    for suf in (f"_{n}", "" if n == 1 else None):
        if suf is None:
            continue
        p = os.path.join(fam, str(n), f"{slug}{suf}_stats.tres")
        if os.path.isfile(p):
            return p
    return None


def set_num(path, key, value, as_int):
    txt = open(path, encoding="utf-8", errors="replace").read()
    v = str(int(round(value))) if as_int else str(round(value, 4))
    new, n = re.subn(rf"^{key} = -?[\d.]+$", f"{key} = {v}", txt, count=1, flags=re.M)
    if n:
        open(path, "w", encoding="utf-8", newline="\n").write(new)
    return bool(n)


def main():
    stat_bumps, eff_bumps, fams = 0, 0, 0

    for kind in ("melee", "ranged"):
        for fam in sorted(glob.glob(os.path.join(DEC, "weapons", kind, "*"))):
            if not os.path.isdir(fam):
                continue
            slug = os.path.basename(fam)
            bs8 = os.path.join(fam, "bs8")
            data8 = os.path.join(bs8, f"{slug}_bs8_data.tres")
            stats8 = os.path.join(bs8, f"{slug}_bs8_stats.tres")
            if not os.path.isfile(data8):
                continue

            touched = False

            # ---- special stats: continue the v3 -> v4 step -------------------------
            s3, s4 = stats_path(fam, slug, 3), stats_path(fam, slug, 4)
            for key in SPECIAL_STATS:
                a, b = read_num(s3, key), read_num(s4, key)
                if a is None or b is None or a == b:
                    continue
                nxt = b + (b - a)
                if key in INT_SPECIAL:
                    nxt = max(0, nxt)
                if set_num(stats8, key, nxt, key in INT_SPECIAL):
                    stat_bumps += 1
                    touched = True

            # ---- per-tier effect resources: give tier 8 its own copies -------------
            txt = open(data8, encoding="utf-8", errors="replace").read()
            for rel in re.findall(r'\[ext_resource path="res://([^"]+)"', txt):
                m = re.match(rf"weapons/{kind}/{slug}/4/(.+)$", rel)
                if not m:
                    continue
                fname = m.group(1)
                if "_effect_" not in fname and "_fooddrop" not in fname:
                    continue

                src4 = os.path.join(DEC, rel)
                v4 = read_num(src4, "value")
                if v4 is None:
                    continue
                # the tier-3 sibling, to learn this family's own increment
                cand = os.path.join(fam, "3", fname.replace("_4_", "_3_"))
                v3 = read_num(cand, "value")
                if v3 is None or v3 == v4:
                    continue

                out_name = fname.replace("_4_", "_bs8_")
                if out_name == fname:
                    out_name = f"{slug}_bs8_" + fname.split("_", 1)[-1]
                out_path = os.path.join(bs8, out_name)
                open(out_path, "w", encoding="utf-8", newline="\n").write(
                    open(src4, encoding="utf-8", errors="replace").read())
                set_num(out_path, "value", v4 + (v4 - v3), True)

                txt = txt.replace(f'path="res://{rel}"',
                                  f'path="res://weapons/{kind}/{slug}/bs8/{out_name}"')
                eff_bumps += 1
                touched = True

            open(data8, "w", encoding="utf-8", newline="\n").write(txt)
            if touched:
                fams += 1

    print(f"tier 8 special scaling: {stat_bumps} stat bumps, {eff_bumps} new effect resources, "
          f"across {fams} families")


main()
