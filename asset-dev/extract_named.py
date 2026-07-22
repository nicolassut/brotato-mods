import struct, os, sys
p = "/Users/nicolassutcliffe/Library/Application Support/Steam/steamapps/common/Brotato/Brotato.app/Contents/Resources/Brotato.pck"
out = "/Users/nicolassutcliffe/brotato-mods/asset-dev/brotato-real-icons"
os.makedirs(out, exist_ok=True)
want = set(sys.argv[1].split(","))
f = open(p, "rb")
assert f.read(4) == b"GDPC"
f.read(4); f.read(12); f.read(16 * 4)
n = struct.unpack("<I", f.read(4))[0]
entries = []
for _ in range(n):
    plen = struct.unpack("<I", f.read(4))[0]
    path = f.read(plen).rstrip(b"\x00").decode("utf-8", "replace")
    off, size = struct.unpack("<QQ", f.read(16)); f.read(16)
    entries.append((path, off, size))


def carve(data):
    i = data.find(b"RIFF")
    if i >= 0 and data[i + 8:i + 12] == b"WEBP":
        sz = struct.unpack("<I", data[i + 4:i + 8])[0]
        return data[i:i + 8 + sz]
    return None


for path, off, size in entries:
    if not path.endswith(".stex") or "_icon.png-" not in path:
        continue
    base = path.split("/")[-1].split(".png-")[0].replace("_icon", "")
    if base in want:
        f.seek(off); blob = carve(f.read(size))
        if blob:
            with open(f"{out}/{base}.webp", "wb") as w:
                w.write(blob)
            print("saved", base)
