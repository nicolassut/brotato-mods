#!/usr/bin/env python3
"""Phase 8 - assemble the distributable Workshop mod ZIPs.

Zip layout (ModLoader convention; the loader mounts the whole zip via
ProjectSettings.load_resource_pack, so payload files sit at their TRUE res://
paths next to the mods-unpacked/ part):

  mods-unpacked/<ModName>/manifest.json
  mods-unpacked/<ModName>/mod_main.gd
  mods-unpacked/<ModName>/translations.csv
  mods-unpacked/<ModName>/extensions/**        (Core only)
  <payload files at their true res:// paths>   (from payload_manifest.json,
                                                materialized from the live
                                                tree ~/brotato-decompiled)

Output: workshop/dist/<ModName>.zip (regenerated from scratch; dist/ is not
committed). Run AFTER build_workshop.py.
"""
import os, json, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "workshop")
LIVE = os.path.expanduser("~/brotato-decompiled")
DIST = os.path.join(OUT, "dist")

MOD_FILE_KEEP = {"manifest.json", "mod_main.gd", "translations.csv",
                 "content_manifest.json", "payload_manifest.json"}


def build_zip(mod_name):
    mod_dir = os.path.join(OUT, mod_name)
    manifest = json.load(open(os.path.join(mod_dir, "payload_manifest.json")))
    zpath = os.path.join(DIST, mod_name + ".zip")
    n_mod = n_payload = 0
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _dirs, files in os.walk(mod_dir):
            for f in files:
                p = os.path.join(root, f)
                rel = os.path.relpath(p, mod_dir)
                if rel in MOD_FILE_KEEP or rel.startswith("extensions" + os.sep):
                    z.write(p, "mods-unpacked/%s/%s" % (mod_name, rel))
                    n_mod += 1
        for rel in manifest["files"]:
            src = os.path.join(LIVE, rel)
            if not os.path.isfile(src):
                raise SystemExit("payload file missing from live tree: %s"
                                 % rel)
            z.write(src, rel)
            n_payload += 1
    size = os.path.getsize(zpath) / 1e6
    print("%-28s %4d mod files + %4d payload files  %6.1f MB"
          % (mod_name + ".zip", n_mod, n_payload, size))


def main():
    os.makedirs(DIST, exist_ok=True)
    for old in os.listdir(DIST):
        if old.endswith(".zip"):
            os.remove(os.path.join(DIST, old))
    mods = sorted(d for d in os.listdir(OUT)
                  if os.path.isfile(os.path.join(OUT, d,
                                                 "payload_manifest.json")))
    if not mods:
        raise SystemExit("no mods with payload manifests - run "
                         "build_workshop.py first")
    for mod_name in mods:
        build_zip(mod_name)


if __name__ == "__main__":
    main()
