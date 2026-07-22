import os

PROJECT_ROOT = "/Users/nicolassutcliffe/brotato-decompiled"


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def effect_tres(key, value, text_key="", sign=3):
    return f'''[gd_resource type="Resource" load_steps=2 format=2]

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
'''


NEUTRAL = 2  # Sign.NEUTRAL

# --- Overtime Pay: keep -2 armor, drop flat +6 attack speed, add descriptive text ---
write(f"{PROJECT_ROOT}/items/custom/overtime_pay/overtime_pay_effect_1.tres",
      effect_tres("stat_armor", -2))
write(f"{PROJECT_ROOT}/items/custom/overtime_pay/overtime_pay_effect_2.tres",
      effect_tres("overtime_pay_desc", 0, "OVERTIME_PAY_DESC", NEUTRAL))

overtime_pay_data = '''[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]
[ext_resource path="res://items/custom/overtime_pay/overtime_pay.png" type="Texture" id=2]
[ext_resource path="res://items/custom/overtime_pay/overtime_pay_effect_1.tres" type="Resource" id=3]
[ext_resource path="res://items/custom/overtime_pay/overtime_pay_effect_2.tres" type="Resource" id=4]

[resource]
script = ExtResource( 1 )
my_id = "item_overtime_pay"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "Overtime Pay"
tier = 2
value = 80
effects = [ ExtResource( 3 ), ExtResource( 4 ) ]
tracking_text = ""
is_lockable = false
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [  ]
tags = [ "stat_attack_speed", "stat_armor" ]
'''
write(f"{PROJECT_ROOT}/items/custom/overtime_pay/overtime_pay_data.tres", overtime_pay_data)

# --- Second Mortgage: keep -15% start wave, drop flat +10 percent_materials, add descriptive text ---
write(f"{PROJECT_ROOT}/items/custom/second_mortgage/second_mortgage_effect_2.tres",
      effect_tres("second_mortgage_desc", 0, "SECOND_MORTGAGE_DESC", NEUTRAL))

second_mortgage_data = '''[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]
[ext_resource path="res://items/custom/second_mortgage/second_mortgage.png" type="Texture" id=2]
[ext_resource path="res://items/custom/second_mortgage/second_mortgage_effect_1.tres" type="Resource" id=3]
[ext_resource path="res://items/custom/second_mortgage/second_mortgage_effect_2.tres" type="Resource" id=4]

[resource]
script = ExtResource( 1 )
my_id = "item_second_mortgage"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "Second Mortgage"
tier = 2
value = 70
effects = [ ExtResource( 3 ), ExtResource( 4 ) ]
tracking_text = ""
is_lockable = false
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [  ]
tags = [ "gain_pct_gold_start_wave" ]
'''
write(f"{PROJECT_ROOT}/items/custom/second_mortgage/second_mortgage_data.tres", second_mortgage_data)

# --- Vampire Fang: keep lifesteal+maxhp, add descriptive text for the shield mechanic ---
write(f"{PROJECT_ROOT}/items/custom/vampire_fang/vampire_fang_effect_3.tres",
      effect_tres("vampire_fang_desc", 0, "VAMPIRE_FANG_DESC", NEUTRAL))

vampire_fang_data = '''[gd_resource type="Resource" load_steps=5 format=2]

[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]
[ext_resource path="res://items/custom/vampire_fang/vampire_fang.png" type="Texture" id=2]
[ext_resource path="res://items/custom/vampire_fang/vampire_fang_effect_1.tres" type="Resource" id=3]
[ext_resource path="res://items/custom/vampire_fang/vampire_fang_effect_2.tres" type="Resource" id=4]
[ext_resource path="res://items/custom/vampire_fang/vampire_fang_effect_3.tres" type="Resource" id=5]

[resource]
script = ExtResource( 1 )
my_id = "item_vampire_fang"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "Vampire Fang"
tier = 3
value = 110
effects = [ ExtResource( 3 ), ExtResource( 4 ), ExtResource( 5 ) ]
tracking_text = ""
is_lockable = false
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [  ]
tags = [ "stat_lifesteal", "stat_max_hp" ]
'''
write(f"{PROJECT_ROOT}/items/custom/vampire_fang/vampire_fang_data.tres", vampire_fang_data)

print("Done: overtime_pay, second_mortgage, vampire_fang updated with real mechanics + descriptions")
