import struct
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
import sys
pattern = sys.argv[1] if len(sys.argv) > 1 else ""
for path, off, size in entries:
    if pattern in path:
        print(path)
