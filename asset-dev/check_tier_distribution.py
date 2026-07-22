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

from collections import Counter
tier_counts = Counter()
examples = {}
for path, off, size in entries:
    if path.startswith("res://items/all/") and path.endswith("_data.tres"):
        f.seek(off)
        data = f.read(size).decode("utf-8", "replace")
        m_tier = None
        for line in data.splitlines():
            if line.startswith("tier = "):
                m_tier = int(line.split("=")[1].strip())
        if m_tier is not None:
            tier_counts[m_tier] += 1
            examples.setdefault(m_tier, []).append(path.split("/")[-1])

print("tier value distribution across all vanilla items:")
for t in sorted(tier_counts):
    print(f"  tier={t}: {tier_counts[t]} items, e.g. {examples[t][:5]}")
