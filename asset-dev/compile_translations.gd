extends SceneTree

# Deterministic replacement for the editor's csv_translation import: compiles
# items/custom/custom_translations.csv into custom_translations.en.translation
# (a plain Translation resource - loads identically). Run after ANY csv edit:
#   godot --path ~/brotato-decompiled -s asset-dev/compile_translations.gd
# No more "focus the editor so it reimports" for translation rows.

func _init() -> void :
	var f: = File.new()
	var err = f.open("res://items/custom/custom_translations.csv", File.READ)
	if err != OK:
		print("COMPILE_TRANSLATIONS: cannot open csv (%s)" % err)
		OS.exit_code = 1
		quit()
		return
	var header: = f.get_csv_line()
	var t: = Translation.new()
	t.locale = "en"
	var rows: = 0
	while not f.eof_reached():
		var row: = f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		t.add_message(row[0], row[1])
		rows += 1
	f.close()
	var save_err = ResourceSaver.save("res://items/custom/custom_translations.en.translation", t)
	if save_err != OK:
		print("COMPILE_TRANSLATIONS: save failed (%s)" % save_err)
		OS.exit_code = 1
	else:
		print("COMPILE_TRANSLATIONS: %d rows compiled (locale en)" % rows)
	quit()
