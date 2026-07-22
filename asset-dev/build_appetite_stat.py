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

# ---------- icon: crossed fork & knife (universal "appetite/dining" glyph), 96x96 ----------
def utensil(kind):
    S=8; N=96*S
    im=Image.new("RGBA",(N,N),(0,0,0,0)); d=ImageDraw.Draw(im); cx=N//2
    SIL=(212,214,222,255); OL=(24,20,26,255)
    def cap(x0,y0,x1,y1,fill,r): d.rounded_rectangle([int(x0),int(y0),int(x1),int(y1)],radius=int(r),fill=fill)
    if kind=="knife":
        cap(cx-5*S,50*S,cx+5*S,86*S,OL,5*S);  cap(cx-3*S,52*S,cx+3*S,84*S,SIL,3*S)     # handle
        d.polygon([(cx-6*S,12*S),(cx+3*S,11*S),(cx+6*S,52*S),(cx-6*S,52*S)],fill=OL)    # blade
        d.polygon([(cx-3*S,16*S),(cx+1*S,15*S),(cx+3*S,50*S),(cx-3*S,50*S)],fill=SIL)
    else:
        cap(cx-5*S,50*S,cx+5*S,86*S,OL,5*S);  cap(cx-3*S,52*S,cx+3*S,84*S,SIL,3*S)     # handle
        cap(cx-8*S,38*S,cx+8*S,56*S,OL,6*S);  cap(cx-6*S,38*S,cx+6*S,54*S,SIL,5*S)     # head
        for tx in (-6,-2,2,6):                                                          # tines
            cap(cx+tx*S-2*S,12*S,cx+tx*S+2*S,44*S,OL,2*S)
            cap(cx+tx*S-1*S,15*S,cx+tx*S+1*S,41*S,SIL,1*S)
    return im,N

f,N=utensil("fork");  k,_=utensil("knife")
fork = f.rotate(26, resample=Image.BICUBIC, center=(N//2,N//2))
knife= k.rotate(-26,resample=Image.BICUBIC, center=(N//2,N//2))
out=Image.new("RGBA",(N,N),(0,0,0,0)); out.alpha_composite(fork); out.alpha_composite(knife)
out.resize((96,96),Image.LANCZOS).save(f"{CS}/appetite.png")
print("wrote appetite.png")

# ---------- StatData resource ----------
open(f"{CS}/stat_appetite.tres","w").write('''[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://items/upgrades/stat_data.gd" type="Script" id=1]
[ext_resource path="res://items/custom_stats/appetite.png" type="Texture" id=2]

[resource]
script = ExtResource( 1 )
stat_name = "stat_appetite"
icon = ExtResource( 2 )
small_icon = ExtResource( 2 )
is_primary_stat = false
is_dlc_stat = true
color_override = Color( 0, 0, 0, 1 )
reverse = false
''')
print("wrote stat_appetite.tres")

# ---------- register in item_service.tscn ----------
t=open(TSCN).read()
if "stat_appetite.tres" not in t:
    anchor='[ext_resource path="res://items/custom_characters/mole/mole_data.tres" type="Resource" id=824]\n'
    assert anchor in t, "mole anchor not found"
    t=t.replace(anchor, anchor+'[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n')
    t=re.sub(r'^stats = \[.*\]$',
             lambda m: m.group(0)[:m.group(0).rfind(']')].rstrip()+", ExtResource( 825 ) ]",
             t, count=1, flags=re.M)
    t=re.sub(r'load_steps=(\d+)', lambda m: f"load_steps={int(m.group(1))+1}", t, count=1)
    open(TSCN,"w").write(t)
    print("registered stat_appetite in item_service.tscn (id 825)")
else:
    print("already registered - skipped")
