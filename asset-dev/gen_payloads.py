#!/usr/bin/env python3
"""Phase 8 - per-mod PAYLOAD manifests + per-mod translation CSVs.

A workshop mod carries two kinds of files:
  - its mods-unpacked/<name>/ part (manifest, mod_main, extensions) - committed
    under workshop/<name>/
  - its PAYLOAD: files overlaid at their TRUE res:// paths (content tres, art
    + .import/.stex, mod-added scripts/scenes). Payloads are NOT copied into
    the repo (art would bloat it) - this module emits payload_manifest.json
    per mod; the zip assembler and the clone gate materialize from the live
    tree (~/brotato-decompiled).

The payload UNIVERSE is measured, not declared: every file in the live tree
that does not exist in the pristine reference (minus explicit exclusions) must
land in EXACTLY ONE payload - nothing mod-added is ever silently dropped.
Assignment rules, in order:
  1. referenced from Core-shipped code (extensions/services literals,
     transitively) -> Core (Core must be self-contained: extensions preload)
  2. in exactly one pack's content closure -> that pack
  3. in 2+ pack closures -> Core (shared)
  4. leftover -> Core (audited)
Modified-vanilla NON-script files: the known set only (project.godot + the two
runtime-patched scenes are excluded; the items/all tag-edit tres ship as FOOD
overlays). Any unknown modified vanilla non-gd file is a HARD ERROR.
The dlcs/ tree is the decompiled PAID DLC: never shipped, hard-excluded (its
one Gourmet edit ships as the DLC-guarded hand extension).

Translations: items/custom/custom_translations.csv (sacred source) is split
per pack by searching each row's key in the pack's payload text corpus;
unclaimed or multi-claimed rows go to Core. The split must reproduce the
original row set exactly. Each mod runtime-loads its own CSV in mod_main.
"""
import os, re, csv, json, subprocess

VAN = os.path.expanduser("~/brotato-vanilla-reference")
LIVE = os.path.expanduser("~/brotato-decompiled")

SKIP_PREFIXES = (".git/", ".import/", "mods-unpacked/", "logs/", "dlcs/",
                 ".DS_Store", "tools/output/")
SKIP_SUFFIXES = (".md5", ".DS_Store", ".gdignore", ".log", ".tmp")
SKIP_EXACT = {
    "gdre_export.log",
    "export_presets.cfg",
    "override.cfg",
    ".gitignore",
    # stray dev screenshot saved into the live tree root
    "Screenshot 2026-07-30 at 11.39.03.png",
    # the sacred CSV is replaced by the per-mod split (runtime-loaded);
    # the compiled .translation + importer sidecar stay live-tree-only
    "items/custom/custom_translations.csv",
    "items/custom/custom_translations.csv.import",
    "items/custom/custom_translations.en.translation",
}

# Deregistered content still on disk (build_appetite_items.py DEREGISTERED,
# ECOSYSTEM open cleanup item) - dead files, deliberately unshipped. If one is
# ever revived into a pack, the pack claim wins and the assert below fires so
# this list gets pruned.
UNSHIPPED_PREFIXES = tuple(
    "items/custom/%s/" % slug for slug in
    ("bib", "rumbling_belly", "family_recipe", "growth_spurt", "tapeworm",
     "executive_palate", "nutrient_paste", "meal_in_a_pill", "nervous_wreck",
     "gastric_band"))

# Dynamically-loaded assets (path built at runtime - invisible to the closure)
# with a hand-declared owner. The full dynamic-loader inventory (grep for
# load("res://...% and path concatenation in game-src, 2026-08-18):
#   main.gd/p2w_reel.gd  items/custom/p2w/chest_%d      -> fortune
#   main.gd              items/foods/%s/%s_small.png    -> food (gumballs)
#   butcher_skin.gd      ICON_DIR/WORLD dir concat      -> food (Butcher-gated)
#   pack_service.gd      packs/<id>/pack_data.tres      -> closure-claimed
OWNER_OVERRIDES = {
    "items/custom/butcher_skin/": "food",
    "items/foods/": "food",
    "items/custom/p2w/": "forge",  # fortune merged into forge
}
# modified VANILLA files handled by other strategies (never payload)
MODIFIED_VANILLA_HANDLED = {
    "project.godot",                  # runtime InputMap / autoload injection
    "pause.tscn",                     # runtime margin patch (pause.gd ext)
    "singletons/item_service.tscn",   # runtime item prune + export default
    "gdre_export.log",
}

RES_REF = re.compile(r'res://[A-Za-z0-9_\-./]+')


def _skip(rel):
    return (rel.startswith(SKIP_PREFIXES) or rel.endswith(SKIP_SUFFIXES)
            or rel in SKIP_EXACT or "/.DS_Store" in rel)


def mod_added_universe():
    """Every live-tree file absent from the pristine reference (curated)."""
    out = set()
    for root, dirs, files in os.walk(LIVE):
        dirs[:] = [d for d in dirs
                   if d not in (".git", ".import", "mods-unpacked", "dlcs",
                                "logs")]
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), LIVE)
            if _skip(rel):
                continue
            # .import sidecars are never assigned on their own - they ride
            # with their asset via with_import_sidecars (an orphan sidecar
            # whose asset was deleted is junk and stays unshipped)
            if rel.endswith(".import"):
                continue
            if not os.path.isfile(os.path.join(VAN, rel)):
                out.add(rel)
    return out


def modified_vanilla_nongd():
    """Modified vanilla non-.gd files, minus the handled set. The items/all
    tag-edit tres are returned (they ship as Food overlays); anything else is
    a hard error."""
    modified = []
    for root, dirs, files in os.walk(VAN):
        dirs[:] = [d for d in dirs if d not in (".git", ".import")]
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), VAN)
            if rel.endswith(".gd") or _skip(rel) \
                    or rel in MODIFIED_VANILLA_HANDLED:
                continue
            lp = os.path.join(LIVE, rel)
            if not os.path.isfile(lp):
                continue
            if subprocess.run(["cmp", "-s", os.path.join(VAN, rel), lp],
                              ).returncode != 0:
                modified.append(rel)
    unknown = [r for r in modified
               if not (r.startswith("items/all/") and r.endswith(".tres"))]
    if unknown:
        raise SystemExit("UNKNOWN modified vanilla non-gd files (no shipping "
                         "strategy): %s" % sorted(unknown))
    return sorted(modified)


def res_refs(path):
    try:
        text = open(path, encoding="utf-8", errors="ignore").read()
    except OSError:
        return set()
    return {m.group(0)[6:] for m in RES_REF.finditer(text)}


def closure(seed_rels):
    """Transitive res:// closure over live-tree text resources. Returns every
    reachable EXISTING live file (caller filters vanilla ones out)."""
    seen, todo = set(), list(seed_rels)
    while todo:
        rel = todo.pop()
        if rel in seen:
            continue
        live = os.path.join(LIVE, rel)
        if not os.path.isfile(live):
            raise SystemExit("payload closure: missing live file: %s" % rel)
        seen.add(rel)
        if rel.endswith((".tres", ".tscn", ".gd")):
            for ref in res_refs(live):
                if ref not in seen and \
                        os.path.isfile(os.path.join(LIVE, ref)):
                    todo.append(ref)
    return seen


def with_import_sidecars(rels):
    """Add .png.import-style sidecars + their compiled dest files (.stex etc.
    from the live .import cache) for every payload asset that has one."""
    out = set(rels)
    for rel in list(rels):
        imp = os.path.join(LIVE, rel + ".import")
        if not os.path.isfile(imp):
            continue
        out.add(rel + ".import")
        for m in re.finditer(r'"res://(\.import/[^"]+)"', open(imp).read()):
            dest = m.group(1)
            if not os.path.isfile(os.path.join(LIVE, dest)):
                raise SystemExit("missing compiled import dest %s (for %s) - "
                                 "open the live tree in the Godot editor to "
                                 "reimport" % (dest, rel))
            out.add(dest)
    return out


def assign_payloads(pack_contents, core_code_files):
    """pack_contents: {pack_id: [content res paths]} (from the pack tres).
    core_code_files: absolute paths of Core-shipped .gd (extensions, mod_main)
    whose res:// literals pin files to Core.
    Returns ({owner: set(rels)}, audit_lines). owner = pack_id or 'core'."""
    audit = []
    universe = mod_added_universe()
    overlays = modified_vanilla_nongd()          # food tag-edit tres

    # pack closures, restricted to mod-added files
    pack_claims = {}
    for pid, content in pack_contents.items():
        seeds = set(content) | {"packs/%s/pack_data.tres" % pid}
        pack_claims[pid] = closure(seeds) & universe

    # Core code literals (transitively, via mod-added files they reference)
    core_seed_refs = set()
    for path in core_code_files:
        for ref in res_refs(path):
            if os.path.isfile(os.path.join(LIVE, ref)):
                core_seed_refs.add(ref)
    core_pinned = closure(core_seed_refs) & universe

    # corpus of every shippable text file - a file whose "/basename" appears
    # nowhere in it (and is not dynamically loaded per OWNER_OVERRIDES) is
    # DEAD: a stale leftover from an earlier build iteration, not shipped
    corpus_parts = []
    for root, dirs, files in os.walk(LIVE):
        dirs[:] = [d for d in dirs if d not in
                   (".git", ".import", "mods-unpacked", "dlcs", "logs")]
        for f in files:
            if f.endswith((".gd", ".tres", ".tscn", ".csv")):
                rel = os.path.relpath(os.path.join(root, f), LIVE)
                if not rel.startswith("tools/"):
                    corpus_parts.append(open(os.path.join(root, f),
                                             encoding="utf-8",
                                             errors="ignore").read())
    corpus = "\n".join(corpus_parts)

    assigned = {pid: set() for pid in pack_contents}
    assigned["core"] = set()
    unshipped, dead = [], []
    for rel in universe:
        claimers = [pid for pid, c in pack_claims.items() if rel in c]
        override = next((o for p, o in OWNER_OVERRIDES.items()
                         if rel.startswith(p)), None)
        if rel.startswith(UNSHIPPED_PREFIXES):
            if claimers or rel in core_pinned:
                raise SystemExit("UNSHIPPED file is actually claimed (%s / "
                                 "core_pinned=%s) - prune UNSHIPPED_PREFIXES: "
                                 "%s" % (claimers, rel in core_pinned, rel))
            unshipped.append(rel)
        elif rel in core_pinned:
            assigned["core"].add(rel)
            if len(claimers) == 1:
                audit.append("core-pinned (referenced by Core code) despite "
                             "pack claim %s: %s" % (claimers[0], rel))
        elif override is not None:
            assigned[override].add(rel)
        elif len(claimers) == 1:
            assigned[claimers[0]].add(rel)
        elif len(claimers) > 1:
            assigned["core"].add(rel)
            audit.append("shared by packs %s -> core: %s"
                         % (sorted(claimers), rel))
        elif "/" + os.path.basename(rel) not in corpus:
            dead.append(rel)
            audit.append("DEAD (unreferenced by any shippable file) - not "
                         "shipped: %s" % rel)
        else:
            assigned["core"].add(rel)
            audit.append("unclaimed -> core (leftover): %s" % rel)
    audit.append("deliberately unshipped (deregistered content): %d files; "
                 "dead unreferenced files: %d" % (len(unshipped), len(dead)))

    # the food tag-edit overlays (modified vanilla tres)
    for rel in overlays:
        assigned["food"].add(rel)
    audit.append("food overlays (modified vanilla tag-edit tres): %d"
                 % len(overlays))

    # import sidecars ride with their owner
    for owner in assigned:
        assigned[owner] = with_import_sidecars(assigned[owner])

    # exactly-once guarantee (sidecars/dests may repeat across owners only if
    # the same asset were double-assigned - which the rules prevent)
    flat = [r for s in assigned.values() for r in s]
    dupes = {r for r in flat if flat.count(r) > 1}
    if dupes:
        raise SystemExit("payload double-assignment: %s" % sorted(dupes)[:10])
    return assigned, audit


def split_translations(assigned):
    """Split the sacred CSV per owner by searching keys in each pack's payload
    text corpus. Returns ({owner: [rows]}, header, audit). Core gets unclaimed
    + multi-claimed rows. Union must equal the original exactly."""
    src = os.path.join(LIVE, "items/custom/custom_translations.csv")
    with open(src, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = [r for r in reader if r and r[0].strip() != ""]

    corpora = {}
    for owner, rels in assigned.items():
        if owner == "core":
            continue
        texts = []
        for rel in rels:
            if rel.endswith((".tres", ".tscn", ".gd", ".csv")):
                texts.append(open(os.path.join(LIVE, rel), encoding="utf-8",
                                  errors="ignore").read())
        corpora[owner] = "\n".join(texts)

    out = {owner: [] for owner in assigned}
    audit = []
    for row in rows:
        key = row[0]
        pat = re.compile(r'\b%s\b' % re.escape(key))
        claimers = [o for o, c in corpora.items() if pat.search(c)]
        if len(claimers) == 1:
            out[claimers[0]].append(row)
        else:
            out["core"].append(row)
            if len(claimers) > 1:
                audit.append("translation row %s claimed by %s -> core"
                             % (key, sorted(claimers)))
    total = sum(len(v) for v in out.values())
    if total != len(rows):
        raise SystemExit("translation split lost rows: %d != %d"
                         % (total, len(rows)))
    audit.append("translation rows: " + ", ".join(
        "%s:%d" % (o, len(v)) for o, v in sorted(out.items())))
    return out, header, audit
