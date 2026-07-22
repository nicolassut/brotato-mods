# Handover prompt — next Brotato art session

Paste this into a fresh Claude Code chat launched from ~/brotato-mods:

---

Read ~/brotato-mods/HANDOVER_ART_PIPELINE.md fully before generating anything. It contains
the complete proven workflow (the user has endorsed it as "almost perfect", do not drift
from it): the style law + vibe law, the style-image recipe, section 3b's sweep loop, the
measured-outline targets, final_cleanup, and vector-prep.

State as of 2026-07-20:
- 44 item icons are DONE and installed live (10 Appetite, 20 food-system spawners, 4
  Appetite basics, the original basic-10). All have cleaned borders and measured 6-11px
  outlines. Do not regenerate any of them.
- The working scripts are in asset-dev/pipeline/ (sweep_jobs.py = job table + queue,
  process_gen.py = thicken/downscale/cleanup/install/vecprep, poll_ids.sh = batch poller,
  pixellab_mcp.py = HTTP fallback client if the PixelLab MCP is not loaded). Use them, do
  not rewrite from scratch.
- Vectorizer staging: Brotato Icons/items_to_vectorize/ has a _vecprep.png for every icon.
  The user vectorizes at their own pace; integration of vectorized versions is a separate
  future step.
- PixelLab balance: 0 generations (exhausted); vecprep pipeline is 8x as of 2026-07-20 late (resets Aug 10).
  Each 192px icon costs 20 per attempt, so that is ~24 more icons this window including
  retries. Check get_balance at start and budget before batch sweeps.
- 2026-07-20 evening redo: farmers_market and nervous_wreck regenerated (user rejected
  originals), chili_greenhouse reprocessed from raw at W=1. process_gen.py is now v2
  (saturation-aware cleanup, main-component-only dilation, auto hole fill); see
  HANDOVER_ART_PIPELINE.md section 3c before the next batch.

Next work, in order:
1. ~33 new items from the parallel "food-system" session (alarm_clock, caltrops,
   sticky_bomb, michelin_star, sugar_rush, pepper_grinder, mosquito_jar, nine_lives,
   preservatives, etc.) currently have crude placeholder icons. BEFORE touching them: read
   ~/.claude/issues/brotato-mods/ACTIVE_WORK.md and confirm the food-system session is done
   or coordinate with it. Its builders draw placeholder icons on every run; they need the
   same prefer-final patch that build_food_system.py already has (copy real art from a
   final folder if present). Confirm the item list is stable, ask the user about budget
   (33 icons is ~660 generations), then sweep with the standard loop.
2. After that: 20 food ground-sprites (fruit-scale consumables, reference
   items/consumables/) and remember spawner icons depict the MACHINE, foods the FOOD.
3. Eventually: Culinary weapon sprites + projectiles, class icon, upgrade icons.

Working rules the user enforces hard: review EVERY generation honestly before installing
(vibe law + physical logic - does the object make real-world sense), ship only what beats
the current version, measure outlines instead of eyeballing, no em-dashes in any file, and
never present an image you have not looked at.

## State update 2026-07-20 late evening (art-pipeline session, credits EXHAUSTED)

- PixelLab balance is 0. User will top up. Everything below is ready to fire on refill.
- Food-spawner STRUCTURES: all 7 done, flat front view per user direction, relative
  world sizes set (SIZES table in scratchpad process_structure.py, copy in this repo's
  pipeline notes): hive 100, wok 95, vendor 105, market 120, greenhouse 125,
  restaurant 130, truck 135. Installed live + asset-dev/structures_food/. The
  build_food_system.py structure loop now prefers asset-dev finals (patched).
- Structure lessons: flat 2D front view like the garden tree, no creatures (nothing
  animates), buildings iso-lock HARD - front-priming subject words break it
  ("cabinet", "facade", "childrens picture book house" won after 4 attempts).
- FOODS: first 10 of 20 done and installed live in items/foods/<slug>/<slug>.png
  (espresso, steak, cake_slice, honey_drop, fried_rice, popcorn, fries, sushi_roll,
  warm_cookie, pizza_slice). 80x80, fruit_food style ref, procedural ground shadow
  (process_food.py in scratchpad - REBUILD it in pipeline/ if scratchpad is gone,
  it is small). Remaining 10 prompts are ALREADY IN sweep_jobs.py JOBS table:
  food_golden_apple, food_mystery_meat, food_cheese_cube, food_protein_shake,
  food_escargot, food_fruit_salad, food_mint, food_chili_pepper, food_leftovers,
  food_ice_cream. Queue in batches of 4 on refill (~200 generations for all 10 with
  retry headroom).
- After foods: ~33 new-pack item icons (coordinate with food-system session), then
  Culinary weapons.
