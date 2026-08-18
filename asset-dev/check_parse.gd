extends SceneTree

# Parse gate (check_all): load() every hand-edited engine script so PARSE
# errors in lazily-loaded scenes/scripts surface at gate time. The boot gate
# only parses what the main menu touches - difficulty_selection.gd shipped a
# parse error for two phases that way (caught 2026-08-18 by the workshop
# clone gate, of all things). Run: godot --path <live> -s <this file>.
# The manifest of scripts is passed via the SCRIPTS env var (newline-joined).

func _init() -> void :
	var manifest: String = OS.get_environment("GOURMET_PARSE_LIST")
	if manifest == "":
		print("PARSE GATE: empty GOURMET_PARSE_LIST")
		OS.exit_code = 1
		quit()
		return
	var failures: = 0
	var count: = 0
	for rel in manifest.split("\n"):
		rel = rel.strip_edges()
		if rel == "":
			continue
		count += 1
		var script = load("res://" + rel)
		if script == null or not (script as Script).can_instance():
			print("PARSE FAIL: ", rel)
			failures += 1
	if failures > 0:
		print("PARSE GATE: %d/%d scripts FAILED to parse" % [failures, count])
		OS.exit_code = 1
	else:
		print("PARSE GATE: all %d scripts parse" % count)
	quit()
