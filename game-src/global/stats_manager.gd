class_name StatsManager
extends Node2D


const ADDITIONAL_RECALC_PER_AGE: = 8
const MAX_QUEUE_AGE: = 60

var _player_queue: = {}
var _weapon_queue: = {}
var _structure_queues: = [{}, {}, {}, {}]
var _pet_queues: = [{}, {}, {}, {}]

var _entity_spawner: EntitySpawner
var _current_frame: int = 0

func init(p_entity_spawner: EntitySpawner) -> void :
	_entity_spawner = p_entity_spawner


func _physics_process(_delta: float) -> void :
	
	for player in _player_queue:
		if not player.dead:
			player.update_player_stats()
	_player_queue.clear()
	_current_frame = Engine.get_physics_frames()

	_dequeue_weapons()
	_dequeue_structures()
	_dequeue_pets()


func _dequeue_weapons() -> void :
	var count: int = 0

	for weapon in _weapon_queue.keys():
		if _should_recalc_item(_weapon_queue[weapon], count):
			
			count += 1
			if is_instance_valid(weapon):
				weapon.init_stats(false)
			_weapon_queue.erase(weapon)
		else:
			break


func _dequeue_structures() -> void :
	for player_structure_queue in _structure_queues:
		var structure_cache: = {}
		var count: int = 0

		for struct in player_structure_queue.keys():
			if not struct.dead:
				if not struct.is_cursed:
					if structure_cache.has(struct.filename):
						struct.set_current_stats(structure_cache[struct.filename])
						
						count += 1
						player_structure_queue.erase(struct)
					elif _should_recalc_item(player_structure_queue[struct], count):
						struct.reload_data()
						structure_cache[struct.filename] = struct.stats
						count += 1
						player_structure_queue.erase(struct)

				elif _should_recalc_item(player_structure_queue[struct], count):
					struct.reload_data()
					count += 1
					player_structure_queue.erase(struct)
			else:
				count += 1
				player_structure_queue.erase(struct)

func _dequeue_pets() -> void :
	var current_frame: = Engine.get_physics_frames()
	for player_pet_queue in _pet_queues:
		var recalced_pets: = []
		var pet_cache: = {}

		for pet in player_pet_queue:
			if not pet.dead:
				if not pet.is_cursed:
					if pet_cache.has(pet.filename):
						pet.set_current_stats(pet_cache[pet.filename])
						recalced_pets.append(pet)
					elif _should_recalc_item(player_pet_queue[pet], recalced_pets.size()):
						pet.reload_data()
						pet_cache[pet.filename] = pet.get_stats()
						recalced_pets.append(pet)

				elif _should_recalc_item(player_pet_queue[pet], recalced_pets.size()):
					pet.reload_data()
					recalced_pets.append(pet)
			else:
				recalced_pets.append(pet)

		for pet in recalced_pets:
			player_pet_queue.erase(pet)

func _should_recalc_item(enqueue_frame: int, recalced_items: int) -> bool:
	var item_age: = _current_frame - enqueue_frame
	return item_age > MAX_QUEUE_AGE or recalced_items < int(ceil(float(item_age) / ADDITIONAL_RECALC_PER_AGE))


func reload_stats(player: Player) -> void :
	if player.dead:
		return

	var current_frame: = Engine.get_physics_frames()
	if not _player_queue.has(player):
		_player_queue[player] = current_frame

	for weapon in player.current_weapons:
		if not _weapon_queue.has(weapon):
			_weapon_queue[weapon] = current_frame

	for struct in _entity_spawner.structures:
		if struct.player_index == player.player_index:
			if not _structure_queues[player.player_index].has(struct):
				_structure_queues[player.player_index][struct] = current_frame

	for pet in _entity_spawner.pets:
		if pet.player_index == player.player_index and pet.should_data_be_reload():
			if not _pet_queues[player.player_index].has(pet):
				_pet_queues[player.player_index][pet] = current_frame
