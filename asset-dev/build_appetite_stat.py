#!/usr/bin/env python3
"""Build the DLC 'Appetite' secondary stat: icon + StatData resource + register
in item_service.tscn. is_dlc_stat=true auto-seeds (player_run_data:462) and
auto-displays (stats_container:42), so registration is all the wiring needed."""
from PIL import Image, ImageDraw
import os, re

DEC  = "/Users/nicolassutcliffe/brotato-decompiled"
CS   = f"{DEC}/items/custom_stats"
TSCN = f"{DEC}/singletons/item_service.tscn"
os.makedirs(CS, exist_ok=True)

# ---------- stat glyph: install the VECTORIZED fork & knife from the tracked final ----------
# (never PIL-draw this: a builder rerun once stomped the proper vectorized glyph
# with the crude placeholder - user 2026-08-14)
import shutil as _sh
_final = os.path.join(os.path.dirname(os.path.abspath(__file__)), "items_appetite", "final", "stat_appetite_icon.png")
_sh.copy(_final, f"{CS}/appetite.png")
print("installed stat glyph from tracked final")

# ---------- StatData resource ----------
# ICON LAW (user 2026-08-11): cutlery = small_icon ONLY (tiny stat rows on cards
# and the stat sheet). Everywhere else - stat popup, upgrade menu, in-round stat
# gain floaters - uses the STOMACH (items/upgrades/appetite/appetite.png).
open(f"{CS}/stat_appetite.tres","w").write('''[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://items/upgrades/stat_data.gd" type="Script" id=1]
[ext_resource path="res://items/custom_stats/appetite.png" type="Texture" id=2]
[ext_resource path="res://items/upgrades/appetite/appetite.png" type="Texture" id=3]

[resource]
script = ExtResource( 1 )
stat_name = "stat_appetite"
icon = ExtResource( 3 )
small_icon = ExtResource( 2 )
is_primary_stat = true
is_dlc_stat = true
color_override = Color( 0.95, 0.62, 0.2, 1 )
reverse = false
''')
print("wrote stat_appetite.tres")

# ---------- register in the FOOD pack (ecosystem Phase 2+) ----------
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pack_registry import register as pack_register
if pack_register("food", "stats", "items/custom_stats/stat_appetite.tres", quiet=True):
    print("registered stat_appetite in the food pack")
else:
    print("stat_appetite pack registration up to date")
