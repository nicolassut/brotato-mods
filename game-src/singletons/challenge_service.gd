extends Node

signal challenge_completed(challenge)

export (Array, Resource) var challenges

var stat_challenges: = []
var hash_to_id: = {}


var achievement_mapping: = {}
var need_achievements: = false
var num_achievement: = 0

var chal_difficulty_0_hash: = Keys.generate_hash("chal_difficulty_0")
var chal_difficulty_1_hash: = Keys.generate_hash("chal_difficulty_1")
var chal_difficulty_2_hash: = Keys.generate_hash("chal_difficulty_2")
var chal_difficulty_3_hash: = Keys.generate_hash("chal_difficulty_3")
var chal_difficulty_4_hash: = Keys.generate_hash("chal_difficulty_4")
var chal_difficulty_5_hash: = Keys.generate_hash("chal_difficulty_5")
var chal_survivor_1_hash: = Keys.generate_hash("chal_survivor_1")
var chal_survivor_2_hash: = Keys.generate_hash("chal_survivor_2")
var chal_survivor_3_hash: = Keys.generate_hash("chal_survivor_3")
var chal_survivor_4_hash: = Keys.generate_hash("chal_survivor_4")
var chal_survivor_5_hash: = Keys.generate_hash("chal_survivor_5")
var chal_gatherer_1_hash: = Keys.generate_hash("chal_gatherer_1")
var chal_gatherer_2_hash: = Keys.generate_hash("chal_gatherer_2")
var chal_gatherer_3_hash: = Keys.generate_hash("chal_gatherer_3")
var chal_gatherer_4_hash: = Keys.generate_hash("chal_gatherer_4")
var chal_gatherer_5_hash: = Keys.generate_hash("chal_gatherer_5")
var chal_rookie_hash: = Keys.generate_hash("chal_rookie")
var chal_dying_hash: = Keys.generate_hash("chal_dying")
var chal_agriculture_hash: = Keys.generate_hash("chal_agriculture")
var chal_hallucination_hash: = Keys.generate_hash("chal_hallucination")
var chal_fast_hash: = Keys.generate_hash("chal_fast")
var chal_hoarder_hash: = Keys.generate_hash("chal_hoarder")
var chal_turrets_hash: = Keys.generate_hash("chal_turrets")
var chal_lumberjack_hash: = Keys.generate_hash("chal_lumberjack")
var chal_medicine_hash: = Keys.generate_hash("chal_medicine")
var chal_perfect_vision_hash: = Keys.generate_hash("chal_perfect_vision")
var chal_fireworks_hash: = Keys.generate_hash("chal_fireworks")
var chal_recycling_hash: = Keys.generate_hash("chal_recycling")
var chal_slow_hash: = Keys.generate_hash("chal_slow")
var chal_hungry_hash: = Keys.generate_hash("chal_hungry")
var chal_advanced_technology_hash: = Keys.generate_hash("chal_advanced_technology")
var chal_giant_slayer_hash: = Keys.generate_hash("chal_giant_slayer")
var chal_robust_hash: = Keys.generate_hash("chal_robust")
var chal_baited_hash: = Keys.generate_hash("chal_baited")
var chal_forest_hash: = Keys.generate_hash("chal_forest")
var chal_bourgeoisie_hash: = Keys.generate_hash("chal_bourgeoisie")
var chal_student_hash: = Keys.generate_hash("chal_student")
var chal_reckless_hash: = Keys.generate_hash("chal_reckless")
var chal_scavenger_hash: = Keys.generate_hash("chal_scavenger")
var chal_well_rounded_hash: = Keys.generate_hash("chal_well_rounded")
var chal_brawler_hash: = Keys.generate_hash("chal_brawler")
var chal_crazy_hash: = Keys.generate_hash("chal_crazy")
var chal_ranger_hash: = Keys.generate_hash("chal_ranger")
var chal_mage_hash: = Keys.generate_hash("chal_mage")
var chal_chunky_hash: = Keys.generate_hash("chal_chunky")
var chal_old_hash: = Keys.generate_hash("chal_old")
var chal_lucky_hash: = Keys.generate_hash("chal_lucky")
var chal_mutant_hash: = Keys.generate_hash("chal_mutant")
var chal_generalist_hash: = Keys.generate_hash("chal_generalist")
var chal_loud_hash: = Keys.generate_hash("chal_loud")
var chal_multitasker_hash: = Keys.generate_hash("chal_multitasker")
var chal_wildling_hash: = Keys.generate_hash("chal_wildling")
var chal_pacifist_hash: = Keys.generate_hash("chal_pacifist")
var chal_gladiator_hash: = Keys.generate_hash("chal_gladiator")
var chal_saver_hash: = Keys.generate_hash("chal_saver")
var chal_sick_hash: = Keys.generate_hash("chal_sick")
var chal_farmer_hash: = Keys.generate_hash("chal_farmer")
var chal_ghost_hash: = Keys.generate_hash("chal_ghost")
var chal_speedy_hash: = Keys.generate_hash("chal_speedy")
var chal_entrepreneur_hash: = Keys.generate_hash("chal_entrepreneur")
var chal_engineer_hash: = Keys.generate_hash("chal_engineer")
var chal_explorer_hash: = Keys.generate_hash("chal_explorer")
var chal_doctor_hash: = Keys.generate_hash("chal_doctor")
var chal_hunter_hash: = Keys.generate_hash("chal_hunter")
var chal_artificer_hash: = Keys.generate_hash("chal_artificer")
var chal_arms_dealer_hash: = Keys.generate_hash("chal_arms_dealer")
var chal_streamer_hash: = Keys.generate_hash("chal_streamer")
var chal_cyborg_hash: = Keys.generate_hash("chal_cyborg")
var chal_glutton_hash: = Keys.generate_hash("chal_glutton")
var chal_jack_hash: = Keys.generate_hash("chal_jack")
var chal_lich_hash: = Keys.generate_hash("chal_lich")
var chal_apprentice_hash: = Keys.generate_hash("chal_apprentice")
var chal_cryptid_hash: = Keys.generate_hash("chal_cryptid")
var chal_fisherman_hash: = Keys.generate_hash("chal_fisherman")
var chal_golem_hash: = Keys.generate_hash("chal_golem")
var chal_king_hash: = Keys.generate_hash("chal_king")
var chal_renegade_hash: = Keys.generate_hash("chal_renegade")
var chal_one_arm_hash: = Keys.generate_hash("chal_one_arm")
var chal_bull_hash: = Keys.generate_hash("chal_bull")
var chal_soldier_hash: = Keys.generate_hash("chal_soldier")
var chal_masochist_hash: = Keys.generate_hash("chal_masochist")
var chal_knight_hash: = Keys.generate_hash("chal_knight")
var chal_demon_hash: = Keys.generate_hash("chal_demon")
var chal_technomage_hash: = Keys.generate_hash("chal_technomage")
var chal_blood_drinker_hash: = Keys.generate_hash("chal_blood_drinker")
var chal_fast_learner_hash: = Keys.generate_hash("chal_fast_learner")
var chal_baby_hash: = Keys.generate_hash("chal_baby")
var chal_vagabond_hash: = Keys.generate_hash("chal_vagabond")
var chal_vampire_hash: = Keys.generate_hash("chal_vampire")
var chal_experimentation_hash: = Keys.generate_hash("chal_experimentation")
var chal_magic_and_machinery_hash: = Keys.generate_hash("chal_magic_and_machinery")
var chal_overkill_hash: = Keys.generate_hash("chal_overkill")
var chal_ogre_hash: = Keys.generate_hash("chal_ogre")
var chal_dwarf_hash: = Keys.generate_hash("chal_dwarf")
var chal_hiker_hash: = Keys.generate_hash("chal_hiker")
var chal_barbecue_hash: = Keys.generate_hash("chal_barbecue")
var chal_blind_greed_hash: = Keys.generate_hash("chal_blind_greed")
var chal_gangster_hash: = Keys.generate_hash("chal_gangster")
var chal_chef_hash: = Keys.generate_hash("chal_chef")
var chal_captain_hash: = Keys.generate_hash("chal_captain")
var chal_diver_hash: = Keys.generate_hash("chal_diver")
var chal_builder_hash: = Keys.generate_hash("chal_builder")
var chal_sailor_hash: = Keys.generate_hash("chal_sailor")
var chal_creature_hash: = Keys.generate_hash("chal_creature")
var chal_romantic_hash: = Keys.generate_hash("chal_romantic")
var chal_buccaneer_hash: = Keys.generate_hash("chal_buccaneer")
var chal_unlucky_hash: = Keys.generate_hash("chal_unlucky")
var chal_druid_hash: = Keys.generate_hash("chal_druid")
var chal_herbalist_hash: = Keys.generate_hash("chal_herbalist")
var chal_uncorrupted_hash: = Keys.generate_hash("chal_uncorrupted")
var chal_curious_hash: = Keys.generate_hash("chal_curious")
var chal_cautious_hash: = Keys.generate_hash("chal_cautious")
var chal_smelly_feet_hash: = Keys.generate_hash("chal_smelly_feet")
var chal_unstoppable_force_hash: = Keys.generate_hash("chal_unstoppable_force")
var chal_fruit_basket_hash: = Keys.generate_hash("chal_fruit_basket")
var chal_banned_items_hash: = Keys.generate_hash("chal_banned_items")
var chal_hourglass_hash: = Keys.generate_hash("chal_hourglass")
var chal_candy_bag_hash: = Keys.generate_hash("chal_candy_bag")
var chal_will_o_the_wisp_hash: = Keys.generate_hash("chal_will_o_the_wisp")
var chal_bonk_dog_hash: = Keys.generate_hash("chal_bonk_dog")
var chal_catling_gun_hash: = Keys.generate_hash("chal_catling_gun")
var chal_bot_o_mine_hash: = Keys.generate_hash("chal_bot_o_mine")
var chal_blazemander_hash: = Keys.generate_hash("chal_blazemander")
var chal_doc_moth_hash: = Keys.generate_hash("chal_doc_moth")
var chal_lootworm_hash: = Keys.generate_hash("chal_lootworm")
var chal_jellyshield_hash: = Keys.generate_hash("chal_jellyshield")
var chal_beast_master_hash: = Keys.generate_hash("chal_beast_master")
var chal_paws_n_claws_hash: = Keys.generate_hash("chal_paws_n_claws")

var _hashes_generated: = false

func add_achievement_mapping(id: int) -> void :
	achievement_mapping[id] = num_achievement
	num_achievement = num_achievement + 1

func _ready() -> void :
	_generate_hashes()

	if DebugService.reinitialize_store_data == false:
		_sync_platform_challenges()
	set_stat_challenges()


func _generate_hashes() -> void :
	if _hashes_generated: return
	for challenge in challenges:
		challenge.my_id_hash = Keys.generate_hash(challenge.my_id)
		hash_to_id[challenge.my_id_hash] = challenge.my_id
	_hashes_generated = true;

func _sync_platform_challenges() -> void :
	if ProgressData.is_unlock_all_save():
		return

	for challenge in challenges:
		if is_challenge_completed(challenge.my_id_hash):
			if challenge.description == "CHAL_CHARACTER_DESC":
				_sync_character_challenge(challenge)
				continue

			Platform.complete_challenge(challenge.my_id_hash)


func _sync_character_challenge(challenge: ChallengeData) -> void :
	if Utils.on_nintendo_nx_or_ounce:
		return

	var char_id_hash = Keys.generate_hash(challenge.my_id.replace("chal_", "character_"))
	for zone_id in [0, 1]:
		var diff_info = ProgressData.get_character_difficulty_info(char_id_hash, zone_id)
		var diff_score = diff_info.max_difficulty_beaten
		if diff_score.difficulty_value >= 0:
			if Platform.get_type() == PlatformType.STEAM or Platform.get_type() == PlatformType.GOG:
				if zone_id == 0:
					Platform.complete_challenge(challenge.my_id_hash)
				elif zone_id == 1:
					if challenge.my_id == "chal_beast_master" or challenge.my_id == "chal_wounded":
						Platform.complete_challenge(challenge.my_id_hash)
					else:
						Platform.complete_challenge(Keys.generate_hash(challenge.my_id + "_abyss"))
			else:
				Platform.complete_challenge(challenge.my_id_hash)

func set_stat_challenges() -> void :
	num_achievement = 0
	stat_challenges = []
	for chal in challenges:
		if chal.stat != "" and _should_add_stat_challenge(chal.my_id_hash):
			stat_challenges.push_back(chal)

	if Utils.on_ps4:
		print("Adding PS4 Trophies mapping")
		add_achievement_mapping(chal_difficulty_0_hash)
		add_achievement_mapping(chal_difficulty_1_hash)
		add_achievement_mapping(chal_difficulty_2_hash)
		add_achievement_mapping(chal_difficulty_3_hash)
		add_achievement_mapping(chal_difficulty_4_hash)
		add_achievement_mapping(chal_difficulty_5_hash)
		add_achievement_mapping(chal_survivor_1_hash)
		add_achievement_mapping(chal_survivor_2_hash)
		add_achievement_mapping(chal_survivor_3_hash)
		add_achievement_mapping(chal_survivor_4_hash)
		add_achievement_mapping(chal_survivor_5_hash)
		add_achievement_mapping(chal_gatherer_1_hash)
		add_achievement_mapping(chal_gatherer_2_hash)
		add_achievement_mapping(chal_gatherer_3_hash)
		add_achievement_mapping(chal_gatherer_4_hash)
		add_achievement_mapping(chal_gatherer_5_hash)
		add_achievement_mapping(chal_rookie_hash)
		add_achievement_mapping(chal_dying_hash)
		add_achievement_mapping(chal_agriculture_hash)
		add_achievement_mapping(chal_hallucination_hash)
		add_achievement_mapping(chal_fast_hash)
		add_achievement_mapping(chal_hoarder_hash)
		add_achievement_mapping(chal_turrets_hash)
		add_achievement_mapping(chal_lumberjack_hash)
		add_achievement_mapping(chal_medicine_hash)
		add_achievement_mapping(chal_perfect_vision_hash)
		add_achievement_mapping(chal_fireworks_hash)
		add_achievement_mapping(chal_recycling_hash)
		add_achievement_mapping(chal_slow_hash)
		add_achievement_mapping(chal_hungry_hash)
		add_achievement_mapping(chal_advanced_technology_hash)
		add_achievement_mapping(chal_giant_slayer_hash)
		add_achievement_mapping(chal_robust_hash)
		add_achievement_mapping(chal_baited_hash)
		add_achievement_mapping(chal_forest_hash)
		add_achievement_mapping(chal_bourgeoisie_hash)
		add_achievement_mapping(chal_reckless_hash)
		add_achievement_mapping(chal_scavenger_hash)
		add_achievement_mapping(chal_well_rounded_hash)
		add_achievement_mapping(chal_crazy_hash)
		add_achievement_mapping(chal_ranger_hash)
		add_achievement_mapping(chal_mage_hash)
		add_achievement_mapping(chal_multitasker_hash)
		add_achievement_mapping(chal_pacifist_hash)
		add_achievement_mapping(chal_ghost_hash)
		add_achievement_mapping(chal_speedy_hash)
		add_achievement_mapping(chal_explorer_hash)
		add_achievement_mapping(chal_doctor_hash)
		add_achievement_mapping(chal_arms_dealer_hash)
		add_achievement_mapping(chal_cyborg_hash)
		add_achievement_mapping(chal_glutton_hash)
		add_achievement_mapping(chal_lich_hash)
		add_achievement_mapping(chal_cryptid_hash)
		add_achievement_mapping(chal_golem_hash)
		add_achievement_mapping(chal_king_hash)
		add_achievement_mapping(chal_renegade_hash)
		add_achievement_mapping(chal_knight_hash)
		add_achievement_mapping(chal_demon_hash)

		
		add_achievement_mapping(chal_technomage_hash)
		add_achievement_mapping(chal_vampire_hash)
		add_achievement_mapping(chal_baby_hash)

		
		add_achievement_mapping(chal_buccaneer_hash)
		add_achievement_mapping(chal_builder_hash)
		add_achievement_mapping(chal_captain_hash)
		add_achievement_mapping(chal_chef_hash)
		add_achievement_mapping(chal_creature_hash)
		add_achievement_mapping(chal_curious_hash)
		add_achievement_mapping(chal_diver_hash)
		add_achievement_mapping(chal_druid_hash)
		add_achievement_mapping(chal_dwarf_hash)
		add_achievement_mapping(chal_gangster_hash)
		add_achievement_mapping(chal_hiker_hash)
		add_achievement_mapping(chal_ogre_hash)
		add_achievement_mapping(chal_romantic_hash)
		need_achievements = true
	elif Utils.on_ps5:
		print("Adding PS5 Trophies mapping")
		add_achievement_mapping(chal_difficulty_0_hash)
		add_achievement_mapping(chal_difficulty_1_hash)
		add_achievement_mapping(chal_difficulty_2_hash)
		add_achievement_mapping(chal_difficulty_3_hash)
		add_achievement_mapping(chal_difficulty_4_hash)
		add_achievement_mapping(chal_difficulty_5_hash)
		add_achievement_mapping(chal_survivor_1_hash)
		add_achievement_mapping(chal_survivor_2_hash)
		add_achievement_mapping(chal_survivor_3_hash)
		add_achievement_mapping(chal_survivor_4_hash)
		add_achievement_mapping(chal_survivor_5_hash)
		add_achievement_mapping(chal_gatherer_1_hash)
		add_achievement_mapping(chal_gatherer_2_hash)
		add_achievement_mapping(chal_gatherer_3_hash)
		add_achievement_mapping(chal_gatherer_4_hash)
		add_achievement_mapping(chal_gatherer_5_hash)
		add_achievement_mapping(chal_rookie_hash)
		add_achievement_mapping(chal_dying_hash)
		add_achievement_mapping(chal_agriculture_hash)
		add_achievement_mapping(chal_hallucination_hash)
		add_achievement_mapping(chal_fast_hash)
		add_achievement_mapping(chal_hoarder_hash)
		add_achievement_mapping(chal_turrets_hash)
		add_achievement_mapping(chal_lumberjack_hash)
		add_achievement_mapping(chal_medicine_hash)
		add_achievement_mapping(chal_perfect_vision_hash)
		add_achievement_mapping(chal_fireworks_hash)
		add_achievement_mapping(chal_recycling_hash)
		add_achievement_mapping(chal_slow_hash)
		add_achievement_mapping(chal_hungry_hash)
		add_achievement_mapping(chal_advanced_technology_hash)
		add_achievement_mapping(chal_giant_slayer_hash)
		add_achievement_mapping(chal_robust_hash)
		add_achievement_mapping(chal_baited_hash)
		add_achievement_mapping(chal_forest_hash)
		add_achievement_mapping(chal_bourgeoisie_hash)
		add_achievement_mapping(chal_reckless_hash)
		add_achievement_mapping(chal_scavenger_hash)
		add_achievement_mapping(chal_well_rounded_hash)
		add_achievement_mapping(chal_crazy_hash)
		add_achievement_mapping(chal_ranger_hash)
		add_achievement_mapping(chal_mage_hash)
		add_achievement_mapping(chal_multitasker_hash)
		add_achievement_mapping(chal_pacifist_hash)
		add_achievement_mapping(chal_ghost_hash)
		add_achievement_mapping(chal_speedy_hash)
		add_achievement_mapping(chal_explorer_hash)
		add_achievement_mapping(chal_doctor_hash)
		add_achievement_mapping(chal_arms_dealer_hash)
		add_achievement_mapping(chal_cyborg_hash)
		add_achievement_mapping(chal_glutton_hash)
		add_achievement_mapping(chal_lich_hash)
		add_achievement_mapping(chal_cryptid_hash)
		add_achievement_mapping(chal_golem_hash)
		add_achievement_mapping(chal_king_hash)
		add_achievement_mapping(chal_renegade_hash)
		add_achievement_mapping(chal_knight_hash)
		add_achievement_mapping(chal_demon_hash)

		
		add_achievement_mapping(chal_buccaneer_hash)
		add_achievement_mapping(chal_builder_hash)
		add_achievement_mapping(chal_captain_hash)
		add_achievement_mapping(chal_chef_hash)
		add_achievement_mapping(chal_creature_hash)
		add_achievement_mapping(chal_curious_hash)
		add_achievement_mapping(chal_diver_hash)
		add_achievement_mapping(chal_druid_hash)
		add_achievement_mapping(chal_dwarf_hash)
		add_achievement_mapping(chal_gangster_hash)
		add_achievement_mapping(chal_hiker_hash)
		add_achievement_mapping(chal_ogre_hash)
		add_achievement_mapping(chal_romantic_hash)

		
		add_achievement_mapping(chal_baby_hash)
		add_achievement_mapping(chal_vampire_hash)
		add_achievement_mapping(chal_technomage_hash)

		need_achievements = true
	elif Utils.on_gdk:
		print("Adding GDK Trophies mapping")
		add_achievement_mapping(chal_difficulty_0_hash)
		add_achievement_mapping(chal_difficulty_1_hash)
		add_achievement_mapping(chal_difficulty_2_hash)
		add_achievement_mapping(chal_difficulty_3_hash)
		add_achievement_mapping(chal_difficulty_4_hash)
		add_achievement_mapping(chal_difficulty_5_hash)
		add_achievement_mapping(chal_survivor_1_hash)
		add_achievement_mapping(chal_survivor_2_hash)
		add_achievement_mapping(chal_survivor_3_hash)
		add_achievement_mapping(chal_survivor_4_hash)
		add_achievement_mapping(chal_survivor_5_hash)
		add_achievement_mapping(chal_gatherer_1_hash)
		add_achievement_mapping(chal_gatherer_2_hash)
		add_achievement_mapping(chal_gatherer_3_hash)
		add_achievement_mapping(chal_gatherer_4_hash)
		add_achievement_mapping(chal_gatherer_5_hash)
		add_achievement_mapping(chal_rookie_hash)
		add_achievement_mapping(chal_dying_hash)
		add_achievement_mapping(chal_agriculture_hash)
		add_achievement_mapping(chal_hallucination_hash)
		add_achievement_mapping(chal_fast_hash)
		add_achievement_mapping(chal_hoarder_hash)
		add_achievement_mapping(chal_turrets_hash)
		add_achievement_mapping(chal_lumberjack_hash)
		add_achievement_mapping(chal_medicine_hash)
		add_achievement_mapping(chal_perfect_vision_hash)
		add_achievement_mapping(chal_fireworks_hash)
		add_achievement_mapping(chal_recycling_hash)
		add_achievement_mapping(chal_slow_hash)
		add_achievement_mapping(chal_hungry_hash)
		add_achievement_mapping(chal_advanced_technology_hash)
		add_achievement_mapping(chal_giant_slayer_hash)
		add_achievement_mapping(chal_robust_hash)
		add_achievement_mapping(chal_baited_hash)
		add_achievement_mapping(chal_forest_hash)
		add_achievement_mapping(chal_bourgeoisie_hash)
		add_achievement_mapping(chal_student_hash)
		add_achievement_mapping(chal_reckless_hash)
		add_achievement_mapping(chal_scavenger_hash)
		add_achievement_mapping(chal_well_rounded_hash)
		add_achievement_mapping(chal_brawler_hash)
		add_achievement_mapping(chal_crazy_hash)
		add_achievement_mapping(chal_ranger_hash)
		add_achievement_mapping(chal_mage_hash)
		add_achievement_mapping(chal_chunky_hash)
		add_achievement_mapping(chal_old_hash)
		add_achievement_mapping(chal_lucky_hash)
		add_achievement_mapping(chal_mutant_hash)
		add_achievement_mapping(chal_generalist_hash)
		add_achievement_mapping(chal_loud_hash)
		add_achievement_mapping(chal_multitasker_hash)
		add_achievement_mapping(chal_wildling_hash)
		add_achievement_mapping(chal_pacifist_hash)
		add_achievement_mapping(chal_gladiator_hash)
		add_achievement_mapping(chal_saver_hash)
		add_achievement_mapping(chal_sick_hash)
		add_achievement_mapping(chal_farmer_hash)
		add_achievement_mapping(chal_ghost_hash)
		add_achievement_mapping(chal_speedy_hash)
		add_achievement_mapping(chal_entrepreneur_hash)
		add_achievement_mapping(chal_engineer_hash)
		add_achievement_mapping(chal_explorer_hash)
		add_achievement_mapping(chal_doctor_hash)
		add_achievement_mapping(chal_hunter_hash)
		add_achievement_mapping(chal_artificer_hash)
		add_achievement_mapping(chal_arms_dealer_hash)
		add_achievement_mapping(chal_streamer_hash)
		add_achievement_mapping(chal_cyborg_hash)
		add_achievement_mapping(chal_glutton_hash)
		add_achievement_mapping(chal_jack_hash)
		add_achievement_mapping(chal_lich_hash)
		add_achievement_mapping(chal_apprentice_hash)
		add_achievement_mapping(chal_cryptid_hash)
		add_achievement_mapping(chal_fisherman_hash)
		add_achievement_mapping(chal_golem_hash)
		add_achievement_mapping(chal_king_hash)
		add_achievement_mapping(chal_renegade_hash)
		add_achievement_mapping(chal_one_arm_hash)
		add_achievement_mapping(chal_bull_hash)
		add_achievement_mapping(chal_soldier_hash)
		add_achievement_mapping(chal_masochist_hash)
		add_achievement_mapping(chal_knight_hash)
		add_achievement_mapping(chal_demon_hash)
		add_achievement_mapping(chal_technomage_hash)
		add_achievement_mapping(chal_blood_drinker_hash)
		add_achievement_mapping(chal_fast_learner_hash)
		add_achievement_mapping(chal_baby_hash)
		add_achievement_mapping(chal_vagabond_hash)
		add_achievement_mapping(chal_vampire_hash)
		add_achievement_mapping(chal_experimentation_hash)
		add_achievement_mapping(chal_magic_and_machinery_hash)
		add_achievement_mapping(chal_overkill_hash)
		add_achievement_mapping(chal_ogre_hash)
		add_achievement_mapping(chal_dwarf_hash)
		add_achievement_mapping(chal_hiker_hash)
		add_achievement_mapping(chal_barbecue_hash)
		add_achievement_mapping(chal_blind_greed_hash)
		add_achievement_mapping(chal_gangster_hash)
		add_achievement_mapping(chal_chef_hash)
		add_achievement_mapping(chal_captain_hash)
		add_achievement_mapping(chal_diver_hash)
		add_achievement_mapping(chal_builder_hash)
		add_achievement_mapping(chal_sailor_hash)
		add_achievement_mapping(chal_creature_hash)
		add_achievement_mapping(chal_romantic_hash)
		add_achievement_mapping(chal_buccaneer_hash)
		add_achievement_mapping(chal_unlucky_hash)
		add_achievement_mapping(chal_druid_hash)
		add_achievement_mapping(chal_herbalist_hash)
		add_achievement_mapping(chal_uncorrupted_hash)
		add_achievement_mapping(chal_curious_hash)
		add_achievement_mapping(chal_cautious_hash)
		add_achievement_mapping(chal_smelly_feet_hash)
		add_achievement_mapping(chal_unstoppable_force_hash)
		need_achievements = true


func _should_add_stat_challenge(chal_id: int) -> bool:
	return (
		chal_id != chal_advanced_technology_hash
		and chal_id != chal_magic_and_machinery_hash
		and chal_id != chal_uncorrupted_hash
	)


func try_complete_challenge(chal_id: int, value: int, check_below: bool = false):
	if is_challenge_completed(chal_id):
		return

	var chal_data: = get_chal(chal_id)
	if chal_data == null:
		return
	if ( not check_below and value >= chal_data.value) or (check_below and value <= chal_data.value):
		complete_challenge(chal_id)

var _challenges_completed_map: = {}
func complete_challenge(chal_id: int, also_complete_platform_challenge: bool = true) -> void :
	
	
	
	if Utils.on_nintendo_nx_or_ounce:
		also_complete_platform_challenge = false

	
	if need_achievements == true and also_complete_platform_challenge:
		if achievement_mapping.has(chal_id):
			OS_Seaven.unlock_achievement(achievement_mapping[chal_id])
		else:
			print("missing challenge/achievement [id: ", (hash_to_id.get(chal_id)), ", hash: " + String(chal_id) + "] in mapping !")

	var chal_data = get_chal(chal_id)
	if chal_data == null:
		print("challenge data not found for my_id " + str(chal_id))
		return

	var has_already_been_completed: = is_challenge_completed(chal_id)
	var should_save: = false

	if not has_already_been_completed:
		ProgressData.challenges_completed.append(chal_id)
		_challenges_completed_map[chal_id] = true
		should_save = true
	if unlock_reward(chal_data):
		should_save = true

	if should_save:
		ProgressData.save()

	if also_complete_platform_challenge and not ProgressData.is_unlock_all_save():
		Platform.complete_challenge(chal_id)

	if not has_already_been_completed:
		emit_signal("challenge_completed", chal_data)


func is_challenge_completed(chal_id: int) -> bool:
	update_challenges_completed_map()
	return _challenges_completed_map.has(chal_id)


func update_challenges_completed_map() -> void :
	if _challenges_completed_map.size() == ProgressData.challenges_completed.size():
		return

	_challenges_completed_map.clear()
	for id in ProgressData.challenges_completed:
		_challenges_completed_map[id] = true


func unlock_reward(chal_data: ChallengeData) -> bool:
	if not chal_data.reward:
		return false

	var list_to_unlock_from: = []
	var list_of_unlocked: = []

	var id_property = "my_id"

	match chal_data.reward_type:
		RewardType.CHARACTER:
			list_to_unlock_from = ItemService.characters
			list_of_unlocked = ProgressData.characters_unlocked
		RewardType.ITEM:
			list_to_unlock_from = ItemService.items
			list_of_unlocked = ProgressData.items_unlocked
		RewardType.WEAPON:
			list_to_unlock_from = ItemService.weapons
			list_of_unlocked = ProgressData.weapons_unlocked
			id_property = "weapon_id"
		RewardType.ZONE:
			list_to_unlock_from = ZoneService.zones
			list_of_unlocked = ProgressData.zones_unlocked
		RewardType.STARTING_WEAPON:
			list_to_unlock_from = ItemService.weapons
			list_of_unlocked = ProgressData.weapons_unlocked
			id_property = "weapon_id"
		RewardType.CONSUMABLE:
			list_to_unlock_from = ItemService.consumables
			list_of_unlocked = ProgressData.consumables_unlocked
		RewardType.UPGRADE:
			list_to_unlock_from = ItemService.upgrades
			list_of_unlocked = ProgressData.upgrades_unlocked
			id_property = "upgrade_id"
		RewardType.SYSTEM:
			list_of_unlocked = ProgressData.systems_unlocked

	var result: = false
	for element in list_to_unlock_from:
		if element[id_property] == chal_data.reward[id_property]:
			var reward_hash = Keys.generate_hash(chal_data.reward[id_property])
			if not list_of_unlocked.has(reward_hash):
				list_of_unlocked.push_back(reward_hash)
				RunData.challenges_completed_this_run.push_back(chal_data)
				result = true
				break

	return result


func find_challenge_from_reward(reward_type: int, reward_data: Resource) -> ChallengeData:
	var challenge_result = null

	for challenge in challenges:
		if challenge.reward_type != reward_type:
			continue

		if challenge.reward.my_id == reward_data.my_id:
			challenge_result = challenge
			break

	return challenge_result


var _challenge_map: = {}

func get_chal(my_id: int) -> ChallengeData:
	if _challenge_map.size() != challenges.size():
		_challenge_map.clear()
		for chal in challenges:
			_challenge_map[chal.my_id_hash] = chal
	return _challenge_map.get(my_id)


func check_counted_challenges() -> void :
	var nb_killed = ProgressData.data.enemies_killed
	var nb_collected = ProgressData.data.materials_collected
	var nb_trees = ProgressData.data.trees_killed
	var nb_killed_far_away = ProgressData.data.enemies_killed_far_away
	var nb_evil_mob_killed = ProgressData.data.evil_mob_killed

	for chal in challenges:
		if ((chal.name == "CHAL_SURVIVOR" and nb_killed >= chal.value)
			or (chal.name == "CHAL_GATHERER" and nb_collected >= chal.value)
			or (chal.name == "CHAL_LUMBERJACK" and nb_trees >= chal.value)
			or (chal.name == "CHAL_CAUTIOUS" and nb_killed_far_away >= chal.value)
			or (chal.name == "CHAL_EVIL_HAT" and nb_evil_mob_killed >= chal.value)):
			complete_challenge(chal.my_id_hash)


func check_stat_challenges(player_index: int) -> void :
	for chal in stat_challenges:
		
		var stat = Utils.get_stat(chal.stat_hash, player_index)
		var reached_goal = (
			(chal.value < 0 and stat <= chal.value)
			or (chal.value > 0 and stat >= chal.value)
			or (chal.value == 0 and stat == chal.value)
		)
		if reached_goal:
			complete_challenge(chal.my_id_hash)

	_check_struct_challenges(player_index, chal_advanced_technology_hash, Keys.stat_ranged_damage_hash)
	_check_struct_challenges(player_index, chal_magic_and_machinery_hash, Keys.stat_elemental_damage_hash)
	_check_doc_moth_chal(player_index)


func _check_struct_challenges(player_index: int, chal_id: int, stat: int):
	if is_challenge_completed(chal_id):
		return

	var chal = get_chal(chal_id)
	if Utils.get_stat(stat, player_index) >= chal.value and RunData.get_player_effect(Keys.structures_hash, player_index).size() >= chal.additional_args[0]:
		complete_challenge(chal_id)

func _check_doc_moth_chal(player_index: int):
	if is_challenge_completed(chal_doc_moth_hash):
		return
	var chal = get_chal(chal_doc_moth_hash)
	var reached_goal = (
		chal.value <= Utils.get_stat(Keys.stat_hp_regeneration_hash, player_index)
		and chal.value <= Utils.get_stat(Keys.stat_lifesteal_hash, player_index)
	)

	if reached_goal:
		complete_challenge(chal_doc_moth_hash)


func complete_all_challenges() -> void :
	for chal in challenges:
		complete_challenge(chal.get_my_id_hash())
