import re

TSCN = "/Users/nicolassutcliffe/brotato-decompiled/singletons/item_service.tscn"

item_paths = []
with open("/tmp/decompiled_item_paths.txt") as f:
    for line in f:
        item_id, name, path = line.strip().split("|")
        item_paths.append((item_id, name, path))

char_path = "res://items/custom_characters/test_character/test_character_data.tres"

with open(TSCN) as f:
    content = f.read()

# 1. bump load_steps
m = re.search(r"\[gd_scene load_steps=(\d+) format=2\]", content)
old_load_steps = int(m.group(1))
new_ext_count = len(item_paths) + 1  # +1 for character
new_load_steps = old_load_steps + new_ext_count
content = content.replace(
    f"[gd_scene load_steps={old_load_steps} format=2]",
    f"[gd_scene load_steps={new_load_steps} format=2]",
    1,
)

# 2. insert new [ext_resource] lines right after the last existing one
start_id = 800
new_ext_lines = []
item_ids = []
next_id = start_id
for item_id, name, path in item_paths:
    new_ext_lines.append(f'[ext_resource path="{path}" type="Resource" id={next_id}]')
    item_ids.append(next_id)
    next_id += 1
char_id = next_id
new_ext_lines.append(f'[ext_resource path="{char_path}" type="Resource" id={char_id}]')

# find the position right before the first "[sub_resource" or "[node" (end of ext_resource block)
insert_marker = re.search(r"\n(\[sub_resource|\[node)", content)
insert_pos = insert_marker.start()
content = content[:insert_pos] + "\n" + "\n".join(new_ext_lines) + content[insert_pos:]

# 3. extend items = [ ... ] and characters = [ ... ] arrays
def extend_array(content, prop_name, new_ids):
    pattern = re.compile(rf"^{prop_name} = \[ (.*) \]$", re.M)
    m = pattern.search(content)
    if not m:
        raise SystemExit(f"could not find {prop_name} array")
    existing = m.group(1)
    new_refs = ", ".join(f"ExtResource( {i} )" for i in new_ids)
    new_line = f"{prop_name} = [ {existing}, {new_refs} ]"
    return content[:m.start()] + new_line + content[m.end():]

content = extend_array(content, "items", item_ids)
content = extend_array(content, "characters", [char_id])

with open(TSCN, "w") as f:
    f.write(content)

print(f"Patched {TSCN}")
print(f"  load_steps: {old_load_steps} -> {new_load_steps}")
print(f"  new item ext_resource ids: {item_ids}")
print(f"  new character ext_resource id: {char_id}")
