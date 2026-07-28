class_name Structure
extends Entity

signal wanted_to_spawn_fruit(pos)
signal wanted_to_spawn_food(food_id_hash, pos)

export (Resource) var curse_particles
export (bool) var to_be_removed_in_priority = false

onready var _muzzle = $Animation / Muzzle

var base_stats: Resource
var stats: Resource
var effects: Array = []
var player_index = - 1
var is_cursed: = false
var is_pet: = false
var curse_particle_instance
var init_stats_args: = WeaponServiceInitStatsArgs.new()

const PENDING_DIE_DURATION = 5.0

func _ready() -> void :
	if is_cursed:
		add_curse_particles()


func respawn() -> void :
	.respawn()
	if is_cursed:
		add_curse_particles()


func set_data(data: Resource) -> void :
	base_stats = data.stats
	effects = data.effects
	is_pet = data.is_pet
	reload_data()

	is_cursed = data.is_cursed


func set_current_stats(new_stats: RangedWeaponStats) -> void :
	stats = new_stats


func reload_data() -> void :
	init_stats_args.effects = effects
	if is_pet:
		stats = WeaponService.init_structure_pet_stats(base_stats, player_index, init_stats_args)
	else:
		stats = WeaponService.init_structure_stats(base_stats, player_index, init_stats_args)


func add_curse_particles() -> void :
	curse_particle_instance = curse_particles.instance()
	_muzzle.add_child(curse_particle_instance)


func die(args: = Utils.default_die_args) -> void :
	assert ( not dead)
	if is_instance_valid(curse_particle_instance):
		curse_particle_instance.queue_free()

	_collision.disabled = true

	cleaning_up = args.cleaning_up
	_animation_player.playback_speed = 1
	dead = true
	_animation_player.play("death")

func deferred_die(args: = Utils.default_die_args) -> void :
	_pending_die = true
	emit_signal("died", self, args)
	yield(get_tree().create_timer(PENDING_DIE_DURATION), "timeout")
	die()

func death_animation_finished() -> void :
	.death_animation_finished()
	player_index = - 1
	is_cursed = false
