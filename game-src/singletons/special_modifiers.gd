extends Node
# Gourmet DLC - The Special (character #18): every wave is jumbled by random modifiers.
#
# DESIGN RULES (user-specced, see asset-dev/characters/MODIFIER_POOL.md):
#  - Wave 1 rolls NOTHING. From then on the shop previews the NEXT wave's modifiers, so the
#    player shops knowing what is coming.
#  - Jagged count curve, peaking at 4-6 around waves 13-20, never running away after.
#  - More bad than good; good gets slightly rarer as the run climbs, but any wave that rolls
#    anything is guaranteed at least one good AND one bad (min 2). See roll_for_wave.
#  - Endless repeats the pool; it never exhausts.
#  - EVERY wave-scoped modifier is temporary.
#
# SAFETY LAW: a modifier is a set of reversible numeric DELTAS on the player's effects dict,
# never an object transformation. "All weapons become tier 1" is unbuildable (28 weapons have
# no tier-1 variant on disk) so it is expressed as a damage delta instead. Anything that
# cannot be undone by one subtraction does not belong in this registry.
#
# COMPENSATION LAW: a modifier that removes a core capability ships its compensation in the
# same entry, scaled where it matters. A bad wave must be painful and survivable, never
# unwinnable.

# lifetimes
const LIFE_WAVE: = 0   # applied at wave start, removed at wave end
const LIFE_SHOP: = 1   # applied at wave end, removed when the following shop closes

# roll tuning
const MAX_ROLL_TRIES: = 40

# Jagged count curve. Index = wave number (clamped), value = how many modifiers roll.
# Deliberately uneven so some waves are a breather. Endless clamps to the last entry.
const COUNT_CURVE: = [0, 0, 1, 1, 2, 1, 2, 3, 2, 3, 3, 4, 3, 5, 4, 6, 5, 4, 6, 5, 5]

# id, display name, numbers line, kind, lifetime, conflict axes, effects [[key, value]...]
# kind: "good" / "bad" / "mixed" - drives colour and the weighting drift.
# Only PLAIN NUMERIC effect keys belong here; array-valued keys are not reversible this way.
var REGISTRY: = [
	# --- enemy stats -------------------------------------------------------------------
	{"id": "well_done", "name": "Well Done", "text": "+50% Enemy Health",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["ENEMY_STATS"], "effects": [["enemy_health", 50]]},
	{"id": "rare", "name": "Rare", "text": "-30% Enemy Health",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["ENEMY_STATS"], "effects": [["enemy_health", -30]]},
	{"id": "sharp_knives", "name": "Sharp Knives", "text": "+40% Enemy Damage",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["ENEMY_DMG"], "effects": [["enemy_damage", 40]]},
	{"id": "blunt", "name": "Blunt", "text": "-40% Enemy Damage",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["ENEMY_DMG"], "effects": [["enemy_damage", -40]]},
	{"id": "hot_plate", "name": "Hot Plate", "text": "+30% Enemy Speed",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["ENEMY_SPEED"], "effects": [["enemy_speed", 30]]},
	{"id": "cold_storage", "name": "Cold Storage", "text": "-30% Enemy Speed",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["ENEMY_SPEED"], "effects": [["enemy_speed", -30]]},

	# --- enemy composition -------------------------------------------------------------
	{"id": "full_house", "name": "Full House", "text": "+50% Enemy Count",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["ENEMY_COUNT"], "effects": [["number_of_enemies", 50]]},
	{"id": "slow_night", "name": "Slow Night", "text": "-40% Enemy Count",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["ENEMY_COUNT"], "effects": [["number_of_enemies", -40]]},

	# --- arena -------------------------------------------------------------------------
	{"id": "walk_in_freezer", "name": "Walk-In Freezer", "text": "-33% Map Size",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["ARENA_SIZE"], "effects": [["map_size", -33]]},
	{"id": "banquet_hall", "name": "Banquet Hall", "text": "+33% Map Size",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["ARENA_SIZE"], "effects": [["map_size", 33]]},
	{"id": "overgrown", "name": "Overgrown", "text": "The arena fills with trees",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["TREES"], "effects": [["trees", 10]]},

	# --- your weapons ------------------------------------------------------------------
	{"id": "sharpened", "name": "Sharpened", "text": "+50% Damage",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["WEAPON_STATS"], "effects": [["stat_percent_damage", 50]]},
	{"id": "dull_blades", "name": "Dull Blades", "text": "-30% Damage",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["WEAPON_STATS"], "effects": [["stat_percent_damage", -30]]},
	{"id": "rapid_service", "name": "Rapid Service", "text": "+50% Attack Speed",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["ATK_SPEED"], "effects": [["stat_attack_speed", 50]]},
	{"id": "slow_service", "name": "Slow Service", "text": "-40% Attack Speed",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["ATK_SPEED"], "effects": [["stat_attack_speed", -40]]},
	{"id": "long_reach", "name": "Long Reach", "text": "+100 Range",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["RANGE"], "effects": [["stat_range", 100]]},
	{"id": "cramped", "name": "Cramped", "text": "-50 Range",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["RANGE"], "effects": [["stat_range", -50]]},
	{"id": "skewered", "name": "Skewered", "text": "Projectiles pierce 1 extra target",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["PROJECTILE"], "effects": [["piercing", 1]]},
	{"id": "double_portion", "name": "Double Portion", "text": "+1 Projectile",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["PROJECTILE"], "effects": [["projectiles", 1]]},
	{"id": "shaky_hands", "name": "Shaky Hands", "text": "-50% Accuracy",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["PROJECTILE"], "effects": [["accuracy", -50]]},
	# expressed as a DAMAGE delta, never an object swap - see the safety law above
	{"id": "blunt_instruments", "name": "Blunt Instruments", "text": "-60% Damage. Your gear feels cheap",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["WEAPON_STATS"], "effects": [["stat_percent_damage", -60]]},
	{"id": "front_of_house", "name": "Front of House", "text": "Melee weapons do nothing this wave",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["WEAPON_BAN"], "needs": "has_ranged",
	 "effects": [["no_melee_weapons", 1]]},
	{"id": "back_of_house", "name": "Back of House", "text": "Ranged weapons do nothing this wave",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["WEAPON_BAN"], "needs": "has_melee",
	 "effects": [["no_ranged_weapons", 1]]},

	# --- your body ---------------------------------------------------------------------
	{"id": "caffeinated", "name": "Caffeinated", "text": "+40% Speed",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["SPEED"], "effects": [["stat_speed", 40]]},
	{"id": "food_coma", "name": "Food Coma", "text": "-40% Speed",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["SPEED"], "effects": [["stat_speed", -40]]},
	{"id": "padded", "name": "Padded", "text": "+10 Armour, -30% Speed",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["ARMOR", "SPEED"],
	 "effects": [["stat_armor", 10], ["stat_speed", -30]]},
	{"id": "featherweight", "name": "Featherweight", "text": "+50% Speed, -8 Max HP",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["SPEED", "HP"],
	 "effects": [["stat_speed", 50], ["stat_max_hp", -8]]},
	{"id": "slippery", "name": "Slippery", "text": "+30% Dodge",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["DODGE"], "effects": [["stat_dodge", 30]]},
	{"id": "butterfingered", "name": "Butterfingered", "text": "Dodge capped at 0%",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["DODGE"], "effects": [["dodge_cap", -100]]},
	{"id": "second_wind", "name": "Second Wind", "text": "+5 HP Regeneration",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["HEAL"], "effects": [["stat_hp_regeneration", 5]]},
	{"id": "nil_by_mouth", "name": "Nil By Mouth", "text": "You cannot heal this wave",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["HEAL"], "effects": [["no_heal", 1]]},
	{"id": "bleeding_out", "name": "Bleeding Out", "text": "Lose 1 HP per second",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["HEAL"], "effects": [["lose_hp_per_second", 1]]},
	{"id": "thick_skin", "name": "Thick Skin", "text": "+15 Armour, -50 Pickup Range",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["ARMOR"],
	 "effects": [["stat_armor", 15], ["pickup_range", -50]]},
	# compensation law: this one is only survivable because of the damage it hands back
	{"id": "glass", "name": "Glass", "text": "You die in ONE hit. +200% Damage",
	 "kind": "mixed", "life": LIFE_WAVE, "axes": ["HP", "WEAPON_STATS"],
	 "effects": [["die_in_one_hit", 1], ["stat_percent_damage", 200]]},

	# --- loot --------------------------------------------------------------------------
	{"id": "generous_tips", "name": "Generous Tips", "text": "+100% Materials dropped",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["LOOT"], "effects": [["gold_drops", 100]]},
	{"id": "stiffed", "name": "Stiffed", "text": "-75% Materials dropped",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["LOOT"], "effects": [["gold_drops", -75]]},
	{"id": "study_hall", "name": "Study Hall", "text": "+50% XP Gain",
	 "kind": "good", "life": LIFE_WAVE, "axes": ["XP"], "effects": [["xp_gain", 50]]},
	{"id": "distracted", "name": "Distracted", "text": "-40% XP Gain",
	 "kind": "bad", "life": LIFE_WAVE, "axes": ["XP"], "effects": [["xp_gain", -40]]},

	# --- next shop (LIFE_SHOP: these survive the wave and die when the shop closes) -----
	{"id": "surge_pricing", "name": "Surge Pricing", "text": "Next shop costs +50%",
	 "kind": "bad", "life": LIFE_SHOP, "axes": ["SHOP_PRICE"], "effects": [["items_price", 50]]},
	{"id": "happy_hour", "name": "Happy Hour", "text": "Next shop costs -40%",
	 "kind": "good", "life": LIFE_SHOP, "axes": ["SHOP_PRICE"], "effects": [["items_price", -40]]},
	{"id": "cash_only", "name": "Cash Only", "text": "Rerolls cost +100% next shop",
	 "kind": "bad", "life": LIFE_SHOP, "axes": ["SHOP_REROLL"], "effects": [["reroll_price", 100]]},
	{"id": "top_shelf", "name": "Top Shelf", "text": "Next shop's weapons are Tier II or better",
	 "kind": "good", "life": LIFE_SHOP, "axes": ["SHOP_TIER"], "effects": [["min_weapon_tier", 1]]},
	{"id": "bargain_bin", "name": "Bargain Bin", "text": "Next shop's weapons are Tier II or worse",
	 "kind": "bad", "life": LIFE_SHOP, "axes": ["SHOP_TIER"], "effects": [["max_weapon_tier", 1]]},
]

# hard-forbidden pairs, beyond the axis exclusion (see MODIFIER_POOL.md audit)
const FORBIDDEN_PAIRS: = [
	["glass", "bleeding_out"],      # chip damage plus one-hit death is not a wave, it is a loss
	["glass", "nil_by_mouth"],
	["blunt_instruments", "sharpened"],
	["front_of_house", "back_of_house"],
]


# Modifier ids are stored in the effects dict as KEY HASHES, never as strings. On load the
# engine runs convert_dictionary_to_hash(recursive), which walks every array value and turns
# any String into Keys.generate_hash(it). Storing strings therefore silently became ints on
# reload: the rules list read as empty and get_by_id was handed an int. Ints survive that pass
# untouched, so hashes are the only round-trip-safe representation here.
var _by_hash: = {}


func _ready() -> void :
	for m in REGISTRY:
		_by_hash[Keys.generate_hash(m.id)] = m


func get_by_id(id: String) -> Dictionary:
	for m in REGISTRY:
		if m.id == id:
			return m
	return {}


func get_by_hash(id_hash: int) -> Dictionary:
	return _by_hash[id_hash] if _by_hash.has(id_hash) else {}


func hash_of(id: String) -> int:
	return Keys.generate_hash(id)


# How many modifiers this wave rolls. Wave 1 is always clean.
func get_count_for_wave(wave: int) -> int:
	if wave <= 1:
		return 0

	var idx: int = int(clamp(wave, 0, COUNT_CURVE.size() - 1))
	return COUNT_CURVE[idx]


# Good gets slightly rarer as the run climbs, bad slightly more common. A drift, not a cliff:
# the pool always keeps some of each so a late wave can still roll all good.
func _weight_for(mod: Dictionary, wave: int) -> float:
	var t: float = clamp(float(wave) / 20.0, 0.0, 1.0)
	match mod.kind:
		"good":
			return lerp(1.0, 0.55, t)
		"bad":
			return lerp(0.85, 1.35, t)
		_:
			return 1.0


func _eligible(mod: Dictionary, player_index: int) -> bool:
	# Eligibility is modifier-vs-PLAYER-STATE, separate from conflict axes. Without it,
	# "ranged weapons do nothing" on an all-melee board is not a hard wave, it is zero
	# damage output and a guaranteed loss.
	if not mod.has("needs"):
		return true

	var weapons: Array = RunData.get_player_weapons_ref(player_index)
	match mod.needs:
		"has_melee":
			for w in weapons:
				if w.type == WeaponType.MELEE:
					return true
			return false
		"has_ranged":
			for w in weapons:
				if w.type == WeaponType.RANGED:
					return true
			return false
	return true


func _conflicts(mod: Dictionary, chosen: Array) -> bool:
	for other in chosen:
		for pair in FORBIDDEN_PAIRS:
			if (pair[0] == mod.id and pair[1] == other.id) or (pair[1] == mod.id and pair[0] == other.id):
				return true
		for axis in mod.axes:
			if axis in other.axes:
				return true
	return false


# Roll the set for `wave`. Returns an array of modifier ids.
# `blocked_axes` lets the caller exclude anything the wave was ALREADY going to do (fog,
# bullet hell, horde, elites), so the player never gets the same event twice.
func roll_for_wave(wave: int, player_index: int, blocked_axes: Array = []) -> Array:
	var count: int = get_count_for_wave(wave)
	if count <= 0:
		return []

	# Gourmet DLC - Wildcard guarantee: any wave he rolls modifiers he always gets at least one
	# POSITIVE and one NEGATIVE, so a minimum of two. (A count of 0 still yields none - the only
	# way he ends a wave with no modifiers.) Seed one good and one bad first, then fill the rest
	# with the normal weighted roll.
	count = int(max(count, 2))

	var chosen: = []
	var seed_good: Dictionary = _pick_of_kind("good", wave, player_index, blocked_axes, chosen)
	if not seed_good.empty():
		chosen.push_back(seed_good)
	var seed_bad: Dictionary = _pick_of_kind("bad", wave, player_index, blocked_axes, chosen)
	if not seed_bad.empty():
		chosen.push_back(seed_bad)

	var tries: = 0

	while chosen.size() < count and tries < MAX_ROLL_TRIES:
		tries += 1
		var candidate: Dictionary = _pick_weighted(wave)
		if candidate.empty():
			continue
		if _conflicts(candidate, chosen):
			continue
		if not _eligible(candidate, player_index):
			continue

		var axis_blocked: = false
		for axis in candidate.axes:
			if axis in blocked_axes:
				axis_blocked = true
				break
		if axis_blocked:
			continue

		chosen.push_back(candidate)

	var ids: = []
	for m in chosen:
		ids.push_back(Keys.generate_hash(m.id))
	return ids


# Gourmet DLC - weighted pick restricted to one kind ("good"/"bad"), honouring the same
# conflict / eligibility / blocked-axis rules as the main roll. Empty {} if none qualify.
func _pick_of_kind(kind: String, wave: int, player_index: int, blocked_axes: Array, chosen: Array) -> Dictionary:
	var pool: = []
	var total: = 0.0
	for m in REGISTRY:
		if m.kind != kind:
			continue
		if _conflicts(m, chosen) or not _eligible(m, player_index):
			continue
		var axis_blocked: = false
		for axis in m.axes:
			if axis in blocked_axes:
				axis_blocked = true
				break
		if axis_blocked:
			continue
		var w: float = _weight_for(m, wave)
		if w > 0.0:
			pool.push_back([m, w])
			total += w
	if total <= 0.0:
		return {}
	var roll: = rand_range(0.0, total)
	for pair in pool:
		roll -= pair[1]
		if roll <= 0.0:
			return pair[0]
	return pool[pool.size() - 1][0]


func _pick_weighted(wave: int) -> Dictionary:
	var total: = 0.0
	for m in REGISTRY:
		total += _weight_for(m, wave)

	if total <= 0.0:
		return {}

	var roll: = rand_range(0.0, total)
	for m in REGISTRY:
		roll -= _weight_for(m, wave)
		if roll <= 0.0:
			return m
	return REGISTRY[REGISTRY.size() - 1]


# Apply / unapply are strict inverses: every effect is a numeric delta on the effects dict.
# Nothing here mutates an object, so a modifier can always be taken back off exactly.
func apply_ids(ids: Array, player_index: int) -> void :
	_shift_ids(ids, player_index, 1)


func unapply_ids(ids: Array, player_index: int) -> void :
	_shift_ids(ids, player_index, - 1)


func _shift_ids(ids: Array, player_index: int, sign_mult: int) -> void :
	if ids.empty():
		return

	var effects: Dictionary = RunData.get_player_effects(player_index)
	for id_hash in ids:
		var mod: Dictionary = get_by_hash(id_hash)
		if mod.empty():
			continue
		for pair in mod.effects:
			var key_hash: int = Keys.generate_hash(pair[0])
			if not effects.has(key_hash):
				continue

			# Plain dict write, deliberately NOT RunData.add_stat.
			#
			# Brotato rebuilds the main scene every wave, so players are constructed fresh and
			# read this dict when they are built. Applying BEFORE entity_spawner.init (which is
			# what main.gd does) therefore needs no dirty flag and no recompute: the values are
			# simply in place before anything reads them.
			#
			# add_stat is actively wrong here. It emits stat_added, and floating_text_manager
			# handles that by indexing players[player_index] - which is an empty array before
			# the spawn, so it crashed. It would also spray "+50 Damage" popups across the
			# screen on teardown at wave end, which is not what a modifier expiring should look
			# like.
			effects[key_hash] += pair[1] * sign_mult

	Utils.reset_stat_cache(player_index)
	LinkedStats.reset_player(player_index)


# Read a stored id list DEFENSIVELY. get_player_effect is a raw dict access, so a run started
# before these keys were seeded (or a save written before they existed) can leave a non-Array
# here. `for id in <int>` then iterates integers and hands get_by_id an int, which is a hard
# type error. Anything that is not a genuine array of known string ids reads as empty.
func stored_ids(key_hash: int, player_index: int) -> Array:
	var effects: Dictionary = RunData.get_player_effects(player_index)
	if not effects.has(key_hash):
		return []

	var raw = effects[key_hash]
	if not (raw is Array):
		return []

	var out: = []
	for v in raw:
		# tolerate a String left by an older save; the engine will have hashed most of them
		var h: int = Keys.generate_hash(v) if v is String else (int(v) if (v is int or v is float) else 0)
		if _by_hash.has(h):
			out.push_back(h)
	return out


func ids_of_life(ids: Array, life: int) -> Array:
	var out: = []
	for id_hash in ids:
		var mod: Dictionary = get_by_hash(id_hash)
		if not mod.empty() and mod.life == life:
			out.push_back(id_hash)
	return out
