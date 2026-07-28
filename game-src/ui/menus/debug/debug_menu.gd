extends PanelContainer
class_name DebugMenu

export (Array, String, DIR) var enemies_directories
export (Array, Resource) var enemies

onready var inventory_weapons: InventoryContainer = $"%Inventory_weapons"
onready var inventory_items: InventoryContainer = $"%Inventory_items"
onready var inventory_upgrades: InventoryContainer = $"%Inventory_upgrades"
onready var inventory_container: TabContainer = $"%inventory_container"
onready var moneySpinBox: SpinBox = $"%gold_spinbox"
onready var invulnerableBut: CheckButton = $"%invulnerable_but"
onready var invisibleBut: CheckButton = $"%invisible_but"
onready var oneshotenemiesBut: CheckButton = $"%oneshotenemies_but"
onready var slowMotionBut: CheckButton = $"%slowmotion_but"
onready var removestartingweaponsBut: CheckButton = $"%removestartingweapons_but"

onready var spawnEntitiesBut: Button = $"%spawnEntities_but"
onready var killallBut: Button = $"%killall_but"
onready var nospawningenemiesBut: CheckButton = $"%NoSpawningEnemies_but"
onready var noswpaningentitiesBut: CheckButton = $"%NoSpawningEntities_but"
onready var inventory_enemies: InventoryContainer = $"%Inventory_enemies"
onready var spawnonlycursedmobsBut: CheckButton = $"%OnlycursedMob_but"

onready var gotowaveSpinbox: SpinBox = $"%GotoWave_spinbox"
onready var customWaveDurationSpinBox: SpinBox = $"%CustomWaveDuration_SpinBox"
onready var startingAtWaveSpinBox: SpinBox = $"%StartingAtWave_SpinBox"
onready var instantwaveBut: CheckButton = $"%instantwave_but"
onready var alwaysdropcratesBut: CheckButton = $"%AlwaysDropCrates_but"
onready var hidetimerBut: CheckButton = $"%HideTimer_but"
onready var hideHUDBut: CheckButton = $"%HideHUD_but"
onready var hideFloatingTextBut: CheckButton = $"%HideFloatingText_but"
onready var reloadwaveBut: Button = $"%reload_wave_but"

onready var unlockallBut: Button = $"%unlockAll_but"
onready var lockallBut: Button = $"%lockAll_but"
onready var unlockAllCharactersBut: Button = $"%unlockAllCharacters_but"
onready var lockAllCharactersBut: Button = $"%lockAllCharacters_but"
onready var unlockAllDifficultiesBut: Button = $"%unlockAllDifficulties_but"
onready var lockAllDifficultiesBut: Button = $"%lockAllDifficulties_but"
onready var unlockAllChallengesBut: Button = $"%unlockAllChallenges_but"
onready var lockAllChallengesBut: Button = $"%lockAllChallenges_but"
onready var unlockAllItemsBut: Button = $"%unlockAllItems_but"
onready var lockAllItemsBut: Button = $"%lockAllItems_but"
onready var unlockAllWeaponsBut: Button = $"%unlockAllWeapons_but"
onready var lockAllWeaponsBut: Button = $"%lockAllWeapons_but"
onready var unlockAllEnemiesBut: Button = $"%unlockAllEnemies_but"
onready var lockAllEnemiesBut: Button = $"%lockAllEnemies_but"

var player_index: int = 0

var remove_items: bool = false
var remove_weapons: bool = false
var cursed_items: bool = false
var item_next_shop: bool = false
var cursed_weapons: bool = false


func _ready():
	get_tree().set_pause(true)

	inventory_weapons._elements.set_elements(ItemService.weapons)
	_update_weaponsInventory_count()
	inventory_items._elements.set_elements(ItemService.items)
	_update_itemsInventory_count()
	inventory_enemies._elements.set_elements(ItemService.entities)
	_update_upgradesInventory_count()
	inventory_upgrades._elements.set_elements(ItemService.upgrades, false, false)

	_set_menu()

	inventory_items._elements.connect("element_pressed", self, "_on_clickOnItemInventory")
	inventory_weapons._elements.connect("element_pressed", self, "_on_clickOnWeaponInventory")
	inventory_enemies._elements.connect("element_pressed", self, "_on_clickOnEnemiesInventory")
	inventory_upgrades._elements.connect("element_pressed", self, "_on_clickOnUpgradeInventory")

	moneySpinBox.connect("value_changed", self, "_update_material")
	invulnerableBut.connect("toggled", self, "_on_invulnerable_but_pressed")
	invisibleBut.connect("toggled", self, "_on_invisible_but_pressed")
	oneshotenemiesBut.connect("toggled", self, "_on_oneshotenemies_but_pressed")
	slowMotionBut.connect("toggled", self, "_on_slowmotion_but_pressed")
	removestartingweaponsBut.connect("toggled", self, "_on_removestartingweapons_but_pressed")

	spawnEntitiesBut.connect("pressed", self, "_on_spawnEntities_but_pressed")
	killallBut.connect("pressed", self, "_on_killall_but_pressed")
	nospawningenemiesBut.connect("toggled", self, "_on_nospawningenemies_but_pressed")
	noswpaningentitiesBut.connect("toggled", self, "_on_nospawningentities_but_pressed")
	spawnonlycursedmobsBut.connect("toggled", self, "_on_spawnonlycursedmobs_but_pressed")

	customWaveDurationSpinBox.connect("value_changed", self, "_updatewaveduration")
	startingAtWaveSpinBox.connect("value_changed", self, "_updatestartingatwave")
	instantwaveBut.connect("toggled", self, "_on_instantwaves_but_pressed")
	alwaysdropcratesBut.connect("toggled", self, "_on_alwaysdropcrates_but_pressed")
	hidetimerBut.connect("toggled", self, "_on_hidetimer_but_pressed")
	hideHUDBut.connect("toggled", self, "_on_hideHUD_but_pressed")
	hideFloatingTextBut.connect("toggled", self, "_on_hidefloatingtext_but_pressed")

	reloadwaveBut.connect("pressed", self, "_on_reload_wave_but_pressed")

	unlockallBut.connect("pressed", self, "_on_unlockall_but_pressed")
	lockallBut.connect("pressed", self, "_on_lockall_but_pressed")
	unlockAllCharactersBut.connect("pressed", self, "_on_unlockallcharacters_but_pressed")
	lockAllCharactersBut.connect("pressed", self, "_on_lockallcharacters_but_pressed")
	unlockAllDifficultiesBut.connect("pressed", self, "_on_unlockalldifficulties_but_pressed")
	lockAllDifficultiesBut.connect("pressed", self, "_on_lockalldifficulties_but_pressed")
	unlockAllChallengesBut.connect("pressed", self, "_on_unlockallchallenges_but_pressed")
	lockAllChallengesBut.connect("pressed", self, "_on_lockallchallenges_but_pressed")
	unlockAllItemsBut.connect("pressed", self, "_on_unlockallitems_but_pressed")
	lockAllItemsBut.connect("pressed", self, "_on_lockallitems_but_pressed")
	unlockAllWeaponsBut.connect("pressed", self, "_on_unlockallweapons_but_pressed")
	lockAllWeaponsBut.connect("pressed", self, "_on_lockallweapons_but_pressed")
	unlockAllEnemiesBut.connect("pressed", self, "_on_unlockallenemies_but_pressed")
	lockAllEnemiesBut.connect("pressed", self, "_on_lockallenemies_but_pressed")


func _set_menu():
	moneySpinBox.value = RunData.get_player_gold(player_index)
	invulnerableBut.pressed = DebugService.invulnerable
	invisibleBut.pressed = DebugService.invisible
	oneshotenemiesBut.pressed = DebugService.one_shot_enemies
	slowMotionBut.pressed = DebugService.slow_motion
	removestartingweaponsBut.pressed = DebugService.remove_starting_weapons

	nospawningenemiesBut.pressed = DebugService.no_enemies
	noswpaningentitiesBut.pressed = DebugService.no_entities
	spawnEntitiesBut.pressed = DebugService.curse_enemy_spawn
	spawnonlycursedmobsBut.pressed = DebugService.always_curse

	customWaveDurationSpinBox.value = DebugService.custom_wave_duration
	startingAtWaveSpinBox.value = DebugService.starting_wave
	instantwaveBut.pressed = DebugService.instant_waves
	alwaysdropcratesBut.pressed = DebugService.always_drop_crates
	hidetimerBut.pressed = DebugService.hide_wave_timer
	hideHUDBut.pressed = DebugService.hide_hud
	hideFloatingTextBut.pressed = DebugService.hide_floating_text

	reloadwaveBut.disabled = not RunData.wave_in_progress
	spawnEntitiesBut.disabled = not RunData.wave_in_progress
	killallBut.disabled = not RunData.wave_in_progress


func _on_clickOnItemInventory(element: InventoryElement) -> void :
	if remove_items:
		RunData.remove_item(element.item, player_index)
	else:
		if cursed_items:
			element.item.is_cursed = true
		if item_next_shop:
			RunData.add_item_next_shop(element.item, player_index)
		else:
			RunData.add_item(element.item, player_index)
	_update_itemsInventory_count()

func _on_clickOnUpgradeInventory(element: InventoryElement) -> void :
	if remove_items:
		RunData.remove_item(element.item, player_index)
	else:
		RunData.add_item(element.item, player_index)
	_update_upgradesInventory_count()

func _update_itemsInventory_count() -> void :
	var all_player_items: = RunData.get_player_items(player_index)
	for element in inventory_items._elements.get_children():
		element.current_number = 0
		if all_player_items.has(element.item):
			element.add_to_number(all_player_items.count(element.item), true)
		else:
			element.current_number = 0
			element._number_label.hide()

func _update_upgradesInventory_count() -> void :
	var all_player_items: = RunData.get_player_items(player_index)
	for element in inventory_upgrades._elements.get_children():
		element.current_number = 0
		if all_player_items.has(element.item):
			element.add_to_number(all_player_items.count(element.item), true)
		else:
			element.current_number = 0
			element._number_label.hide()

func _on_clickOnWeaponInventory(element: InventoryElement) -> void :
	if remove_weapons:
		RunData.remove_weapon(element.item, player_index)
	else:
		if cursed_weapons:
			element.item.is_cursed = true
		RunData.add_weapon(element.item, player_index)
	_update_weaponsInventory_count()

func _update_weaponsInventory_count() -> void :
	var all_player_weapons: Array
	for weapon in RunData.get_player_weapons(player_index):
		all_player_weapons.append(weapon.my_id)
	for element in inventory_weapons._elements.get_children():
		element.current_number = 0
		if all_player_weapons.has(element.item.my_id):
			element.add_to_number(all_player_weapons.count(element.item.my_id), true)
		else:
			element.current_number = 0
			element._number_label.hide()

func _on_clickOnEnemiesInventory(element: InventoryElement) -> void :
	if get_tree().current_scene is Main:
		var main: Main = get_tree().current_scene
		var entitySpawner: EntitySpawner = get_tree().current_scene._entity_spawner
		var scene: = get_enemies_from_myid(element.item.my_id)
		var mob_pos: Vector2 = main._players[player_index].global_position + Vector2(rand_range( - 1, 1), rand_range( - 1, 1)).normalized() * 500
		var args: = EntitySpawner.SpawnEntityArgs.new(mob_pos, EntityType.ENEMY)
		var enemy = entitySpawner.spawn_entity(scene, args)



func get_enemies_from_myid(enemy_id: String) -> PackedScene:
	for directory in enemies_directories:
		var check = get_enemies_scene_from_folder(enemy_id, directory)
		if check != null:
			return check
	return null


func get_enemies_scene_from_folder(enemy_id: String, scan_dir: String) -> PackedScene:
	var dir: = Directory.new()
	if dir.open(scan_dir) != OK:
		printerr("Warning: could not open directory: ", scan_dir)
		return null

	if dir.list_dir_begin(true, true) != OK:
		printerr("Warning: could not list contents of: ", scan_dir)
		return null

	var file_name: = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			var child = get_enemies_scene_from_folder(enemy_id, dir.get_current_dir() + "/" + file_name)
			if child != null:
				return child
		else:
			var resource_path: String = dir.get_current_dir() + "/" + file_name
			if resource_path.ends_with(".tscn"):
				var resource: PackedScene = load(resource_path)
				var instance: = resource.instance()
				if instance is Enemy:
					if instance.enemy_id == enemy_id:
						instance.queue_free()
						return resource
				instance.queue_free()
		file_name = dir.get_next()
	return null


func _on_giveitems_but_pressed() -> void :
	if inventory_items.visible and inventory_container.visible:
		inventory_container.hide()
	else:
		inventory_container.show()
		inventory_container.current_tab = 0
func _on_giveweapons_but_pressed() -> void :
	if inventory_weapons.visible and inventory_container.visible:
		inventory_container.hide()
	else:
		inventory_container.show()
		inventory_container.current_tab = 1
func _on_givemeupgrades_but_pressed():
	if inventory_upgrades.visible and inventory_container.visible:
		inventory_container.hide()
	else:
		inventory_container.show()
		inventory_container.current_tab = 3
func _update_material(new_value: float) -> void :
	if player_index == RunData.DUMMY_PLAYER_INDEX:
		return
	var added: int = new_value - RunData.players_data[player_index].gold
	if added > 0:
		RunData.add_gold(added, player_index)
	elif added < 0:
		RunData.remove_gold( - added, player_index)
func _on_randomize_equipment_pressed() -> void :
	DebugService._randomize_equipement(player_index)
func _on_invulnerable_but_pressed(button_pressed: bool) -> void :
	DebugService.invulnerable = button_pressed
func _on_invisible_but_pressed(button_pressed: bool) -> void :
	DebugService.invisible = button_pressed
func _on_oneshotenemies_but_pressed(button_pressed: bool) -> void :
	DebugService.one_shot_enemies = button_pressed
func _on_removestartingweapons_but_pressed(button_pressed: bool) -> void :
	DebugService.remove_starting_weapons = button_pressed
func _on_slowmotion_but_pressed(button_pressed: bool) -> void :
	if button_pressed:
		Engine.time_scale = 0.25
	else:
		Engine.time_scale = 1.0
	DebugService.slow_motion = button_pressed

func _on_add_items_but_pressed():
	remove_items = false
func _on_remove_items_but_pressed():
	remove_items = true
func _on_cursed_items_checkbut_toggled(button_pressed):
	cursed_items = button_pressed
func _on_item_next_shop_checkbut_toggled(button_pressed):
	item_next_shop = button_pressed

func _on_add_weapons_but_pressed():
	remove_weapons = false
func _on_remove_weapons_but_pressed():
	remove_weapons = true
func _on_cursed_weapons_checkbut_toggled(button_pressed):
	cursed_weapons = button_pressed

func _on_cursed_enemies_checkbut_toggled(button_pressed):
	DebugService.curse_enemy_spawn = button_pressed


func _on_spawnEntities_but_pressed():
	if inventory_enemies.visible and inventory_container.visible:
		inventory_container.hide()
	else:
		inventory_container.show()
		inventory_container.current_tab = 2
func _on_killall_but_pressed():
	if get_tree().current_scene is Main:
		var main: Main = get_tree().current_scene
		for node in main._entities_container.get_children():
			if node is Enemy:
				var enemy: Enemy = node
				if not enemy.dead:
					enemy.die()
func _on_nospawningenemies_but_pressed(button_pressed: bool) -> void :
	DebugService.no_enemies = button_pressed
func _on_nospawningentities_but_pressed(button_pressed: bool) -> void :
	DebugService.no_entities = button_pressed
func _on_spawnonlycursedmobs_but_pressed(button_pressed: bool):
	DebugService.always_curse = button_pressed


func _on_goToWaveBut_pressed() -> void :
	RunData.current_wave = gotowaveSpinbox.value
	if RunData.wave_in_progress:
		get_tree().reload_current_scene()
func _updatewaveduration(new_value: float) -> void :
	DebugService.custom_wave_duration = new_value
func _updatestartingatwave(new_value: float) -> void :
	DebugService.starting_wave = new_value
func _on_instantwaves_but_pressed(button_pressed: bool) -> void :
	DebugService.instant_waves = button_pressed
func _on_alwaysdropcrates_but_pressed(button_pressed: bool) -> void :
	DebugService.always_drop_crates = button_pressed
func _on_hidetimer_but_pressed(button_pressed: bool) -> void :
	DebugService.hide_wave_timer = button_pressed
	if get_tree().current_scene is Main:
		get_tree().current_scene._updatehidingHUD()
func _on_hideHUD_but_pressed(button_pressed: bool) -> void :
	DebugService.hide_hud = button_pressed
	if get_tree().current_scene is Main:
		get_tree().current_scene._updatehidingHUD()
func _on_hidefloatingtext_but_pressed(button_pressed: bool) -> void :
	DebugService.hide_floating_text = button_pressed
	if get_tree().current_scene is Main:
		get_tree().current_scene._updatehidingHUD()


func _on_unlockall_but_pressed() -> void :
	ProgressData.unlock_all()
func _on_lockall_but_pressed() -> void :
	ProgressData.lock_all()
func _on_unlockallcharacters_but_pressed() -> void :
	ProgressData.unlock_all_characters()
func _on_lockallcharacters_but_pressed() -> void :
	ProgressData.lock_all_characters()
func _on_unlockalldifficulties_but_pressed() -> void :
	ProgressData.unlock_all_difficulties()
func _on_lockalldifficulties_but_pressed() -> void :
	ProgressData.lock_all_difficulties()
func _on_unlockallchallenges_but_pressed() -> void :
	ChallengeService.complete_all_challenges()
func _on_lockallchallenges_but_pressed() -> void :
	ProgressData.challenges_completed.clear()
func _on_unlockallitems_but_pressed() -> void :
	ProgressData.unlock_all_items()
func _on_lockallitems_but_pressed() -> void :
	ProgressData.lock_all_items()
func _on_unlockallweapons_but_pressed() -> void :
	ProgressData.unlock_all_weapoons()
func _on_lockallweapons_but_pressed() -> void :
	ProgressData.lock_all_weapons()
func _on_unlockallenemies_but_pressed() -> void :
	ProgressData.unlock_all_enemies()
func _on_lockallenemies_but_pressed() -> void :
	ProgressData.lock_all_enemies()


func _on_reload_wave_but_pressed():
	RunData.invulnerable = DebugService.invulnerable
	if RunData.wave_in_progress:
		get_tree().reload_current_scene()


func _input(event):
	if event.is_action_pressed("open_debug_menu"):
		_on_cross_button_pressed()


func _on_cross_button_pressed() -> void :
	queue_free()


func _exit_tree():
	DebugService.curse_enemy_spawn = false
	get_tree().set_pause(false)


func _on_hide_button_pressed():
	if rect_position.x == 0:
		var tween: = Tween.new()
		add_child(tween)
		tween.interpolate_property(self, "rect_position", Vector2(0, 0), Vector2( - 603, 0), 0.2, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
		tween.start()
	else:
		var tween: = Tween.new()
		add_child(tween)
		tween.interpolate_property(self, "rect_position", Vector2( - 603, 0), Vector2(0, 0), 0.2, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
		tween.start()
