#!/usr/bin/env python3
"""Build the Gourmet DLC food/spawner content: spawner items into items/custom/,
FoodData foods into items/foods/, PIL placeholder icons, item_service.tscn
registration (pair i: spawner ext id 840+2i, food 841+2i) and
custom_translations.csv rows. Idempotent: skips registration/rows already present,
regenerates tres+art in place.

Placeholder art only. The later art pass just replaces the PNGs in place.

DEFERRED pairs (add here when their systems land): Ice Cream Truck (structure),
Doggy Bag (ground expiry + Leftovers), Chili Greenhouse (burn application)."""
import os, re, shutil
from PIL import Image, ImageDraw

DEC  = "/Users/nicolassutcliffe/brotato-decompiled"
TSCN = f"{DEC}/singletons/item_service.tscn"
CSV  = f"{DEC}/items/custom/custom_translations.csv"
BASE_ID = 840  # 826-839 belong to build_appetite_items.py

FRUIT_WAVS = [f"res://items/consumables/fruit/comedy_bite_chew_0{i}.wav" for i in (1, 2, 3)]

# SPAWNERS[i] pairs with FOODS[i]. spawn_effect = (custom_key, value=foods per fire).
# The effect's key is always the paired food's my_id.
SPAWNERS = [
 dict(slug="espresso_machine", max_nb=2, name="Espresso Machine", tier=1, value=50,
      tags=["food", "stat_attack_speed"], trigger="wave_start_foods", count=2,
      text_key="EFFECT_ESPRESSO_MACHINE"),
 dict(slug="butchers_hook", max_nb=3, name="Butcher's Hook", tier=2, value=80,
      tags=["food", "stat_percent_damage"], trigger="kill_foods", count=1,
      text_key="EFFECT_BUTCHERS_HOOK"),
 dict(slug="bakers_oven", max_nb=3, name="Baker's Oven", tier=1, value=45,
      tags=["food", "stat_max_hp"], trigger="level_up_foods", count=1,
      text_key="EFFECT_BAKERS_OVEN"),
 dict(slug="beehive", max_nb=3, name="Beehive", tier=1, value=55,
      tags=["food", "structure", "stat_hp_regeneration"], count=1,
      structure=dict(scene="res://entities/structures/turret/beehive/beehive.tscn", stats="res://entities/structures/turret/beehive/beehive_stats.tres"),
      text_key="EFFECT_BEEHIVE"),
 dict(slug="wok_station", max_nb=3, name="Wok Station", tier=2, value=70,
      tags=["food", "stat_attack_speed"], trigger="burning_kill_foods", count=1,
      anchor_structure=dict(scene="res://entities/structures/turret/wok_station/wok_station.tscn", stats="res://entities/structures/turret/food_stand_stats.tres"),
      text_key="EFFECT_WOK_STATION"),
 dict(slug="popcorn_machine", max_nb=3, name="Popcorn Machine", tier=1, value=50,
      tags=["food", "stat_dodge"], trigger="explosion_foods", count=1,
      text_key="EFFECT_POPCORN_MACHINE"),
 dict(slug="deep_fryer", max_nb=4, name="Deep Fryer", tier=1, value=55,
      tags=["food", "stat_speed"], trigger="material_foods", count=1,
      text_key="EFFECT_DEEP_FRYER"),
 dict(slug="sushi_bar", max_nb=3, name="Sushi Bar", tier=2, value=85,
      tags=["food", "stat_crit_chance"], trigger="crit_foods", count=1,
      text_key="EFFECT_SUSHI_BAR"),
 dict(slug="grandmas_cookbook", max_nb=3, name="Grandma's Cookbook", tier=0, value=25,
      tags=["food", "stat_armor"], trigger="damage_taken_foods", count=1,
      text_key="EFFECT_GRANDMAS_COOKBOOK"),
 dict(slug="pizza_delivery", max_nb=4, name="Pizza Delivery", tier=0, value=20,
      tags=["food", "stat_percent_damage"], trigger="mid_wave_foods", count=1,
      text_key="EFFECT_PIZZA_DELIVERY"),
 dict(slug="victory_feast", max_nb=3, name="Victory Feast", tier=2, value=80,
      tags=["food"], trigger="elite_kill_foods", count=1,
      text_key="EFFECT_VICTORY_FEAST"),
 dict(slug="street_vendor", max_nb=3, name="Street Vendor", tier=0, value=22,
      tags=["food", "stat_percent_damage"], trigger="random_times_foods", count=1,
      anchor_structure=dict(scene="res://entities/structures/turret/street_vendor/street_vendor.tscn", stats="res://entities/structures/turret/food_stand_stats.tres"),
      text_key="EFFECT_STREET_VENDOR"),
 dict(slug="fondue_set", max_nb=3, name="Fondue Set", tier=1, value=50,
      tags=["food", "stat_armor"], trigger="standstill_timer_foods", count=1,
      text_key="EFFECT_FONDUE_SET"),
 dict(slug="gym_membership", max_nb=3, name="Gym Membership", tier=1, value=45,
      tags=["food", "stat_speed"], trigger="step_foods", count=1,
      text_key="EFFECT_GYM_MEMBERSHIP"),
 dict(slug="fancy_restaurant", max_nb=2, name="Fancy Restaurant", tier=3, value=95,
      tags=["food", "structure", "stat_dodge"], count=1,
      structure=dict(scene="res://entities/structures/turret/fancy_restaurant/fancy_restaurant.tscn", stats="res://entities/structures/turret/fancy_restaurant/fancy_restaurant_stats.tres"),
      text_key="EFFECT_FANCY_RESTAURANT"),
 dict(slug="farmers_market", max_nb=2, name="Farmers' Market", tier=1, value=60,
      tags=["food", "stat_harvesting"], trigger="reroll_banked_foods", count=1,
      anchor_structure=dict(scene="res://entities/structures/turret/farmers_market/farmers_market.tscn", stats="res://entities/structures/turret/food_stand_stats.tres"),
      text_key="EFFECT_FARMERS_MARKET",
      tracking_text="GOURMET_HARVESTING_GAINED"),  # fruit salad perma-harvesting counter
 dict(slug="after_dinner_mints", name="After-Dinner Mints", tier=2, value=75,
      tags=["food"], trigger="consumable_count_foods", count=1, max_nb=2,
      text_key="EFFECT_AFTER_DINNER_MINTS"),
 dict(slug="chili_greenhouse", max_nb=3, name="Chili Greenhouse", tier=2, value=75,
      tags=["food", "stat_elemental_damage"], trigger="burning_tick_foods", count=1,
      anchor_structure=dict(scene="res://entities/structures/turret/chili_greenhouse/chili_greenhouse.tscn", stats="res://entities/structures/turret/food_stand_stats.tres"),
      text_key="EFFECT_CHILI_GREENHOUSE"),
 dict(slug="doggy_bag", name="Doggy Bag", tier=2, value=70,
      tags=["food"], sum_key="doggy_bag", count=1, max_nb=2,
      tracking_text="DOGGY_BAG_LEFTOVERS", text_key="EFFECT_DOGGY_BAG"),
 dict(slug="ice_cream_truck", max_nb=2, name="Ice Cream Truck", tier=3, value=100,
      tags=["food", "structure", "stat_attack_speed"], count=1,
      structure=dict(scene="res://entities/structures/turret/ice_cream_truck/ice_cream_truck.tscn",
                     stats="res://entities/structures/turret/ice_cream_truck/ice_cream_truck_stats.tres"),
      text_key="EFFECT_ICE_CREAM_TRUCK"),
]

def food(slug, name, text_key, buff=(), dur=0, dur_app=0.0, stacks=True, cap=0,
         stack_cap=20, wave=(), perm=(), heal=0.0, heal_app=0.0, special="", tracking_item=""):
    # tracking_item: my_id of the item credited on its card for perm gains
    # (vanilla perma-stat tracking rule; key must be in init_tracked_items)
    # stack_cap: max times the buff can stack (count, ceiling 20; strong foods lower)
    return dict(slug=slug, my_id=f"consumable_food_{slug}", name=name,
                text_key=text_key, buff=buff, dur=dur, dur_app=dur_app,
                stacks=stacks, cap=cap, stack_cap=stack_cap, wave=wave, perm=perm, heal=heal,
                heal_app=heal_app, special=special, tracking_item=tracking_item)

FOODS = [
 food("espresso", "Espresso", "EFFECT_FOOD_ESPRESSO",
      buff=[("stat_attack_speed", 10, 0.2)], dur=6, stack_cap=15),
 food("steak", "Steak", "EFFECT_FOOD_STEAK",
      buff=[("stat_percent_damage", 8, 0.25)], dur=5, stack_cap=15),
 food("cake_slice", "Cake Slice", "EFFECT_FOOD_CAKE_SLICE",
      heal=2, heal_app=0.1, wave=[("stat_max_hp", 2, 0)]),
 food("honey_drop", "Honey Drop", "EFFECT_FOOD_HONEY_DROP",
      wave=[("stat_hp_regeneration", 2, 0.1)]),
 food("fried_rice", "Fried Rice", "EFFECT_FOOD_FRIED_RICE",
      buff=[("stat_attack_speed", 4, 0.15)], dur=6),
 food("popcorn", "Popcorn", "EFFECT_FOOD_POPCORN",
      buff=[("stat_dodge", 2, 0.1)], dur=5, cap=20),
 food("fries", "Fries", "EFFECT_FOOD_FRIES",
      buff=[("stat_speed", 4, 0.1)], dur=5),
 food("sushi_roll", "Sushi Roll", "EFFECT_FOOD_SUSHI_ROLL",
      buff=[("stat_crit_chance", 4, 0.15)], dur=6),
 food("warm_cookie", "Warm Cookie", "EFFECT_FOOD_WARM_COOKIE",
      heal=1, buff=[("stat_armor", 1, 0.1)], dur=6),
 food("pizza_slice", "Pizza Slice", "EFFECT_FOOD_PIZZA_SLICE",
      buff=[("stat_percent_damage", 3, 0), ("stat_speed", 3, 0)], dur=10, dur_app=0.1),
 food("golden_apple", "Golden Apple", "EFFECT_FOOD_GOLDEN_APPLE",
      heal=5, heal_app=0.2, dur=10, special="golden_apple"),
 food("mystery_meat", "Mystery Meat", "EFFECT_FOOD_MYSTERY_MEAT",
      buff=[("stat_percent_damage", 10, 0.3)], dur=8, stack_cap=15, special="mystery_meat"),
 food("cheese_cube", "Cheese Cube", "EFFECT_FOOD_CHEESE_CUBE",
      buff=[("stat_armor", 2, 0.15)], dur=4),
 food("protein_shake", "Protein Shake", "EFFECT_FOOD_PROTEIN_SHAKE",
      buff=[("stat_speed", 4, 0.1), ("stat_melee_damage", 2, 0.1)], dur=6),
 food("escargot", "Escargot", "EFFECT_FOOD_ESCARGOT",
      buff=[("stat_dodge", 3, 0.15)], dur=8, stack_cap=12, special="escargot"),
 food("fruit_salad", "Fruit Salad", "EFFECT_FOOD_FRUIT_SALAD",
      heal=4, heal_app=0.2, perm=[("stat_harvesting", 1)],
      tracking_item="item_farmers_market"),
 food("mint", "Mint", "EFFECT_FOOD_MINT", special="mint"),
 food("chili_pepper", "Chili Pepper", "EFFECT_FOOD_CHILI_PEPPER",
      buff=[("chili_burn", 3, 0.1)], dur=4, stacks=False, special="chili"),
 food("leftovers", "Leftovers", "EFFECT_FOOD_LEFTOVERS", special="leftovers"),
 food("ice_cream", "Ice Cream", "EFFECT_FOOD_ICE_CREAM",
      buff=[("stat_attack_speed", 2, 0.2)], dur=4),
]

CSV_ROWS = [
 ("EFFECT_ESPRESSO_MACHINE", "Spawns 2 Espressos at the start of each wave"),
 ("EFFECT_FOOD_ESPRESSO", "Eating grants +{0}% ({1}) Attack Speed for 6 seconds. Stacks"),
 ("EFFECT_BUTCHERS_HOOK", "Spawns a Steak every 40 kills"),
 ("EFFECT_FOOD_STEAK", "Eating grants +{0}% ({1}) Damage for 5 seconds. Stacks"),
 ("EFFECT_BAKERS_OVEN", "Spawns a Cake Slice on every level up"),
 ("EFFECT_FOOD_CAKE_SLICE", "Eating heals {1} HP ({2}) and grants +{0} Max HP until the end of the wave"),
 ("EFFECT_BEEHIVE", "Places a Beehive that drips a Honey Drop every {0} seconds"),
 ("EFFECT_FOOD_HONEY_DROP", "Eating grants +{0} ({1}) HP Regeneration until the end of the wave. Stacks"),
 ("EFFECT_WOK_STATION", "Serves a Fried Rice at the wok every 8 enemies that die burning"),
 ("EFFECT_FOOD_FRIED_RICE", "Eating grants +{0}% ({1}) Attack Speed for 6 seconds. Stacks"),
 ("EFFECT_POPCORN_MACHINE", "Spawns a Popcorn for every explosion you cause"),
 ("EFFECT_FOOD_POPCORN", "Eating grants +{0}% ({1}) Dodge for 5 seconds. Stacks up to +20%"),
 ("EFFECT_DEEP_FRYER", "Spawns a Fries every 30 materials you collect"),
 ("EFFECT_FOOD_FRIES", "Eating grants +{0}% ({1}) Speed for 5 seconds. Stacks"),
 ("EFFECT_SUSHI_BAR", "Spawns a Sushi Roll every 12 critical hits"),
 ("EFFECT_FOOD_SUSHI_ROLL", "Eating grants +{0}% ({1}) Crit Chance for 6 seconds. Stacks"),
 ("EFFECT_GRANDMAS_COOKBOOK", "Spawns a Warm Cookie when you take damage (2 second cooldown)"),
 ("EFFECT_FOOD_WARM_COOKIE", "Eating heals {2} HP and grants +{0} ({1}) Armor for 6 seconds. Stacks"),
 ("EFFECT_PIZZA_DELIVERY", "Delivers a Pizza Slice somewhere mid-wave"),
 ("EFFECT_FOOD_PIZZA_SLICE", "Eating grants +{0}% Damage and +{1}% Speed for {2} ({3}) seconds"),
 ("EFFECT_VICTORY_FEAST", "Spawns a Golden Apple when an elite or a boss dies"),
 ("EFFECT_FOOD_GOLDEN_APPLE", "Eating heals {0} HP ({1}) and grants +8% to a random stat for 10 seconds"),
 ("EFFECT_STREET_VENDOR", "A Mystery Meat shows up at the cart 1 to 3 times per wave"),
 ("EFFECT_FOOD_MYSTERY_MEAT", "Eating grants +{0}% ({1}) Damage for 8 seconds half the time. Otherwise you lose 2 HP"),
 ("EFFECT_FONDUE_SET", "Spawns a Cheese Cube every 3 seconds you stand still"),
 ("EFFECT_FOOD_CHEESE_CUBE", "Eating grants +{0} ({1}) Armor for 4 seconds. Stacks"),
 ("EFFECT_GYM_MEMBERSHIP", "Spawns a Protein Shake every 200 steps"),
 ("EFFECT_FOOD_PROTEIN_SHAKE", "Eating grants +{0}% ({1}) Speed and +{2} ({3}) Melee Damage for 6 seconds. Stacks"),
 ("EFFECT_FANCY_RESTAURANT", "Places a restaurant that serves an Escargot every {0} seconds to nearby players at full HP"),
 ("EFFECT_FOOD_ESCARGOT", "Eating grants +{0}% ({1}) Dodge for 8 seconds. Stacks"),
 ("EFFECT_FARMERS_MARKET", "Banks every shop reroll as a Fruit Salad served at the stall next wave"),
 ("EFFECT_FOOD_FRUIT_SALAD", "Eating heals {0} HP ({1}) and grants +1 Harvesting permanently"),
 ("EFFECT_AFTER_DINNER_MINTS", "Spawns a Mint every 5 consumables you pick up"),
 ("EFFECT_FOOD_MINT", "Eating refreshes all your active food buffs to their full duration"),
 ("GOURMET_APPETITE_GAINED", "Appetite gained: {0}"),
 ("EFFECT_CHILI_GREENHOUSE", "Grows a Chili Pepper at the greenhouse every 10 burning ticks you deal"),
 ("EFFECT_FOOD_CHILI_PEPPER", "Eating makes your attacks burn enemies for 4 seconds. Burns deal {0} ({1}) damage plus 30% Elemental Damage"),
 ("EFFECT_DOGGY_BAG", "Food that expires uneaten becomes a Leftover granting +1% Damage every following wave. Stacks endlessly"),
 ("EFFECT_FOOD_LEFTOVERS", "Each banked Leftover grants +1% Damage for the wave"),
 ("EFFECT_ICE_CREAM_TRUCK", "Places a truck that serves an Ice Cream every {0} seconds to nearby players"),
 ("EFFECT_FOOD_ICE_CREAM", "Eating grants +{0}% ({1}) Attack Speed for 4 seconds. Stacks"),
 ("DOGGY_BAG_LEFTOVERS", "Leftovers banked: {0}"),
]


# ---------- placeholder art (PIL colored shapes with bold outlines) ----------

OUTLINE = (20, 16, 12, 255)

def canvas(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

# ---- spawner items, 96x96 ----

def art_espresso_machine(d):
    d.rectangle([58, 40, 74, 82], fill=(52, 54, 62, 255), outline=OUTLINE, width=4)
    d.rounded_rectangle([24, 6, 72, 22], radius=5, fill=(176, 182, 196, 255), outline=OUTLINE, width=4)
    d.rounded_rectangle([20, 18, 76, 48], radius=6, fill=(72, 74, 86, 255), outline=OUTLINE, width=4)
    d.ellipse([60, 26, 70, 36], fill=(240, 196, 80, 255), outline=OUTLINE, width=3)
    d.ellipse([26, 26, 36, 36], fill=(196, 60, 48, 255), outline=OUTLINE, width=3)
    d.rectangle([42, 48, 54, 58], fill=(120, 124, 138, 255), outline=OUTLINE, width=3)
    d.rectangle([34, 60, 62, 78], fill=(196, 60, 48, 255), outline=OUTLINE, width=4)
    d.rounded_rectangle([16, 78, 80, 90], radius=4, fill=(52, 54, 62, 255), outline=OUTLINE, width=4)

def art_butchers_hook(d):
    d.rounded_rectangle([22, 10, 74, 86], radius=6, fill=(150, 104, 66, 255), outline=OUTLINE, width=4)
    d.rectangle([44, 14, 52, 34], fill=(168, 174, 186, 255), outline=OUTLINE, width=3)
    d.arc([30, 28, 66, 72], start=300, end=180, fill=(168, 174, 186, 255), width=9)
    d.arc([30, 28, 66, 72], start=300, end=180, fill=OUTLINE, width=3)
    d.polygon([(30, 52), (22, 62), (34, 62)], fill=(168, 174, 186, 255), outline=OUTLINE)

def art_bakers_oven(d):
    d.rounded_rectangle([14, 18, 82, 84], radius=6, fill=(96, 88, 96, 255), outline=OUTLINE, width=4)
    d.rectangle([22, 26, 74, 38], fill=(60, 54, 60, 255), outline=OUTLINE, width=3)
    d.rounded_rectangle([22, 44, 74, 76], radius=4, fill=(238, 200, 120, 255), outline=OUTLINE, width=4)
    d.rectangle([28, 50, 68, 70], fill=(210, 140, 60, 255), outline=OUTLINE, width=3)
    d.line([30, 60, 66, 60], fill=OUTLINE, width=3)

def art_beehive(d):
    d.ellipse([24, 12, 72, 36], fill=(232, 176, 72, 255), outline=OUTLINE, width=4)
    d.ellipse([18, 28, 78, 56], fill=(240, 190, 88, 255), outline=OUTLINE, width=4)
    d.ellipse([24, 48, 72, 76], fill=(232, 176, 72, 255), outline=OUTLINE, width=4)
    d.ellipse([40, 58, 56, 74], fill=(60, 44, 24, 255), outline=OUTLINE, width=3)
    d.ellipse([64, 66, 76, 78], fill=(240, 200, 60, 255), outline=OUTLINE, width=3)
    d.line([66, 72, 74, 72], fill=OUTLINE, width=2)

def art_wok_station(d):
    d.polygon([(14, 40), (82, 40), (68, 64), (28, 64)], fill=(58, 60, 70, 255), outline=OUTLINE)
    d.ellipse([14, 32, 82, 48], fill=(84, 88, 100, 255), outline=OUTLINE, width=4)
    d.rectangle([82, 34, 94, 42], fill=(150, 104, 66, 255), outline=OUTLINE, width=3)
    for x in (30, 46, 62):
        d.polygon([(x, 84), (x + 6, 68), (x + 12, 84)], fill=(240, 140, 48, 255), outline=OUTLINE)

def art_popcorn_machine(d):
    d.rectangle([22, 40, 74, 86], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    for x in range(28, 72, 12):
        d.rectangle([x, 44, x + 6, 82], fill=(238, 234, 224, 255), outline=OUTLINE, width=2)
    d.rectangle([18, 14, 78, 42], fill=(196, 220, 232, 255), outline=OUTLINE, width=4)
    for x, y in ((28, 24), (42, 18), (56, 26), (36, 32), (52, 34)):
        d.ellipse([x, y, x + 10, y + 10], fill=(244, 224, 130, 255), outline=OUTLINE, width=2)

def art_deep_fryer(d):
    d.rounded_rectangle([14, 30, 82, 82], radius=6, fill=(160, 166, 178, 255), outline=OUTLINE, width=4)
    d.rectangle([22, 38, 74, 60], fill=(230, 178, 62, 255), outline=OUTLINE, width=3)
    for x in range(28, 72, 10):
        d.line([x, 40, x, 58], fill=OUTLINE, width=2)
    d.line([30, 30, 42, 14], fill=OUTLINE, width=5)
    d.rectangle([38, 8, 52, 18], fill=(58, 60, 70, 255), outline=OUTLINE, width=3)
    d.rectangle([22, 66, 74, 76], fill=(58, 60, 70, 255), outline=OUTLINE, width=3)

def art_sushi_bar(d):
    d.rectangle([12, 52, 84, 70], fill=(92, 66, 46, 255), outline=OUTLINE, width=4)
    d.rectangle([18, 70, 78, 84], fill=(70, 50, 36, 255), outline=OUTLINE, width=4)
    d.ellipse([22, 40, 74, 58], fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    for x in (30, 52):
        d.ellipse([x, 30, x + 16, 46], fill=(46, 60, 46, 255), outline=OUTLINE, width=3)
        d.ellipse([x + 4, 34, x + 12, 42], fill=(240, 140, 110, 255), outline=OUTLINE, width=2)

def art_grandmas_cookbook(d):
    d.rounded_rectangle([18, 14, 78, 84], radius=5, fill=(150, 82, 70, 255), outline=OUTLINE, width=4)
    d.rectangle([24, 20, 34, 78], fill=(120, 62, 54, 255), outline=OUTLINE, width=3)
    d.rounded_rectangle([40, 30, 70, 56], radius=4, fill=(238, 230, 210, 255), outline=OUTLINE, width=3)
    d.ellipse([48, 36, 54, 42], fill=(196, 60, 48, 255))
    d.ellipse([56, 36, 62, 42], fill=(196, 60, 48, 255))
    d.polygon([(48, 42), (62, 42), (55, 50)], fill=(196, 60, 48, 255))

def art_pizza_delivery(d):
    d.polygon([(14, 52), (82, 52), (74, 30), (22, 30)], fill=(222, 74, 56, 255), outline=OUTLINE)
    d.rectangle([14, 52, 82, 70], fill=(238, 224, 196, 255), outline=OUTLINE, width=4)
    d.rectangle([14, 70, 82, 78], fill=(222, 74, 56, 255), outline=OUTLINE, width=3)
    d.ellipse([38, 34, 58, 50], fill=(238, 224, 196, 255), outline=OUTLINE, width=3)
    d.polygon([(44, 46), (52, 38), (52, 46)], fill=(222, 74, 56, 255))

def art_victory_feast(d):
    d.ellipse([14, 62, 82, 82], fill=(176, 182, 196, 255), outline=OUTLINE, width=4)
    d.pieslice([22, 22, 74, 74], start=180, end=360, fill=(196, 202, 216, 255), outline=OUTLINE, width=4)
    d.line([22, 48, 74, 48], fill=OUTLINE, width=4)
    d.ellipse([44, 12, 52, 20], fill=(240, 196, 80, 255), outline=OUTLINE, width=3)
    d.line([48, 20, 48, 26], fill=OUTLINE, width=3)

def art_street_vendor(d):
    for i, x in enumerate(range(16, 80, 16)):
        color = (222, 74, 56, 255) if i % 2 == 0 else (238, 234, 224, 255)
        d.rectangle([x, 14, x + 16, 30], fill=color, outline=OUTLINE, width=3)
    d.rectangle([20, 30, 76, 62], fill=(150, 104, 66, 255), outline=OUTLINE, width=4)
    d.rectangle([28, 38, 68, 50], fill=(96, 70, 46, 255), outline=OUTLINE, width=3)
    d.ellipse([26, 62, 42, 78], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    d.ellipse([54, 62, 70, 78], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)

def art_fondue_set(d):
    d.ellipse([24, 26, 72, 58], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    d.rectangle([24, 26, 72, 42], fill=(238, 214, 130, 255), outline=OUTLINE, width=3)
    for x in (34, 48, 62):
        d.ellipse([x - 3, 40, x + 3, 52], fill=(238, 214, 130, 255), outline=OUTLINE, width=2)
    d.rectangle([42, 58, 54, 70], fill=(58, 60, 70, 255), outline=OUTLINE, width=3)
    d.polygon([(42, 86), (48, 70), (54, 86)], fill=(240, 140, 48, 255), outline=OUTLINE)

def art_gym_membership(d):
    d.rectangle([30, 44, 66, 52], fill=(120, 124, 138, 255), outline=OUTLINE, width=3)
    for x in (14, 70):
        d.rounded_rectangle([x, 28, x + 12, 68], radius=3, fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    for x in (26, 62):
        d.rounded_rectangle([x, 34, x + 8, 62], radius=3, fill=(84, 88, 100, 255), outline=OUTLINE, width=3)

def art_fancy_restaurant(d):
    d.ellipse([12, 66, 84, 84], fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.pieslice([20, 26, 76, 78], start=180, end=360, fill=(200, 206, 220, 255), outline=OUTLINE, width=4)
    d.ellipse([44, 18, 52, 26], fill=(200, 206, 220, 255), outline=OUTLINE, width=3)
    d.line([70, 16, 78, 24], fill=(240, 196, 80, 255), width=4)
    d.line([78, 16, 70, 24], fill=(240, 196, 80, 255), width=4)

def art_farmers_market(d):
    for i, x in enumerate(range(10, 90, 16)):
        color = (104, 160, 88, 255) if i % 2 == 0 else (238, 234, 224, 255)
        d.rectangle([x, 12, x + 16, 30], fill=color, outline=OUTLINE, width=3)
    d.rectangle([20, 42, 76, 78], fill=(150, 104, 66, 255), outline=OUTLINE, width=4)
    d.line([20, 54, 76, 54], fill=OUTLINE, width=3)
    for x, c in ((28, (200, 56, 48)), (44, (240, 196, 80)), (60, (104, 160, 88))):
        d.ellipse([x, 32, x + 12, 44], fill=c + (255,), outline=OUTLINE, width=3)

def art_after_dinner_mints(d):
    d.rounded_rectangle([16, 34, 80, 74], radius=8, fill=(90, 150, 120, 255), outline=OUTLINE, width=4)
    d.rectangle([16, 44, 80, 52], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    for x in (28, 46, 64):
        d.ellipse([x - 8, 16, x + 8, 32], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
        d.arc([x - 6, 18, x + 6, 30], start=300, end=120, fill=(120, 190, 150, 255), width=4)

# ---- foods, 80x80 ----

def art_espresso(d):
    d.ellipse([12, 56, 68, 72], fill=(214, 214, 222, 255), outline=OUTLINE, width=4)
    d.rectangle([22, 34, 58, 62], fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.ellipse([24, 30, 56, 42], fill=(94, 58, 32, 255), outline=OUTLINE, width=4)
    d.arc([54, 40, 72, 58], start=270, end=90, fill=OUTLINE, width=5)
    for x in (30, 44):
        d.arc([x, 8, x + 8, 20], start=90, end=270, fill=(196, 196, 208, 255), width=4)
        d.arc([x + 4, 16, x + 12, 28], start=270, end=90, fill=(196, 196, 208, 255), width=4)

def art_steak(d):
    d.ellipse([10, 22, 66, 60], fill=(158, 74, 58, 255), outline=OUTLINE, width=4)
    d.ellipse([20, 30, 56, 52], fill=(196, 104, 84, 255), outline=OUTLINE, width=3)
    d.ellipse([58, 30, 74, 46], fill=(238, 230, 210, 255), outline=OUTLINE, width=4)
    d.ellipse([63, 35, 69, 41], fill=(158, 74, 58, 255), outline=OUTLINE, width=2)

def art_cake_slice(d):
    d.polygon([(14, 62), (66, 62), (40, 18)], fill=(238, 200, 120, 255), outline=OUTLINE)
    d.polygon([(24, 46), (56, 46), (40, 18)], fill=(238, 150, 170, 255), outline=OUTLINE)
    d.rectangle([14, 62, 66, 70], fill=(150, 104, 66, 255), outline=OUTLINE, width=3)
    d.ellipse([34, 8, 46, 20], fill=(200, 56, 48, 255), outline=OUTLINE, width=3)

def art_honey_drop(d):
    d.polygon([(40, 8), (62, 44), (18, 44)], fill=(240, 176, 60, 255), outline=OUTLINE)
    d.ellipse([16, 30, 64, 72], fill=(240, 176, 60, 255), outline=OUTLINE, width=4)
    d.polygon([(40, 12), (58, 42), (22, 42)], fill=(240, 176, 60, 255))
    d.ellipse([28, 44, 40, 56], fill=(248, 208, 120, 255))

def art_fried_rice(d):
    d.pieslice([10, 34, 70, 78], start=0, end=180, fill=(84, 88, 100, 255), outline=OUTLINE, width=4)
    d.ellipse([14, 26, 66, 46], fill=(238, 234, 224, 255), outline=OUTLINE, width=4)
    for x, y, c in ((24, 30, (240, 140, 48)), (38, 26, (104, 160, 88)), (50, 32, (240, 196, 80))):
        d.ellipse([x, y, x + 7, y + 7], fill=c + (255,), outline=OUTLINE, width=2)

def art_popcorn(d):
    d.polygon([(20, 34), (60, 34), (56, 72), (24, 72)], fill=(200, 56, 48, 255), outline=OUTLINE)
    for x in (28, 40):
        d.rectangle([x, 36, x + 6, 70], fill=(238, 234, 224, 255), outline=OUTLINE, width=2)
    for x, y in ((18, 20), (32, 12), (46, 18), (26, 26), (42, 26)):
        d.ellipse([x, y, x + 13, y + 13], fill=(244, 224, 130, 255), outline=OUTLINE, width=3)

def art_fries(d):
    for i, x in enumerate((24, 33, 42, 51)):
        y = 12 if i % 2 == 0 else 18
        d.rectangle([x, y, x + 7, 48], fill=(240, 196, 80, 255), outline=OUTLINE, width=3)
    d.polygon([(16, 36), (64, 36), (58, 72), (22, 72)], fill=(200, 56, 48, 255), outline=OUTLINE)

def art_sushi_roll(d):
    d.ellipse([14, 14, 66, 66], fill=(46, 60, 46, 255), outline=OUTLINE, width=4)
    d.ellipse([24, 24, 56, 56], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    d.ellipse([33, 33, 47, 47], fill=(240, 140, 110, 255), outline=OUTLINE, width=3)

def art_warm_cookie(d):
    d.ellipse([12, 12, 68, 68], fill=(210, 160, 96, 255), outline=OUTLINE, width=4)
    for x, y in ((26, 26), (44, 22), (52, 42), (28, 46), (40, 54)):
        d.ellipse([x, y, x + 9, y + 9], fill=(92, 58, 38, 255), outline=OUTLINE, width=2)

def art_pizza_slice(d):
    d.polygon([(12, 20), (68, 20), (40, 70)], fill=(238, 200, 120, 255), outline=OUTLINE)
    d.rectangle([12, 12, 68, 24], fill=(210, 140, 60, 255), outline=OUTLINE, width=3)
    for x, y in ((28, 30), (44, 28), (36, 44)):
        d.ellipse([x, y, x + 11, y + 11], fill=(200, 56, 48, 255), outline=OUTLINE, width=3)

def art_golden_apple(d):
    d.ellipse([16, 22, 64, 70], fill=(240, 196, 80, 255), outline=OUTLINE, width=4)
    d.rectangle([38, 12, 44, 26], fill=(92, 58, 38, 255), outline=OUTLINE, width=2)
    d.ellipse([44, 10, 60, 22], fill=(104, 160, 88, 255), outline=OUTLINE, width=3)
    d.ellipse([26, 32, 38, 44], fill=(248, 220, 130, 255))

def art_mystery_meat(d):
    d.line([40, 30, 40, 74], fill=(150, 104, 66, 255), width=6)
    d.line([40, 30, 40, 74], fill=OUTLINE, width=2)
    d.polygon([(20, 16), (58, 12), (66, 34), (52, 50), (24, 46)], fill=(148, 110, 130, 255), outline=OUTLINE)
    d.ellipse([32, 22, 44, 34], fill=(120, 86, 104, 255), outline=OUTLINE, width=2)

def art_cheese_cube(d):
    d.polygon([(12, 60), (68, 60), (68, 34), (12, 20)], fill=(240, 196, 80, 255), outline=OUTLINE)
    d.polygon([(12, 20), (68, 34), (68, 26), (24, 14)], fill=(248, 220, 130, 255), outline=OUTLINE)
    for x, y, r in ((26, 38, 6), (46, 46, 5), (56, 38, 4)):
        d.ellipse([x, y, x + r * 2, y + r * 2], fill=(210, 160, 60, 255), outline=OUTLINE, width=2)

def art_protein_shake(d):
    d.rounded_rectangle([24, 26, 56, 72], radius=6, fill=(90, 150, 120, 255), outline=OUTLINE, width=4)
    d.rectangle([28, 14, 52, 28], fill=(58, 60, 70, 255), outline=OUTLINE, width=3)
    d.rectangle([36, 6, 44, 16], fill=(58, 60, 70, 255), outline=OUTLINE, width=3)
    d.line([28, 44, 52, 44], fill=OUTLINE, width=3)
    d.line([28, 56, 52, 56], fill=OUTLINE, width=3)

def art_escargot(d):
    d.ellipse([18, 18, 66, 66], fill=(210, 160, 96, 255), outline=OUTLINE, width=4)
    d.arc([26, 26, 58, 58], start=0, end=300, fill=OUTLINE, width=4)
    d.arc([34, 34, 50, 50], start=60, end=360, fill=OUTLINE, width=3)
    d.ellipse([10, 54, 34, 70], fill=(178, 130, 80, 255), outline=OUTLINE, width=3)

def art_fruit_salad(d):
    d.pieslice([10, 36, 70, 78], start=0, end=180, fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    for x, y, c in ((16, 28, (200, 56, 48)), (30, 22, (240, 196, 80)), (44, 26, (104, 160, 88)), (54, 32, (240, 140, 48))):
        d.ellipse([x, y, x + 14, y + 14], fill=c + (255,), outline=OUTLINE, width=3)

def art_mint(d):
    d.ellipse([16, 16, 64, 64], fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.arc([22, 22, 58, 58], start=300, end=60, fill=(120, 190, 150, 255), width=6)
    d.arc([22, 22, 58, 58], start=120, end=240, fill=(120, 190, 150, 255), width=6)
    d.ellipse([32, 32, 48, 48], fill=(120, 190, 150, 255), outline=OUTLINE, width=3)

def art_chili_greenhouse(d):
    d.polygon([(14, 44), (48, 14), (82, 44)], fill=(196, 220, 232, 255), outline=OUTLINE)
    d.rectangle([18, 44, 78, 84], fill=(196, 220, 232, 255), outline=OUTLINE, width=4)
    d.line([48, 16, 48, 82], fill=OUTLINE, width=3)
    d.line([20, 62, 76, 62], fill=OUTLINE, width=3)
    for x, y in ((28, 68), (42, 72), (58, 66), (66, 74)):
        d.ellipse([x, y, x + 9, y + 9], fill=(200, 56, 48, 255), outline=OUTLINE, width=2)

def art_doggy_bag(d):
    d.polygon([(24, 30), (72, 30), (78, 86), (18, 86)], fill=(178, 130, 80, 255), outline=OUTLINE)
    d.rectangle([22, 20, 74, 34], fill=(150, 104, 66, 255), outline=OUTLINE, width=4)
    d.line([30, 44, 30, 80], fill=(150, 104, 66, 255), width=3)
    d.line([66, 44, 66, 80], fill=(150, 104, 66, 255), width=3)
    d.ellipse([36, 52, 46, 62], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    d.ellipse([50, 52, 60, 62], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    d.rectangle([40, 54, 56, 60], fill=(238, 238, 244, 255), outline=OUTLINE, width=2)

def art_ice_cream_truck_icon(d):
    d.rounded_rectangle([10, 30, 74, 74], radius=5, fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.rectangle([10, 46, 74, 58], fill=(238, 150, 170, 255), outline=OUTLINE, width=3)
    d.rectangle([74, 42, 88, 74], fill=(196, 220, 232, 255), outline=OUTLINE, width=4)
    d.rectangle([76, 46, 86, 58], fill=(120, 170, 200, 255), outline=OUTLINE, width=3)
    d.ellipse([20, 68, 36, 84], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    d.ellipse([56, 68, 72, 84], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    d.polygon([(38, 30), (44, 12), (50, 30)], fill=(238, 200, 120, 255), outline=OUTLINE)
    d.ellipse([38, 6, 50, 18], fill=(238, 150, 170, 255), outline=OUTLINE, width=3)

def art_chili_pepper(d):
    d.arc([16, 20, 68, 72], start=300, end=140, fill=(200, 56, 48, 255), width=16)
    d.ellipse([44, 24, 66, 60], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    d.ellipse([20, 40, 40, 68], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    d.ellipse([28, 30, 60, 66], fill=(200, 56, 48, 255))
    d.ellipse([32, 38, 44, 50], fill=(226, 96, 80, 255))
    d.rectangle([54, 12, 60, 26], fill=(104, 160, 88, 255), outline=OUTLINE, width=3)
    d.ellipse([48, 8, 66, 20], fill=(104, 160, 88, 255), outline=OUTLINE, width=3)

def art_leftovers(d):
    d.polygon([(20, 34), (60, 34), (56, 70), (24, 70)], fill=(238, 238, 244, 255), outline=OUTLINE)
    d.polygon([(20, 34), (8, 20), (28, 24)], fill=(214, 214, 222, 255), outline=OUTLINE)
    d.polygon([(60, 34), (72, 20), (52, 24)], fill=(214, 214, 222, 255), outline=OUTLINE)
    d.arc([26, 28, 42, 44], start=180, end=360, fill=(240, 176, 60, 255), width=4)
    d.arc([36, 26, 52, 42], start=180, end=360, fill=(240, 176, 60, 255), width=4)
    d.line([24, 52, 56, 52], fill=(214, 214, 222, 255), width=3)

def art_ice_cream(d):
    d.polygon([(28, 40), (52, 40), (40, 74)], fill=(238, 200, 120, 255), outline=OUTLINE)
    d.line([32, 48, 46, 48], fill=OUTLINE, width=2)
    d.line([34, 56, 45, 56], fill=OUTLINE, width=2)
    d.ellipse([24, 16, 56, 46], fill=(238, 150, 170, 255), outline=OUTLINE, width=4)
    d.ellipse([34, 8, 46, 20], fill=(200, 56, 48, 255), outline=OUTLINE, width=3)

def art_ice_cream_truck_ingame(d):
    d.rounded_rectangle([6, 34, 76, 80], radius=6, fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.rectangle([6, 52, 76, 64], fill=(238, 150, 170, 255), outline=OUTLINE, width=3)
    d.rectangle([76, 46, 94, 80], fill=(196, 220, 232, 255), outline=OUTLINE, width=4)
    d.rectangle([79, 50, 91, 62], fill=(120, 170, 200, 255), outline=OUTLINE, width=3)
    d.ellipse([16, 72, 34, 90], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    d.ellipse([56, 72, 74, 90], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    d.ellipse([20, 76, 30, 86], fill=(160, 166, 178, 255))
    d.ellipse([60, 76, 70, 86], fill=(160, 166, 178, 255))
    d.polygon([(34, 34), (40, 14), (46, 34)], fill=(238, 200, 120, 255), outline=OUTLINE)
    d.ellipse([34, 8, 46, 20], fill=(238, 150, 170, 255), outline=OUTLINE, width=3)

SPAWNER_ART = {
 "espresso_machine": art_espresso_machine, "butchers_hook": art_butchers_hook,
 "bakers_oven": art_bakers_oven, "beehive": art_beehive, "wok_station": art_wok_station,
 "popcorn_machine": art_popcorn_machine, "deep_fryer": art_deep_fryer,
 "sushi_bar": art_sushi_bar, "grandmas_cookbook": art_grandmas_cookbook,
 "pizza_delivery": art_pizza_delivery, "victory_feast": art_victory_feast,
 "street_vendor": art_street_vendor, "fondue_set": art_fondue_set,
 "gym_membership": art_gym_membership, "fancy_restaurant": art_fancy_restaurant,
 "farmers_market": art_farmers_market, "after_dinner_mints": art_after_dinner_mints,
 "chili_greenhouse": art_chili_greenhouse, "doggy_bag": art_doggy_bag,
 "ice_cream_truck": art_ice_cream_truck_icon,
}
FOOD_ART = {
 "espresso": art_espresso, "steak": art_steak, "cake_slice": art_cake_slice,
 "honey_drop": art_honey_drop, "fried_rice": art_fried_rice, "popcorn": art_popcorn,
 "fries": art_fries, "sushi_roll": art_sushi_roll, "warm_cookie": art_warm_cookie,
 "pizza_slice": art_pizza_slice, "golden_apple": art_golden_apple,
 "mystery_meat": art_mystery_meat, "cheese_cube": art_cheese_cube,
 "protein_shake": art_protein_shake, "escargot": art_escargot,
 "fruit_salad": art_fruit_salad, "mint": art_mint,
 "chili_pepper": art_chili_pepper, "leftovers": art_leftovers, "ice_cream": art_ice_cream,
}


# ---------- tres writers ----------

def gd_arr3(entries):
    if not entries:
        return "[  ]"
    return "[ " + ", ".join(f'[ "{k}", {float(b)}, {float(r)} ]' for k, b, r in entries) + " ]"

def gd_arr2(entries):
    if not entries:
        return "[  ]"
    return "[ " + ", ".join(f'[ "{k}", {int(v)} ]' for k, v in entries) + " ]"

def effect_spawn_tres(key, custom_key, value, text_key):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = "{text_key}"
value = {value}
custom_key = "{custom_key}"
storage_method = 1
effect_sign = 0
custom_args = [  ]
"""

def effect_text_tres(text_key, food_my_id):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = ""
text_key = "{text_key}"
value = 0
custom_key = "{food_my_id}"
storage_method = 0
effect_sign = 2
custom_args = [  ]
"""

def sum_effect_tres(key, value, text_key):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = "{text_key}"
value = {value}
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]
"""

def structure_effect_tres(scene, stats, text_key):
    return f"""[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://effects/items/turret_effect.gd" type="Script" id=1]
[ext_resource path="{scene}" type="PackedScene" id=2]
[ext_resource path="{stats}" type="Resource" id=3]

[resource]
script = ExtResource( 1 )
key = ""
text_key = "{text_key}"
value = 1
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
spawn_cooldown = -1
scene = ExtResource( 2 )
stats = ExtResource( 3 )
effects = [  ]
spawn_in_center = -1
spawn_around_player = -1
can_be_grouped = true
is_pet = false
shooting_animation_speed = 0.5
is_burning = false
is_spawning = true
tracking_key = ""
"""

def spawner_tres(s):
    slug = s["slug"]
    tags = ", ".join(f'"{t}"' for t in ["spawner"] + s["tags"])
    n_effects = 3 if s.get("anchor_structure") else 2
    effect_ext = "\n".join(
        f'[ext_resource path="res://items/custom/{slug}/{slug}_effect_{i}.tres" type="Resource" id={3 + i}]'
        for i in range(n_effects))
    effect_refs = ", ".join(f"ExtResource( {3 + i} )" for i in range(n_effects))
    return f"""[gd_resource type="Resource" load_steps={3 + n_effects} format=2]

[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]
[ext_resource path="res://items/custom/{slug}/{slug}.png" type="Texture" id=2]
{effect_ext}

[resource]
script = ExtResource( 1 )
my_id = "item_{slug}"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "{s['name']}"
tier = {s['tier']}
value = {s['value']}
effects = [ {effect_refs} ]
tracking_text = "{s.get('tracking_text', '')}"
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = {s.get('max_nb', -1)}
item_appearances = [  ]
tags = [ {tags} ]
"""

def food_tres(f):
    slug = f["slug"]
    wav_lines = "\n".join(
        f'[ext_resource path="{w}" type="AudioStream" id={3 + i}]' for i, w in enumerate(FRUIT_WAVS))
    return f"""[gd_resource type="Resource" load_steps=7 format=2]

[ext_resource path="res://items/foods/food_data.gd" type="Script" id=1]
[ext_resource path="res://items/foods/{slug}/{slug}.png" type="Texture" id=2]
{wav_lines}
[ext_resource path="res://items/foods/{slug}/{slug}_text_effect.tres" type="Resource" id=6]

[resource]
script = ExtResource( 1 )
my_id = "{f['my_id']}"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "{f['name']}"
tier = 0
value = 1
effects = [ ExtResource( 6 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [  ]
tags = [  ]
to_be_processed_at_end_of_wave = false
pickup_sounds = [ ExtResource( 3 ), ExtResource( 4 ), ExtResource( 5 ) ]
buff_stats = {gd_arr3(f['buff'])}
buff_duration = {f['dur']}
duration_app_ratio = {float(f['dur_app'])}
buff_stacks = {'true' if f['stacks'] else 'false'}
buff_total_cap = {f['cap']}
buff_stack_cap = {f.get('stack_cap', 20)}
wave_stats = {gd_arr3(f['wave'])}
permanent_stats = {gd_arr2(f['perm'])}
heal_base = {float(f['heal'])}
heal_app_ratio = {float(f['heal_app'])}
special_id = "{f['special']}"
tracking_item_id = "{f.get('tracking_item', '')}"
"""


# ---------- registration ----------

ANCHOR = '[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n'

def register(spawner_ids, food_ids):
    t = open(TSCN).read()
    assert ANCHOR in t, "appetite stat anchor missing"
    added = 0

    new_item_ids, new_food_ids = [], []
    for slug, ext_id in spawner_ids:
        line = f'[ext_resource path="res://items/custom/{slug}/{slug}_data.tres" type="Resource" id={ext_id}]\n'
        if line not in t:
            t = t.replace(ANCHOR, ANCHOR + line)
            new_item_ids.append(ext_id)
            added += 1
    for slug, ext_id in food_ids:
        line = f'[ext_resource path="res://items/foods/{slug}/{slug}_data.tres" type="Resource" id={ext_id}]\n'
        if line not in t:
            t = t.replace(ANCHOR, ANCHOR + line)
            new_food_ids.append(ext_id)
            added += 1

    if new_item_ids:
        m = re.search(r"^items = \[.*\]$", t, re.M)
        arr = m.group(0)
        add = "".join(f", ExtResource( {i} )" for i in new_item_ids)
        t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + add + " ]", 1)

    if new_food_ids:
        m = re.search(r"^foods = \[.*\]$", t, re.M)
        if m:
            arr = m.group(0)
            add = "".join(f", ExtResource( {i} )" for i in new_food_ids)
            t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + add + " ]", 1)
        else:
            refs = ", ".join(f"ExtResource( {i} )" for i in new_food_ids)
            m2 = re.search(r"^consumables = \[.*\]$\n", t, re.M)
            assert m2, "consumables array line missing"
            t = t.replace(m2.group(0), m2.group(0) + f"foods = [ {refs} ]\n", 1)

    if added:
        m3 = re.search(r"load_steps=(\d+)", t)
        t = t.replace(f"load_steps={m3.group(1)}", f"load_steps={int(m3.group(1)) + added}", 1)
        open(TSCN, "w").write(t)
    print(f"registered {added} new ext resources in item_service.tscn")


def add_csv_rows():
    lines = open(CSV).read().rstrip("\n").split("\n")
    added, updated = 0, 0
    for key, text in CSV_ROWS:
        assert "," not in text, f"comma in CSV text for {key} (breaks the 2-column CSV)"
        row = f"{key},{text}"
        hit = [i for i, l in enumerate(lines) if l.startswith(key + ",")]
        if hit:
            if lines[hit[0]] != row:
                lines[hit[0]] = row
                updated += 1
        else:
            lines.append(row)
            added += 1
    open(CSV, "w").write("\n".join(lines) + "\n")
    print(f"added {added} / updated {updated} translation rows")


def main():
    assert len(SPAWNERS) == len(FOODS), "SPAWNERS and FOODS must pair by index"
    spawner_ids, food_ids = [], []

    for i, (s, f) in enumerate(zip(SPAWNERS, FOODS)):
        slug, food_slug = s["slug"], f["slug"]
        spawner_ids.append((slug, BASE_ID + 2 * i))
        food_ids.append((food_slug, BASE_ID + 2 * i + 1))

        d = f"{DEC}/items/custom/{slug}"
        os.makedirs(d, exist_ok=True)
        real_icon = f"{os.path.dirname(os.path.abspath(__file__))}/items_food_system/final/{slug}.png"
        if os.path.exists(real_icon):
            shutil.copy(real_icon, f"{d}/{slug}.png")
        else:
            img, draw = canvas(96)
            SPAWNER_ART[slug](draw)
            img.save(f"{d}/{slug}.png")
        with open(f"{d}/{slug}_effect_0.tres", "w") as fh:
            if s.get("sum_key"):
                fh.write(sum_effect_tres(s["sum_key"], s["count"], s["text_key"]))
            elif s.get("structure"):
                fh.write(structure_effect_tres(s["structure"]["scene"], s["structure"]["stats"], s["text_key"]))
            else:
                fh.write(effect_spawn_tres(f["my_id"], s["trigger"], s["count"], s["text_key"]))
        with open(f"{d}/{slug}_effect_1.tres", "w") as fh:
            fh.write(effect_text_tres(f["text_key"], f["my_id"]))
        if s.get("anchor_structure"):
            with open(f"{d}/{slug}_effect_2.tres", "w") as fh:
                fh.write(structure_effect_tres(s["anchor_structure"]["scene"], s["anchor_structure"]["stats"], "EFFECT_HIDDEN"))
        with open(f"{d}/{slug}_data.tres", "w") as fh:
            fh.write(spawner_tres(s))

        d = f"{DEC}/items/foods/{food_slug}"
        os.makedirs(d, exist_ok=True)
        img, draw = canvas(80)
        FOOD_ART[food_slug](draw)
        img.save(f"{d}/{food_slug}.png")
        with open(f"{d}/{food_slug}_text_effect.tres", "w") as fh:
            fh.write(effect_text_tres(f["text_key"], f["my_id"]))
        with open(f"{d}/{food_slug}_data.tres", "w") as fh:
            fh.write(food_tres(f))

        print(f"pair {i}: {slug} (id {BASE_ID + 2 * i}) + {food_slug} (id {BASE_ID + 2 * i + 1})")

    # on-map structure sprites live with their scenes, 100x100 like the garden's
    structure_sprites = {
        "ice_cream_truck": art_ice_cream_truck_ingame,
        "beehive": art_beehive,
        "fancy_restaurant": art_fancy_restaurant,
        "chili_greenhouse": art_chili_greenhouse,
        "wok_station": art_wok_station,
        "street_vendor": art_street_vendor,
        "farmers_market": art_farmers_market,
    }
    for structure_slug, art_fn in structure_sprites.items():
        real = f"{os.path.dirname(os.path.abspath(__file__))}/structures_food/final/{structure_slug}_ingame.png"
        dst = f"{DEC}/entities/structures/turret/{structure_slug}/{structure_slug}_ingame.png"
        if os.path.exists(real):
            shutil.copy(real, dst)
        else:
            img, draw = canvas(100)
            art_fn(draw)
            img.save(dst)

    register(spawner_ids, food_ids)
    add_csv_rows()

if __name__ == "__main__":
    main()
