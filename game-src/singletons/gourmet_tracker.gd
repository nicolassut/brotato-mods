extends Node

# Gourmet DLC - playtest telemetry. Writes JSON lines to user://gourmet_tracker.jsonl
# (~/Library/Application Support/Brotato/ on macOS); asset-dev/analyze_tracker.py
# turns the log into a verification report that cross-checks every food-system
# formula against what actually happened in game.
#
# Low-frequency events log directly via ev(); high-frequency ones (kill counts,
# chili ignites, caltrops hits...) aggregate through count() and flush every few
# seconds plus at wave boundaries. A fresh log is started per game process.

const LOG_PATH = "user://gourmet_tracker.jsonl"
const FLUSH_INTERVAL = 5.0

const SNAPSHOT_STATS = ["stat_appetite", "stat_max_hp", "stat_hp_regeneration",
	"stat_percent_damage", "stat_melee_damage", "stat_ranged_damage",
	"stat_elemental_damage", "stat_attack_speed", "stat_crit_chance",
	"stat_armor", "stat_dodge", "stat_speed", "stat_luck", "stat_harvesting"]

var enabled: = true
var _file: File = null
var _counters: = {}
var _flush_accum: = 0.0
var _trigger_names: = {}


func _ready() -> void :
	_file = File.new()
	var err = _file.open(LOG_PATH, File.WRITE)
	if err != OK:
		enabled = false
		return

	for trigger_name in ["wave_start_foods", "kill_foods", "burning_kill_foods",
		"crit_foods", "burning_tick_foods", "explosion_foods", "material_foods",
		"level_up_foods", "damage_taken_foods", "elite_kill_foods",
		"consumable_count_foods", "step_foods", "timer_foods",
		"full_hp_timer_foods", "standstill_timer_foods", "mid_wave_foods",
		"random_times_foods", "reroll_banked_foods", "close_kill_foods",
		"far_kill_foods", "turret_kill_foods"]:
		_trigger_names[Keys.generate_hash(trigger_name)] = trigger_name

	ev("session_start", {"v": 1})


func _process(delta: float) -> void :
	if not enabled:
		return
	_flush_accum += delta
	if _flush_accum >= FLUSH_INTERVAL:
		_flush_accum = 0.0
		flush_counters("interval")


func ev(kind: String, data: Dictionary = {}) -> void :
	if not enabled:
		return
	data["e"] = kind
	data["t"] = stepify(OS.get_ticks_msec() / 1000.0, 0.01)
	data["w"] = RunData.current_wave
	_file.store_line(JSON.print(data))
	_file.flush()


func count(counter: String, amount: int = 1) -> void :
	if not enabled:
		return
	_counters[counter] = _counters.get(counter, 0) + amount


func flush_counters(reason: String) -> void :
	if not enabled or _counters.empty():
		return
	var flushed = _counters
	_counters = {}
	ev("counters", {"reason": reason, "c": flushed})


func trigger_name(trigger_hash: int) -> String:
	return _trigger_names.get(trigger_hash, str(trigger_hash))


func stat_snapshot(player_index: int) -> Dictionary:
	var snap: = {}
	for stat_name in SNAPSHOT_STATS:
		snap[stat_name] = stepify(Utils.get_stat(Keys.generate_hash(stat_name), player_index), 0.1)
	return snap
