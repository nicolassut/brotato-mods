#!/usr/bin/env python3
"""Ecosystem Phase 8 - Workshop packaging toolchain (scaffold stage).

Generates `workshop/` from the current repo state:
  - nicolassut-GourmetCore/   manifest + mod_main stub + the CORE SURFACE inventory
    (every game-src engine file = a future script-extension target)
  - nicolassut-Gourmet<Pack>/ per pack: manifest (depends on Core) + mod_main stub +
    content_manifest.json (every resource path the pack registers, from its pack tres)
  - WORKSHOP_READINESS.md     the honest state report: what is packageable today,
    what blocks real packaging, and the conversion debt per engine file

This stage ships NO distribution and produces NO working mods - it is the
measurement + skeleton layer the actual conversion fills in. Idempotent:
regenerates everything from scratch on each run.
"""
import os, re, json, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_extensions
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "workshop")
PACKS = ["food", "fortune", "forge", "ledger", "roster"]
GAME_VERSION = "1.1.15.4"

# files that are PACK data or generated, not Core engine surface
NON_CORE_PREFIXES = ("packs/", "items/custom/p2w/p2w_data.gd", "items/upgrades/appetite/",
                     "items/custom/custom_translations.csv", "items/upgrades/appetite/stomach.png")


def manifest(name, description, dependencies):
    return {
        "name": name, "namespace": "nicolassut", "version_number": "0.1.0",
        "description": description,
        "website_url": "https://github.com/nicolassut/brotato-mods",
        "dependencies": dependencies,
        "extra": {"godot": {
            "incompatibilities": [], "authors": ["nicolassut"],
            "compatible_mod_loader_version": "6.x",
            "compatible_game_version": [GAME_VERSION],
            "config_defaults": {},
        }},
    }


def pack_content(pack_id):
    text = open(f"{REPO}/game-src/packs/{pack_id}/pack_data.tres").read()
    paths = re.findall(r'\[ext_resource path="res://([^"]+)" type="Resource"', text)
    return [p for p in paths if p != "packs/pack_data.gd"]


def main():
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)

    # ---- core surface inventory ----
    core_files = []
    for root, _dirs, files in os.walk(f"{REPO}/game-src"):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), f"{REPO}/game-src")
            if rel == "README.md" or any(rel.startswith(p) for p in NON_CORE_PREFIXES):
                continue
            core_files.append(rel)
    core_files.sort()
    gd_files = [f for f in core_files if f.endswith(".gd")]
    other_files = [f for f in core_files if not f.endswith(".gd")]

    # With the pristine reference present (~/brotato-vanilla-reference, GDRE
    # v2.6.0 recovery of the Steam pck), the surface splits into REAL diffs:
    # modified-vanilla files (extension targets, with line counts), mod-ADDED
    # files (ship as-is, no extension needed), and precautionary mirrors
    # (identical to vanilla - not Core surface at all).
    import subprocess
    van = os.path.expanduser("~/brotato-vanilla-reference")
    diffed, added, identical = [], [], []
    if os.path.isdir(van):
        for f in gd_files:
            vpath = os.path.join(van, f)
            if not os.path.exists(vpath):
                added.append(f)
            elif subprocess.run(["cmp", "-s", vpath, f"{REPO}/game-src/{f}"]).returncode == 0:
                identical.append(f)
            else:
                n = int(subprocess.run(["bash", "-c", "diff '%s' '%s/game-src/%s' | grep -c '^[<>]'" % (vpath, REPO, f)],
                                       capture_output=True, text=True).stdout.strip() or 0)
                diffed.append({"file": f, "diff_lines": n})
        diffed.sort(key=lambda d: -d["diff_lines"])

    core_dir = os.path.join(OUT, "nicolassut-GourmetCore")
    os.makedirs(os.path.join(core_dir, "extensions"))
    json.dump(manifest("GourmetCore",
                       "Gourmet ecosystem base: engine extensions, PackService, game modes, the Hub. All Gourmet packs depend on this.",
                       []),
              open(os.path.join(core_dir, "manifest.json"), "w"), indent="\t")
    json.dump({"script_extension_targets": diffed if diffed else gd_files,
               "mod_added_scripts": added, "precautionary_mirrors_identical": identical,
               "non_script_surface": other_files},
              open(os.path.join(core_dir, "core_surface.json"), "w"), indent=1)
    # ---- REAL extensions: generated per-function diff vs the pristine tree ----
    targets = sorted(d["file"] for d in diffed)
    if not targets:
        raise SystemExit("no pristine reference found - cannot generate extensions")
    installed, errors, _audit = gen_extensions.generate(
        targets, f"{REPO}/game-src", core_dir)
    if errors:
        raise SystemExit(
            "extension generation FAILED for %d file(s) - see %s/AUDIT.md"
            % (len(errors), core_dir))
    ext_list = "\n".join('\t"%s",' % rel for rel in installed)
    open(os.path.join(core_dir, "mod_main.gd"), "w").write(
"""extends Node

# GourmetCore mod entry (GENERATED by asset-dev/build_workshop.py - DO NOT EDIT)
#
# 1. installs a script extension for every vanilla .gd the ecosystem modifies
#    (generated from a per-function diff against the pristine 1.1.15.4 tree)
# 2. root-injects the 5 custom services as runtime pseudo-autoloads
#    (project.godot cannot be patched by a mod). Node names MUST match the
#    live-tree autoload names: Utils.packs & co resolve /root/<Name> in both
#    worlds.
# 3. registers the "interact" input action (lobby NPCs) via InputMap.
#
# ONLY ModLoaderMod.install_script_extension works on autoload scripts - the
# deprecated ModLoader.install_script_extension shim silently no-ops there
# (probe-proven 2026-08-18).

const LOG_NAME = "nicolassut-GourmetCore"
const EXT_ROOT = "res://mods-unpacked/nicolassut-GourmetCore/extensions/"

const SERVICES = [
	["GourmetTracker", "res://singletons/gourmet_tracker.gd"],
	["ButcherSkin", "res://singletons/butcher_skin.gd"],
	["SpecialModifiers", "res://singletons/special_modifiers.gd"],
	["Packs", "res://singletons/pack_service.gd"],
	["GameModes", "res://singletons/game_mode_service.gd"],
]

const EXTENSIONS = [
%s
]


func _init(modLoader = ModLoader):
	ModLoaderUtils.log_info("Init", LOG_NAME)
	for ext in EXTENSIONS:
		ModLoaderMod.install_script_extension(EXT_ROOT.plus_file(ext))


func _ready():
	ModLoaderUtils.log_info("Ready", LOG_NAME)
	_register_interact_action()
	# IMMEDIATE add_child - call_deferred lands after the autoload phase, too
	# late (probe-proven 2026-08-18). The service NODES must exist at /root
	# before ProgressData._ready drives Packs.apply_at_boot; their own _ready
	# fires after every vanilla autoload's, same relative order as the live
	# tree where they are the last autoloads.
	var tree_root = get_tree().get_root()
	for svc in SERVICES:
		if tree_root.has_node(svc[0]):
			continue
		var node = load(svc[1]).new()
		node.name = svc[0]
		tree_root.add_child(node)


func _register_interact_action() -> void :
	# mirrors the live-tree project.godot action: E + gamepad button 3
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact", 0.5)
	var key = InputEventKey.new()
	key.scancode = KEY_E
	InputMap.action_add_event("interact", key)
	var joy = InputEventJoypadButton.new()
	joy.button_index = 3
	InputMap.action_add_event("interact", joy)
""" % ext_list)
    print(f"generated {len(installed)} extensions + real mod_main.gd")

    # ---- per-pack mods ----
    for pack_id in PACKS:
        content = pack_content(pack_id)
        pack_dir = os.path.join(OUT, "nicolassut-Gourmet%s" % pack_id.capitalize())
        os.makedirs(pack_dir)
        json.dump(manifest("Gourmet%s" % pack_id.capitalize(),
                           "Gourmet ecosystem pack: %s (%d resources). Requires GourmetCore." % (pack_id, len(content)),
                           ["nicolassut-GourmetCore"]),
                  open(os.path.join(pack_dir, "manifest.json"), "w"), indent="\t")
        json.dump({"pack_id": pack_id, "resources": content},
                  open(os.path.join(pack_dir, "content_manifest.json"), "w"), indent=1)
        open(os.path.join(pack_dir, "mod_main.gd"), "w").write(
"""extends Node

# Gourmet%s pack mod entry (SCAFFOLD). Real implementation: ship this pack's
# resource files + pack_data.tres inside the mod, then hand the pack to
# GourmetCore's PackService for registration (content_manifest.json is the
# authoritative file list to bundle).

func _init(modLoader = ModLoader):
	pass
""" % pack_id.capitalize())
        print(f"scaffolded {os.path.basename(pack_dir)}: {len(content)} resources")

    # ---- readiness report ----
    hook_marked = sum(1 for f in gd_files if "Gourmet" in open(f"{REPO}/game-src/{f}").read())
    report = f"""# WORKSHOP_READINESS - Phase 8 state (generated by build_workshop.py)

## What exists
- {len(PACKS)} pack mod scaffolds + GourmetCore scaffold under `workshop/` (manifests
  validate against the ModLoader schema used by the working prototypes in
  `mods-unpacked/`).
- Pack content manifests are REAL: generated from the live pack tres files, so the
  data side of packaging is already mechanical.

## Core surface (what GourmetCore must carry) - MEASURED against pristine vanilla
- {len(diffed) if diffed else len(gd_files)} vanilla .gd files actually modified (extension targets, ranked by
  diff-line count in `core_surface.json`; top: {diffed[0]["file"] + " at " + str(diffed[0]["diff_lines"]) + " lines" if diffed else "n/a"}).
- {len(added)} mod-ADDED scripts (ship as files, no extension machinery needed).
- {len(identical)} precautionary mirrors identical to vanilla (not Core surface).
- {len(other_files)} non-script files (scenes/config/art) needing other strategies.
- {hook_marked}/{len(gd_files)} .gd files carry Gourmet-marked edits.

## Blockers before real packaging (ordered)
1. ~~Pristine decompile~~ **RESOLVED 2026-08-18**: `~/brotato-vanilla-reference/` is a
   GDRE v2.6.0 recovery of the Steam pck ({GAME_VERSION}), determinism-validated
   (untouched files byte-identical, 445/445 scripts). Regenerable: GDRE Tools in
   ~/Downloads, `--headless --recover=<pck> --output=<dir>`. Full-game sweep found
   exactly ONE unmirrored edit (debug_service.gd - the known local-only debug block).
2. ~~Autoload strategy~~ **RESOLVED BY EXPERIMENT 2026-08-18** (disposable-clone
   probes, real trees untouched; full backups taken first). Findings:
   - Script extensions via `ModLoaderMod.install_script_extension` WORK ON
     AUTOLOAD SCRIPTS (utils.gd + progress_data.gd proven) - the deprecated
     `ModLoader.install_script_extension` shim does NOT; never use it.
   - The critical ordering survives: an extension of ProgressData._ready runs
     BEFORE the vanilla body loads the save - packs-before-save-load holds.
   - Service root-injection: add_child must be IMMEDIATE from the mod's _ready
     (call_deferred lands after the autoload phase - too late).
   - Bare autoload identifiers are PARSE-FATAL on installs lacking them (655
     cascade errors with Packs/GameModes removed). Strategy: host services on
     an extension of an always-present vanilla autoload and rewrite references
     mechanically. Measured burden: Packs. x11, GameModes. x8, GourmetTracker.
     x66, SpecialModifiers. x19, ButcherSkin. x5 = 109 references total.
3. ~~project.godot input action~~ **RESOLVED**: Core's mod_main registers
   `interact` (E + gamepad button 3) via InputMap at runtime.
4. ~~item_service.tscn / scene diffs~~ **RESOLVED**: zero vanilla scenes ship.
   The item_service.tscn diff (5 vanilla item removals + `foods` export) is a
   guarded runtime prune + an extension export default; the pause.tscn diff
   (blobfish margins) is patched from the pause.gd extension. The 8 mod-ADDED
   scenes ship as files.
5. **Extensions are now GENERATED** (extensions/ + AUDIT.md, per-function diff
   vs the pristine tree; dict merges at _init, verified-safe inner-class
   redeclarations). Remaining before the clone gate can pass:
   - the 109 bare service references must be rewritten to the Utils accessors
     (extensions currently inherit whatever game-src has)
   - pack payload assembly: art/scripts/tres at their true res:// paths +
     .import/.stex entries, per-pack translations
   - end-to-end disposable-clone gate (check_workshop.sh)

## Law
Regenerate this report after any engine change: `python3 asset-dev/build_workshop.py`.
The scaffolds are throwaway; the inventories are the deliverable.
"""
    open(os.path.join(OUT, "WORKSHOP_READINESS.md"), "w").write(report)
    print(f"core surface: {len(gd_files)} .gd + {len(other_files)} other; report written")


if __name__ == "__main__":
    main()
