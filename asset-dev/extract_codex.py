#!/usr/bin/env python3
"""Extract every character/weapon/item (base + Abyssal DLC + Gourmet mod) from the
decompiled project into codex.json for the browser artifact. Renders effect lines
with the game's own translation templates + operator/percent rules."""
import re, os, glob, json, base64, io, csv
from PIL import Image

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
OUT = "/Users/nicolassutcliffe/brotato-mods/asset-dev/codex.json"

# ---------- translations ----------
TR = {}
with open(f"{DEC}/.assets/resources/translations/translations.csv", newline='', encoding="utf-8-sig") as f:
    rd = csv.reader(f)
    head = next(rd)
    en = head.index("en") if "en" in head else 1
    for row in rd:
        if row and row[0]: TR[row[0].strip()] = row[en] if len(row) > en else row[0]
with open(f"{DEC}/items/custom/custom_translations.csv", newline='') as f:
    rd = csv.reader(f); next(rd)
    for row in rd:
        if row and row[0]: TR[row[0].strip()] = row[1] if len(row) > 1 else row[0]

# keys the game ships only in compiled translations (verified against in-game renders)
TR.setdefault("WEAPON_CLASS_MUSICAL", "Musical")
TR.setdefault("WEAPON_CLASS_NAVAL", "Naval")
TR.setdefault("REROLL_PRICE", "{0}% Reroll Price")
TR.setdefault("EFFECT_GAIN_PCT_GOLD_START_WAVE", "{0} Materials at the start of the wave")
TR.setdefault("WEAPON_SLOT", "{0} Weapon Slot")
TR.setdefault("ENEMY_HEALTH", "{0}% Enemy health")
TR.setdefault("XP_GAIN", "{0}% XP Gain")
TR.setdefault("STRUCTURE_ATTACK_SPEED", "{0}% Structure Attack Speed")

def _prettify(k):
    # DLC-gated mod content (naval expansion) keeps its names in a compiled PHashTranslation
    # the codex cannot read, so untranslated WEAPON_/ITEM_/CHARACTER_ keys fall through here.
    m = re.match(r'^(?:WEAPON_CLASS|WEAPON|ITEM|CHARACTER|SET)_(.+)$', k)
    if not m: return k
    name = m.group(1).replace('_', ' ').title()
    name = re.sub(r'\b(\w+?)s (Sword|Blade|Eye|Scepter|Sceptre|Bell|Hook|Flag|Map|Egg)\b', r"\1's \2", name)
    return name

def tr(k):
    if not k: return ""
    v = TR.get(k, TR.get(k.upper()))
    return v if v is not None else _prettify(k)

# ---------- operator/percent lists from text.gd ----------
tg = open(f"{DEC}/singletons/text.gd").read()
def parse_list(varname):
    m = re.search(varname + r":\s*=\s*\{(.*?)\n\}", tg, re.S)
    d = {}
    for k, v in re.findall(r'"([^"]+)":\s*\[([0-9,\s]*)\]', m.group(1)):
        d[k] = [int(x) for x in v.replace(" ", "").split(",") if x != ""]
    return d
OPS = parse_list("keys_needing_operator")
PCT = parse_list("keys_needing_percent")
OPS.setdefault("reroll_price", [0])

# ---------- tres helpers ----------
def props(path):
    t = open(path).read()
    ext = {int(i): p for p, i in re.findall(r'\[ext_resource path="([^"]+)" type="[^"]+" id=(\d+)\]', t)}
    body = t.split("[resource]")[-1]
    out = {"__ext": ext, "__path": path}
    for k, v in re.findall(r'^(\w+) = (.+)$', body, re.M):
        out[k] = v
    return out

def resolve(dec_ref, ext):
    m = re.match(r'ExtResource\(\s*(\d+)\s*\)', dec_ref or "")
    if not m: return None
    p = ext.get(int(m.group(1)))
    return f"{DEC}/{p[len('res://'):]}" if p else None

def num(v, default=0):
    try: return int(v)
    except Exception:
        try: return float(v)
        except Exception: return default

def thumb(png, size=32):
    # WebP at 32px keeps these small pixel-art icons legible with alpha but is far smaller
    # than PNG. ~600 embedded thumbnails dominate the codex file size, and the artifact
    # must stay under ~1MB to be shareable publicly, so keep the size + quality modest.
    try:
        im = Image.open(png).convert("RGBA")
        im.thumbnail((size, size), Image.LANCZOS)
        b = io.BytesIO(); im.save(b, "WEBP", quality=60, method=6)
        return "data:image/webp;base64," + base64.b64encode(b.getvalue()).decode()
    except Exception:
        return ""

# ---------- foods (Gourmet DLC) ----------
# Food card lines are rendered live in-game (effect.gd EFFECT_FOOD_ branch reading
# the FoodData); mirror that here. Arg order: buff_stats, duration (if app-scaled),
# wave_stats, heal. The in-game appetite icon becomes the word "Appetite".
FOOD_BY_ID = {}
for _p in glob.glob(f"{DEC}/items/foods/*/*_data.tres"):
    _d = props(_p)
    FOOD_BY_ID[(_d.get("my_id") or '""').strip('"')] = _d

def food_formula_args(d):
    args = []
    def add(base, ratio):
        args.append(str(int(float(base))))
        if float(ratio) != 0:
            args.append("+%d%% Appetite" % round(float(ratio) * 100))
    for _k, b, r in re.findall(r'\[ "(\w+)", ([\d.]+), ([\d.]+) \]', d.get("buff_stats", "")):
        add(b, r)
    if float(d.get("duration_app_ratio", "0.0")) != 0:
        add(d.get("buff_duration", "0"), d.get("duration_app_ratio", "0"))
    for _k, b, r in re.findall(r'\[ "(\w+)", ([\d.]+), ([\d.]+) \]', d.get("wave_stats", "")):
        add(b, r)
    if float(d.get("heal_base", "0.0")) > 0:
        add(d.get("heal_base"), d.get("heal_app_ratio", "0"))
    return args

# ---------- effect rendering (mirror of Text.text) ----------
def fmt_arg(key, idx, val):
    s = str(val)
    if idx in OPS.get(key.lower(), []) and not s.startswith("-"): s = "+" + s
    if idx in PCT.get(key.lower(), []): s = s + "%"
    return s

def render_effect(epath):
    p = props(epath)
    key = (p.get("key") or '""').strip('"')
    text_key = (p.get("text_key") or '""').strip('"')
    val = num(p.get("value", "0"))
    script = p["__ext"].get(1, "")
    tkey = text_key if text_key else key
    if not tkey: return None
    if text_key == "EFFECT_HIDDEN": return None
    custom_key = (p.get("custom_key") or '""').strip('"')
    if text_key.startswith("EFFECT_FOOD_") and custom_key in FOOD_BY_ID:
        out = tr(text_key)
        for i, a in enumerate(food_formula_args(FOOD_BY_ID[custom_key])):
            out = out.replace("{%d}" % i, a)
        out = re.sub(r"\{\d\}", "", out)
        out = re.sub(r"\s+", " ", out).strip()
        return {"t": out, "good": True}
    # projectile effects (Food Fight): {1} = base damage, {3} = scaling text
    if "projectile_effect" in script:
        stats_path = resolve(p.get("weapon_stats"), p["__ext"])
        if stats_path and os.path.exists(stats_path):
            sp = props(stats_path)
            template = tr(text_key.upper()) if text_key else ""
            if template:
                scal = re.findall(r'\[ "(\w+)", ([\d.]+) \]', sp.get("scaling_stats", ""))
                scal_text = " ".join("+%d%% %s" % (round(float(r) * 100), tr(k.upper())) for k, r in scal)
                out = template.replace("{1}", sp.get("damage", "0")).replace("{3}", "(%s)" % scal_text if scal_text else "")
                out = re.sub(r"\{\d\}", "", out)
                out = re.sub(r"\(\s*\(", "(", out).replace("))", ")")
                out = re.sub(r"\s+", " ", out).strip()
                return {"t": out, "good": True}

    # spawning turret effects (Garden, Ice Cream Truck): {0} = spawn interval seconds
    if "turret_effect" in script and (p.get("is_spawning") or "").strip() == "true":
        stats_path = resolve(p.get("stats"), p["__ext"])
        if stats_path and os.path.exists(stats_path):
            sp = props(stats_path)
            template = tr(text_key.upper()) if text_key else ""
            if template and "{0}" in template:
                out = template.replace("{0}", str(round(num(sp.get("cooldown", "0")) / 60.0, 1)).rstrip("0").rstrip("."))
                return {"t": out, "good": True}
    template = tr(tkey.upper()) if tr(tkey.upper()) != tkey.upper() else tr(tkey)
    if template in (tkey, tkey.upper()):
        template = tkey.replace("_", " ").capitalize()
    sign = num(p.get("effect_sign", "3"))
    good = (sign == 0) or (sign == 3 and val >= 0) or (sign == 2)
    if sign == 1: good = False
    args = {0: fmt_arg(tkey, 0, val), 1: (tr(key.upper()) if key and tr(key.upper()) != key.upper() else "")}
    if p.get("value2") is not None: args[1] = num(p.get("value2"))
    if p.get("value3") is not None: args[2] = num(p.get("value3"))
    if "gain_stat_for_every_stat" in script:
        scaled = (p.get("stat_scaled") or '""').strip('"')
        args[4] = tr(scaled.upper())
    if "{0}" not in template:
        if 0 in OPS.get(tkey.lower(), []):
            template = "{0} " + template
        else:
            # game rule: value only displays for operator-listed keys or {0} templates
            pass
    out = template
    for i in range(0, 6):
        out = out.replace("{%d}" % i, str(args.get(i, "")))
    out = re.sub(r"\{\d\}", "", out)
    out = out.replace("%%", "%")
    out = re.sub(r"\(\s*\)", "", out)
    out = re.sub(r"\[\s*\]", "", out)
    out = re.sub(r"\s+", " ", out).strip()
    return {"t": out, "good": good}

def render_effects(data, ext):
    lines = []
    for ref in re.findall(r'ExtResource\(\s*\d+\s*\)', data.get("effects", "")):
        ep = resolve(ref, ext)
        if ep and os.path.exists(ep):
            r = render_effect(ep)
            if r and r["t"]: lines.append(r)
    return lines

# ---------- characters ----------
def load_character(path, source):
    d = props(path)
    name = (d.get("name") or '""').strip('"')
    disp = tr(name) if name.startswith("CHARACTER") else name
    icon = resolve(d.get("icon"), d["__ext"])
    return {"name": disp or os.path.basename(path), "source": source,
            "icon": thumb(icon) if icon else "", "effects": render_effects(d, d["__ext"])}

# ---------- items ----------
TIER_NAMES = ["Common", "Uncommon", "Rare", "Legendary"]
def load_item(path, source):
    d = props(path)
    name = (d.get("name") or '""').strip('"')
    disp = tr(name) if name.upper() == name and "_" in name else name
    icon = resolve(d.get("icon"), d["__ext"])
    tags = re.findall(r'"([^"]+)"', d.get("tags", ""))
    return {"name": disp or os.path.basename(path), "source": source,
            "tier": num(d.get("tier", "0")), "value": num(d.get("value", "0")),
            "icon": thumb(icon) if icon else "", "tags": tags,
            "max_nb": num(d.get("max_nb", "-1")),
            "effects": render_effects(d, d["__ext"])}

# ---------- weapons ----------
def weapon_stats(spath):
    if not spath or not os.path.exists(spath): return {}
    s = props(spath)
    g = lambda k: s.get(k)
    out = {}
    for label, k in [("Damage", "damage"), ("Cooldown", "cooldown"), ("Crit ×", "crit_chance"),
                     ("Crit %", "crit_multiplier"), ("Range", "max_range"), ("Knockback", "knockback")]:
        if g(k) is not None: out[label] = g(k)
    # correct crit naming (crit_chance is the multiplier? keep raw keys too)
    return {k: v for k, v in out.items()}

def load_weapon_family(folder, source):
    tiers = []
    base = None
    for tdir in sorted(glob.glob(folder + "/[0-9]")):
        dats = glob.glob(tdir + "/*_data.tres")
        dats = [x for x in dats if "_burning_" not in x] or dats
        if not dats: continue
        d = props(dats[0])
        name = (d.get("name") or '""').strip('"')
        disp = tr(name) if name.startswith("WEAPON") else name
        icon = resolve(d.get("icon"), d["__ext"])
        stats_p = resolve(d.get("stats"), d["__ext"])
        sets = []
        if True:
            for ref in re.findall(r'ExtResource\(\s*\d+\s*\)', d.get("sets", "")):
                sp = resolve(ref, d["__ext"])
                if sp and os.path.exists(sp):
                    sd = props(sp)
                    sets.append(tr((sd.get("name") or '""').strip('"')))
        st = {}
        if stats_p and os.path.exists(stats_p):
            sp2 = props(stats_p)
            for k in ["damage", "cooldown", "crit_chance", "crit_multiplier", "max_range", "knockback", "lifesteal"]:
                if k in sp2: st[k] = num(sp2[k])
        tiers.append({"tier": num(d.get("tier", "0")), "value": num(d.get("value", "0")),
                      "stats": st, "effects": render_effects(d, d["__ext"])})
        if base is None:
            cls = [c for c in sets if c]
            # Culinary mod weapons live in the base weapon folders, so folder-based source
            # mislabels them "base". A Culinary class means it is a Gourmet-mod weapon.
            src = "mod" if any("Culinary" in c for c in cls) else source
            slug = os.path.basename(folder)
            held_png = f"{folder}/{slug}.png"
            base = {"name": disp, "source": src, "icon": thumb(icon) if icon else "",
                    "held": thumb(held_png, 128) if os.path.exists(held_png) else "",
                    "classes": cls, "kind": "Melee" if "/melee/" in folder else "Ranged"}
    if base:
        base["tiers"] = tiers
    return base

# ---------- walk everything ----------
codex = {"characters": [], "weapons": [], "items": [], "foods": []}

# spawner linkage: each spawner's food-text effect (effect_1) carries the food's
# my_id in custom_key (works for trigger, SUM and structure spawners alike)
SPAWNER_OF = {}
for p in sorted(glob.glob(f"{DEC}/items/custom/*/*_effect_1.tres")):
    ep = props(p)
    k = (ep.get("custom_key") or '""').strip('"')
    if k.startswith("consumable_food_"):
        sd = props(p.replace("_effect_1.tres", "_data.tres"))
        SPAWNER_OF[k] = (sd.get("name") or '""').strip('"')

def load_food(path):
    d = props(path)
    name = (d.get("name") or '""').strip('"')
    icon = resolve(d.get("icon"), d["__ext"])
    my_id = (d.get("my_id") or '""').strip('"')
    has_buff = ('[ "' in (d.get("buff_stats", "") or "")) or ('[ "' in (d.get("wave_stats", "") or ""))
    stack_cap = 1 if d.get("buff_stacks", "true") == "false" else num(d.get("buff_stack_cap", "20"))
    return {"name": name or os.path.basename(path), "source": "mod",
            "icon": thumb(icon) if icon else "", "spawner": SPAWNER_OF.get(my_id, ""),
            "stack_cap": stack_cap if has_buff else 0,
            "effects": render_effects(d, d["__ext"])}

for p in sorted(glob.glob(f"{DEC}/items/foods/*/*_data.tres")):
    codex["foods"].append(load_food(p))

for p in sorted(glob.glob(f"{DEC}/items/custom_characters/*/*_data.tres")):
    if "test_character" in p: continue
    codex["characters"].append(load_character(p, "mod"))
for p in sorted(glob.glob(f"{DEC}/items/characters/*/*_data.tres")):
    codex["characters"].append(load_character(p, "base"))
for p in sorted(glob.glob(f"{DEC}/dlcs/dlc_1/characters/*/*_data.tres")):
    if "/challenges/" in p: continue
    codex["characters"].append(load_character(p, "dlc"))

for p in sorted(glob.glob(f"{DEC}/items/custom/*/*_data.tres")):
    codex["items"].append(load_item(p, "mod"))
for p in sorted(glob.glob(f"{DEC}/items/all/*/*_data.tres")):
    codex["items"].append(load_item(p, "base"))
for p in sorted(glob.glob(f"{DEC}/dlcs/dlc_1/items/*/*_data.tres")):
    codex["items"].append(load_item(p, "dlc"))

# ---------- Butcher meat variants (runtime reskin, not separate ItemData) ----------
# When the Butcher is in the run, ButcherSkin.apply() renames/re-icons these vanilla items
# and swaps every fruit/tree description to a meat line. Shown here as their own entries so
# the codex documents the whole skin.
BUTCHER_VARIANTS = [
    ("Meat Rack", "meat_rack_icon.png", "Tree", [("More meat racks spawn", True)]),
    ("Meat Locker", "meat_locker_icon.png", "Garden",
     [("Spawns a meat locker that dispenses a steak regularly", True)]),
    ("Meat Cooler", "meat_cooler_icon.png", "Fruit Basket",
     [("Enemies have a higher chance of dropping steaks", True), ("-3 HP Regeneration", False)]),
    ("Beef Broth", "beef_broth_icon.png", "Lemonade", [("Consumables heal +1 HP", True)]),
    ("Bloody Butcher's Apron", "butchers_apron_icon.png", "Lumberjack Shirt",
     [("Meat racks die in one hit", True)]),
]
for vname, vicon, replaces, veffects in BUTCHER_VARIANTS:
    ip = f"{DEC}/items/custom/butcher_skin/{vicon}"
    codex["items"].append({
        "name": vname, "source": "mod", "tier": 0, "value": 0,
        "icon": thumb(ip) if os.path.exists(ip) else "", "tags": ["butcher"],
        "effects": [{"t": t, "good": g} for t, g in veffects] +
                   [{"t": f"Butcher only - replaces {replaces} (same mechanics, meat theme)", "good": True}]})

# Weapons our mod adds live in the vanilla weapons/ folders (they clone a base weapon), so
# path can't distinguish them. build_weapons.py is the source of truth for which are ours.
MOD_WEAPONS = set(re.findall(r'\bw\("([a-z_]+)"',
                  open("/Users/nicolassutcliffe/brotato-mods/asset-dev/build_weapons.py").read()))
for folder in sorted(glob.glob(f"{DEC}/weapons/melee/*") + glob.glob(f"{DEC}/weapons/ranged/*")):
    if not os.path.isdir(folder): continue
    w = load_weapon_family(folder, "mod" if os.path.basename(folder) in MOD_WEAPONS else "base")
    if w: codex["weapons"].append(w)
for folder in sorted(glob.glob(f"{DEC}/dlcs/dlc_1/weapons/melee/*") + glob.glob(f"{DEC}/dlcs/dlc_1/weapons/ranged/*")):
    if not os.path.isdir(folder): continue
    w = load_weapon_family(folder, "dlc")
    if w: codex["weapons"].append(w)

# ---------- structures (in-world spawner sprites) ----------
codex["structures"] = []
for sdir in sorted(glob.glob(f"{DEC}/entities/structures/turret/*")):
    if not os.path.isdir(sdir): continue
    slug = os.path.basename(sdir)
    ing = f"{sdir}/{slug}_ingame.png"
    if not os.path.exists(ing): continue
    name = slug.replace("_", " ").title(); effects = []
    item_data = f"{DEC}/items/custom/{slug}/{slug}_data.tres"
    if os.path.exists(item_data):
        d = props(item_data)
        nm = (d.get("name") or '""').strip('"')
        name = tr(nm) if nm else name
        effects = render_effects(d, d["__ext"])
    codex["structures"].append({"name": name, "source": "mod", "kind": "Structure",
                                "icon": thumb(ing, 80), "effects": effects})

# ---------- projectiles (what each MOD ranged weapon fires) ----------
# MOD_WEAPONS (not the Culinary set) decides membership: galley_cannon is naval-set but
# ours. Lowest tier dir, not hardcoded /1/ (ice_cream_scoop starts at tier 2).
codex["projectiles"] = []
for folder in sorted(glob.glob(f"{DEC}/weapons/ranged/*")):
    if not os.path.isdir(folder): continue
    slug = os.path.basename(folder)
    if slug not in MOD_WEAPONS: continue
    tiers = sorted(int(x) for x in os.listdir(folder) if x.isdigit())
    if not tiers: continue
    tt = tiers[0]
    wd = sorted(glob.glob(f"{folder}/{tt}/*_data.tres"))
    st = sorted(glob.glob(f"{folder}/{tt}/*stats.tres"))
    if not wd or not st: continue
    d = props(wd[0]); wname = tr((d.get("name") or '""').strip('"')) or slug
    sp = props(st[0]); proj_ref = resolve(sp.get("projectile_scene"), sp["__ext"])
    pname, picon = "—", ""
    if proj_ref and os.path.exists(proj_ref):
        pname = os.path.basename(os.path.dirname(proj_ref)).replace("_projectile", "").replace("_", " ").title()
        pm = re.search(r'res://([^"]*\.png)', open(proj_ref).read())
        if pm and os.path.exists(f"{DEC}/{pm.group(1)}"): picon = thumb(f"{DEC}/{pm.group(1)}", 56)
        # our cloned projectile scenes point the texture at the weapon's own folder
        pm2 = re.search(r'res://(weapons/ranged/[^"]*_projectile\.png)', open(proj_ref).read())
        if pm2 and os.path.exists(f"{DEC}/{pm2.group(1)}"):
            picon = thumb(f"{DEC}/{pm2.group(1)}", 56)
            pname = wname + " shot"
    codex["projectiles"].append({"name": wname, "source": "mod", "kind": "Projectile",
                                 "icon": picon, "projectile": pname,
                                 "effects": [{"t": "Fires the " + pname + " projectile", "good": True}]})

json.dump(codex, open(OUT, "w"))
print("characters:", len(codex["characters"]), "| weapons:", len(codex["weapons"]),
      "| items:", len(codex["items"]), "| foods:", len(codex["foods"]),
      "| structures:", len(codex["structures"]), "| projectiles:", len(codex["projectiles"]))
print("size:", round(os.path.getsize(OUT) / 1024), "KB")
