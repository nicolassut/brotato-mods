import struct, re
p = "/Users/nicolassutcliffe/Library/Application Support/Steam/steamapps/common/Brotato/Brotato.app/Contents/Resources/Brotato.pck"
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

keys = set()
struct_related = []
for path, off, size in entries:
    if "_effect" in path and path.endswith(".tres"):
        f.seek(off)
        data = f.read(size).decode("utf-8", "replace")
        m = re.search(r'^key = "([^"]*)"', data, re.M)
        if m:
            keys.add(m.group(1))
        if "curse" in data.lower() or "structure" in data.lower():
            struct_related.append((path, data))

print("=== all stat keys found across vanilla item/character effects ===")
for k in sorted(keys):
    print(k)

print("\n=== effect files mentioning curse/structure ===")
for path, data in struct_related[:10]:
    print("---", path)
    print(data)
