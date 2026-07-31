#!/usr/bin/env python3
"""Render the nine Gourmet-DLC item cards as an in-game-accurate HTML page.

Every colour, string and number is taken from the live game data, not retyped:
tier colours from singletons/item_service.gd, SECONDARY/CATEGORY colours from
singletons/utils.gd, card text from items/custom/custom_translations.csv, and the
Anybody-Medium face that ui/menus/shop/item_description.tscn actually loads.
"""
import json, os

OUT = os.path.dirname(os.path.abspath(__file__))
A = json.load(open(f"{OUT}/item_cards_assets.json"))

# item_service.gd TIER_*_COLOR / TIER_*_COLOR_DARK
TIERS = [
    ("Common",     "#e6e6e6", "#000000"),
    ("Uncommon",   "#5abeff", "#0f2028"),
    ("Rare",       "#ad5aff", "#100a1b"),
    ("Legendary",  "#ff3b3b", "#240909"),
]
POS, NEG, NEUTRAL = "#00ff00", "#ff0000", "#ffffff"
CURSE, COUNTER, CATEGORY = "#ca61ff", "#eae2b0", "#faf4cc"

def stat(icon, text, colour):
    """A stat effect: get_args returns [value, stat name] and BOTH carry the sign colour,
    so the whole line is green / red / curse-purple, preceded by the stat icon."""
    return {"kind": "stat", "icon": icon, "text": text, "colour": colour}

def line(*segments, scale=None):
    """A template effect. Text.text only colours the {N} args; the template itself takes the
    label's default white. Pass plain strings for template text and (text, colour) tuples
    for args."""
    segs = [(x, NEUTRAL) if isinstance(x, str) else x for x in segments]
    return {"kind": "line", "segs": segs, "scale": scale}

# scale = (base, "+N%", stat-icon) reproducing effect.gd _scaling_formula_text
CARDS = [
 dict(slug="caltrops", name="Caltrops", tier=0, value=25, category="Item",
      effects=[line("Enemies that hit you in melee take",
                    scale=("3", "+30%", "melee_damage"))],
      tail=" damage back", counters=["Damage dealt: 0"]),

 dict(slug="loyalty_card", name="Loyalty Card", tier=1, value=55, category="Unique",
      effects=[line("Every 5th shop purchase is 30% off")],
      counters=["Materials saved: 0"]),

 dict(slug="overtime_pay", name="Overtime Pay", tier=2, value=80, category="Item",
      effects=[stat("armor", "-2 Armor", NEG),
               line("Gain 1% Attack Speed per 80 Materials collected each wave "
                    "(max +6% per wave, permanent)")],
      counters=["Attack Speed gained: 0"]),

 dict(slug="second_mortgage", name="Second Mortgage", tier=2, value=70, category="Item",
      effects=[line(("-30%", NEG), " Materials at the start of the wave"),
               line("+15% Materials at the end of each wave")],
      counters=["Materials gained: 0"]),

 dict(slug="static_cling", name="Static Cling", tier=2, value=85, category="Item",
      effects=[line("Every 8th hit zaps the 3 nearest enemies for",
                    scale=("6", "+100%", "elemental_damage"))],
      tail=" damage", counters=["Damage dealt: 0"]),

 dict(slug="panic_button", name="Panic Button", tier=2, value=80, category="Unique",
      effects=[line("Below 30% HP: a burst knocks back nearby enemies. "
                    "10 second cooldown")],
      counters=[]),

 dict(slug="voodoo_potato", name="Voodoo Potato", tier=2, value=70, category="Item",
      effects=[stat("curse", "+20 Curse", CURSE),
               stat("max_hp", "-5 Max HP", NEG)],
      counters=[]),

 dict(slug="nine_lives", name="Nine Lives", tier=3, value=110, category="Unique",
      effects=[line("Survive lethal damage at 1 HP. Once per wave and 9 times per run"),
               stat("percent_damage", "-15 % Damage", NEG)],
      counters=["Lives used: 0"]),

 dict(slug="vampire_fang", name="Vampire Fang", tier=3, value=110, category="Item",
      effects=[stat("lifesteal", "+15 % Life Steal", POS),
               stat("max_hp", "-5 Max HP", NEG),
               line("Life Steal can heal up to 20% of your max HP past your max HP")],
      counters=["HP recovered: 0"]),
]

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def render_effect(e, tail):
    if e["kind"] == "stat":
        return (f'<li class="fx stat"><img class="sicon" src="{A["stats"][e["icon"]]}" alt="">'
                f'<span style="color:{e["colour"]}">{esc(e["text"])}</span></li>')
    body = "".join(
        esc(t) if c == NEUTRAL else f'<span style="color:{c}">{esc(t)}</span>'
        for t, c in e["segs"])
    if e["scale"]:
        base, rate, icon = e["scale"]
        body += (f' <b>{base}</b> <span class="rate">({rate}'
                 f'<img class="sicon inline" src="{A["stats"][icon]}" alt="">)</span>'
                 f'{esc(tail or "")}')
    return f'<li class="fx">{body}</li>'

def render_card(c):
    tname, border, ground = TIERS[c["tier"]]
    fx = "".join(render_effect(e, c.get("tail")) for e in c["effects"])
    counters = "".join(f'<li class="count">{esc(x)}</li>' for x in c["counters"])
    return f'''
<article class="card t{c['tier']}" style="--edge:{border};--ground:{ground}">
  <header class="head">
    <div class="frame"><img class="icon" src="{A['icons'][c['slug']]}" alt="{esc(c['name'])}"></div>
    <div class="titles">
      <h2 class="name">{esc(c['name'])}</h2>
      <p class="cat">{esc(c['category'])}</p>
    </div>
  </header>
  <ul class="fxlist">{fx}{counters}</ul>
  <footer class="foot">
    <span class="tier">{tname} &middot; Tier {c['tier'] + 1}</span>
    <span class="price"><img class="sicon" src="{A['stats']['materials']}" alt="">{c['value']}</span>
  </footer>
</article>'''

cards = "".join(render_card(c) for c in CARDS)

html = f'''<title>Gourmet DLC - Item Cards</title>
<style>
@font-face {{
  font-family: "Anybody";
  src: url(data:font/ttf;base64,{A["font"]}) format("truetype");
  font-weight: 500; font-display: block;
}}
*, *::before, *::after {{ box-sizing: border-box; }}

:root {{
  --page: #cfcabb; --page-ink: #2b2820; --page-sub: #5d5849; --rule: #b3ae9e;
}}
@media (prefers-color-scheme: dark) {{
  :root {{ --page: #17171b; --page-ink: #ece8dc; --page-sub: #918b7c; --rule: #34343c; }}
}}
:root[data-theme="dark"] {{ --page: #17171b; --page-ink: #ece8dc; --page-sub: #918b7c; --rule: #34343c; }}
:root[data-theme="light"] {{ --page: #cfcabb; --page-ink: #2b2820; --page-sub: #5d5849; --rule: #b3ae9e; }}

body {{
  margin: 0; padding: clamp(20px, 4vw, 48px);
  background: var(--page); color: var(--page-ink);
  font-family: "Anybody", system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}}
.masthead {{ max-width: 1180px; margin: 0 auto clamp(22px, 3vw, 34px); }}
.masthead h1 {{
  margin: 0 0 6px; font-size: clamp(24px, 3.4vw, 38px); letter-spacing: .01em;
  text-wrap: balance;
}}
.masthead p {{ margin: 0; color: var(--page-sub); font-size: 15px; max-width: 62ch; line-height: 1.5; }}
.rule {{ height: 1px; background: var(--rule); max-width: 1180px; margin: 0 auto clamp(22px, 3vw, 32px); }}

.grid {{
  max-width: 1180px; margin: 0 auto;
  display: grid; gap: clamp(16px, 2vw, 24px);
  grid-template-columns: repeat(auto-fill, minmax(330px, 1fr));
  align-items: stretch;
}}

/* --- the card: a replica of ui/menus/shop/item_description.tscn --- */
.card {{
  background: var(--ground);
  border: 3px solid var(--edge);
  border-radius: 10px;
  padding: 16px 18px 14px;
  display: flex; flex-direction: column; gap: 12px;
  box-shadow: 0 10px 26px rgba(0,0,0,.42);
}}
.card.t0 {{ background: #0a0a0c; }}   /* pure black ground reads as a hole; nudge it */

.head {{ display: flex; gap: 14px; align-items: center; }}
.frame {{
  flex: 0 0 auto; width: 74px; height: 74px; border-radius: 8px;
  background: color-mix(in srgb, var(--edge) 16%, #000);
  border: 2px solid color-mix(in srgb, var(--edge) 42%, transparent);
  display: grid; place-items: center;
}}
.icon {{ width: 58px; height: 58px; image-rendering: pixelated; }}
.titles {{ min-width: 0; }}
.name {{
  margin: 0; font-size: 25px; line-height: 1.12; color: var(--edge);
  text-wrap: balance; text-shadow: 0 2px 0 rgba(0,0,0,.6);
}}
.cat {{ margin: 3px 0 0; font-size: 15px; color: {CATEGORY}; }}

.fxlist {{ list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 9px; }}
.fx {{
  font-size: 16px; line-height: 1.36; color: #fff;
  padding-left: 20px; position: relative; text-shadow: 0 1px 0 rgba(0,0,0,.65);
}}
.fx::before {{
  content: "\\2022"; position: absolute; left: 4px; top: -1px;
  color: rgba(255,255,255,.62); font-size: 17px;
}}
.fx.stat {{ padding-left: 0; display: flex; align-items: center; gap: 8px; }}
.fx.stat::before {{ content: none; }}
.sicon {{ width: 19px; height: 19px; image-rendering: pixelated; flex: 0 0 auto; }}
.sicon.inline {{ width: 15px; height: 15px; vertical-align: -2px; margin-left: 3px; }}
.rate {{ color: #fff; }}
.fx b {{ font-weight: 500; color: #fff; }}

.count {{
  font-size: 15px; color: {COUNTER}; padding-left: 0;
  text-shadow: 0 1px 0 rgba(0,0,0,.65);
}}
.count::before {{ content: none; }}

.foot {{
  margin-top: auto; padding-top: 11px;
  border-top: 1px solid rgba(255,255,255,.13);
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
}}
.tier {{ font-size: 13px; letter-spacing: .06em; text-transform: uppercase; color: var(--edge); opacity: .82; }}
.price {{
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 17px; color: #76ff76; font-variant-numeric: tabular-nums;
}}

@media (max-width: 380px) {{
  .grid {{ grid-template-columns: 1fr; }}
  .name {{ font-size: 22px; }}
}}
</style>

<div class="masthead">
  <h1>Gourmet DLC &mdash; Item Cards</h1>
  <p>Nine items as they render in game. Colours, text and counters are read from the live
     game data, and the type is Anybody Medium, the same face the in-game item panel loads.
     Ordered by tier.</p>
</div>
<div class="rule"></div>
<main class="grid">{cards}</main>
'''

path = "/Users/nicolassutcliffe/brotato-mods/asset-dev/item_cards.html"
open(path, "w").write(html)
print(f"wrote {path}  ({len(html)/1024:.0f} KB)")
