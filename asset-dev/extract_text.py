import struct, sys, os
p = "/Users/nicolassutcliffe/Library/Application Support/Steam/steamapps/common/Brotato/Brotato.app/Contents/Resources/Brotato.pck"
f = open(p, "rb")
assert f.read(4) == b"GDPC"
f.read(4); f.read(12); f.read(16 * 4)
n = struct.unpack("<I", f.read(4))[0]
entries = {}
for _ in range(n):
    plen = struct.unpack("<I", f.read(4))[0]
    path = f.read(plen).rstrip(b"\x00").decode("utf-8", "replace")
    off, size = struct.unpack("<QQ", f.read(16)); f.read(16)
    entries[path] = (off, size)

for target in sys.argv[1:]:
    if target not in entries:
        print(f"=== NOT FOUND: {target} ===")
        continue
    off, size = entries[target]
    f.seek(off)
    data = f.read(size)
    print(f"=== {target} ({size} bytes) ===")
    try:
        print(data.decode("utf-8"))
    except UnicodeDecodeError:
        print("[binary]", data[:80])
    print()
