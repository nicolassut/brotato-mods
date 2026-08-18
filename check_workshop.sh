#!/bin/bash
# Phase 8 END-TO-END WORKSHOP GATE.
# Disposable clone of the pristine vanilla reference + the generated workshop
# mods must boot with PackService VERIFY OK - per install combo (that is the
# Workshop promise: any subset of pack mods on top of Core).
#
# The payload overlay is COPIED into the clone (zip mounting cannot be tested
# in editor mode - load_resource_pack wipes res:// there; the zip path is
# exercised only on a real exported install). The clone gets its own user://
# (project renamed) so the real save/settings are never touched. The vanilla
# reference itself is READ-ONLY - rsync source only.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
VAN="$HOME/brotato-vanilla-reference"
LIVE="$HOME/brotato-decompiled"
GODOT="$HOME/Applications/Godot3.app/Contents/MacOS/Godot"
CLONE="$HOME/brotato-workshop-gate-clone"
WORK="$REPO/workshop"
USERDIR="$HOME/Library/Application Support/BrotatoWorkshopGate"

N_EXTENSIONS=$(grep -c '^\t"' "$(dirname "$0")/workshop/nicolassut-GourmetCore/mod_main.gd")

fail() { echo "FAIL: $1"; exit 1; }

install_mod() { # $1 = mod dir name
  local src="$WORK/$1" dst="$CLONE/mods-unpacked/$1"
  mkdir -p "$dst"
  cp "$src/manifest.json" "$src/mod_main.gd" "$dst/"
  [ -f "$src/translations.csv" ] && cp "$src/translations.csv" "$dst/"
  [ -d "$src/extensions" ] && cp -R "$src/extensions" "$dst/extensions"
  python3 - "$src/payload_manifest.json" "$LIVE" "$CLONE" <<'EOF'
import json, os, shutil, sys
man, live, clone = sys.argv[1:4]
for rel in json.load(open(man))["files"]:
    dst = os.path.join(clone, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(os.path.join(live, rel), dst)
EOF
}

boot_combo() { # $1 = label, $2 = expected mods loaded, $3 = expected PackService line, rest = mod names
  local label="$1" n_mods="$2" expect="$3"; shift 3
  echo "== combo: $label (${*}) =="
  rm -rf "$CLONE"
  rsync -a --exclude '.git' "$VAN/" "$CLONE/"
  # isolate user:// - never touch the real save/settings
  sed -i '' 's|config/name="Brotato"|config/name="BrotatoWorkshopGate"|' "$CLONE/project.godot"
  grep -q 'config/name="BrotatoWorkshopGate"' "$CLONE/project.godot" || fail "project rename"
  rm -rf "$USERDIR"
  for mod in "$@"; do install_mod "$mod"; done
  local log; log="$(mktemp)"
  "$GODOT" --path "$CLONE" --quit > "$log" 2>&1 || { tail -30 "$log"; fail "$label: boot crashed"; }
  # known vanilla-clone artifact: GDRE cannot recover the GodotSteam GDNative
  # dylib from the pck, so Steam.restartAppIfNecessary is Nil in the clone.
  # Real installs have the lib; everything else must be clean.
  # Errors are judged AFTER the extension-install phase: ModLoader's
  # inheritance sorter load()s every child extension BEFORE any install, so
  # cross-extension member references parse-fail against the still-vanilla
  # bases and are superseded when apply_extension reloads them (measured
  # 2026-08-18). Functional coverage comes from VERIFY + the exact counts.
  # Whitelist (vanilla-reference artifacts, never present on real installs):
  #  - restartAppIfNecessary/getCurrentGameLanguage: GDRE cannot recover the
  #    GodotSteam GDNative dylib
  #  - res://tests/ + reload-null pair: GUT test-double sources are in
  #    _global_script_classes but not in the pck
  local post; post="$(mktemp)"
  sed -n "/DONE: Installed all script extensions/,\$p" "$log" > "$post"
  grep -q "DONE: Installed all script extensions" "$log" || { tail -20 "$log"; fail "$label: extension install phase never completed"; }
  if grep -iE "parse error|script error" "$post" | grep -vE "restartAppIfNecessary|getCurrentGameLanguage|res://tests/|script_extension.gd|Invalid get index .resource_path. \(on base: .null instance.\)|call function .reload. in base .null instance." | grep -q .; then
    grep -iE "parse error|script error" "$post" | grep -vE "restartAppIfNecessary|getCurrentGameLanguage|res://tests/|script_extension.gd|Invalid get index .resource_path. \(on base: .null instance.\)|call function .reload. in base .null instance." | head -15
    fail "$label: script errors after extension install"
  fi
  rm -f "$post"
  local n_inst
  n_inst=$(grep -c "Installing script extension" "$log" || true)
  [ "$n_inst" = "$N_EXTENSIONS" ] || { grep "Installing script extension" "$log" | head -3; fail "$label: expected $N_EXTENSIONS extension installs, saw $n_inst"; }
  grep -q "DONE: Setup $n_mods mods" "$log" || { grep "DONE" "$log" || true; fail "$label: expected $n_mods mods loaded"; }
  grep -q "PackService VERIFY: OK" "$log" || { grep "PackService" "$log" || true; fail "$label: no PackService VERIFY OK"; }
  local line
  line=$(grep "PackService: " "$log" | head -1)
  echo "   $line"
  if [ "$expect" != "MEASURE" ]; then
    echo "$line" | grep -qF "$expect" || fail "$label: expected '$expect'"
  fi
  grep "PackService synergies" "$log" | head -1 || true
  rm -f "$log"
}

# Expected counts are MEASURED on the no-DLC clone (the reference recovers the
# base pck only): vanilla items 209 (Core prunes 5 at first pool build - the
# core-only line prints before that, cosmetic), chars 50, weapons 205. Deltas
# per pack verified exact vs the pack manifests. The live-tree matrix numbers
# differ by exactly the Abyssal DLC content (+14 chars/+33 items/+52 weapons).
# combo 1: full collection - all five mods (fortune merged into GourmetForge)
boot_combo "all" 5 \
  "PackService: 4 available, enabled=[food, forge, ledger, roster] | chars=69 items=286 weapons=556 foods=27" \
  nicolassut-GourmetCore nicolassut-GourmetFood nicolassut-GourmetForge \
  nicolassut-GourmetLedger nicolassut-GourmetRoster

# combo 2: Core + Food only (the modularity promise: any subset works)
boot_combo "core+food" 2 \
  "PackService: 1 available, enabled=[food] | chars=58 items=284 weapons=276 foods=27" \
  nicolassut-GourmetCore nicolassut-GourmetFood

# combo 3: Core alone (pure framework, zero content)
boot_combo "core-only" 1 \
  "PackService: 0 available, enabled=[] | chars=50 items=209 weapons=205 foods=0" \
  nicolassut-GourmetCore

rm -rf "$CLONE" "$USERDIR"
echo ""
echo "WORKSHOP GATE PASSED (clone deleted; real trees untouched)."
