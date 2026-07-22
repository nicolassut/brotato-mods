YET TO VECTORIZE - redesigned Culinary weapons (2026-07-21)
===========================================================
Run each of these through vectorizer.ai, then drop the results into
New_Vectorized_Icons/ with the SAME filename.

12 files = 6 weapons x (icon + in-hand sprite):

  weapon__<slug>.png         = shop/inventory ICON (tilted)
  weapon_sprite__<slug>.png  = in-hand game SPRITE (horizontal, points right)

Weapons: corn_cannon, galley_cannon, sauce_blaster, champagne_popper,
         fish_slapper, frying_pan

Notes:
- corn_cannon icon here REPLACES the old wheeled-cannon vectorized version.
- All are already despeckled (white border dots removed) and sized for the
  vectorizer (128px). Everything else in the mod is already vectorized.

- weapon__whisk.png added: it was already vectorized last session; this is the
  despeckled vecprep for an optional clean re-trace (it is already dot-free in-game).

FRYING PAN SIZE (it is detail-dense: egg + rim + cooking surface):
  weapon__frying_pan.png       = 256x256, RECOMMENDED - vectorize this first.
  weapon__frying_pan_192.png   = smaller/smoother if 256 looks too chunky.
  weapon__frying_pan_300.png   = larger/more detail if 256 loses the egg.
  Pick the smallest one that still vectorizes cleanly; 300 is the max worth using.

PROJECTILES (2026-07-22) - one themed shot per ranged weapon, 6 files:
  projectile__corn_cannon      = flying corn cob        (was rocket)
  projectile__galley_cannon    = cannonball             (was rocket)
  projectile__sauce_blaster    = hot-sauce glob         (was fireball)
  projectile__champagne_popper = champagne cork         (was default bullet)
  projectile__pizza_cutter     = spinning pizza         (was shuriken)
  projectile__ice_cream_scoop  = ice-cream scoop        (was potato)
  Already installed + wired in-game; vectorize only if you want them crisper.

BUTCHER MEAT RESKIN (2026-07-22) - 7 files, all installed + wired in-game:
  butcher__meat_rack / meat_locker / meat_cooler / beef_broth / butchers_apron
    = item icons replacing Tree / Garden / Fruit Basket / Lemonade / Lumberjack Shirt
      when the Butcher is in the run (128px vecpreps)
  butcher__meat_rack_ingame   = on-map tree replacement (256px vecprep)
  butcher__meat_locker_ingame = garden structure replacement (256px vecprep)

UPDATE 2026-07-22 (after vectorizer feedback):
- butcher__ icon vecpreps are now 200x200 (detailed icons keep more detail at 200;
  the user's new standing rule). meat_rack_ingame stays 256.
- meat rack (icon + ingame) re-fixed with the v2 pool method: gaps open but the
  hanging hooks and joints are preserved this time. Re-vectorize BOTH rack files
  and weapon__whisk.png (rebuilt from the fixed in-game icon).

DINNER BELL (2026-07-22): weapon__dinner_bell.png (200px) added - the bell finally
got its icon. Vectorize it; the held sprite + icon are already live in-game.
The 13 new held weapon sprites were built FROM the vectorized masters (rotated to
horizontal + vanilla hand) so they need NO vectorizing of their own.
