class_name FoodData
extends ConsumableData

# Gourmet DLC - food consumable definition. Foods are consumables that grant
# temporary effects via the shared-timer buff engine in player.gd.
# Per-stack buff strength per stat = base + app_ratio * Appetite (floored).
# Base duration in seconds = (buff_duration + duration_app_ratio * Appetite)
# * (1 + Appetite / 100), floored.
# Foods spawn ONLY through their spawner item, never through enemy drop rolls,
# so they are registered in ItemService.foods and NOT in ItemService.consumables.
# Cyclic-dependency law: this script must not reference other Data class names.

# timed stacking buff: entries are [stat_key: String, base: float, app_ratio: float]
export (Array) var buff_stats = []
export (int) var buff_duration = 0
export (float) var duration_app_ratio = 0.0
export (bool) var buff_stacks = true
# cap on the total applied magnitude per stat across stacks (0 = uncapped)
export (int) var buff_total_cap = 0
# cap on how many times the buff can stack (count, not magnitude). At the cap, eating
# the food again extends the shared timer but adds no more magnitude and does not grow
# the stack count. Ceiling is 20 for any food; strong foods use a lower cap.
export (int) var buff_stack_cap = 20

# wave-long TempStats (no timer): entries are [stat_key, base, app_ratio]
export (Array) var wave_stats = []
# permanent RunData stats: entries are [stat_key, value]
export (Array) var permanent_stats = []
# Gourmet DLC - permanent_stats grant scales base * (1 + ratio * Appetite) when > 0
# (Fried Egg: +1 Luck x(1 + 5%/Appetite)); 0 = flat grant (Fruit Salad).
export (float) var permanent_app_ratio = 0.0
# my_id of the item credited on its card for permanent_stats gains (vanilla
# perma-stat tracking rule); the key must be seeded in RunData.init_tracked_items
export (String) var tracking_item_id = ""

export (float) var heal_base = 0.0
export (float) var heal_app_ratio = 0.0

# coded behaviors: "mint", "mystery_meat", "golden_apple", "escargot"
export (String) var special_id = ""
