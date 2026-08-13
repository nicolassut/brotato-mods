"""P2W chest system - item rarity spread (Phase 1).

Assigns every registered, lootable ITEM to one of the 8 rungs of the Blacksmith
tier ladder (weapons already carry real ladder tiers and need no table):

    1 white   2 green   3 blue   4 orange   5 purple   6 red   7 pink   8 gold

Vanilla tiers keep their home rung (T0->white, T1->blue, T2->purple, T3->red);
within each tier items are ranked by shop value and the strong/weak ends are
promoted/demoted into the four new rungs so every rung has a fair population.
The output is a DRAFT: the user reviews rarity_spread.json (via the HTML page)
and edits/locks it before Phase 2 consumes it. Reruns respect locked entries.

Outputs (both in this directory):
  rarity_spread.json  - {"locked": bool, "items": {my_id: {rung, name, tier, value}}}
  rarity_spread.html  - color-coded review page, one section per rung
"""
import base64
import json
import os
import re
import sys

DEC = os.path.expanduser("~/brotato-decompiled")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_JSON = os.path.join(HERE, "rarity_spread.json")

# ladder rung -> (label, engine color, dark color) - item_service.gd constants
RUNGS = {
    1: ("White", "#e6e6e6", "#1a1a1a"),
    2: ("Green", "#7adb58", "#0c1a09"),
    3: ("Blue", "#5abeff", "#0f2028"),
    4: ("Teal", "#00d2be", "#041a18"),
    5: ("Purple", "#ad5aff", "#100a1b"),
    6: ("Red", "#ff3b3b", "#240909"),
    7: ("Pink", "#ff69c7", "#210d1a"),
    8: ("Gold", "#ffcd3c", "#211a07"),
}
HOME_RUNG = {0: 1, 1: 3, 2: 5, 3: 6}  # engine tier -> home rung

# within-tier value-quantile split: (fraction, rung) applied low -> high.
# e.g. tier 1: cheapest 15% demote to green, middle 55% stay blue, top 30% promote orange.
SPLITS = {
    0: [(0.60, 1), (0.40, 2)],
    1: [(0.15, 2), (0.55, 3), (0.30, 4)],
    2: [(0.20, 4), (0.55, 5), (0.25, 6)],
    3: [(0.45, 6), (0.35, 7), (0.20, 8)],
}

# ---------- translations (same sources as extract_codex.py) ----------
TR = {}
import csv as _csv
with open(f"{DEC}/.assets/resources/translations/translations.csv", newline="", encoding="utf-8-sig") as f:
    for row in _csv.reader(f):
        if len(row) >= 2:
            TR[row[0]] = row[1]
with open(f"{DEC}/items/custom/custom_translations.csv", newline="") as f:
    for row in _csv.reader(f):
        if len(row) >= 2:
            TR[row[0]] = row[1]


def tr(k):
    return TR.get(k, k.replace("ITEM_", "").replace("_", " ").title())


def props(path):
    d = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^(\w+) = (.*)$", line.strip())
        if m:
            d[m.group(1)] = m.group(2)
    return d


def registered_item_paths():
    src = open(f"{DEC}/singletons/item_service.tscn").read()
    ext = dict(re.findall(r'\[ext_resource path="([^"]+)" type="Resource" id=(\d+)\]', src))
    by_id = {i: p for p, i in ext.items()}
    m = re.search(r"^items = \[ (.*) \]$", src, re.M)
    return [by_id[i] for i in re.findall(r"ExtResource\(\s*(\d+)\s*\)", m.group(1))]


def load_items():
    import glob as _glob
    items = []
    # base+mod items from the registry, plus Abyssal items which register at boot
    # via dlc_1_data rather than item_service.tscn (same source set the codex uses)
    paths = [os.path.join(DEC, r.replace("res://", "")) for r in registered_item_paths()]
    paths += sorted(_glob.glob(f"{DEC}/dlcs/dlc_1/items/*/*_data.tres"))
    for path in paths:
        d = props(path)
        if d.get("can_be_looted", "true") != "true":
            continue
        name_raw = d.get("name", '""').strip('"')
        icon_m = re.search(r'ExtResource\(\s*(\d+)\s*\)', d.get("icon", ""))
        icon_path = None
        if icon_m:
            src = open(path).read()
            em = re.search(r'\[ext_resource path="([^"]+)"[^\]]*id=%s\]' % icon_m.group(1), src)
            if em:
                icon_path = os.path.join(DEC, em.group(1).replace("res://", ""))
        items.append({
            "my_id": d.get("my_id", '""').strip('"'),
            "name": tr(name_raw),
            "tier": int(d.get("tier", "0")),
            "value": int(float(d.get("value", "0"))),
            "max_nb": int(float(d.get("max_nb", "-1"))),
            "icon": icon_path,
        })
    return items


def draft_rungs(items):
    prev = {}
    if os.path.exists(OUT_JSON):
        old = json.load(open(OUT_JSON))
        if old.get("locked"):
            prev = {k: v["rung"] for k, v in old.get("items", {}).items()}
    by_tier = {}
    for it in items:
        by_tier.setdefault(it["tier"], []).append(it)
    for tier, group in by_tier.items():
        group.sort(key=lambda x: (x["value"], x["name"]))
        splits = SPLITS.get(tier, [(1.0, HOME_RUNG.get(tier, 6))])
        n = len(group)
        bounds, acc = [], 0.0
        for frac, rung in splits:
            acc += frac
            bounds.append((round(acc * n), rung))
        idx = 0
        for cut, rung in bounds:
            while idx < max(cut, idx) and idx < n:
                group[idx]["rung"] = rung
                idx += 1
        while idx < n:  # rounding tail joins the top rung
            group[idx]["rung"] = bounds[-1][1]
            idx += 1
    for it in items:
        if it["my_id"] in prev:  # user-locked assignments always win
            it["rung"] = prev[it["my_id"]]
    return items


def b64(path):
    if not path or not os.path.exists(path):
        return ""
    return "data:image/png;base64," + base64.b64encode(open(path, "rb").read()).decode()


def build_html(items):
    secs = []
    for rung in range(8, 0, -1):
        label, col, dark = RUNGS[rung]
        rows = [it for it in items if it["rung"] == rung]
        rows.sort(key=lambda x: (x["tier"], x["value"], x["name"]))
        cells = []
        for it in rows:
            moved = it["rung"] != HOME_RUNG[it["tier"]]
            arrow = ""
            if moved:
                d = "&#8593;" if it["rung"] > HOME_RUNG[it["tier"]] else "&#8595;"
                arrow = f'<span class="mv">{d} T{it["tier"] + 1}</span>'
            uniq = '<span class="uq">&#9670;</span>' if it["max_nb"] == 1 else ""
            sent = (f'<span class="sb">[{it["sent"]}]</span>' if it.get("sent") else "")
            cells.append(
                f'<div class="it" style="border-color:{col};background:{dark}">'
                f'<img src="{b64(it["icon"])}" alt="">'
                f'<div class="nm">{it["name"]}{uniq}</div>'
                f'<div class="sub">{it["value"]}g {arrow}{sent}</div></div>'
            )
        secs.append(
            f'<h2 style="color:{col}">{rung}. {label} <small>({len(rows)} items)</small></h2>'
            f'<div class="grid">{"".join(cells)}</div>'
        )
    counts = {r: sum(1 for i in items if i["rung"] == r) for r in range(1, 9)}
    chips = "".join(
        f'<span class="chip" style="border-color:{RUNGS[r][1]}">'
        f'<b style="color:{RUNGS[r][1]}">{RUNGS[r][0]}</b> {counts[r]}</span>'
        for r in range(1, 9)
    )
    html = f"""<meta charset="utf-8">
<title>P2W Item Rarity Spread (draft)</title>
<style>
/* dark-committed on purpose: these are Brotato's in-game rarity colors and are
   judged against the same dark shop-panel ground they render on in game */
body{{font-family:-apple-system,'Segoe UI',sans-serif;background:#141414;color:#ddd;
     margin:0;padding:2rem clamp(1rem,4vw,3rem);max-width:1240px}}
h1{{font-size:1.35rem;letter-spacing:.01em;margin:0 0 .75rem}}
h1 .draft{{color:#ffcd3c;font-size:.8rem;vertical-align:middle;border:1px solid #ffcd3c;
     border-radius:4px;padding:2px 6px;margin-left:8px;letter-spacing:.08em}}
h2{{margin:2rem 0 .6rem;font-size:1.05rem}} h2 small{{color:#888;font-weight:400}}
.chips{{display:flex;flex-wrap:wrap;gap:6px;margin:.75rem 0}}
.chip{{border:1.5px solid;border-radius:999px;padding:3px 10px;font-size:.78rem;
     font-variant-numeric:tabular-nums;background:#1c1c1c}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px}}
.it{{border:2px solid;border-radius:8px;padding:8px;display:flex;flex-direction:column;
     align-items:center;text-align:center}}
.it img{{width:48px;height:48px;image-rendering:pixelated}}
.nm{{font-size:.8rem;margin-top:4px;text-wrap:balance}}
.sub{{font-size:.72rem;color:#999;font-variant-numeric:tabular-nums}}
.mv{{color:#ffcd3c;font-weight:600}} .uq{{color:#ff69c7;margin-left:3px}}
.sb{{color:#5abeff;margin-left:4px;font-weight:600}}
.note{{background:#1e1e1e;border:1px solid #2c2c2c;border-radius:8px;
     padding:10px 14px;font-size:.85rem;color:#aaa;line-height:1.45}}
</style>
<h1>P2W item rarity spread<span class="draft">DRAFT</span></h1>
<div class="chips">{chips}</div>
<div class="note">Every registered lootable item, assigned to a chest-ladder rung.
Arrows mark promotions/demotions from the item's vanilla tier (shown as T1&ndash;T4);
unmarked items sit at their home rung. &#9670; = unique (max 1 per run). Weapons are
not listed: they already carry real ladder tiers. Tell Claude any item to move;
the table locks only after your approval.</div>
{"".join(secs)}"""
    return html


def main():
    if "--html-only" in sys.argv:
        # rebuild the page from the JSON as-is (e.g. after apply_sentiment --write);
        # never re-drafts, so sentiment moves and hand edits survive
        data = json.load(open(OUT_JSON))
        items = load_items()
        items = [it for it in items if it["my_id"] in data["items"]]
        for it in items:
            rec = data["items"][it["my_id"]]
            it["rung"] = rec["rung"]
            it["sent"] = rec.get("sentiment")
        open(os.path.join(HERE, "rarity_spread.html"), "w").write(build_html(items))
        print(f"page rebuilt from JSON ({len(items)} items)")
        return
    items = draft_rungs(load_items())
    data = {
        "locked": False,
        "ladder": {str(r): RUNGS[r][0] for r in RUNGS},
        "items": {it["my_id"]: {"rung": it["rung"], "name": it["name"],
                                "tier": it["tier"], "value": it["value"]}
                  for it in items},
    }
    json.dump(data, open(OUT_JSON, "w"), indent=1)
    open(os.path.join(HERE, "rarity_spread.html"), "w").write(build_html(items))
    counts = {r: sum(1 for i in items if i["rung"] == r) for r in range(1, 9)}
    print(f"{len(items)} lootable items ->", " ".join(f"{RUNGS[r][0]}:{counts[r]}" for r in range(1, 9)))


if __name__ == "__main__":
    main()
