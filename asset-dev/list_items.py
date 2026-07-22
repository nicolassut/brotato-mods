import struct
p = "/Users/nicolassutcliffe/Library/Application Support/Steam/steamapps/common/Brotato/Brotato.app/Contents/Resources/Brotato.pck"
f = open(p, "rb")
assert f.read(4) == b"GDPC"
f.read(4); f.read(12); f.read(16 * 4)
n = struct.unpack("<I", f.read(4))[0]
items = set()
for _ in range(n):
    plen = struct.unpack("<I", f.read(4))[0]
    path = f.read(plen).rstrip(b"\x00").decode("utf-8", "replace")
    f.read(16); f.read(16)
    if path.startswith("res://items/all/") and "_icon" in path.rsplit("/", 1)[-1]:
        name = path.split("/all/")[1].split("/")[0]
        items.add(name)
items = sorted(items)
print(f"total items: {len(items)}")
targets = {
    "Vampire Fang": ["vampir", "fang", "tooth", "blood", "bite", "bat"],
    "Iron Lung": ["lung", "organ", "heart", "breath", "iron"],
    "Overclocked Chip": ["chip", "circuit", "cpu", "processor", "computer", "tech"],
    "Overtime Pay": ["money", "cash", "coin", "dollar", "gold", "paycheck", "work", "wage", "salary"],
    "Second Mortgage": ["mortgage", "house", "home", "loan", "bank", "key", "deed"],
    "Voodoo Potato": ["voodoo", "doll", "curse", "hex", "witch", "totem"],
    "Energy Drink": ["energy", "drink", "can", "bottle", "soda", "cola", "juice"],
    "Loaded Dice": ["dice", "gambling", "poker", "card"],
    "Tin Foil Hat": ["hat", "cap", "helmet", "foil", "tin"],
    "Potato Peeler": ["peeler", "knife", "tool", "potato", "spatula", "kitchen"],
}
for name, keys in targets.items():
    hits = [i for i in items if any(k in i.lower() for k in keys)]
    print(f"\n{name}:", hits if hits else "no collisions")
