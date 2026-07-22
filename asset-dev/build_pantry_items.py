#!/usr/bin/env python3
"""Build the remaining Gourmet DLC catalog items (design PDF sections 2a/2b/3a/3c)
into items/custom/ and register them in item_service.tscn (ext ids 880-913).
PIL placeholder icons. Idempotent. CSV rows update-or-append.

DEFERRED (need engine primitives): Set Menu (spawner selection UI), Burp of
Power + Panic Button (knockback burst), Pocket Sand (enemy slow on being hit).

Kit entry types:
  ("stat", key, val)                    plain stat effect, sign from value
  ("key", key, val, text_key, sign)     custom-key SUM effect with card text
  ("proj", text_key)                    ProjectileEffect (Food Fight)"""
import os, re
from PIL import Image, ImageDraw

DEC  = "/Users/nicolassutcliffe/brotato-decompiled"
TSCN = f"{DEC}/singletons/item_service.tscn"
CSV  = f"{DEC}/items/custom/custom_translations.csv"
BASE_ID = 880

def item(slug, name, tier, value, kit, tags=(), max_nb=-1, tracking=""):
    return dict(slug=slug, name=name, tier=tier, value=value, kit=kit,
                tags=list(tags), max_nb=max_nb, tracking=tracking)

ITEMS = [
 # --- 2a: the six deferred Appetite items ---
 item("pepper_grinder", "Pepper Grinder", 1, 55, [
   ("stat", "stat_appetite", 2),
   ("key", "damage_vs_burning", 2, "EFFECT_DAMAGE_VS_BURNING", 0)], ["stat_appetite"]),
 item("growling_stomach", "Growling Stomach", 1, 50, [
   ("stat", "stat_appetite", 4),
   ("key", "consumables_no_heal", 1, "EFFECT_CONSUMABLES_NO_HEAL", 1)], ["stat_appetite"]),
 item("sous_vide_machine", "Sous-Vide Machine", 2, 80, [
   ("stat", "stat_appetite", 4),
   ("key", "food_buff_duration", 1, "EFFECT_FOOD_BUFF_DURATION", 0)], ["stat_appetite"]),
 item("cast_iron_stomach", "Cast-Iron Stomach", 2, 75, [
   ("stat", "stat_appetite", 5),
   ("key", "mystery_meat_safe", 1, "EFFECT_MYSTERY_MEAT_SAFE", 0)], ["stat_appetite"]),
 item("michelin_star", "Michelin Star", 3, 110, [
   ("stat", "stat_appetite", 8),
   ("key", "spawner_trigger_speed", 15, "EFFECT_SPAWNER_TRIGGER_SPEED", 0),
   ("stat", "stat_armor", -3)], ["stat_appetite"], 1),
 item("bottomless_pit", "Bottomless Pit", 3, 100, [
   ("stat", "stat_appetite", 10),
   ("key", "food_heal_disabled", 1, "EFFECT_FOOD_HEAL_DISABLED", 1),
   ("stat", "stat_speed", -5)], ["stat_appetite"]),
 # --- 2b: system texture ---
 item("slow_cooker", "Slow Cooker", 1, 50, [
   ("key", "food_buff_duration", 2, "EFFECT_FOOD_BUFF_DURATION", 0)]),
 item("preservatives", "Preservatives", 2, 70, [
   ("key", "food_buff_duration", 4, "EFFECT_FOOD_BUFF_DURATION", 0),
   ("key", "food_heal_disabled", 1, "EFFECT_FOOD_HEAL_DISABLED", 1)]),
 item("msg", "MSG", 2, 85, [
   ("key", "food_buff_strength", 50, "EFFECT_FOOD_BUFF_STRENGTH", 0),
   ("key", "food_heal_disabled", 1, "EFFECT_FOOD_HEAL_DISABLED", 1)], (), 1),
 item("intermittent_fasting", "Intermittent Fasting", 3, 95, [
   ("key", "food_buff_strength", 100, "EFFECT_FOOD_BUFF_STRENGTH", 0),
   ("key", "food_spawns_halved", 1, "EFFECT_FOOD_SPAWNS_HALVED", 1)], (), 1),
 item("second_helping", "Second Helping", 2, 75, [
   ("key", "second_helping", 25, "EFFECT_SECOND_HELPING", 0)]),
 item("cooler_box", "Cooler Box", 1, 55, [
   ("key", "cooler_box", 1, "EFFECT_COOLER_BOX", 0)], (), 1),
 item("compost_bin", "Compost Bin", 1, 45, [
   ("key", "compost_bin", 1, "EFFECT_COMPOST_BIN", 0)], ["stat_harvesting"],
   tracking="GOURMET_HARVESTING_GAINED"),
 item("chicken_soup", "Chicken Soup", 0, 20, [
   ("key", "food_bonus_heal", 1, "EFFECT_FOOD_BONUS_HEAL", 0)]),
 item("sugar_rush", "Sugar Rush", 0, 25, [
   ("key", "food_speed_burst", 1, "EFFECT_FOOD_SPEED_BURST", 0)], ["stat_speed"]),
 item("food_fight", "Food Fight", 2, 80, [
   ("proj", "EFFECT_FOOD_FIGHT")], ["stat_ranged_damage"]),
 item("grease_fire", "Grease Fire", 2, 75, [
   ("key", "grease_fire", 1, "EFFECT_GREASE_FIRE", 0)], ["stat_elemental_damage"]),
 item("full_belly", "Full Belly", 1, 55, [
   ("key", "full_belly", 2, "EFFECT_FULL_BELLY", 0)], ["stat_armor"]),
 item("food_coma", "Food Coma", 3, 100, [
   ("key", "food_coma", 1, "EFFECT_FOOD_COMA", 0)]),
 item("snack_break", "Snack Break", 0, 22, [
   ("key", "snack_break", 1, "EFFECT_SNACK_BREAK", 0)], ["stat_harvesting"]),
 item("buffet_insurance", "Buffet Insurance", 1, 60, [
   ("key", "buffet_insurance", 5, "EFFECT_BUFFET_INSURANCE", 0)]),
 # --- 3a: stat-clone replacements ---
 item("alarm_clock", "Alarm Clock", 0, 20, [
   ("stat", "stat_attack_speed", 10), ("stat", "stat_percent_damage", -2)], ["stat_attack_speed"]),
 item("party_balloon", "Party Balloon", 0, 15, [
   ("stat", "stat_max_hp", 3), ("stat", "stat_percent_damage", -1)], ["stat_max_hp"]),
 item("mosquito_jar", "Mosquito Jar", 0, 25, [
   ("stat", "stat_lifesteal", 2), ("stat", "stat_hp_regeneration", -1)], ["stat_lifesteal"]),
 item("sticky_bomb", "Sticky Bomb", 2, 70, [
   ("stat", "stat_ranged_damage", 3), ("key", "explosion_size", 5, "EFFECT_EXPLOSION_SIZE", 0),
   ("key", "explosion_damage", 10, "EFFECT_EXPLOSION_DAMAGE", 0),
   ("stat", "stat_speed", -3), ("stat", "stat_dodge", -3)], ["stat_ranged_damage"]),
 item("space_heater", "Space Heater", 2, 60, [
   ("key", "regen_per_burning_enemy", 1, "EFFECT_REGEN_PER_BURNING_ENEMY", 0)], ["stat_hp_regeneration"]),
 # --- 3c: new general items ---
 item("caltrops", "Caltrops", 0, 25, [
   ("key", "caltrops", 1, "EFFECT_CALTROPS", 0)], ["stat_melee_damage"]),
 item("magnifying_glass", "Magnifying Glass", 1, 45, [
   ("key", "crit_vs_elites", 5, "EFFECT_CRIT_VS_ELITES", 0),
   ("key", "pickup_range", 15, "EFFECT_PICKUP_RANGE_BONUS", 0)], ["stat_crit_chance"]),
 item("sunscreen", "Sunscreen", 1, 40, [
   ("key", "burning_damage_taken", -50, "EFFECT_BURNING_DAMAGE_TAKEN", 0),
   ("stat", "stat_dodge", 3)], ["stat_dodge"]),
 item("training_weights", "Training Weights", 2, 75, [
   ("stat", "stat_percent_damage", 12), ("stat", "stat_attack_speed", -8)], ["stat_percent_damage"]),
 item("loyalty_card", "Loyalty Card", 1, 55, [
   ("key", "loyalty_card", 1, "EFFECT_LOYALTY_CARD", 0)], (), 1,
   tracking="MATERIALS_SAVED"),
 item("static_cling", "Static Cling", 2, 85, [
   ("key", "static_cling", 1, "EFFECT_STATIC_CLING", 0)], ["stat_elemental_damage"]),
 item("echo_chamber", "Echo Chamber", 3, 105, [
   ("key", "echo_chamber", 20, "EFFECT_ECHO_CHAMBER", 0),
   ("stat", "stat_armor", -2)]),
 item("nine_lives", "Nine Lives", 3, 110, [
   ("key", "nine_lives", 1, "EFFECT_NINE_LIVES", 0),
   ("stat", "stat_percent_damage", -15)], (), 1, "NINE_LIVES_USED"),
 item("burp_of_power", "Burp of Power", 1, 50, [
   ("key", "burp_of_power", 20, "EFFECT_BURP_OF_POWER", 0)]),
 item("panic_button", "Panic Button", 2, 80, [
   ("key", "panic_button", 1, "EFFECT_PANIC_BUTTON", 0)], (), 1),
 item("pocket_sand", "Pocket Sand", 0, 18, [
   ("stat", "stat_dodge", 3),
   ("key", "pocket_sand_slow", 1, "EFFECT_POCKET_SAND", 0)], ["stat_dodge"]),
 item("set_menu", "Set Menu", 2, 70, [
   ("key", "set_menu", 1, "EFFECT_SET_MENU", 0)], ["food"], 1),
]

CSV_ROWS = [
 ("EFFECT_DAMAGE_VS_BURNING", "+{0} Damage against burning enemies"),
 ("EFFECT_CONSUMABLES_NO_HEAL", "Consumables no longer heal you"),
 ("EFFECT_FOOD_BUFF_DURATION", "+{0}s food buff duration"),
 ("EFFECT_MYSTERY_MEAT_SAFE", "Mystery Meat never rolls its bad outcome"),
 ("EFFECT_SPAWNER_TRIGGER_SPEED", "Food spawners trigger {0}% faster"),
 ("EFFECT_FOOD_HEAL_DISABLED", "Foods no longer heal you"),
 ("EFFECT_FOOD_BUFF_STRENGTH", "Food buffs are {0}% stronger"),
 ("EFFECT_FOOD_SPAWNS_HALVED", "Half as much food spawns"),
 ("EFFECT_SECOND_HELPING", "{0}% chance food spawns are doubled"),
 ("EFFECT_COOLER_BOX", "Foods on the ground never expire"),
 ("EFFECT_COMPOST_BIN", "Expired food grants +1 permanent Harvesting"),
 ("EFFECT_FOOD_BONUS_HEAL", "Foods heal +{0} additional HP"),
 ("EFFECT_FOOD_SPEED_BURST", "Eating a food grants a burst of Speed for 2 seconds. Scales with Appetite"),
 ("EFFECT_FOOD_FIGHT", "Eating a food throws a projectile dealing {1} ({3}) damage"),
 ("EFFECT_GREASE_FIRE", "Eating a food ignites enemies in melee range. Scales with Appetite and Elemental Damage"),
 ("EFFECT_FULL_BELLY", "+{0} Armor while any food buff is active"),
 ("EFFECT_FOOD_COMA", "+15% Damage and -10% Speed while you have 5 or more food buffs"),
 ("EFFECT_SNACK_BREAK", "Eating a food has a 10% chance to grant materials equal to the wave number"),
 ("EFFECT_BUFFET_INSURANCE", "Heal {0} HP at the end of a wave in which you ate no food"),
 ("EFFECT_EXPLOSION_SIZE", "+{0}% Explosion Size"),
 ("EFFECT_EXPLOSION_DAMAGE", "+{0}% Explosion Damage"),
 ("EFFECT_REGEN_PER_BURNING_ENEMY", "+{0} HP Regeneration for every burning enemy"),
 ("EFFECT_CALTROPS", "Enemies that hit you in melee take damage back. Scales with Melee Damage"),
 ("EFFECT_CRIT_VS_ELITES", "+{0}% Crit Chance against elites and bosses"),
 ("EFFECT_PICKUP_RANGE_BONUS", "+{0}% Pickup Range"),
 ("EFFECT_BURNING_DAMAGE_TAKEN", "{0}% burning damage taken"),
 ("EFFECT_LOYALTY_CARD", "Every 5th shop purchase is 30% off"),
 ("EFFECT_STATIC_CLING", "Every 8th hit zaps 3 nearby enemies. Scales with Elemental Damage"),
 ("EFFECT_ECHO_CHAMBER", "{0}% chance for on-kill effects to trigger twice"),
 ("EFFECT_NINE_LIVES", "Survive lethal damage at 1 HP. Once per wave and 9 times per run"),
 ("NINE_LIVES_USED", "Lives used: {0}"),
 ("EFFECT_BURP_OF_POWER", "Eating a food knocks back nearby enemies"),
 ("EFFECT_PANIC_BUTTON", "Below 30% HP: a burst knocks back nearby enemies. 10 second cooldown"),
 ("EFFECT_POCKET_SAND", "Enemies that hit you are slowed 20% for 2 seconds"),
 ("EFFECT_SET_MENU", "Press an owned food spawner in the shop to make it the daily special. It triggers 40% faster and other spawners 20% slower"),
 ("GOURMET_SELECT_SPAWNER", "Set active"),
 ("GOURMET_SPAWNER_ACTIVE", "Active"),
 ("SPAWNER_ITEMS_PRICE", "% Food Spawner Price"),
 ("EFFECT_PICKY_ONE_SPAWNER", "Only one food spawner is active at a time. Press an owned spawner in the shop to choose it"),
 ("EFFECT_PICKY_STRONGER", "The active spawner's food is +100% stronger"),
 ("EFFECT_PICKY_PENALTY", "-15% Damage while no food buff is active"),
 ("EFFECT_DISHWASHER_EXPIRY", "Food on the ground expires 50% faster"),
 ("EFFECT_RUMINANT_ECHO", "Every food buff triggers again at 50% strength 5 seconds later"),
 ("EFFECT_GOURMET_FRUIT", "All fruit becomes food"),
 ("EFFECT_DISHWASHER_LEFTOVERS", "Leftovers generation is doubled"),
 ("EFFECT_DISHWASHER_REFUND", "Expired food refunds 1 material"),
 ("EFFECT_BLACKSMITH_FORGE", "Combine two same-tier weapons sharing a class into a random next-tier weapon of that class"),
 ("EFFECT_MOLE_FOG", "Fog of war covers every wave"),
 ("EFFECT_SLUG_TRAIL", "Leaves a slime trail that slows enemies 30%"),
 ("ENEMY_ATTACK_SPEED", "% Enemy Attack Speed"),
]


# ---------- placeholder art ----------

OUTLINE = (20, 16, 12, 255)

def canvas():
    img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def _box(d, xy, fill, r=6, w=4):
    d.rounded_rectangle(xy, radius=r, fill=fill, outline=OUTLINE, width=w)

A = {}
def art(slug):
    def deco(fn):
        A[slug] = fn
        return fn
    return deco

@art("pepper_grinder")
def _(d):
    _box(d, [34, 10, 62, 30], (150, 104, 66, 255))
    d.polygon([(30, 30), (66, 30), (60, 86), (36, 86)], fill=(196, 220, 232, 255), outline=OUTLINE)
    for y in (46, 60, 74):
        d.ellipse([44, y, 52, y + 8], fill=(60, 54, 60, 255))

@art("growling_stomach")
def _(d):
    d.ellipse([18, 22, 78, 78], fill=(238, 170, 150, 255), outline=OUTLINE, width=4)
    d.arc([30, 38, 66, 66], start=20, end=160, fill=OUTLINE, width=4)
    for x in (26, 70):
        d.line([x, 30, x - 6 if x < 48 else x + 6, 18], fill=OUTLINE, width=3)

@art("sous_vide_machine")
def _(d):
    _box(d, [14, 34, 82, 80], (196, 220, 232, 255))
    d.rectangle([20, 42, 76, 72], fill=(120, 170, 200, 255), outline=OUTLINE, width=3)
    _box(d, [40, 12, 60, 40], (72, 74, 86, 255), r=4)
    d.ellipse([44, 18, 56, 26], fill=(240, 196, 80, 255), outline=OUTLINE, width=2)

@art("cast_iron_stomach")
def _(d):
    d.ellipse([18, 26, 78, 74], fill=(72, 74, 86, 255), outline=OUTLINE, width=4)
    d.rectangle([10, 40, 20, 52], fill=(72, 74, 86, 255), outline=OUTLINE, width=3)
    d.rectangle([76, 40, 86, 52], fill=(72, 74, 86, 255), outline=OUTLINE, width=3)
    d.arc([32, 40, 64, 62], start=20, end=160, fill=(160, 166, 178, 255), width=4)

@art("michelin_star")
def _(d):
    pts = []
    import math
    for i in range(10):
        r = 34 if i % 2 == 0 else 14
        a = math.pi * i / 5 - math.pi / 2
        pts.append((48 + r * math.cos(a), 48 + r * math.sin(a)))
    d.polygon(pts, fill=(240, 196, 80, 255), outline=OUTLINE)
    d.ellipse([40, 40, 56, 56], fill=(248, 220, 130, 255))

@art("bottomless_pit")
def _(d):
    d.ellipse([16, 20, 80, 50], fill=(60, 54, 60, 255), outline=OUTLINE, width=4)
    d.ellipse([26, 28, 70, 44], fill=(20, 16, 12, 255))
    d.polygon([(20, 36), (76, 36), (66, 84), (30, 84)], fill=(60, 54, 60, 255), outline=OUTLINE)
    d.ellipse([32, 44, 64, 76], fill=(20, 16, 12, 255))

@art("slow_cooker")
def _(d):
    _box(d, [16, 36, 80, 78], (200, 56, 48, 255))
    d.ellipse([16, 26, 80, 46], fill=(196, 202, 216, 255), outline=OUTLINE, width=4)
    d.rectangle([42, 18, 54, 30], fill=(72, 74, 86, 255), outline=OUTLINE, width=3)
    _box(d, [26, 82, 70, 90], (58, 60, 70, 255), r=3, w=3)

@art("preservatives")
def _(d):
    _box(d, [26, 20, 70, 82], (196, 220, 232, 255))
    d.rectangle([26, 34, 70, 44], fill=(104, 160, 88, 255), outline=OUTLINE, width=3)
    for y in (52, 62, 72):
        d.ellipse([38, y, 46, y + 8], fill=(240, 176, 60, 255), outline=OUTLINE, width=2)
        d.ellipse([52, y, 60, y + 8], fill=(200, 56, 48, 255), outline=OUTLINE, width=2)

@art("msg")
def _(d):
    d.polygon([(28, 14), (68, 14), (78, 84), (18, 84)], fill=(238, 238, 244, 255), outline=OUTLINE)
    d.rectangle([34, 6, 62, 18], fill=(200, 56, 48, 255), outline=OUTLINE, width=3)
    for x, y in ((34, 40), (48, 32), (58, 48), (40, 60), (54, 68)):
        d.ellipse([x, y, x + 6, y + 6], fill=(238, 200, 120, 255), outline=OUTLINE, width=2)

@art("intermittent_fasting")
def _(d):
    d.ellipse([18, 18, 78, 78], fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.pieslice([18, 18, 78, 78], start=270, end=90, fill=(120, 124, 138, 255))
    d.ellipse([18, 18, 78, 78], outline=OUTLINE, width=4)
    d.line([48, 48, 48, 26], fill=OUTLINE, width=4)
    d.line([48, 48, 62, 56], fill=OUTLINE, width=4)

@art("second_helping")
def _(d):
    d.ellipse([10, 40, 60, 62], fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.ellipse([36, 34, 86, 56], fill=(214, 214, 222, 255), outline=OUTLINE, width=4)
    d.ellipse([22, 34, 46, 50], fill=(240, 176, 60, 255), outline=OUTLINE, width=3)
    d.ellipse([50, 28, 74, 44], fill=(200, 56, 48, 255), outline=OUTLINE, width=3)

@art("cooler_box")
def _(d):
    _box(d, [14, 34, 82, 80], (90, 150, 200, 255))
    d.rectangle([14, 46, 82, 54], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    _box(d, [22, 24, 74, 40], (120, 170, 200, 255), r=5)
    d.rectangle([40, 28, 56, 34], fill=(238, 238, 244, 255), outline=OUTLINE, width=2)

@art("compost_bin")
def _(d):
    d.polygon([(20, 34), (76, 34), (70, 84), (26, 84)], fill=(104, 160, 88, 255), outline=OUTLINE)
    d.rectangle([16, 26, 80, 38], fill=(84, 130, 70, 255), outline=OUTLINE, width=3)
    d.arc([34, 46, 62, 74], start=300, end=200, fill=(238, 238, 244, 255), width=4)
    d.polygon([(60, 46), (70, 50), (62, 56)], fill=(238, 238, 244, 255))

@art("chicken_soup")
def _(d):
    d.pieslice([12, 36, 84, 88], start=0, end=180, fill=(238, 238, 244, 255), outline=OUTLINE, width=4)
    d.ellipse([12, 28, 84, 48], fill=(240, 196, 80, 255), outline=OUTLINE, width=4)
    for x in (30, 46, 62):
        d.arc([x, 10, x + 8, 26], start=90, end=270, fill=(196, 196, 208, 255), width=3)

@art("sugar_rush")
def _(d):
    d.polygon([(20, 40), (50, 24), (44, 44), (72, 32), (36, 76), (44, 52), (24, 60)], fill=(240, 196, 80, 255), outline=OUTLINE)
    for x, y in ((66, 60), (74, 70), (60, 74)):
        d.ellipse([x, y, x + 7, y + 7], fill=(238, 150, 170, 255), outline=OUTLINE, width=2)

@art("food_fight")
def _(d):
    d.ellipse([14, 40, 50, 76], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    d.ellipse([22, 48, 34, 60], fill=(226, 96, 80, 255))
    for i, (x, y) in enumerate(((54, 34), (64, 26), (74, 18))):
        d.ellipse([x, y, x + 8, y + 8], fill=(240, 176, 60, 255), outline=OUTLINE, width=2)

@art("grease_fire")
def _(d):
    _box(d, [18, 56, 78, 82], (58, 60, 70, 255))
    d.rectangle([78, 60, 92, 68], fill=(150, 104, 66, 255), outline=OUTLINE, width=3)
    for x, h in ((28, 30), (44, 42), (60, 26)):
        d.polygon([(x, 58), (x + 7, 58 - h), (x + 14, 58)], fill=(240, 140, 48, 255), outline=OUTLINE)
        d.polygon([(x + 4, 58), (x + 7, 58 - h + 12), (x + 10, 58)], fill=(240, 196, 80, 255))

@art("full_belly")
def _(d):
    d.ellipse([20, 20, 76, 80], fill=(238, 170, 150, 255), outline=OUTLINE, width=4)
    d.ellipse([34, 36, 62, 64], fill=(226, 140, 120, 255))
    d.ellipse([44, 46, 54, 56], fill=OUTLINE)
    d.arc([28, 24, 68, 50], start=200, end=340, fill=OUTLINE, width=3)

@art("food_coma")
def _(d):
    d.ellipse([18, 34, 66, 82], fill=(238, 170, 150, 255), outline=OUTLINE, width=4)
    d.arc([30, 52, 44, 64], start=0, end=180, fill=OUTLINE, width=3)
    d.arc([42, 52, 56, 64], start=0, end=180, fill=OUTLINE, width=3)
    for i, s in enumerate((10, 8, 6)):
        x = 62 + i * 9
        y = 28 - i * 8
        d.line([x, y, x + s, y], fill=OUTLINE, width=3)
        d.line([x + s, y, x, y + s * 0.8], fill=OUTLINE, width=3)
        d.line([x, y + s * 0.8, x + s, y + s * 0.8], fill=OUTLINE, width=3)

@art("snack_break")
def _(d):
    _box(d, [26, 16, 70, 84], (238, 150, 170, 255))
    d.rectangle([26, 30, 70, 38], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    d.ellipse([38, 48, 58, 68], fill=(240, 196, 80, 255), outline=OUTLINE, width=3)

@art("buffet_insurance")
def _(d):
    _box(d, [16, 26, 80, 74], (238, 238, 244, 255))
    d.line([16, 42, 80, 42], fill=OUTLINE, width=3)
    d.rectangle([24, 50, 52, 56], fill=(120, 124, 138, 255))
    d.rectangle([24, 62, 44, 68], fill=(120, 124, 138, 255))
    d.ellipse([58, 50, 74, 66], fill=(104, 160, 88, 255), outline=OUTLINE, width=3)
    d.line([62, 58, 66, 62], fill=(238, 238, 244, 255), width=3)
    d.line([66, 62, 71, 53], fill=(238, 238, 244, 255), width=3)

@art("alarm_clock")
def _(d):
    d.ellipse([20, 24, 76, 80], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    d.ellipse([28, 32, 68, 72], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    d.line([48, 52, 48, 38], fill=OUTLINE, width=3)
    d.line([48, 52, 58, 58], fill=OUTLINE, width=3)
    for x in (24, 60):
        d.arc([x, 12, x + 14, 26], start=180, end=360, fill=OUTLINE, width=4)

@art("party_balloon")
def _(d):
    d.ellipse([26, 12, 70, 64], fill=(238, 150, 170, 255), outline=OUTLINE, width=4)
    d.ellipse([36, 22, 48, 38], fill=(248, 200, 214, 255))
    d.polygon([(44, 62), (52, 62), (48, 70)], fill=(238, 150, 170, 255), outline=OUTLINE)
    d.arc([40, 66, 56, 88], start=270, end=60, fill=OUTLINE, width=3)

@art("mosquito_jar")
def _(d):
    _box(d, [24, 24, 72, 84], (196, 220, 232, 255), r=8)
    d.rectangle([30, 14, 66, 28], fill=(150, 104, 66, 255), outline=OUTLINE, width=3)
    d.ellipse([40, 46, 52, 56], fill=(60, 54, 60, 255))
    d.line([50, 48, 58, 42], fill=OUTLINE, width=2)
    d.line([50, 52, 60, 52], fill=OUTLINE, width=2)

@art("sticky_bomb")
def _(d):
    d.ellipse([22, 30, 70, 78], fill=(58, 60, 70, 255), outline=OUTLINE, width=4)
    d.rectangle([40, 20, 52, 34], fill=(120, 124, 138, 255), outline=OUTLINE, width=3)
    d.line([46, 20, 56, 8], fill=OUTLINE, width=3)
    d.ellipse([52, 4, 62, 14], fill=(240, 140, 48, 255), outline=OUTLINE, width=2)
    for x, y in ((64, 44), (70, 58), (60, 70)):
        d.ellipse([x, y, x + 8, y + 8], fill=(104, 160, 88, 255), outline=OUTLINE, width=2)

@art("space_heater")
def _(d):
    _box(d, [22, 20, 74, 80], (200, 56, 48, 255))
    for y in (32, 44, 56, 68):
        d.line([30, y, 66, y], fill=(238, 200, 120, 255), width=4)
    d.line([30, 80, 26, 90], fill=OUTLINE, width=4)
    d.line([66, 80, 70, 90], fill=OUTLINE, width=4)

@art("caltrops")
def _(d):
    for cx, cy in ((32, 36), (62, 30), (48, 66)):
        d.line([cx - 12, cy + 10, cx + 12, cy - 10], fill=(120, 124, 138, 255), width=5)
        d.line([cx - 12, cy - 10, cx + 12, cy + 10], fill=(120, 124, 138, 255), width=5)
        d.line([cx, cy - 14, cx, cy + 14], fill=(120, 124, 138, 255), width=5)
        d.line([cx - 12, cy + 10, cx + 12, cy - 10], fill=OUTLINE, width=2)
        d.line([cx - 12, cy - 10, cx + 12, cy + 10], fill=OUTLINE, width=2)
        d.line([cx, cy - 14, cx, cy + 14], fill=OUTLINE, width=2)

@art("magnifying_glass")
def _(d):
    d.ellipse([18, 18, 62, 62], fill=(196, 220, 232, 255), outline=OUTLINE, width=5)
    d.ellipse([26, 26, 44, 44], fill=(238, 238, 244, 255))
    d.line([58, 58, 82, 82], fill=(150, 104, 66, 255), width=9)
    d.line([58, 58, 82, 82], fill=OUTLINE, width=3)

@art("sunscreen")
def _(d):
    _box(d, [30, 30, 66, 84], (240, 196, 80, 255))
    d.rectangle([36, 18, 60, 34], fill=(238, 238, 244, 255), outline=OUTLINE, width=3)
    d.ellipse([70, 10, 90, 30], fill=(240, 176, 60, 255), outline=OUTLINE, width=3)
    for a in range(8):
        import math
        x = 80 + 16 * math.cos(a * math.pi / 4)
        y = 20 + 16 * math.sin(a * math.pi / 4)
        d.line([80 + 11 * math.cos(a * math.pi / 4), 20 + 11 * math.sin(a * math.pi / 4), x, y], fill=OUTLINE, width=2)

@art("training_weights")
def _(d):
    d.rectangle([30, 44, 66, 52], fill=(120, 124, 138, 255), outline=OUTLINE, width=3)
    for x in (14, 70):
        _box(d, [x, 28, x + 12, 68], (58, 60, 70, 255), r=3)
    for x in (26, 62):
        _box(d, [x, 34, x + 8, 62], (84, 88, 100, 255), r=3, w=3)

@art("loyalty_card")
def _(d):
    _box(d, [14, 30, 82, 72], (238, 150, 170, 255), r=8)
    d.line([14, 44, 82, 44], fill=OUTLINE, width=3)
    for i in range(5):
        x = 22 + i * 12
        color = (240, 196, 80, 255) if i < 4 else (238, 238, 244, 255)
        d.ellipse([x, 52, x + 9, 61], fill=color, outline=OUTLINE, width=2)

@art("static_cling")
def _(d):
    d.polygon([(52, 8), (30, 50), (46, 50), (40, 88), (68, 42), (50, 42)], fill=(240, 196, 80, 255), outline=OUTLINE)
    d.ellipse([18, 20, 30, 32], fill=(196, 220, 232, 255), outline=OUTLINE, width=3)
    d.ellipse([68, 66, 80, 78], fill=(196, 220, 232, 255), outline=OUTLINE, width=3)

@art("echo_chamber")
def _(d):
    for i, r in enumerate((14, 26, 38)):
        d.arc([48 - r, 48 - r, 48 + r, 48 + r], start=300, end=60, fill=(120, 170, 200, 255), width=5)
        d.arc([48 - r, 48 - r, 48 + r, 48 + r], start=120, end=240, fill=(120, 170, 200, 255), width=5)
    d.ellipse([40, 40, 56, 56], fill=(72, 74, 86, 255), outline=OUTLINE, width=3)

@art("burp_of_power")
def _(d):
    d.ellipse([20, 30, 62, 72], fill=(238, 170, 150, 255), outline=OUTLINE, width=4)
    d.ellipse([32, 44, 40, 52], fill=OUTLINE)
    d.ellipse([32, 56, 48, 66], fill=(60, 54, 60, 255))
    for x, y, r in ((60, 24, 7), (72, 14, 9), (84, 30, 6)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(196, 220, 232, 255), outline=OUTLINE, width=3)

@art("panic_button")
def _(d):
    _box(d, [18, 48, 78, 82], (160, 166, 178, 255))
    d.ellipse([28, 26, 68, 66], fill=(200, 56, 48, 255), outline=OUTLINE, width=4)
    d.ellipse([36, 32, 52, 44], fill=(226, 96, 80, 255))
    for a, b in (((14, 22), (24, 32)), ((82, 22), (72, 32)), ((48, 8), (48, 22))):
        d.line([a, b], fill=(240, 196, 80, 255), width=4)

@art("pocket_sand")
def _(d):
    d.polygon([(28, 34), (64, 34), (70, 80), (22, 80)], fill=(178, 130, 80, 255), outline=OUTLINE)
    d.rectangle([32, 26, 60, 38], fill=(150, 104, 66, 255), outline=OUTLINE, width=3)
    for x, y in ((66, 24), (76, 16), (84, 28), (74, 36), (88, 42)):
        d.ellipse([x, y, x + 6, y + 6], fill=(240, 196, 80, 255), outline=OUTLINE, width=2)

@art("set_menu")
def _(d):
    _box(d, [24, 12, 72, 84], (238, 238, 244, 255), r=4)
    d.rectangle([32, 20, 64, 30], fill=(200, 56, 48, 255), outline=OUTLINE, width=2)
    for y in (40, 50, 60, 70):
        d.line([32, y, 58, y], fill=(120, 124, 138, 255), width=3)
    d.ellipse([56, 62, 70, 76], fill=(240, 196, 80, 255), outline=OUTLINE, width=3)

@art("nine_lives")
def _(d):
    d.ellipse([26, 34, 70, 78], fill=(72, 74, 86, 255), outline=OUTLINE, width=4)
    d.polygon([(30, 40), (26, 22), (42, 34)], fill=(72, 74, 86, 255), outline=OUTLINE)
    d.polygon([(66, 40), (70, 22), (54, 34)], fill=(72, 74, 86, 255), outline=OUTLINE)
    d.ellipse([36, 48, 44, 56], fill=(240, 196, 80, 255))
    d.ellipse([52, 48, 60, 56], fill=(240, 196, 80, 255))
    d.arc([40, 58, 56, 70], start=0, end=180, fill=(240, 196, 80, 255), width=3)


# ---------- tres writers ----------

def stat_effect_tres(key, value):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = ""
value = {value}
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
"""

def key_effect_tres(key, value, text_key, sign):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = "{text_key}"
value = {value}
custom_key = ""
storage_method = 0
effect_sign = {sign}
custom_args = [  ]
"""

def proj_effect_tres(slug, text_key):
    return f"""[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://effects/items/projectile_effect.gd" type="Script" id=1]
[ext_resource path="res://items/custom/{slug}/{slug}_proj_stats.tres" type="Resource" id=2]

[resource]
script = ExtResource( 1 )
key = "projectiles_on_eat"
text_key = "{text_key}"
value = 1
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]
weapon_stats = ExtResource( 2 )
auto_target_enemy = true
cooldown = -1
"""

def proj_stats_tres():
    base = open(f"{DEC}/weapons/ranged/base_ranged_weapon_stats.tres").read()
    base = base.replace("damage = 1\n", "damage = 10\n")
    base = base.replace('scaling_stats = [ [ "stat_ranged_damage", 1.0 ] ]',
                        'scaling_stats = [ [ "stat_ranged_damage", 0.5 ], [ "stat_appetite", 0.5 ] ]')
    return base

def item_tres(it):
    slug = it["slug"]
    n = len(it["kit"])
    lines = [f'[gd_resource type="Resource" load_steps={n + 3} format=2]', ""]
    lines.append('[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]')
    lines.append(f'[ext_resource path="res://items/custom/{slug}/{slug}.png" type="Texture" id=2]')
    for i in range(n):
        lines.append(f'[ext_resource path="res://items/custom/{slug}/{slug}_effect_{i}.tres" type="Resource" id={3 + i}]')
    effs = ", ".join(f"ExtResource( {3 + i} )" for i in range(n))
    tags = ", ".join(f'"{t}"' for t in it["tags"])
    lines += ["", "[resource]",
      "script = ExtResource( 1 )",
      f'my_id = "item_{slug}"',
      "unlocked_by_default = true",
      "can_be_looted = true",
      "icon = ExtResource( 2 )",
      f'name = "{it["name"]}"',
      f"tier = {it['tier']}",
      f"value = {it['value']}",
      f"effects = [ {effs} ]",
      f'tracking_text = "{it["tracking"]}"',
      "is_lockable = true",
      "unlock_codex_descr_after_get_it = 1",
      "is_cursed = false",
      "curse_factor = 0.0",
      f"max_nb = {it['max_nb']}",
      "item_appearances = [  ]",
      f"tags = [ {tags} ]",
      ""]
    return "\n".join(lines)


# ---------- registration ----------

ANCHOR = '[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n'

def register(ids):
    t = open(TSCN).read()
    assert ANCHOR in t, "appetite stat anchor missing"
    new_ids = []
    for slug, ext_id in ids:
        line = f'[ext_resource path="res://items/custom/{slug}/{slug}_data.tres" type="Resource" id={ext_id}]\n'
        if line not in t:
            t = t.replace(ANCHOR, ANCHOR + line)
            new_ids.append(ext_id)
    if new_ids:
        m = re.search(r"^items = \[.*\]$", t, re.M)
        arr = m.group(0)
        add = "".join(f", ExtResource( {i} )" for i in new_ids)
        t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + add + " ]", 1)
        m3 = re.search(r"load_steps=(\d+)", t)
        t = t.replace(f"load_steps={m3.group(1)}", f"load_steps={int(m3.group(1)) + len(new_ids)}", 1)
        open(TSCN, "w").write(t)
    print(f"registered {len(new_ids)} new ext resources")


def add_csv_rows():
    lines = open(CSV).read().rstrip("\n").split("\n")
    added, updated = 0, 0
    for key, text in CSV_ROWS:
        assert "," not in text, f"comma in CSV text for {key}"
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
    ids = []
    for i, it in enumerate(ITEMS):
        slug = it["slug"]
        ids.append((slug, BASE_ID + i))
        d = f"{DEC}/items/custom/{slug}"
        os.makedirs(d, exist_ok=True)
        # prefer a finished icon from the art pipeline over the PIL placeholder
        real_icon = f"{os.path.dirname(os.path.abspath(__file__))}/items_food_system/final/{slug}.png"
        if os.path.exists(real_icon):
            import shutil
            shutil.copy(real_icon, f"{d}/{slug}.png")
        else:
            img, draw = canvas()
            A[slug](draw)
            img.save(f"{d}/{slug}.png")
        for j, entry in enumerate(it["kit"]):
            path = f"{d}/{slug}_effect_{j}.tres"
            if entry[0] == "stat":
                open(path, "w").write(stat_effect_tres(entry[1], entry[2]))
            elif entry[0] == "key":
                open(path, "w").write(key_effect_tres(entry[1], entry[2], entry[3], entry[4]))
            elif entry[0] == "proj":
                open(f"{d}/{slug}_proj_stats.tres", "w").write(proj_stats_tres())
                open(path, "w").write(proj_effect_tres(slug, entry[1]))
        open(f"{d}/{slug}_data.tres", "w").write(item_tres(it))
        print(f"{BASE_ID + i}: {slug} (T{it['tier']}/{it['value']})")

    register(ids)
    add_csv_rows()

if __name__ == "__main__":
    main()
