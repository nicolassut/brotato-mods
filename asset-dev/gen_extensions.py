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

# {file: [inner class names]} - verified safe to redeclare (see gen() check)
SAFE_REDECLARED_CLASSES = {
    "ui/menus/ingame/upgrades_ui.gd": ["ConsumableToProcess"],
    "ui/menus/pages/sort_inventory_button.gd": ["SortInventory"],
    "ui/menus/pages/menu_codex.gd": ["SortItem"],
}

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
                    for j, extra in enumerate(inject.pop(s["name"])):
                        lines.insert(hdr + 1 + j, extra)
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


def generate(targets, src_root, out_root):
    """targets: rel paths of modified vanilla .gd. Returns (installed, errors,
    audit). Writes extensions/ + AUDIT.md under out_root."""
    audit, errors, installed = [], [], []
    for rel in targets:
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
