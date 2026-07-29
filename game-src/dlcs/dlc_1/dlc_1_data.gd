extends DLCData

export (Resource) var cursed_chest
export (float, 0.0, 1.0, 0.01) var base_cursed_chest_chance: = 0.03
export (float, 0.0, 1.0, 0.01) var base_item_curse_chance: = 0.03

export (int, 0, 100) var cursed_item_base_percent_modifier: = 40
export (int, 0, 100) var cursed_item_random_percent_modifier: = 30
export (int, 0, 100) var cursed_item_percent_modifier_increase_each_wave: = 2
export (float, 0.0, 0.1, 0.001) var curse_per_item_value = 0.04
export (float, 0.0, 1.0, 0.01) var max_curse_item_chance = 0.01

export var increase_factor_for_mediocre_boosts: = 3
export var treasure_map_luck: = 5
export var wandering_bot_speed: = 5
export var anvil_armor: = 3
export var mirror_item_price: = - 10
export var sifds_relic_dodge: = 10
export var axolotl_stats: = 5
export var jerky_hp_regen: = 2
export var hunting_trophy_crit_chance: = 5
export var curse_hook_damage: = 3

export (Resource) var poisoned_fruit


func update_consumable_to_get(base_consumable_data: ConsumableData) -> ConsumableData:
	var chance_poisoned = 0

	for player_data in RunData.players_data:
		if player_data.effects[Keys.poisoned_fruit_hash] > 0:
			chance_poisoned = player_data.effects[Keys.poisoned_fruit_hash]
			break

	if base_consumable_data != null and base_consumable_data.my_id == "consumable_fruit" and Utils.get_chance_success(chance_poisoned / 100.0):
		return poisoned_fruit
	return base_consumable_data


# Gourmet DLC - The Freeloader's flat, unmodifiable shop curse rate. Sits deliberately
# above max_curse_item_chance (0.15 in dlc_data.tres), which is the hard ceiling no other
# character can pass no matter how much Curse they stack.
const FREELOADER_CURSE_CHANCE: = 0.25


func update_item_effects(item_data: ItemParentData, player_index: int) -> ItemParentData:


	var curse_chance = max(0, Utils.get_max_capped_stat(Keys.stat_curse_hash, player_index)) as int
	var drop_chance: float = Utils.get_curse_factor(max(base_item_curse_chance * 100.0, curse_chance), max_curse_item_chance * 100.0) / 100.0

	# Gourmet DLC - flat 25% for the Freeloader, ignoring both his own stat_curse and the
	# game ceiling above. He still ACCUMULATES stat_curse from every cursed item he takes:
	# that is the entire cost of the character. Curse has three jobs (enemy curse chance,
	# shop curse chance, cursed drop chance) and for him the last two are locked or dead,
	# so it collapses into "how many enemies are cursed" - and cursed enemies compensate
	# in gold, which he cannot use.
	if RunData.is_freeloader(player_index):
		drop_chance = FREELOADER_CURSE_CHANCE

	return curse_item(item_data, player_index) if Utils.get_chance_success(drop_chance) else item_data


func curse_item(item_data: ItemParentData, player_index: int, turn_randomization_off: bool = false, min_modifier: float = 0.0) -> ItemParentData:
	if item_data.is_cursed:
		return item_data

	var new_effects: = []
	var max_effect_modifier = 0.0
	var curse_effect_modified: = false
	var new_item_data = item_data.duplicate()

	if item_data is WeaponData:
		var effect_modifier: = _get_cursed_item_effect_modifier(turn_randomization_off, min_modifier)
		max_effect_modifier = max(max_effect_modifier, effect_modifier)
		new_item_data.stats = _boost_weapon_stats_damage(item_data.stats, effect_modifier)

	for effect in item_data.effects:
		var effect_modifier: = _get_cursed_item_effect_modifier(turn_randomization_off, min_modifier)
		max_effect_modifier = max(max_effect_modifier, effect_modifier)

		if effect.key != "":
			assert (effect.key_hash != null and effect.key_hash != Keys.empty_hash)

		var new_effect = effect.duplicate()

		if effect is StructureEffect:
			new_effect.is_cursed = true

			if effect.key_hash == Keys.wandering_bot_hash:
				
				assert (item_data.my_id == "item_wandering_bot", "expected item_wandering_bot (got %s)" % item_data.my_id)
				var extra_effect = Effect.new()
				extra_effect.key = "stat_speed"
				extra_effect.key_hash = Keys.stat_speed_hash
				extra_effect.value = int(ceil(wandering_bot_speed * (1.0 + effect_modifier)))
				new_effects.append(extra_effect)
			elif effect.spawn_cooldown > 0:
				
				new_effect.spawn_cooldown = WeaponService.apply_attack_speed_mod_to_cooldown(effect.spawn_cooldown, effect_modifier)
			elif not effect.stats.scaling_stats.empty():
				
				new_effect.stats = _boost_weapon_stats_damage(effect.stats, effect_modifier)
			elif effect.effects.size() >= 1 and effect.effects[0] is BurningEffect:
				
				var new_burning_effect = effect.effects[0].duplicate()
				var new_burning_data = new_burning_effect.burning_data.duplicate()
				new_burning_data.scaling_stats = _boost_scaling_sats(new_burning_data.scaling_stats, effect_modifier)
				new_burning_effect.burning_data = new_burning_data
				new_effect.effects[0] = new_burning_effect
			else:
				
				var stats = effect.stats.duplicate()
				
				stats.cooldown = WeaponService.apply_attack_speed_mod_to_cooldown(stats.cooldown / Utils.TICKS_PER_SECOND, effect_modifier) * Utils.TICKS_PER_SECOND
				new_effect.stats = stats
		elif effect is PetEffect:
			new_effect.is_cursed = true
			if effect is BonkDogEffect:
				new_effect.weapon_stats = _boost_weapon_stats_damage(effect.weapon_stats, effect_modifier)
				var explosion_effect = effect.explosion_effect.duplicate()
				explosion_effect.stats = _boost_weapon_stats_damage(effect.explosion_effect.stats, effect_modifier)
				new_effect.explosion_effect = explosion_effect
			elif effect is CatlingGunEffect:
				new_effect.weapon_stats = _boost_weapon_stats_damage(effect.weapon_stats, effect_modifier)
			elif effect is BotOMineEffect:
				new_effect.weapon_stats = _boost_weapon_stats_damage(effect.weapon_stats, effect_modifier)
				var landmine_effect_stat = effect.landmine_effect_stat.duplicate()
				landmine_effect_stat.spawn_cooldown = WeaponService.apply_attack_speed_mod_to_cooldown(landmine_effect_stat.spawn_cooldown, effect_modifier)
				new_effect.landmine_effect_stat = landmine_effect_stat
			elif effect is BlazemanderEffect:
				var new_burning_data = effect.burning_data.duplicate()
				new_burning_data.scaling_stats = _boost_scaling_sats(effect.burning_data.scaling_stats, effect_modifier)
				new_effect.burning_data = new_burning_data
				var new_ranged_weapon_stats = effect.ranged_weapon_stats.duplicate()
				new_ranged_weapon_stats.cooldown = effect.ranged_weapon_stats.cooldown / 2
				new_ranged_weapon_stats.max_range = effect.ranged_weapon_stats.max_range / (1 + effect_modifier)
				new_effect.ranged_weapon_stats = new_ranged_weapon_stats
			elif effect is DocMothEffect:
				new_effect.boost_zone_scale = effect.boost_zone_scale * (1 + effect_modifier)
				new_effect.text_key = "EFFECT_PET_DOC_MOTH_CURSED"
			elif effect is LootwormEffect:
				new_effect.double_chance = effect.double_chance * (1 + effect_modifier)
			elif effect is ScapegoatEffect:
				new_effect.revive_duration = effect.revive_duration / (1 + effect_modifier)
				new_effect.health_boost += effect_modifier
				new_effect.text_key = "EFFECT_PET_SCAPEGOAT_CURSED"
			elif effect is RatzillaEffect:
				new_effect.weapon_stats = _boost_weapon_stats_damage(effect.weapon_stats, effect_modifier)
		elif effect is PlayerNoHitEffect:
			new_effect.value = int(effect.value * (1 + effect_modifier))
		elif effect is BurnChanceEffect:
			
			var burning_data = effect.burning_data.duplicate()
			burning_data.duration = int(ceil(burning_data.duration * (1.0 + effect_modifier)))
			burning_data.damage = int(ceil(burning_data.damage * (1.0 + effect_modifier)))
			new_effect.burning_data = burning_data
		elif effect is BurningEffect:
			
			var burning_data = effect.burning_data.duplicate()
			burning_data.duration = int(ceil(burning_data.duration * (1.0 + effect_modifier)))
			burning_data.damage = int(ceil(burning_data.damage * (1.0 + effect_modifier)))
			new_effect.burning_data = burning_data
		elif effect is ItemExplodingEffect:
			if effect.scale_with_missing_health:
				new_effect.value = _boost_effect_value_positively(effect, effect_modifier)
			else:
				new_effect.stats = _boost_weapon_stats_damage(effect.stats, effect_modifier)
		elif item_data is WeaponData and effect is ExplodingEffect and effect.chance < 1.0:
			new_effect.chance = min(1.0, new_effect.chance * (1.0 + effect_modifier / 5.0))

			if new_effect.chance >= 1.0:
				new_effect.text_key = "effect_explode"

		elif effect is ProjectileEffect or effect is ProjectilesOnHitEffect:
			new_effect.weapon_stats = _boost_weapon_stats_damage(effect.weapon_stats, effect_modifier)
		elif effect is GainStatEveryKilledEnemiesEffect:
			new_effect.value = _boost_effect_value_positively(new_effect, effect_modifier, true, Sign.NEGATIVE)
		elif effect.custom_key_hash == Keys.gain_stat_for_every_step_after_equip_hash:
			new_effect.value2 = _boost_effect_value_positively(new_effect, effect_modifier, true, Sign.NEGATIVE, true)
		elif effect.key_hash == Keys.break_on_hit_hash:
			new_effect.value2 = _boost_effect_value_positively(new_effect, effect_modifier, false, Sign.POSITIVE, true)
		elif effect.key_hash == Keys.dodge_cap_hash:
			new_effect.value = Utils.randi_range(72, 76)
		elif item_data.my_id_hash == Keys.item_will_o_the_wisp_hash and effect.key_hash == Keys.stat_elemental_damage_hash:
			new_effect.value = Utils.randi_range(16, 25)
			new_effect.value3 = Utils.randi_range(5, 7)
		elif item_data.my_id_hash == Keys.item_candy_bag_hash and effect.key_hash == Keys.extra_elite_next_wave_chance_hash:
			new_effect.value = effect.value
		elif effect.key_hash == Keys.hp_start_next_wave_hash:
			new_effect.value = - 100
		elif effect.key_hash == Keys.stat_jellyshield_count_hash:
			var extra_effect = Effect.new()
			extra_effect.key = "stat_armor"
			extra_effect.key_hash = Keys.stat_armor_hash
			extra_effect.value = int(ceil(1 * (1.0 + effect_modifier)))
			new_effects.append(extra_effect)
		elif effect.key_hash == Keys.item_mirror_hash:
			new_effects.append(effect)
			var extra_effect = Effect.new()
			extra_effect.key = "items_price"
			extra_effect.key_hash = Keys.items_price_hash
			extra_effect.value = mirror_item_price
			extra_effect.effect_sign = Sign.POSITIVE
			extra_effect.value = _boost_effect_value_positively(extra_effect, effect_modifier)
			new_effects.append(extra_effect)
			var extra_tooltip_effect = Effect.new()
			extra_tooltip_effect.text_key = "EFFECT_CURSED_MIRROR"
			new_effects.append(extra_tooltip_effect)
			continue
		elif effect.key_hash == Keys.hit_protection_hash:
			assert (item_data.my_id == "item_tardigrade", "expected item_tardigrade (got %s)" % item_data.my_id)
			new_effect.value = 2
			new_effect.text_key = "effect_hit_protection_plural"
		elif effect.key_hash == Keys.one_shot_trees_hash or effect.key_hash == Keys.tree_turrets_hash:
			
			var extra_effect = Effect.new()
			extra_effect.key = "trees"
			extra_effect.key_hash = Keys.trees_hash
			extra_effect.text_key = "effect_trees"
			extra_effect.value = 1
			new_effects.append(extra_effect)
		elif effect.key_hash == Keys.instant_gold_attracting_hash and effect.value == 100:
			assert (item_data.my_id == "item_sifds_relic", "expected item_sifds_relic (got %s)" % item_data.my_id)
			var extra_effect = Effect.new()
			extra_effect.key = "stat_dodge"
			extra_effect.key_hash = Keys.stat_dodge_hash
			extra_effect.value = int(ceil(sifds_relic_dodge * (1.0 + effect_modifier)))
			new_effects.append(extra_effect)
		elif effect.key_hash == Keys.hp_regen_bonus_hash:
			
			assert (item_data.my_id == "item_potion", "expected item_potion (got %s)" % item_data.my_id)
			new_effect.value2 = min(90.0, _boost_effect_value_positively(effect, effect_modifier, false, Sign.POSITIVE, true))
		else:
			var override = false
			var overriden_sign = Sign.POSITIVE

			if effect.key_hash == Keys.consumable_heal_over_time_hash:
				override = true
				overriden_sign = Sign.NEUTRAL
				var extra_effect = Effect.new()
				extra_effect.key = "stat_hp_regeneration"
				extra_effect.key_hash = Keys.stat_hp_regeneration_hash
				extra_effect.value = int(ceil(jerky_hp_regen * (1.0 + effect_modifier)))
				new_effects.append(extra_effect)
			elif effect.key_hash == Keys.knockback_aura_hash:
				override = true
				overriden_sign = Sign.NEGATIVE
			elif effect.key_hash == Keys.modify_every_x_projectile_hash:
				override = true
				overriden_sign = Sign.NEGATIVE
			elif item_data.my_id_hash == Keys.item_estys_couch_hash and effect.key_hash == Keys.stat_speed_hash:
				override = true
				overriden_sign = Sign.POSITIVE
			elif "weapon_mace" in item_data.my_id and effect.key_hash == Keys.stat_attack_speed_hash:
				override = true
				overriden_sign = Sign.POSITIVE
			elif ((item_data.my_id_hash == Keys.item_baby_gecko_hash and effect.key_hash == Keys.stat_range_hash) or 
				(item_data.my_id_hash == Keys.item_potion_hash and effect.key_hash == Keys.stat_hp_regeneration_hash) or 
				item_data.my_id_hash == Keys.item_pile_of_books_hash or item_data.my_id_hash == Keys.item_pocket_factory_hash):
				effect_modifier *= increase_factor_for_mediocre_boosts
			elif new_effect.custom_key_hash == Keys.upgrade_random_weapon_hash:
				
				assert (item_data.my_id == "item_anvil", "expected item_anvil (got %s)" % item_data.my_id)
				var extra_effect = Effect.new()
				extra_effect.key = "stat_armor"
				extra_effect.key_hash = Keys.stat_armor_hash
				extra_effect.value = int(ceil(anvil_armor * (1.0 + effect_modifier)))
				new_effects.append(extra_effect)
			elif effect.custom_key_hash == Keys.extra_item_in_crate_hash and effect.key_hash == Keys.random_hash:
				var extra_effect = Effect.new()
				extra_effect.key = "stat_luck"
				extra_effect.key_hash = Keys.stat_luck_hash
				extra_effect.value = treasure_map_luck
				extra_effect.effect_sign = Sign.POSITIVE
				extra_effect.value = _boost_effect_value_positively(extra_effect, effect_modifier)
				new_effects.append(extra_effect)

			new_effect.value = _boost_effect_value_positively(effect, effect_modifier, override, overriden_sign)

			if new_effect.custom_key_hash == Keys.consumable_stats_while_max_hash:
				new_effect.value2 = _boost_effect_value_positively(effect, effect_modifier, override, overriden_sign, true)
			elif new_effect.key_hash == Keys.remove_speed_hash:
				new_effect.value2 = new_effect.value * 4
			elif (new_effect.key_hash == Keys.burning_enemy_hp_percent_damage_hash
				or new_effect.key_hash == Keys.giant_crit_damage_hash
				or new_effect.key_hash == Keys.bonus_current_health_damage_hash):
				new_effect.value2 = new_effect.value / 10.0
			elif new_effect.key_hash == Keys.gold_on_crit_kill_hash:
				new_effect.value = min(new_effect.value, 100) as int
				if item_data.my_id_hash == Keys.item_hunting_trophy_hash:
					var extra_effect = Effect.new()
					extra_effect.key = "stat_crit_chance"
					extra_effect.key_hash = Keys.stat_crit_chance_hash
					extra_effect.value = int(ceil(hunting_trophy_crit_chance * (1.0 + effect_modifier)))
					new_effects.append(extra_effect)


			if effect.key_hash == Keys.stat_curse_hash:
				curse_effect_modified = true

		
		if effect.custom_key_hash == Keys.increase_tier_on_reroll_hash:
			new_effect.text_key = "effect_increase_tier_on_reroll_plural"
		elif effect.key_hash == Keys.modify_every_x_projectile_hash:
			if effect is WeaponEffectWithSubEffects:
				
				new_effect.value = max(1, effect.value - 1)
				if new_effect.value == 1:
					new_effect.text_key = "effect_weapon_modify_every_x_projectile_first"
				elif new_effect.value == 2:
					new_effect.text_key = "effect_weapon_modify_every_x_projectile_second"
				elif new_effect.value == 3:
					new_effect.text_key = "effect_weapon_modify_every_x_projectile_third"
			elif effect is EffectWithSubEffects:
				if new_effect.value == 1:
					new_effect.text_key = "effect_modify_every_x_projectile_first"
				elif new_effect.value == 2:
					new_effect.text_key = "effect_modify_every_x_projectile_second"
				elif new_effect.value == 3:
					new_effect.text_key = "effect_modify_every_x_projectile_third"
		elif effect.key_hash == Keys.bounce_hash:
			new_effect.text_key = "effect_bouncing_plural"
		elif effect.key_hash == Keys.piercing_hash:
			new_effect.text_key = "effect_piercing_plural"
		elif effect.key_hash == Keys.free_rerolls_hash:
			new_effect.text_key = "effect_free_shop_reroll_plural"
		elif effect.key_hash == Keys.gold_on_cursed_enemy_kill_hash:
			new_effect.text_key = "effect_gold_on_cursed_enemy_kill_plural"
		elif effect.key_hash == Keys.burning_spread_hash:
			new_effect.text_key = "effect_burning_spread_plural"
		elif effect.key_hash == Keys.trees_hash:
			new_effect.text_key = "effect_trees_plural"
		elif effect.key_hash == Keys.knockback_aura_hash and new_effect.value <= 1:
			new_effect.text_key = "effect_knockback_aura"

		new_effects.append(new_effect)

		if effect is SwapMaxMinStatEffect:
			var min_max_stat_values = effect._find_min_max_stat_keys(player_index)

			var extra_effect = Effect.new()
			extra_effect.key = Keys.hash_to_string[min_max_stat_values[1]]
			extra_effect.key_hash = min_max_stat_values[1]
			extra_effect.value = axolotl_stats
			extra_effect.effect_sign = Sign.POSITIVE
			extra_effect.value = _boost_effect_value_positively(extra_effect, effect_modifier)
			new_effects.append(extra_effect)

			var extra_effect_2 = extra_effect.duplicate()
			extra_effect_2.key = Keys.hash_to_string[min_max_stat_values[0]]
			extra_effect_2.key_hash = min_max_stat_values[0]
			new_effects.append(extra_effect_2)

	if not curse_effect_modified:
		var curse_effect = Effect.new()
		curse_effect.key = "stat_curse"
		curse_effect.key_hash = Keys.stat_curse_hash
		curse_effect.value = round(max(1.0, curse_per_item_value * item_data.value * (1.0 + max_effect_modifier))) as int
		curse_effect.effect_sign = Sign.OVERRIDE
		new_effects.append(curse_effect)

	new_item_data.effects = new_effects
	new_item_data.is_cursed = true

	new_item_data.curse_factor = max_effect_modifier

	return new_item_data as ItemParentData


func _get_cursed_item_effect_modifier(turn_randomization_off: bool = false, min_modifier: float = 0.0) -> float:
	var random_modifier: = 0 if turn_randomization_off else Utils.randi_range( - cursed_item_random_percent_modifier, cursed_item_random_percent_modifier)
	var wave_basis = 0 if turn_randomization_off else RunData.current_wave
	var percent_modifier: = cursed_item_base_percent_modifier + cursed_item_percent_modifier_increase_each_wave * min(20, (wave_basis - 1)) + random_modifier
	return max(min_modifier, percent_modifier / 100.0)


func _boost_effect_value_positively(effect: Effect, effect_modifier: float, override_effect_good_or_bad_status: bool = false, overriden_sign: int = Sign.POSITIVE, modify_value2: bool = false) -> int:

	var value = effect.value if not modify_value2 else effect.value2
	var effect_sign = effect.get_sign(effect.effect_sign, value)

	if override_effect_good_or_bad_status:
		effect_sign = overriden_sign

	var is_effect_good = effect_sign == Sign.POSITIVE or effect_sign == Sign.OVERRIDE
	var effect_value_sign: = sign(value) as int

	if is_effect_good:
		return effect_value_sign * int(ceil(abs(value) * (1.0 + effect_modifier)))
	elif effect_sign == Sign.NEUTRAL:
		return value

	return effect_value_sign * int(max(1.0, floor(abs(value) / (1.0 + effect_modifier))))


func _boost_weapon_stats_damage(stats: WeaponStats, effect_modifier: float) -> WeaponStats:
	var new_stats = stats.duplicate()
	new_stats.damage = int(ceil(stats.damage * (1.0 + effect_modifier)))
	new_stats.scaling_stats = _boost_scaling_sats(stats.scaling_stats, effect_modifier)
	new_stats.crit_damage = stepify(stats.crit_damage * (1.0 + effect_modifier / 5.0), 0.1)

	if new_stats.lifesteal > 0:
		new_stats.lifesteal = stepify(stats.lifesteal * (1.0 + effect_modifier), 0.01)

	if stats is RangedWeaponStats:
		if new_stats.piercing > 0:
			new_stats.piercing = int(min(stats.piercing + 1, ceil(stats.piercing * (1.0 + effect_modifier / 5.0))))

		if new_stats.bounce > 0:
			new_stats.bounce = int(min(stats.bounce + 1, ceil(stats.bounce * (1.0 + effect_modifier / 5.0))))

	return new_stats


func _boost_scaling_sats(scaling_stats: Array, effect_modifier: float) -> Array:
	var new_scaling_stats = scaling_stats.duplicate(true)
	for scaling_stat in new_scaling_stats:
		scaling_stat[1] *= (1.0 + effect_modifier)
	return new_scaling_stats
