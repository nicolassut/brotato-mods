# GourmetCore extension AUDIT (generated - encode resolutions in gen_extensions.py)

## Flags (emitted, verify once)
- `dlcs/dlc_1/dlc_1_data.gd`: hand extension (no pristine baseline): segments ['FREELOADER_CURSE_CHANCE', 'update_item_effects'], installed late, DLC-guarded
- `singletons/item_service.gd`: dict item_groups entry "lifesteal" CHANGED value: '["item_butterfly", "item_bat", "item_whetstone", "item_decomposing_flesh", "item_bloody_hand", "item_fresh_meat"]' -> '["item_butterfly", "item_bat", "item_whetstone", "item_decomposing_flesh", "item_bloody_hand", "item_fresh_meat", "item_vampire_fang"]'
- `singletons/item_service.gd`: dict item_groups entry "lifesteal_and_hp_regeneration" CHANGED value: '["item_blood_leech"]' -> '["item_blood_leech", "item_mosquito_jar"]'
- `singletons/item_service.gd`: dict item_groups entry "hp_regeneration" CHANGED value: '["item_mushroom", "item_plant", "item_sad_tomato", "item_medikit", "item_fairy", "item_potion", "item_fried_rice", "item_baby_squid", "item_coral", "item_penguin"]' -> '["item_mushroom", "item_plant", "item_sad_tomato", "item_medikit", "item_fairy", "item_potion", "item_fried_rice", "item_baby_squid", "item_coral", "item_penguin", "item_iron_lung", "item_meal_in_a_pill"]'
- `singletons/item_service.gd`: dict item_groups entry "consumable_heal" CHANGED value: '["item_jerky", "item_weird_food", "item_lemonade", "item_fruit_basket"]' -> '["item_jerky", "item_weird_food", "item_lemonade", "item_fruit_basket", "item_chicken_soup", "item_buffet_insurance"]'
- `singletons/item_service.gd`: dict item_groups: 0 added / 4 changed entries merged at _init
- `singletons/item_service.gd`: synthesized _init() to host injected calls ['_gourmet_merge_item_groups()']
- `singletons/progress_data_loader_v3.gd`: synthesized forwarding _init(save_dir: = "", current_profile_id: int = 0)
- `singletons/run_data.gd`: dict init_tracked_items: 60 added / 0 changed entries merged at _init
- `singletons/run_data.gd`: synthesized _init() to host injected calls ['_gourmet_merge_init_tracked_items()']
- `singletons/text.gd`: dict keys_needing_operator: 19 added / 0 changed entries merged at _init
- `singletons/text.gd`: synthesized _init() to host injected calls ['_gourmet_merge_keys_needing_operator()']
- `singletons/utils.gd`: new setget declaration packs in extension
- `singletons/utils.gd`: new setget declaration game_modes in extension
- `singletons/utils.gd`: new setget declaration gourmet_tracker in extension
- `singletons/utils.gd`: new setget declaration special_modifiers in extension
- `singletons/utils.gd`: new setget declaration butcher_skin in extension
- `ui/menus/pages/menu_codex.gd`: inner class SortItem redeclared in child - safe: all reference sites ['_pop'] ship in the extension
- `ui/menus/pages/sort_inventory_button.gd`: inner class SortInventory redeclared in child - safe: all reference sites ['_sort_inventory'] ship in the extension
- `<all>`: cross-file member shadowing (new var colliding with an ANCESTOR script's member) is not statically checked here - the clone-gate boot surfaces it as a parse error
