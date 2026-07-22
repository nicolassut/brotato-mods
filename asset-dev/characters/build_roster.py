#!/usr/bin/env python3
"""Build all 14 DLC character selection icons via the composite pipeline:
real game parts + vectorized custom pieces + code-drawn simple pieces."""
from PIL import Image, ImageDraw, ImageFilter
import glob, os, math
import numpy as np

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
VEC = "/Users/nicolassutcliffe/brotato-mods/Brotato Icons/character_pieces_vectorized"
OUTDIR = "/Users/nicolassutcliffe/brotato-mods/asset-dev/characters/final"
os.makedirs(OUTDIR, exist_ok=True)

ALLP = [p for p in (glob.glob(f"{DEC}/items/characters/*/*.png") + glob.glob(f"{DEC}/items/characters/*/appearances/*.png")
        + glob.glob(f"{DEC}/dlcs/dlc_1/characters/*/*.png") + glob.glob(f"{DEC}/dlcs/dlc_1/characters/*/appearances/*.png"))
        if "icon" not in p and Image.open(p).size == (150,150)]
def part(sub):
    for p in ALLP:
        if os.path.basename(p) == sub + ".png": return Image.open(p).convert("RGBA")
    raise SystemExit("missing part: " + sub)

BODY = Image.open(f"{DEC}/entities/units/player/potato.png").convert("RGBA")
BODYA = np.array(BODY)[..., 3]

def frame_border(layer, W):
    """Add a bold black outline at the 150-FRAME scale (dilate-under). Do this AFTER place_c so
    the border weight matches the body outline instead of being shrunk away by the downscale."""
    a = np.array(layer); sil = ((a[..., 3] > 60).astype("uint8")) * 255
    grown = Image.fromarray(sil).filter(ImageFilter.MaxFilter(2*W+1))
    black = Image.new("RGBA", layer.size, (15, 13, 15, 255))
    empty = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    return Image.alpha_composite(Image.composite(black, empty, grown), layer)

def clip_body(layer):
    """Mask a placed layer to the body silhouette so pieces (e.g. wrap-around goggle straps) are
    cut exactly at the head edge and read as going behind it. Never clips past the silhouette."""
    a = np.array(layer); a[..., 3] = (a[..., 3].astype(int) * (BODYA > 40)).astype("uint8")
    return Image.fromarray(a, "RGBA")

def tint(im, c):
    b = im.copy(); px = b.load()
    for y in range(b.height):
        for x in range(b.width):
            r,g,bl,a = px[x,y]
            if a>0 and (r+g+bl)>120:
                px[x,y]=(min(255,int(r*c[0])),min(255,int(g*c[1])),min(255,int(bl*c[2])),a)
    return b

def scaled(im, w, xy):
    s = w/im.width; im2 = im.resize((w, max(1,int(im.height*s))), Image.LANCZOS)
    f = Image.new("RGBA",(150,150),(0,0,0,0)); f.alpha_composite(im2, xy); return f

def place_c(piece, cx, cy, w, flip=False, rot=0):
    """crop to content, scale to width w, center content at (cx,cy) in 150 frame.
    rot rotates (degrees, ccw) after flip for a subtle turn/tilt."""
    bb = piece.getbbox(); piece = piece.crop(bb)
    if flip: piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
    if rot: piece = piece.rotate(rot, expand=True, resample=Image.BICUBIC); piece = piece.crop(piece.getbbox())
    s = w/piece.width; piece = piece.resize((w, max(1,int(piece.height*s))), Image.LANCZOS)
    f = Image.new("RGBA",(150,150),(0,0,0,0))
    f.alpha_composite(piece, (int(round(cx-piece.width/2)), int(round(cy-piece.height/2))))
    return f

# ---------- code-drawn pieces (supersampled for smooth edges) ----------
def draw_shell():
    S=6; N=110*S
    img=Image.new("RGBA",(N,N),(0,0,0,0)); d=ImageDraw.Draw(img)
    cx=cy=N//2
    # spiral coil: black under-stroke then brown over-stroke
    def spiral(width,color):
        pts=[]
        for i in range(0,720,4):
            t=math.radians(i); rad=(i/720.0)*(46*S)
            pts.append((cx+rad*math.cos(t), cy+rad*math.sin(t)))
        d.line(pts, fill=color, width=width, joint="curve")
    # outer shell circle (black outline + cream fill)
    R=50*S
    d.ellipse([cx-R,cy-R,cx+R,cy+R], fill=(20,12,10,255))
    d.ellipse([cx-R+5*S,cy-R+5*S,cx+R-5*S,cy+R-5*S], fill=(196,150,96,255))
    spiral(11*S,(20,12,10,255))     # black coil
    spiral(5*S,(150,104,60,255))    # brown coil highlight
    im=img.resize((110,110),Image.LANCZOS); bb=im.getbbox(); return im.crop(bb)

def draw_blood():
    S=6; W,H=70*S,64*S
    black=Image.new("RGBA",(W,H),(0,0,0,0)); db=ImageDraw.Draw(black)
    red=Image.new("RGBA",(W,H),(0,0,0,0)); dr=ImageDraw.Draw(red)
    # irregular splats: each = main blob + satellite lobes (not perfect circles)
    splats=[  # (cx,cy, [(dx,dy,r),...])
      (26,24,[(0,0,13),(9,-7,7),(-8,6,6),(6,9,5)]),
      (46,38,[(0,0,9),(6,4,5),(-5,-4,4)]),
      (34,54,[(0,0,6),(4,3,3)]),
    ]
    OL=5*S
    for (cx,cy,lobes) in splats:
        for (dx,dy,r) in lobes:
            x,y,rr=(cx+dx)*S,(cy+dy)*S,r*S
            db.ellipse([x-rr-OL,y-rr-OL,x+rr+OL,y+rr+OL], fill=(16,8,10,255))
    for (cx,cy,lobes) in splats:
        for (dx,dy,r) in lobes:
            x,y,rr=(cx+dx)*S,(cy+dy)*S,r*S
            dr.ellipse([x-rr,y-rr,x+rr,y+rr], fill=(180,32,38,255))
    out=Image.alpha_composite(black,red)
    im=out.resize((70,64),Image.LANCZOS); bb=im.getbbox(); return im.crop(bb)

def draw_mime():
    """Pierrot mime makeup: white eyes, thick black arched brows, black
    diamond tear-drops under each eye, small red lips. Returns 150x150 aligned."""
    S=6; N=150*S
    img=Image.new("RGBA",(N,N),(0,0,0,0)); d=ImageDraw.Draw(img)
    def P(x,y): return (x*S,y*S)
    black=(22,16,18,255); red=(196,42,52,255); white=(246,246,246,255)
    # cluster shifted right (center ~81) so he looks 3/4 to the side like the real faces
    LE=(72,69); RE=(90,69)
    # eyeballs: white with black pupil (nudged right for a sideways gaze) + thin rim
    for (ex,ey) in (LE,RE):
        d.ellipse([*P(ex-4,ey-4),*P(ex+4,ey+4)], fill=white, outline=black, width=2*S)
        d.ellipse([*P(ex-1,ey-2),*P(ex+3,ey+2)], fill=black)
    # eyebrows: bold black arches, raised well clear of the eyes
    for (ex,ey) in (LE,RE):
        d.arc([*P(ex-10,ey-22),*P(ex+10,ey-9)], start=185, end=355, fill=black, width=4*S)
    # tear-drop diamonds under each eye
    for (ex,ey) in (LE,RE):
        top=(ex,ey+8); bot=(ex,ey+19); l=(ex-3,ey+13); r=(ex+3,ey+13)
        d.polygon([P(*top),P(*r),P(*bot),P(*l)], fill=black)
    # small red lips with a subtle centre parting (shifted right with the cluster)
    mx,my=81,91
    d.ellipse([*P(mx-7,my-3),*P(mx+7,my+3)], fill=red, outline=black, width=S)
    d.line([*P(mx-6,my),*P(mx+6,my)], fill=black, width=S)
    return img.resize((150,150),Image.LANCZOS)

def draw_bowler():
    """Classic juggler's bowler hat: black felt dome + curled brim + blue band,
    cocked at a jaunty angle. Returns a cropped RGBA piece (place_c positions it)."""
    S=6; W,H=64*S,46*S
    img=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(img)
    def P(x,y): return (int(x*S),int(y*S))
    black=(24,22,27,255); dome=(42,40,47,255); band=(30,96,205,255); hi=(96,92,104,255)
    cx=32
    # brim: wide thin curled ellipse (black), sitting at the base
    d.ellipse([*P(cx-27,29),*P(cx+27,41)], fill=black)
    d.ellipse([*P(cx-24,31),*P(cx+24,39)], fill=dome)      # brim top surface (lighter)
    d.ellipse([*P(cx-27,28),*P(cx+27,35)], fill=black)     # brim front lip (black)
    # dome: rounded crown, black outline + dark-grey fill
    d.ellipse([*P(cx-19,3),*P(cx+19,35)], fill=black)
    d.ellipse([*P(cx-16,6),*P(cx+16,33)], fill=dome)
    d.rectangle([*P(cx-16,22),*P(cx+16,31)], fill=dome)
    # blue band around the base of the dome
    d.rectangle([*P(cx-17,25),*P(cx+17,31)], fill=band)
    d.rectangle([*P(cx-17,25),*P(cx+17,26)], fill=(20,64,150,255))  # band shadow line
    # soft highlight on the dome
    d.ellipse([*P(cx-11,8),*P(cx-1,19)], fill=hi)
    im=img.resize((64,46),Image.LANCZOS)
    bb=im.getbbox(); im=im.crop(bb)
    return im.rotate(11, expand=True, resample=Image.BICUBIC)   # jaunty cock

def draw_mini_dots():
    """Minimalist: a MUCH tinier minimal face - two small eye dots + a short LINE mouth,
    on the big blank body. The joke is minimalism, so keep it very small and centred on the
    face (viewer-right). Returns a 150x150 aligned overlay."""
    S=6; N=150*S; img=Image.new("RGBA",(N,N),(0,0,0,0)); d=ImageDraw.Draw(img)
    dark=(32,28,32,255)
    def circ(x,y,r): d.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S], fill=dark)
    cx,cy=81,70
    circ(cx-4,cy,2); circ(cx+4,cy,2)   # two tiny eyes
    th=1.6                              # short line mouth (a rounded bar, not a dot)
    d.rounded_rectangle([(cx-4)*S,(cy+7-th)*S,(cx+4)*S,(cy+7+th)*S], radius=th*S, fill=dark)
    return img.resize((150,150),Image.LANCZOS)

PR = "/Users/nicolassutcliffe/brotato-mods/asset-dev/characters/pieces_raw/"
SHELL = Image.open(PR+"snail_shell_final.png").convert("RGBA")
STALKS = Image.open(PR+"snail_stalks_vec.png").convert("RGBA")
MIME = draw_mime()
MINI_DOTS = draw_mini_dots()
def _load_bowler():
    import numpy as np
    im = Image.open(f"{VEC}/image_2026-07-19_051726392.png").convert("RGBA")
    im = im.crop(im.getbbox())
    a = np.array(im); rgb = a[:,:,:3].astype(int); al = a[:,:,3]
    blue = (al>80)&(rgb[:,:,2]-rgb[:,:,0]>35)&(rgb[:,:,2]>80)
    dark = (al>80)&(~blue)
    a[dark,0]=16; a[dark,1]=15; a[dark,2]=19          # merge charcoal felt into solid black (no hollow look)
    im = Image.fromarray(a,"RGBA")
    return im.resize((im.width, int(im.height*0.68)), Image.LANCZOS)  # squat the tall dome
BOWLER = _load_bowler()
BLOOD = draw_blood()
NOSE  = Image.open("/Users/nicolassutcliffe/brotato-mods/Brotato Icons/character_pieces_to_vectorize/ruminant_nose.png").convert("RGBA")
HORNS = Image.open(f"{VEC}/image_2026-07-18_173634376.png").convert("RGBA")
BUBBLES = Image.open(f"{VEC}/image_2026-07-18_173810494.png").convert("RGBA")
BERET = Image.open(f"{VEC}/image_2026-07-18_173833126.png").convert("RGBA")
# custom character props generated 2026-07-20 (raster pixel finals, pre-vectorize).
# thickened via dilate-under so placed outline matches the body + borrowed neighbors.
MOLE_SNOUT   = Image.open(PR+"mole_snout_thick.png").convert("RGBA")    # pink snout+nostrils+buck teeth
ZOMBIE_MOUTH = Image.open(PR+"zombie_mouth_thick.png").convert("RGBA")  # rotten drooling maw
BLACKSMITH_GOGGLES = Image.open(PR+"blacksmith_goggles_vec.png").convert("RGBA")  # VECTORIZED welding goggles (border baked in)
PICKY_TONGUE = Image.open(PR+"picky_tongue_thick.png").convert("RGBA")  # tongue-out "blegh" of disgust
# borrowed-OK tier props (2026-07-20): one custom prop each, layered over the still-borrowed face.
GOURMET_MONOCLE = Image.open(PR+"gourmet_monocle_thick.png").convert("RGBA")  # gold monocle over right eye
TOURIST_CAMERA  = Image.open(PR+"tourist_camera_thick.png").convert("RGBA")   # camera on a neck strap
COMP_HEADBAND   = Image.open(PR+"comp_eater_headband_thick.png").convert("RGBA")  # red athletic sweatband
BUTCHER_CLEAVER = Image.open(PR+"butcher_cleaver_thick.png").convert("RGBA")  # brandished bloody cleaver (pre-rotated)
DISHWASHER_SUDS = Image.open(PR+"dishwasher_suds_thick.png").convert("RGBA")  # soap foam over the mouth
BUTCHER_BLOOD   = Image.open(PR+"butcher_blood_thick.png").convert("RGBA")    # convincing blood splat on forehead

# ---------- character recipes: (name, body, [real-part subs], [custom layers]) ----------
def compose(bodyimg, real_subs, customs, shell_behind=None):
    c = Image.new("RGBA",(150,150),(0,0,0,0))
    if shell_behind is not None: c.alpha_composite(shell_behind)
    c.alpha_composite(bodyimg)
    for s in real_subs: c.alpha_composite(part(s))
    for cust in customs: c.alpha_composite(cust)
    return c

# body head: bbox (45,38,104,107); center x=74; top=38; face eyes~60 mouth~74
# RECIPES: name -> (body_tint or None, [real-part subs], [custom 150x150 layers])
RECIPES = {
 "gourmet":    (None, ["old_eyes","king_mouth","gangster_app_2"], [place_c(GOURMET_MONOCLE,87,70,22,flip=True)]),
 "picky_eater":(None, ["sick_eyes"], [place_c(PICKY_TONGUE,80,92,33,rot=-8)]),
 "dishwasher": (None, ["sick_eyes"], [place_c(DISHWASHER_SUDS,74,95,58)]),
 "comp_eater": (None, ["brawler_eyes","loud_mouth"], [place_c(COMP_HEADBAND,74,55,54)]),
 "butcher":    (None, ["brawler_eyes","hunter_mouth"], [place_c(BUTCHER_BLOOD,80,62,44), part("chef_app_2")]),
 "zombie":     ((0.38,0.62,0.28), [], [place_c(part("lich_eyes"),81,65,43), place_c(ZOMBIE_MOUTH,81,86,37)]),
 "minimalist": (None, [], [MINI_DOTS]),
 "mime":       (None, [], [MIME, place_c(BERET,80,43,60,flip=True)]),
 "tourist":    (None, ["generalist_eyes","fisherman_mouth","hiker_app_2"], [place_c(TOURIST_CAMERA,74,98,44)]),
 "ruminant":   (None, ["apprentice_eyes"], [place_c(HORNS,74,36,64), place_c(NOSE,80,89,35,rot=-7)]),
 "snail":      ((0.64,0.70,0.65), ["well_rounded_mouth"], [place_c(STALKS,74,33,48)]),
 # vectorized goggles have the black border baked in - no frame_border. Shifted right + clipped
 # so the right lens recedes behind the right head edge (the "looking right" cut) and the left
 # strap wraps the left edge.
 "blacksmith": (None, ["explorer_mouth"], [clip_body(place_c(BLACKSMITH_GOGGLES,82,68,66))]),
 "juggler":    (None, ["crazy_eyes","fisherman_mouth"], [place_c(BOWLER,78,48,84)]),
 "mole":       ((0.85,0.72,0.55), ["arms_dealer_eyes"], [place_c(MOLE_SNOUT,80,95,33,flip=True)]),
}

def features_of(real_subs, customs):
    """all the pieces that sit ON TOP of the body, on a transparent 150 frame."""
    f = Image.new("RGBA",(150,150),(0,0,0,0))
    for s in real_subs: f.alpha_composite(part(s))
    for c in customs:   f.alpha_composite(c)
    return f

chars = {}          # name -> full 150 composite (for the icon)
APP   = {}          # name -> (skin_png_or_None, features_png)  for in-game appearance
for name,(tc,real,cust) in RECIPES.items():
    feats = features_of(real, cust)
    skin  = tint(BODY, tc) if tc else None
    body  = skin if skin is not None else BODY
    comp  = Image.new("RGBA",(150,150),(0,0,0,0))
    comp.alpha_composite(body); comp.alpha_composite(feats)
    chars[name] = comp
    APP[name]   = (skin, feats)

# ---------- bake 96x96 icons framed like the real Brotato icons ----------
# Vanilla icons fill the frame (head ~0.76W x 0.88H, body bottom-anchored). We crop to
# CONTENT and scale the potato to match, keeping the head centred on a common baseline so
# headwear extends up and side-props (thermometer, blood) don't shove the head off-centre.
BODY_CX, BODY_BOTTOM = 74.5, 107.0   # potato head centre-x and bottom-y in the 150 composite
FRAC, BASELINE = 0.92, 90            # content fills 92% of 96; body rests on the y=90 baseline
def bake(comp):
    bb = comp.getbbox(); crop = comp.crop(bb)
    s = (FRAC * 96) / max(crop.size)
    nw, nh = max(1, round(crop.width * s)), max(1, round(crop.height * s))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    icon = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    x = round(48 - (BODY_CX - bb[0]) * s)            # head horizontally centred
    y = round(BASELINE - (BODY_BOTTOM - bb[1]) * s)  # body on a common baseline
    x = max(0, min(96 - nw, x)) if nw <= 96 else (96 - nw) // 2   # clamp inside frame (never crop)
    y = max(0, min(96 - nh, y)) if nh <= 96 else (96 - nh) // 2
    icon.alpha_composite(crop, (x, y))
    return icon

for name, comp in chars.items():
    bake(comp).save(f"{OUTDIR}/{name}_icon.png")

# ---------- in-game appearance sprites (150x150, aligned to the potato body) ----------
# face  = everything drawn ON TOP of the body (position OTHER, depth 600)
# skin  = tinted full body, only for tinted characters (position SKIN, depth 1.0)
APPDIR = f"{OUTDIR}/appearances"; os.makedirs(APPDIR, exist_ok=True)
for name,(skin,feats) in APP.items():
    feats.save(f"{APPDIR}/{name}_face.png")
    if skin is not None:
        skin.save(f"{APPDIR}/{name}_skin.png")

# roster sheet
cols=7; cell=96; lh=16; rows=(len(chars)+cols-1)//cols
sheet=Image.new("RGBA",(cols*(cell+8), rows*(cell+lh+8)),(48,48,48,255)); d=ImageDraw.Draw(sheet)
for i,(name,comp) in enumerate(chars.items()):
    x=(i%cols)*(cell+8)+4; y=(i//cols)*(cell+lh+8)+4
    sheet.alpha_composite(bake(comp),(x,y)); d.text((x+2,y+cell+2),name,fill=(255,255,120,255))
sheet.convert("RGB").save("/tmp/roster_final.png")
print("baked", len(chars), "icons ->", OUTDIR)
