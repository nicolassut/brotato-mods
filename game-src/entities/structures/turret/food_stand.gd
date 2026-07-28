extends Turret

# Gourmet DLC - decorative spawn anchor. Trigger-based food spawners (Chili
# Greenhouse, Wok Station, Street Vendor, Farmers' Market) place one of these
# on the map each wave and their foods pop out of it instead of around the
# player. main.gd maps anchored_food -> this structure per player; the trigger
# logic itself is unchanged. Never shoots.

export (String) var anchored_food = ""


func should_shoot() -> bool:
	return false
