class_name Effect
extends Resource

enum Sign { POSITIVE, NEGATIVE, NEUTRAL, FROM_VALUE, FROM_ARG, OVERRIDE }
enum StorageMethod { SUM, KEY_VALUE, REPLACE , APPEND_KEY, APPEND_KEY_VALUE }

export(String) var key := ""
var key_hash: int = Keys.empty_hash

export(String) var text_key := ""

export(int) var value := 0


export(String) var custom_key := ""
var custom_key_hash: int = Keys.empty_hash


export(StorageMethod) var storage_method = StorageMethod.SUM

export(Sign) var effect_sign := Sign.FROM_VALUE

export(Array, Resource) var custom_args

var curse_factor: float = 0.0
var base_value = 0
var _custom_args_added := false


func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)

	if key_hash == Keys.empty_hash and key != "":
		key_hash = Keys.generate_hash(key)

	duplication.key_hash = self.key_hash

	if custom_key_hash == Keys.empty_hash:
		custom_key_hash = Keys.generate_hash(custom_key)

	duplication.custom_key_hash = self.custom_key_hash

	return duplication


static func get_id() -> String:
	return "effect"


func _init() -> void:


	if custom_key_hash == Keys.empty_hash or key_hash == Keys.empty_hash:
		call_deferred("_generate_hashes")


func _generate_hashes() -> void:
	custom_key_hash = Keys.generate_hash(custom_key)
	key_hash = Keys.generate_hash(key)


func apply(player_index: int) -> void:
	if key_hash == Keys.empty_hash: return

	var effects = RunData.get_player_effects(player_index)
	if storage_method == StorageMethod.KEY_VALUE:
		var effect_items: Array = effects[custom_key_hash]
		for existing_item in effect_items:
			if existing_item[0] == key_hash:
				existing_item[1] += value
				return
		effect_items.push_back([key_hash, value])
	elif storage_method == StorageMethod.APPEND_KEY:
		if not key in effects[custom_key_hash]:
			effects[custom_key_hash].append(key_hash)
	elif storage_method == StorageMethod.APPEND_KEY_VALUE:
		effects[custom_key_hash].append([key_hash, value])
	elif storage_method == StorageMethod.REPLACE:
		base_value = effects[key_hash]
		effects[key_hash] = value
	else:
		effects[key_hash] += value
	Utils.reset_stat_cache(player_index)


func unapply(player_index: int) -> void:
	if key_hash == Keys.empty_hash: return

	var effects = RunData.get_player_effects(player_index)
	if storage_method == StorageMethod.KEY_VALUE:
		var effect_items: Array = effects[custom_key_hash]
		for i in effect_items.size():
			var effect_item = effect_items[i]
			assert(effect_item[0] is int)
			if effect_item[0] == key_hash:
				effect_item[1] -= value
				if effect_item[1] == 0:
					effect_items.remove(i)
				return
	elif storage_method == StorageMethod.APPEND_KEY:
		effects[custom_key_hash].erase(key_hash)
	elif storage_method == StorageMethod.APPEND_KEY_VALUE:
		var effect_items: Array = effects[custom_key_hash]
		for i in effect_items.size():
			var effect_item = effect_items[i]
			if effect_item[0] == key_hash and int(effect_item[1]) == value:
				effect_items.remove(i)
				return
	elif storage_method == StorageMethod.REPLACE:
		effects[key_hash] = base_value
	else:
		effects[key_hash] -= value
	Utils.reset_stat_cache(player_index)


func get_text(player_index: int, colored: bool = true) -> String:
	# effects marked EFFECT_HIDDEN work silently everywhere (summary line carries their text)
	if text_key == "EFFECT_HIDDEN":
		return ""

	# Gourmet DLC - food card lines render their Appetite scaling formula in the
	# vanilla "base (+ratio% icon)" style. The effect's custom_key holds the food's
	# my_id; the food is fetched through ItemService and read duck-typed
	# (no item class references here - cyclic law). Arg order must match the
	# templates written by asset-dev/build_food_system.py:
	# buff_stats, then duration (if app-scaled), then wave_stats, then heal.
	if text_key.begins_with("EFFECT_FOOD_") and custom_key != "":
		var food = ItemService.get_food_from_hash(Keys.generate_hash(custom_key))
		if food != null:
			var food_args: = []
			var food_signs: = []
			for food_buff_stat in food.buff_stats:
				_add_food_formula_args(food_buff_stat[1], food_buff_stat[2], food_args, food_signs, player_index, colored)
			# Gourmet DLC - the duration pair uses the SAME idiom as every other number on a
			# card: {n} = "current | base" seconds, {n+1} = the "+rate per Appetite" chunk. It
			# used to push (base, current) as two bare numbers, which read as "16 (16)" at 0
			# Appetite - a duplicated value where every other card shows a rate. The x1.5 that
			# used to be applied here is gone: it is baked into the authored buff_duration now
			# (see build_food_system.py), so what the card prints is what player.gd uses.
			if food.duration_app_ratio != 0.0:
				var dur_app: = 0.0
				if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
					dur_app = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
				var dur_current: int = int((food.buff_duration + food.duration_app_ratio * dur_app) * (1.0 + dur_app * 0.01))
				food_args.push_back(_weapon_style_value(dur_current, int(food.buff_duration), colored))
				food_signs.push_back(Sign.NEUTRAL)
				food_args.push_back(Utils.get_scaling_stat_icon_text(Keys.stat_appetite_hash, food.duration_app_ratio, true))
				food_signs.push_back(Sign.NEUTRAL)
			for food_wave_stat in food.wave_stats:
				_add_food_formula_args(food_wave_stat[1], food_wave_stat[2], food_args, food_signs, player_index, colored)
			if food.heal_base > 0.0:
				_add_food_formula_args(food.heal_base, food.heal_app_ratio, food_args, food_signs, player_index, colored)
			for food_perm_stat in food.permanent_stats:
				_add_food_perm_args(food_perm_stat[1], food.permanent_app_ratio, food_args, food_signs, player_index, colored)
			return Text.text(text_key, food_args, [] if !colored else food_signs)

	# Gourmet DLC - custom scaling cards render their real formula live (base + scaling stat
	# + current amount). Each (base, stat, ratio) MUST match the gameplay code noted below.
	if text_key == "EFFECT_FOOD_SPEED_BURST":  # player.gd: (5 + 0.1 * Appetite) * stacks Speed
		return _scaling_formula_text(text_key, 5.0, Keys.stat_appetite_hash, 0.1, player_index, colored)
	if text_key == "EFFECT_CALTROPS":  # player.gd: (3 + 0.3 * Melee Damage) * stacks thorns
		return _scaling_formula_text(text_key, 3.0, Keys.stat_melee_damage_hash, 0.3, player_index, colored)
	if text_key == "EFFECT_STATIC_CLING":  # main.gd: 6 + Elemental Damage per zap
		return _scaling_formula_text(text_key, 6.0, Keys.stat_elemental_damage_hash, 1.0, player_index, colored)
	if text_key == "EFFECT_GREASE_FIRE":  # main.gd: (2 + 0.2 * Appetite) * stacks burn/tick
		return _scaling_formula_text(text_key, 2.0, Keys.stat_appetite_hash, 0.2, player_index, colored)
	# Gourmet DLC - Slug slimed tick: main.gd SLIME_DAMAGE_BASE + SLIME_DAMAGE_ELEMENTAL_RATIO
	# x Elemental Damage, floored at 1, every SLIME_DAMAGE_TICK seconds. Keep in sync.
	if text_key == "EFFECT_SLUG_SLIME":
		return _scaling_formula_text(text_key, 1.0, Keys.stat_elemental_damage_hash, 0.15, player_index, colored)
	# Soul Food risk: player.gd flips a buff negative on a FLAT SOUL_FLIP_PCT%. It used to
	# scale as max(0, 5 - 0.1 x Luck), which floored at 0 and let high-Luck builds delete
	# the downside, so there is nothing left to compute live - render the effect's own
	# value (the template is single-arg to match; see the silent-discard trap).
	if text_key == "EFFECT_SOUL_FOOD_RISK":
		return Text.text(text_key, [str(int(value))], [] if !colored else [Sign.NEUTRAL])
	# Gourmet DLC - weapon on-hit food proc (Corn/Fish/Pizza/Sauce/Scoop/Spatula): the
	# effect value IS the tier's % chance; render it into the "{0}% chance" line. One case
	# covers all six weapons (custom_key "food_drop:<food>").
	if custom_key.begins_with("food_drop:"):
		return Text.text(text_key, [str(int(value))], [] if !colored else [Sign.NEUTRAL])

	# Gourmet DLC - Dinner Bell: extend_buffs value is tenths of a second (unit.gd uses
	# value/10), so render value/10 - scales per tier (2/3/4/5 -> 0.2/0.3/0.4/0.5s).
	if text_key == "EFFECT_W_BELL":
		return Text.text(text_key, [str(stepify(value / 10.0, 0.1))], [] if !colored else [Sign.NEUTRAL])

	if text_key == "EFFECT_POPCORN_MACHINE":  # main.gd add_explosion: 5% * (1 + 0.10 * Appetite) chance per explosion
		var pop_app: = 0.0
		if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
			pop_app = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
		var pop_current: = stepify(5.0 * (1.0 + 0.10 * pop_app), 0.1)
		# {2} is the per-pop food count. This branch bypasses get_args(), so without pushing
		# `value` explicitly a cursed Popcorn Machine would pop 2 and still advertise 1.
		return Text.text(text_key, ["5", str(pop_current), str(int(value))],
			[] if !colored else [Sign.NEUTRAL, Sign.NEUTRAL, Sign.NEUTRAL])

	if text_key == "EFFECT_JUGGLER_TEMPO":  # weapon.gd metronome: 18 frames / (1 + AttackSpeed/100), clamped [3, 180] -> 0.3s base
		var jt_as: float = 0.0
		if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
			jt_as = Utils.get_stat(Keys.stat_attack_speed_hash, player_index)
		var jt_cur: float = stepify(clamp(18.0 / max(0.1, 1.0 + jt_as / 100.0), 3.0, 180.0) / 60.0, 0.01)
		return Text.text(text_key, ["0.3", str(jt_cur)], [] if !colored else [Sign.NEUTRAL, Sign.NEUTRAL])

	# Gourmet DLC - Juggler combo: weapon.gd JUGGLER_COMBO_PER_WEAPON per weapon already fired
	# this cycle, so the LAST weapon of an N-weapon loadout hits for 8 x (N - 1) percent more.
	# {0} is that peak, computed from the live weapon count (0 with fewer than 2 weapons).
	if text_key == "EFFECT_JUGGLER_COMBO":
		var jc_weapons: = 0
		if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
			jc_weapons = RunData.get_player_weapons_ref(player_index).size()
		var jc_peak: int = int(round(8.0 * max(0, jc_weapons - 1)))
		return Text.text(text_key, [str(jc_peak)], [] if !colored else [Sign.POSITIVE])

	# Gourmet DLC - Minimalist summary: always rendered live from the current inventory,
	# so stale effects embedded in old run saves still display correctly.
	# No class references here: Effect must not depend on the item class chain (cyclic).
	if text_key == "EFFECT_MINIMALIST_ALL":
		var minimalist_total: = 0.0
		if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
			minimalist_total = RunData.get_nb_minimalist_items(player_index) * 2.0
		var minimalist_signs: = [] if !colored else [Sign.POSITIVE]
		return Text.text("EFFECT_MINIMALIST_ALL", [str(int(round(minimalist_total)))], minimalist_signs)

	var key_text = key.to_upper() if text_key.length() == 0 else text_key.to_upper()
	var args = get_args(player_index)
	var signs = []

	for i in args:
		signs.push_back(get_sign(effect_sign, value))

	if not _custom_args_added:
		_add_custom_args()
		_custom_args_added = true

	for custom_arg in custom_args:
		var i = custom_arg.arg_index
		if i >= args.size():
			for j in (i - args.size()) + 1:
				args.push_back("")
				signs.push_back(Sign.NEUTRAL)

		args[i] = get_arg_value(custom_arg, args[i], player_index)
		if args[i] == "no_display" :
			return ""
		signs[i] = get_sign(custom_arg.arg_sign, int(args[i]))
		args[i] = get_formatted(custom_arg.arg_format, args[i], custom_arg.arg_value)

	var text = Text.text(key_text, args, [] if !colored else signs)
	if text == "":
		return text

	return text


# Gourmet DLC - weapon-style value string: the live scaled value, colored like weapon
# damage (green if boosted, white if not), with " | base" appended (dimmed grey) only once
# scaling has added at least 1. Mirrors weapon_stats.get_dmg_text_with_scaling_stats.
func _weapon_style_value(current: int, base_value: int, colored: bool) -> String:
	if not colored:
		return str(current) if current - base_value < 1 else str(current) + " | " + str(base_value)
	var col_a = "[color=#" + ProgressData.settings.color_positive + "]" if current > base_value else "[color=white]"
	var value_text = col_a + str(current) + "[/color]"
	if current - base_value >= 1:
		value_text += " [color=#555555]| " + str(base_value) + "[/color]"
	return value_text


# Gourmet DLC - food card scaling arg, weapon-style: the value arg is "current | base"
# (base shown only once scaling adds >=1) plus the "+ratio% [Appetite icon]" chunk. Coloring
# is baked into the value string, so its sign is NEUTRAL.
func _add_food_formula_args(base, ratio, args: Array, signs: Array, player_index: int, colored: bool) -> void:
	var appetite: = 0.0
	if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
		appetite = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
	args.push_back(_weapon_style_value(int(base + ratio * appetite), int(base), colored))
	signs.push_back(Sign.NEUTRAL)
	if ratio != 0.0:
		args.push_back(Utils.get_scaling_stat_icon_text(Keys.stat_appetite_hash, ratio, true))
		signs.push_back(Sign.NEUTRAL)


# Gourmet DLC - the permanent-grant twin of _add_food_formula_args (Fried Egg +Luck, Fruit
# Salad +Harvesting). Same card idiom and same 1-or-2 arg rule, but the maths is
# MULTIPLICATIVE - base x (1 + ratio x Appetite), mirroring player.gd - where the buff/heal
# path is additive, so the two cannot share an implementation.
func _add_food_perm_args(base, ratio, args: Array, signs: Array, player_index: int, colored: bool) -> void:
	var appetite: = 0.0
	if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
		appetite = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
	args.push_back(_weapon_style_value(int(round(base * (1.0 + ratio * appetite))), int(base), colored))
	signs.push_back(Sign.NEUTRAL)
	if ratio != 0.0:
		args.push_back(Utils.get_scaling_stat_icon_text(Keys.stat_appetite_hash, ratio, true))
		signs.push_back(Sign.NEUTRAL)


# Gourmet DLC - custom scaling cards, weapon-style "current | base (+ratio% [stat icon])".
# Keep the (base, stat, ratio) at each call site in sync with the gameplay code.
func _scaling_formula_text(formula_key: String, base: float, stat_hash: int, ratio: float, player_index: int, colored: bool) -> String:
	var stat_value: = 0.0
	if player_index >= 0 and player_index != RunData.DUMMY_PLAYER_INDEX:
		stat_value = max(0.0, Utils.get_stat(stat_hash, player_index))
	var s_args: = [_weapon_style_value(int(base + ratio * stat_value), int(base), colored), Utils.get_scaling_stat_icon_text(stat_hash, ratio, true)]
	var s_signs: = [Sign.NEUTRAL, Sign.NEUTRAL]
	return Text.text(formula_key, s_args, [] if !colored else s_signs)


func get_icon(_player_index: int) -> Texture:
	var icon : Texture

	var stat_icon : int
	match key_hash :
		Keys.effect_increase_stat_gains_hash, Keys.effect_reduce_stat_gains_hash :
			stat_icon = Keys.generate_hash(get("stat_displayed"))
		Keys.effect_weapon_class_bonus_hash:
			stat_icon = Keys.generate_hash(get("stat_displayed_name"))
		_ :


			stat_icon = key_hash
	match stat_icon :
		Keys.stat_crit_damage_hash :
			stat_icon = Keys.stat_crit_chance_hash
		Keys.stat_damage_hash :
			stat_icon = Keys.stat_percent_damage_hash

	if stat_icon != Keys.empty_hash and stat_icon != Keys.explosion_damage_hash and stat_icon != Keys.xp_gain_hash:
		icon = ItemService.get_stat_small_icon(stat_icon)
	if icon == null :
		return UIService.empty_stat


	return icon


func get_arg_value(custom_arg: CustomArg, p_base_value: String, player_index: int) -> String:
	var from_arg_value = custom_arg.arg_value
	var from_arg_key = custom_arg.arg_key
	var final_value = p_base_value

	if from_arg_value != ArgValue.USUAL:
		match from_arg_value:
			ArgValue.VALUE: final_value = str(value)
			ArgValue.ABS_VALUE: final_value = str(abs(value))
			ArgValue.DIFFICULTY_VALUE:
				if RunData.current_difficulty < int(from_arg_key) :
					final_value = "no_display"
			ArgValue.KEY:
				var arg_key = key if from_arg_key.empty() else from_arg_key
				final_value = str(tr(arg_key.to_upper()))
			ArgValue.UNIQUE_WEAPONS:
				var nb = RunData.get_unique_weapon_ids(player_index).size()
				final_value = str(value * nb)
			ArgValue.ADDITIONAL_WEAPONS:
				var nb = RunData.get_player_weapons_ref(player_index).size()
				final_value = str(value * nb)
			ArgValue.TIER:
				var val = "TIER_I"
				if value == 1: val = "TIER_II"
				elif value == 2: val = "TIER_III"
				elif value == 3: val = "TIER_IV"
				final_value = tr(val)
			ArgValue.SCALING_STAT:



				var show_plus_prefix := false
				assert(key_hash != null and key_hash != Keys.empty_hash)
				final_value = Utils.get_scaling_stat_icon_text(key_hash, value/100.0, show_plus_prefix)
			ArgValue.SCALING_STAT_VALUE:
				final_value = str(WeaponService.sum_scaling_stat_values([[key_hash, value/100.0]], player_index))
			ArgValue.MAX_NB_OF_WAVES:
				final_value = str(RunData.nb_of_waves)
			ArgValue.TIER_IV_WEAPONS:
				var weapons = RunData.get_player_weapons_ref(player_index)
				var nb_tier_iv_weapons = 0
				for weapon in weapons:
					if weapon.tier >= Tier.LEGENDARY:
						nb_tier_iv_weapons += 1
				final_value = str(value * nb_tier_iv_weapons)
			ArgValue.TIER_I_WEAPONS:
				var weapons = RunData.get_player_weapons_ref(player_index)
				var nb_tier_i_weapons = 0
				for weapon in weapons:
					if weapon.tier <= Tier.COMMON:
						nb_tier_i_weapons += 1
				final_value = str(value * nb_tier_i_weapons)
			_: print("wrong value")
	return final_value


func get_sign(from_sign: int, from_value: int) -> int:

	var final_sign = from_sign

	if from_sign == Sign.FROM_VALUE:
		final_sign = Sign.POSITIVE if value > 0 else Sign.NEGATIVE if value < 0 else Sign.NEUTRAL
	elif from_sign == Sign.FROM_ARG:
		final_sign = Sign.POSITIVE if from_value > 0 else Sign.NEGATIVE if from_value < 0 else Sign.NEUTRAL
	else:
		final_sign = from_sign

	return final_sign


func get_formatted(from_format: int, from_value: String, base_arg_value: int) -> String:
	var formatted = from_value

	if from_format != Format.USUAL:
		match from_format:
			Format.PERCENT: formatted = str(float(from_value) / 100.0)
			Format.ARG_VALUE_AS_NUMBER: formatted = str(base_arg_value)
			Format.REMOVE_OPERATOR: formatted = from_value.replace("-", "")
			_: print("wrong format")

	return formatted


func get_args(_player_index: int) -> Array:
	var displayed_key = key

	if custom_key == "starting_weapon":
		displayed_key = key.substr(0, key.length() - 2)

	return [str(value), tr(displayed_key.to_upper())]


func serialize() -> Dictionary:

	var custom_args_serialized = []

	for custom_arg in custom_args:
		custom_args_serialized.push_back(custom_arg.serialize())

	return {
		"effect_id": get_id(),
		"key": key,
		"custom_key": custom_key,
		"text_key": text_key,
		"storage_method": storage_method,
		"value": str(value),
		"effect_sign": effect_sign,
		"base_value": base_value,
		"curse_factor": curse_factor,
		"custom_args": custom_args_serialized
	}


func deserialize_and_merge(effect: Dictionary) -> void:
	key = effect.key
	key_hash = Keys.generate_hash(key)
	custom_key = effect.custom_key
	custom_key_hash = Keys.generate_hash(custom_key)
	text_key = effect.text_key
	value = effect.value as int
	effect_sign = effect.effect_sign as int
	storage_method = effect.storage_method as int
	base_value = effect.base_value
	curse_factor = effect.curse_factor if "curse_factor" in effect else 0.0

	if "custom_args" in effect:
		var deserialized_custom_args = []
		for serialized_custom_arg in effect.custom_args:
			var deserialized_custom_arg = CustomArg.new()
			deserialized_custom_arg.deserialize_and_merge(serialized_custom_arg)
			deserialized_custom_args.push_back(deserialized_custom_arg)
		custom_args = deserialized_custom_args


func _add_custom_args() -> void:

	return
