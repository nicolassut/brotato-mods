#!/usr/bin/env python3
"""Phase 8 - GourmetCore script-extension GENERATOR.

For every vanilla .gd that game-src modifies, emit a ModLoader script extension:
    extends "res://<original path>"
    + declarations that exist only in the modified file (position-independent)
    + full bodies of modified + new top-level functions

Invoked by build_workshop.py (workshop/ is regenerated wholesale). Never edit
the emitted files - encode every hand-audit resolution HERE so regeneration
stays idempotent.

Fail-loud guards (generator refuses to emit silently-wrong extensions):
  - a shared declaration whose text CHANGED (child cannot redeclare a parent
    member) without an encoded resolution below
  - a vanilla declaration or function REMOVED in the modified file
  - a modified inner class without a verified-safe redeclaration entry
Everything flagged lands in workshop/nicolassut-GourmetCore/AUDIT.md.

Encoded resolutions:
  DICT_MERGE_DECLS  - shared dict vars that only GAIN entries: the extension
      keeps the parent declaration and merges the added entries in _init
      (instantiation time - BEFORE any autoload's _ready can read them; the
      earliest reader of all three is the ProgressData._ready DLC/pack flow).
  SAFE_REDECLARED_CLASSES - inner classes redeclared in the child; safe only
      when EVERY top-level function referencing the class is itself emitted,
      which gen() re-verifies mechanically on every run.
  EXTRA_SNIPPETS / INJECT_CALLS - hand-written runtime patches replacing the
      two scene diffs (item_service.tscn item prune, pause.tscn blobfish).
"""
import os, re

VAN = os.path.expanduser("~/brotato-vanilla-reference")

STARTER = re.compile(
    r'^(extends\b|tool\b|class_name\b|signal\s|const\s|var\s|export\b|onready\s'
    r'|enum\b|static\s+func\s|func\s|class\s)')
FUNC_NAME = re.compile(r'^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)')
DECL_NAME = re.compile(
    r'^(?:export\s*(?:\([^)]*\))?\s*)?(?:onready\s+)?(?:const|var|signal)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)')
ENUM_NAME = re.compile(r'^enum\s+([A-Za-z_][A-Za-z0-9_]*)?')
CLASS_NAME = re.compile(r'^class\s+([A-Za-z_][A-Za-z0-9_]*)')

# ---- hand-audit resolutions --------------------------------------------------

# {file: {dict_var_name: func_to_call_merge_from}} - the merge target func is
# force-included (or synthesized) and the generated _gourmet_merge_<var>() call
# is injected at its top. _init = instantiation time, see module docstring.
DICT_MERGE_DECLS = {
    "singletons/run_data.gd": {"init_tracked_items": "_init"},
    "singletons/item_service.gd": {"item_groups": "_init"},
    "singletons/text.gd": {"keys_needing_operator": "_init"},
}

# Extensions with NO pristine baseline: the Abyssal Terrors DLC pck is not
# part of the vanilla reference, so dlc_1_data.gd cannot be diffed. The listed
# segments are the hand-identified Gourmet edits, emitted verbatim from
# game-src. A guard errors if any OTHER segment of the file carries a Gourmet
# marker (keeps future edits honest). These do NOT go into mod_main's install
# list - the DLC pck mounts inside ProgressData._ready (load_dlc_pcks), so the
# progress_data extension installs them LATE, guarded on the DLC being present
# (ModLoaderMod.install_script_extension applies immediately outside the init
# phase - verified against addons/mod_loader/api/mod.gd).
HAND_EXTENSIONS = {
    "dlcs/dlc_1/dlc_1_data.gd": ["FREELOADER_CURSE_CHANCE",
                                 "update_item_effects"],
}

# {file: {func: [(anchor_line_stripped, [lines to insert after it])]}} -
# mid-function insertion into an emitted function body.
INSERT_AFTER = {
    "singletons/progress_data.gd": {
        "_ready": [("load_dlc_pcks()", ["\t_gourmet_install_dlc_extension()"])],
    },
}

# {file: [inner class names]} - verified safe to redeclare (see gen() check)
SAFE_REDECLARED_CLASSES = {
    "ui/menus/pages/sort_inventory_button.gd": ["SortInventory"],
    "ui/menus/pages/menu_codex.gd": ["SortItem"],
}

# (file, ClassName) stale-binding references verified HARMLESS: the referenced
# member is byte-identical between vanilla and extension, so binding the
# vanilla class object early changes nothing. main.gd/UpgradesUI: only the
# vanilla inner classes are referenced (p2w rung rides in meta, 2026-08-18).
STALE_BINDING_OK = {("main.gd", "UpgradesUI")}

# Hand-written code appended to specific extensions (runtime patches for the
# two scene diffs - ZERO vanilla scenes ship in Core).
EXTRA_SNIPPETS = {
    # the 5 deliberate vanilla item removals that used to live in
    # item_service.tscn's pruned items array (Gourmet foods supersede them).
    # Guarded + injected at every pre-_ready read path of `items`
    # (init_unlocked_pool / reset_tiers_data run from ProgressData._ready).
    "singletons/item_service.gd": '''
# --- GourmetCore runtime patch: the 5 vanilla items removed by the mod ---
# (was: pruned from item_service.tscn's items array; a mod cannot ship a scene)
const GOURMET_REMOVED_VANILLA_ITEMS = ["item_cake", "item_coffee",
\t"item_fried_rice", "item_honey", "item_fresh_meat"]
var _gourmet_vanilla_items_pruned: = false

func _gourmet_core_remove_vanilla_items() -> void :
\tif _gourmet_vanilla_items_pruned:
\t\treturn
\tif items.empty():
\t\treturn
\t_gourmet_vanilla_items_pruned = true
\tvar kept = []
\tfor i in items:
\t\tif not GOURMET_REMOVED_VANILLA_ITEMS.has(i.my_id):
\t\t\tkept.push_back(i)
\titems = kept
''',
    # the Gourmet edits to the Abyssal Terrors DLC script can only install
    # AFTER load_dlc_pcks() mounts the DLC pck, and only for DLC owners (the
    # child script cannot even parse without its base)
    "singletons/progress_data.gd": '''
# --- GourmetCore: late script extension for the Abyssal Terrors DLC ---
func _gourmet_install_dlc_extension() -> void :
\tif not ResourceLoader.exists("res://dlcs/dlc_1/dlc_1_data.gd"):
\t\treturn
\tModLoaderMod.install_script_extension("res://mods-unpacked/nicolassut-GourmetCore/extensions/dlcs/dlc_1/dlc_1_data.gd")
''',
    # pause.tscn's only diff: the blobfish easter-egg Control re-anchored from
    # (940,520)..(980,560) to centered -20..20 - patched at runtime instead
    "pause.gd": '''
# --- GourmetCore runtime patch: pause.tscn blobfish margins (scene diff) ---
func _gourmet_core_patch_blobfish() -> void :
\tvar blobfish = get_node_or_null("blobfish")
\tif blobfish == null:
\t\treturn
\tblobfish.margin_left = - 20.0
\tblobfish.margin_top = - 20.0
\tblobfish.margin_right = 20.0
\tblobfish.margin_bottom = 20.0
''',
}

# {file: {func: [lines to inject right after the func header]}} - the func is
# force-included even if unmodified, or synthesized if it does not exist.
INJECT_CALLS = {
    "singletons/item_service.gd": {
        "_ready": ["\t_gourmet_core_remove_vanilla_items()"],
        "init_unlocked_pool": ["\t_gourmet_core_remove_vanilla_items()"],
        "reset_tiers_data": ["\t_gourmet_core_remove_vanilla_items()"],
    },
    "pause.gd": {"_ready": ["\t_gourmet_core_patch_blobfish()"]},
    # force-include (no injection): these unmodified funcs are the only
    # reference sites of the redeclared sort-functor classes - copying them
    # into the child binds SortInventory/SortItem to the child's class
    "ui/menus/pages/sort_inventory_button.gd": {"_sort_inventory": []},
    "ui/menus/pages/menu_codex.gd": {"_pop": []},
}

# ---- parsing -----------------------------------------------------------------


def _strip_code(line):
    """Remove string contents and comments so bracket/colon scanning is safe.
    Replaces string contents with spaces (keeps indices aligned)."""
    out, i, n, q = [], 0, len(line), None
    while i < n:
        c = line[i]
        if q:
            if c == "\\":
                out.append("  ")
                i += 2
                continue
            if c == q:
                q = None
                out.append(c)
            else:
                out.append(" ")
            i += 1
            continue
        if c in "\"'":
            q = c
            out.append(c)
            i += 1
            continue
        if c == "#":
            break
        out.append(c)
        i += 1
    return "".join(out)


def segment(path):
    """Split a .gd file into top-level segments.

    Returns list of dicts {kind, name, lines}. Comment/blank lines at depth 0
    attach to the FOLLOWING segment (doc comments stay with their function;
    blank lines lost from inside a body are cosmetic only). A line only starts
    a segment at bracket depth 0 and column 0.
    """
    lines = open(path, encoding="utf-8").read().split("\n")
    segs, pending, cur, depth = [], [], None, 0

    def close():
        nonlocal cur
        if cur is not None:
            while cur["lines"] and cur["lines"][-1].strip() == "":
                cur["lines"].pop()
            segs.append(cur)
            cur = None

    for line in lines:
        stripped = line.strip()
        at_top = line[:1] not in (" ", "\t") and stripped != ""
        if depth == 0 and at_top and STARTER.match(line):
            close()
            kw = re.match(r"[A-Za-z_]+", line).group(0)
            if kw in ("func", "static"):
                kind, name = "func", FUNC_NAME.match(line).group(1)
            elif kw == "class":
                kind, name = "class", CLASS_NAME.match(line).group(1)
            elif kw == "enum":
                m = ENUM_NAME.match(line)
                kind, name = "enum", (m.group(1) or "<anonymous-enum>")
            elif kw in ("extends", "tool", "class_name"):
                kind, name = kw, kw
            else:
                kind = "decl"
                m = DECL_NAME.match(line)
                if not m:
                    raise SystemExit("cannot parse declaration in %s: %r"
                                     % (path, line))
                name = m.group(1)
            cur = {"kind": kind, "name": name, "lines": pending + [line]}
            pending = []
        elif depth == 0 and (stripped == "" or
                             (at_top and stripped.startswith("#"))):
            pending.append(line)
        elif cur is not None:
            cur["lines"].append(line)
        else:
            pending.append(line)
        code = _strip_code(line)
        depth += code.count("(") - code.count(")")
        depth += code.count("[") - code.count("]")
        depth += code.count("{") - code.count("}")
    close()
    return segs


def norm(seg_lines):
    return [l.rstrip() for l in seg_lines if l.strip() != ""]


def by_name(segs, kinds):
    out = {}
    for s in segs:
        if s["kind"] in kinds:
            if s["name"] in out:
                raise SystemExit("duplicate %s %s" % (s["kind"], s["name"]))
            out[s["name"]] = s
    return out


def class_reference_sites(segs, cls):
    """Names of top-level funcs whose body references <cls> at all (covers
    Cls.new() construction AND sort_custom(Cls, ...) functor use)."""
    pat = re.compile(r"\b%s\b" % cls)
    return [s["name"] for s in segs if s["kind"] == "func"
            and pat.search("\n".join(s["lines"]))]


def dict_entries(seg, path):
    """Parse a single-line-per-entry dict declaration into
    {key_code: (value_code, full_entry_line)}. Errors on multi-line entries."""
    body = seg["lines"]
    first = next(i for i, l in enumerate(body) if DECL_NAME.match(l))
    entries = {}
    for line in body[first + 1:]:
        code = _strip_code(line)          # strings blanked, comment removed,
        orig = line[:len(code)]           # indices align with the original
        s = code.strip()
        if s in ("", "}", "},"):
            continue
        # entry line must be bracket-balanced on its own
        if (code.count("(") != code.count(")") or
                code.count("[") != code.count("]") or
                code.count("{") != code.count("}")):
            raise SystemExit("multi-line dict entry in %s %s: %r"
                             % (path, seg["name"], line))
        # split at the first depth-0 colon (scan the stripped code, slice the
        # ORIGINAL text - stripped strings would corrupt keys/values)
        d, split = 0, -1
        for i, c in enumerate(code):
            if c in "([{":
                d += 1
            elif c in ")]}":
                d -= 1
            elif c == ":" and d == 0:
                split = i
                break
        if split < 0:
            raise SystemExit("no key/value colon in %s %s: %r"
                             % (path, seg["name"], line))
        key = orig[:split].strip()
        val = orig[split + 1:].strip().rstrip(",").strip()
        entries[key] = (val, line)
    return entries


def build_dict_merge(rel, name, vseg, mseg, audit):
    """Generate the _gourmet_merge_<name>() func for a dict that gained
    entries. Errors if vanilla lost an entry; changed values are emitted as
    plain assignments (and audit-noted)."""
    ve, me = dict_entries(vseg, rel), dict_entries(mseg, rel)
    removed = [k for k in ve if k not in me]
    if removed:
        return None, "dict %s REMOVED vanilla entries: %s" % (name, removed)
    lines = ["func _gourmet_merge_%s() -> void :" % name]
    n_add = n_chg = 0
    for k, (val, _raw) in me.items():
        if k not in ve:
            lines.append("\t%s[%s] = %s" % (name, k, val))
            n_add += 1
        elif ve[k][0] != val:
            lines.append("\t%s[%s] = %s" % (name, k, val))
            n_chg += 1
            audit.append((rel, "dict %s entry %s CHANGED value: %r -> %r"
                          % (name, k, ve[k][0], val)))
    if n_add + n_chg == 0:
        return None, "dict %s flagged for merge but no entries differ" % name
    audit.append((rel, "dict %s: %d added / %d changed entries merged at "
                  "_init" % (name, n_add, n_chg)))
    return lines, None


def gen_one(rel, src_root, audit):
    vpath, mpath = os.path.join(VAN, rel), os.path.join(src_root, rel)
    vsegs, msegs = segment(vpath), segment(mpath)
    vfun, mfun = by_name(vsegs, ("func",)), by_name(msegs, ("func",))
    vdecl = by_name(vsegs, ("decl", "enum", "class"))
    mdecl = by_name(msegs, ("decl", "enum", "class"))
    merge_cfg = DICT_MERGE_DECLS.get(rel, {})
    inject = {k: list(v) for k, v in INJECT_CALLS.get(rel, {}).items()}

    problems = []
    for k in vfun:
        if k not in mfun:
            problems.append("REMOVED function: %s" % k)
    for k in vdecl:
        if k not in mdecl:
            problems.append("REMOVED declaration: %s" % k)

    emit_classes, merge_funcs = [], []
    for k in vdecl:
        if k not in mdecl or norm(vdecl[k]["lines"]) == norm(mdecl[k]["lines"]):
            continue
        if k in merge_cfg:
            lines, err = build_dict_merge(rel, k, vdecl[k], mdecl[k], audit)
            if err:
                problems.append(err)
            else:
                merge_funcs.append(lines)
                target = merge_cfg[k]
                inject.setdefault(target, []).append(
                    "\t_gourmet_merge_%s()" % k)
        elif vdecl[k]["kind"] == "class" and \
                k in SAFE_REDECLARED_CLASSES.get(rel, []):
            sites = set(class_reference_sites(vsegs, k) +
                        class_reference_sites(msegs, k))
            unemitted = [s for s in sorted(sites)
                         if s in vfun and s in mfun
                         and norm(vfun[s]["lines"]) == norm(mfun[s]["lines"])
                         and s not in inject]
            if unemitted:
                problems.append("inner class %s: reference sites %s are NOT "
                                "in the extension - redeclaration unsafe"
                                % (k, unemitted))
            else:
                emit_classes.append(k)
                audit.append((rel, "inner class %s redeclared in child - "
                              "safe: all reference sites %s ship in the "
                              "extension" % (k, sorted(sites))))
        else:
            problems.append("CHANGED shared declaration (child cannot "
                            "redeclare): %s\n  vanilla : %s\n  modified: %s"
                            % (k, norm(vdecl[k]["lines"])[:6],
                               norm(mdecl[k]["lines"])[:6]))
    if problems:
        return None, problems

    out_segs = []
    inserts = INSERT_AFTER.get(rel, {})
    emitted_funcs = set()
    for s in msegs:
        if s["kind"] in ("extends", "tool", "class_name"):
            continue
        if s["kind"] == "func":
            changed = s["name"] not in vfun or \
                norm(vfun[s["name"]]["lines"]) != norm(s["lines"])
            if changed or s["name"] in inject:
                lines = list(s["lines"])
                if s["name"] in inject:
                    hdr = next(i for i, l in enumerate(lines)
                               if FUNC_NAME.match(l))
                    if not _strip_code(lines[hdr]).rstrip().endswith(":"):
                        raise SystemExit("cannot inject into one-line func %s "
                                         "in %s" % (s["name"], rel))
                    # match the function's OWN body indentation (some GDRE
                    # output opens bodies at two tabs; a one-tab injected line
                    # there is a parse error)
                    body_indent = "\t"
                    for l in lines[hdr + 1:]:
                        if l.strip() and not l.strip().startswith("#"):
                            body_indent = l[:len(l) - len(l.lstrip())]
                            break
                    for j, extra in enumerate(inject.pop(s["name"])):
                        lines.insert(hdr + 1 + j, body_indent + extra.lstrip())
                for anchor, extra_lines in inserts.get(s["name"], []):
                    hits = [i for i, l in enumerate(lines)
                            if l.strip() == anchor]
                    if len(hits) != 1:
                        raise SystemExit(
                            "INSERT_AFTER anchor %r in %s.%s matched %d lines"
                            % (anchor, rel, s["name"], len(hits)))
                    a_line = lines[hits[0]]
                    a_indent = a_line[:len(a_line) - len(a_line.lstrip())]
                    for j, el in enumerate(extra_lines):
                        lines.insert(hits[0] + 1 + j, a_indent + el.lstrip())
                emitted_funcs.add(s["name"])
                out_segs.append(lines)
                if changed and s["name"] in vfun and \
                        re.match(r"^static\s", s["lines"][0]):
                    audit.append((rel, "modified STATIC func %s - overrides "
                                  "resolve via instance dispatch; verify call "
                                  "sites use the autoload/instance, not a "
                                  "preload of the vanilla script" % s["name"]))
        elif s["kind"] in ("decl", "enum"):
            if s["name"] not in vdecl:
                out_segs.append(s["lines"])
                decl_line = next((l for l in s["lines"] if DECL_NAME.match(l)),
                                 "")
                if re.match(r"^(export\s*(\([^)]*\))?\s*)?onready\b",
                            decl_line):
                    audit.append((rel, "new onready var %s in extension"
                                  % s["name"]))
                if "setget" in _strip_code(decl_line):
                    audit.append((rel, "new setget declaration %s in "
                                  "extension" % s["name"]))
        elif s["kind"] == "class":
            if s["name"] not in vdecl or s["name"] in emit_classes:
                out_segs.append(s["lines"])

    for fname in inserts:
        if fname not in emitted_funcs:
            raise SystemExit("INSERT_AFTER target %s.%s was not emitted"
                             % (rel, fname))

    # Forwarding constructor: a child script without an explicit _init cannot
    # be .new(args)'d when the vanilla base has required _init args (Godot 3
    # quirk - "Invalid call to 'new'. Expected 0 arguments"). Synthesize one.
    if "_init" in vfun and "_init" not in emitted_funcs:
        vsig = _func_sig(vfun["_init"])
        args, req = _sig_args(vsig)
        # even fully-defaulted parent args are lost: the implicit child
        # constructor takes ZERO arguments
        if args:
            names = [a.split(":")[0].split("=")[0].strip() for a in args]
            arg_decl = ", ".join(a for a in args)
            out_segs.append([
                "# forwarding constructor (vanilla base has required _init "
                "args; a child",
                "# script without an explicit _init cannot forward them - "
                "Godot 3 quirk)",
                "func _init(%s).(%s) -> void :" % (arg_decl,
                                                   ", ".join(names)),
                "	pass"])
            audit.append((rel, "synthesized forwarding _init(%s)"
                          % arg_decl))

    # synthesize any inject-target funcs that exist in neither tree
    for fname, calls in inject.items():
        if fname in mfun:
            continue  # already handled above (or force-include missed = bug)
        if fname in vfun:
            raise SystemExit("inject target %s exists in vanilla %s but not "
                             "modified - mirror drift?" % (fname, rel))
        out_segs.append(["func %s() -> void :" % fname] + calls)
        audit.append((rel, "synthesized %s() to host injected calls %s"
                      % (fname, [c.strip() for c in calls])))
    for lines in merge_funcs:
        out_segs.append(lines)

    body = ['# generated by asset-dev/gen_extensions.py - DO NOT EDIT',
            '# GourmetCore extension of the vanilla file (full modified/new '
            'functions + new members)',
            'extends "res://%s"' % rel, '']
    for lines in out_segs:
        body.extend(lines)
        body.append("")
    if rel in EXTRA_SNIPPETS:
        body.append(EXTRA_SNIPPETS[rel].strip("\n"))
        body.append("")
    return "\n".join(body).rstrip("\n") + "\n", None


def _func_sig(seg):
    """Normalized 'func name(args)' header text of a func segment."""
    txt = " ".join(l.strip() for l in seg["lines"]
                   if not l.strip().startswith("#"))
    m = re.search(r'((?:static\s+)?func\s+\w+\s*\([^)]*\))', txt)
    return re.sub(r"\s+", " ", m.group(1)) if m else None


def _sig_args(sig):
    """(arg_specs, n_required) from a normalized signature."""
    inner = sig[sig.index("(") + 1:sig.rindex(")")].strip()
    if not inner:
        return [], 0
    args = [a.strip() for a in re.split(r",(?![^\[\(]*[\]\)])", inner)]
    required = sum(1 for a in args if "=" not in a)
    return args, required


def _vanilla_parent_map():
    """{vanilla rel path: parent rel path} resolving extends-by-path and
    extends-by-class_name (builtin bases absent)."""
    by_class, extends_of, all_gd = {}, {}, []
    for root, dirs, files in os.walk(VAN):
        dirs[:] = [d for d in dirs if d not in (".git", ".import")]
        for f in files:
            if not f.endswith(".gd"):
                continue
            rel = os.path.relpath(os.path.join(root, f), VAN)
            all_gd.append(rel)
            head = open(os.path.join(VAN, rel), errors="ignore").read(4096)
            m = re.search(r'^class_name\s+(\w+)', head, re.M)
            if m:
                by_class[m.group(1)] = rel
            m = re.search(r'^extends\s+(.+)$', head, re.M)
            if m:
                extends_of[rel] = m.group(1).strip()
    parent_of = {}
    for rel, tgt in extends_of.items():
        m = re.match(r'"res://([^"]+)"', tgt)
        if m:
            parent_of[rel] = m.group(1)
        elif tgt in by_class:
            parent_of[rel] = by_class[tgt]
    return parent_of, all_gd


def inheritance_order(rels):
    """Sort target files base-classes-first (a child extension must install
    AFTER its ancestors' extensions, or it reloads against a still-vanilla
    parent), ties alphabetical."""
    parent_of, _all = _vanilla_parent_map()

    def depth(rel):
        d, p, seen = 0, parent_of.get(rel), set()
        while p and p not in seen:
            seen.add(p)
            d += 1
            p = parent_of.get(p)
        return d
    return sorted(rels, key=lambda r: (depth(r), r))


def _vanilla_descendants():
    """{vanilla rel path: [rel paths of vanilla scripts extending it,
    transitively]} - resolves both extends-by-path and extends-by-class_name."""
    by_class, extends_of, all_gd = {}, {}, []
    for root, dirs, files in os.walk(VAN):
        dirs[:] = [d for d in dirs if d not in (".git", ".import")]
        for f in files:
            if not f.endswith(".gd"):
                continue
            rel = os.path.relpath(os.path.join(root, f), VAN)
            all_gd.append(rel)
            head = open(os.path.join(VAN, rel), errors="ignore").read(4096)
            m = re.search(r'^class_name\s+(\w+)', head, re.M)
            if m:
                by_class[m.group(1)] = rel
            m = re.search(r'^extends\s+(.+)$', head, re.M)
            if m:
                extends_of[rel] = m.group(1).strip()
    parent_of = {}
    for rel, tgt in extends_of.items():
        m = re.match(r'"res://([^"]+)"', tgt)
        if m:
            parent_of[rel] = m.group(1)
        elif tgt in by_class:
            parent_of[rel] = by_class[tgt]
    down = {}
    for rel in all_gd:
        p, seen = parent_of.get(rel), set()
        while p and p not in seen:
            seen.add(p)
            down.setdefault(p, []).append(rel)
            p = parent_of.get(p)
    return down


def check_extension_hazards(targets, src_root):
    """The extension-sandwich rules, checked mechanically:
    1. a modified func may not change its vanilla signature in a way that
       breaks a vanilla DESCENDANT override (type/required changes always
       break; added trailing defaulted args break only overriding children)
    2. an emitted STATIC func may not reference a parent (vanilla) const it
       does not redeclare - extension statics cannot see them
    3. _init cannot be emitted when the vanilla _init has required args (the
       implicit parent constructor call fails at parse)
    Returns a list of problem strings (empty = clean)."""
    problems = []
    down = _vanilla_descendants()
    # ModLoader re-sorts extensions lexicographically by vanilla inheritance
    # stack (InheritanceSorting) - our install list order is IGNORED. Any
    # emitted code referencing the class_name of a target that takes over
    # LATER in that sort binds the STALE vanilla class at compile (measured:
    # progress_data's loader, main.gd's UpgradesUI inner classes). Such sites
    # must use load-by-path in game-src.
    parent_of, _all = _vanilla_parent_map()

    def ml_stack(rel):
        chain, p, seen = [rel], parent_of.get(rel), set()
        while p and p not in seen:
            seen.add(p)
            chain.append(p)
            p = parent_of.get(p)
        return ["res://" + x for x in reversed(chain)]
    ml_pos = {r: i for i, r in enumerate(sorted(targets, key=ml_stack))}
    cls_of = {}
    for rel in targets:
        m = re.search(r'^class_name\s+(\w+)',
                      open(os.path.join(VAN, rel), errors="ignore").read(4096),
                      re.M)
        if m:
            cls_of[rel] = m.group(1)
    for rel in targets:
        msegs = segment(os.path.join(src_root, rel))
        vsegs = segment(os.path.join(VAN, rel))
        vfun = by_name(vsegs, ("func",))
        emitted_text = []
        for s in msegs:
            if s["kind"] == "func" and (s["name"] not in vfun or
                    norm(vfun[s["name"]]["lines"]) != norm(s["lines"])):
                emitted_text.extend(_strip_code(l) for l in s["lines"])
        text = chr(10).join(emitted_text)
        for b, cn in cls_of.items():
            if b == rel or ml_pos[b] < ml_pos[rel] or \
                    (rel, cn) in STALE_BINDING_OK:
                continue
            for m in re.finditer(r'%s\s*\.\s*\w+' % cn, text):
                problems.append(
                    "%s :: emitted code references %s (%s) which takes over "
                    "LATER in ModLoader's sort - STALE class binding; use "
                    "load-by-path in game-src (%r)"
                    % (rel, cn, b, m.group(0)[:60]))
    for rel in targets:
        vsegs = segment(os.path.join(VAN, rel))
        msegs = segment(os.path.join(src_root, rel))
        vfun = by_name(vsegs, ("func",))
        vdecl_consts = {s["name"] for s in vsegs if s["kind"] == "decl"
                        and any(re.match(r"const\s", l) for l in s["lines"])}
        mdecl = {s["name"] for s in msegs if s["kind"] in ("decl", "enum")}
        new_decls = mdecl - {s["name"] for s in vsegs
                             if s["kind"] in ("decl", "enum")}
        for s in msegs:
            if s["kind"] != "func" or s["name"] not in vfun:
                continue
            changed = norm(vfun[s["name"]]["lines"]) != norm(s["lines"])
            if not changed:
                continue
            vsig, msig = _func_sig(vfun[s["name"]]), _func_sig(s)
            if vsig != msig:
                vargs, vreq = _sig_args(vsig)
                margs, mreq = _sig_args(msig)
                compatible_extras = (margs[:len(vargs)] == vargs
                                     and mreq <= vreq)
                overriders = [d for d in down.get(rel, [])
                              if re.search(r'^(static\s+)?func\s+%s\b'
                                           % s["name"],
                                           open(os.path.join(VAN, d),
                                                errors="ignore").read(),
                                           re.M)]
                if not compatible_extras:
                    problems.append(
                        "%s :: %s changes the vanilla signature "
                        "incompatibly\n    van: %s\n    mod: %s"
                        % (rel, s["name"], vsig, msig))
                elif overriders:
                    problems.append(
                        "%s :: %s adds args but vanilla descendants override "
                        "it with the OLD signature (%s) - extension sandwich"
                        % (rel, s["name"], overriders))
            if re.match(r"^static\s", s["lines"][
                    next(i for i, l in enumerate(s["lines"])
                         if FUNC_NAME.match(l))]):
                body = "\n".join(s["lines"])
                bad = [c for c in vdecl_consts if c not in new_decls
                       and re.search(r"\b%s\b" % c, body)]
                if bad:
                    problems.append(
                        "%s :: static %s references parent consts %s - "
                        "invisible to extension statics" % (rel, s["name"],
                                                            bad))
            if s["name"] == "_init":
                _a, vreq = _sig_args(_func_sig(vfun["_init"]) or "f()")
                if vreq > 0:
                    problems.append(
                        "%s :: _init override with required-arg vanilla "
                        "_init - implicit parent ctor call fails" % rel)
    return problems


def gen_hand(rel, seg_names, src_root, audit):
    """Emit an extension with no pristine baseline: the named segments are
    copied verbatim from the modified tree. Guard: every segment carrying a
    Gourmet marker must be in the list."""
    segs = segment(os.path.join(src_root, rel))
    picked, problems = [], []
    for s in segs:
        text = "\n".join(s["lines"])
        if s["name"] in seg_names:
            picked.append(s)
        elif s["kind"] in ("func", "decl", "enum", "class") \
                and "Gourmet" in text:
            problems.append("segment %s %s carries a Gourmet marker but is "
                            "not in HAND_EXTENSIONS - list it or revert it"
                            % (s["kind"], s["name"]))
    missing = set(seg_names) - {s["name"] for s in picked}
    if missing:
        problems.append("HAND_EXTENSIONS segments not found: %s"
                        % sorted(missing))
    if problems:
        return None, problems
    body = ['# generated by asset-dev/gen_extensions.py - DO NOT EDIT',
            '# HAND extension (no pristine baseline - Abyssal Terrors DLC pck '
            'is not in the reference);',
            '# segments hand-listed in HAND_EXTENSIONS, emitted verbatim from '
            'game-src. Installed LATE',
            '# by the progress_data extension, only when the DLC is mounted.',
            'extends "res://%s"' % rel, '']
    for s in picked:
        body.extend(s["lines"])
        body.append("")
    audit.append((rel, "hand extension (no pristine baseline): segments %s, "
                  "installed late, DLC-guarded" % seg_names))
    return "\n".join(body).rstrip("\n") + "\n", None


def generate(targets, src_root, out_root):
    """targets: rel paths of modified vanilla .gd. Returns (installed, errors,
    audit). Writes extensions/ + AUDIT.md under out_root. HAND_EXTENSIONS are
    emitted too but NOT included in `installed` (they install late, guarded)."""
    audit, errors, installed = [], [], []
    hazards = check_extension_hazards(targets, src_root)
    if hazards:
        raise SystemExit("EXTENSION HAZARDS (fix game-src, see the "
                         "extension-sandwich rule):\n" +
                         "\n".join("- " + h for h in hazards))
    for rel, seg_names in HAND_EXTENSIONS.items():
        text, problems = gen_hand(rel, seg_names, src_root, audit)
        if problems:
            errors.append((rel, problems))
            continue
        dst = os.path.join(out_root, "extensions", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "w").write(text)
    for rel in inheritance_order(targets):
        text, problems = gen_one(rel, src_root, audit)
        if problems:
            errors.append((rel, problems))
            continue
        dst = os.path.join(out_root, "extensions", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "w").write(text)
        installed.append(rel)
    audit.append(("<all>", "cross-file member shadowing (new var colliding "
                  "with an ANCESTOR script's member) is not statically "
                  "checked here - the clone-gate boot surfaces it as a parse "
                  "error"))
    lines = ["# GourmetCore extension AUDIT (generated - encode resolutions "
             "in gen_extensions.py)", ""]
    if errors:
        lines.append("## HARD ERRORS (no extension emitted)")
        for rel, probs in errors:
            lines.append("### %s" % rel)
            for p in probs:
                lines.append("- %s" % p)
        lines.append("")
    lines.append("## Flags (emitted, verify once)")
    for rel, msg in audit:
        lines.append("- `%s`: %s" % (rel, msg))
    open(os.path.join(out_root, "AUDIT.md"), "w").write("\n".join(lines) + "\n")
    return installed, errors, audit
