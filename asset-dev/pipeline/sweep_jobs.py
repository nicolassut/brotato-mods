#!/usr/bin/env python3
"""Queue a batch of restyle jobs on PixelLab. Usage: sweep_jobs.py <slug> [<slug> ...]
Prints slug=object_id lines. Job table covers all 24 sweep items."""
import json, base64, io, subprocess, sys
from PIL import Image

REAL = '/Users/nicolassutcliffe/brotato-mods/asset-dev/brotato-real-icons'
TAIL = (", wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, "
        "isolated object on transparent background, game item icon")

JOBS = {
 # appetite pack
 "salt_shaker": ("glass_cannon", "a wonky glass salt shaker tilted mid-shake with salt grains flying out of the crooked silver cap" + TAIL),
 "silver_fork": ("lucky_coin", "a fancy silver dinner fork tilted at a jaunty angle with one bent prong and a gleaming sparkle" + TAIL),
 "chewing_gum": ("piggy_bank", "a wad of pink chewing gum blowing a huge lopsided wonky bubble, tilted at an angle" + TAIL),
 "chopsticks": ("bag_icon", "one pair of chopsticks, exactly two parallel wooden sticks side by side, pinching a plump steamed dumpling between their lower tips, tilted at a diagonal angle" + TAIL),
 "tapeworm": ("ugly_tooth", "a silly coiled tapeworm parasite with a derpy smiling face, googly eyes and buck teeth on its raised head end, one single continuous pale cream segmented body coiling in a loose spiral and tapering to one pointed tail tip, the entire body the same pale cream color from head to tail, tilted at an angle" + TAIL),
 "rumbling_belly": ("extra_stomach", "a round plump pink cartoon stomach organ with the same anatomical pouch shape and little duodenum curl, a hungry grumbling face, rumbling and shaking hard with bold curved motion lines and little growl sound waves on both sides, bright pink color, tilted at an angle, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game item icon"),
 "gastric_band": ("piggy_bank", "a pink cartoon stomach organ cinched tight in the middle by a black adjustable strap with a silver buckle, squeezed into a wonky hourglass shape, tilted at an angle" + TAIL),
 "nervous_wreck": ("ugly_tooth", "a pair of wind-up chattering teeth toy caught mid-hop tilted at an angle, just two disembodied denture jaws and nothing else, no skull, no eyes, no face, no head, mouth wide open with crooked yellowed teeth and pink gums, a small metal wind-up key on the side, little red sneakers on two short legs, a few sweat drops flying off, no motion lines and no ground shadow" + TAIL),
 # in-world structure sprites (upright, NOT icon-tilted; style ref = vanilla turret)
 "beehive_ingame": ("turret_structure", "a woven golden beehive standing on a small wooden stand, honey dripping from the dark entrance hole, no bees and no insects anywhere, flat front view facing the camera like a paper cutout, standing upright, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "wok_station_ingame": ("turret_structure", "a small food stall cooking station with a big black wok on a stone burner with flames underneath and steam rising, standing upright, slight three-quarter view, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "street_vendor_ingame": ("turret_structure", "a simple small wooden street food cart with a patched umbrella overhead and gentle smoke rising from a tiny grill, simple and readable, flat front view facing the camera like a paper cutout, standing upright, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "farmers_market_ingame": ("turret_structure", "a small wooden market stall with a striped cloth awning and crates of colorful vegetables, standing upright, slight three-quarter view, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "chili_greenhouse_ingame": ("garden_structure", "a tiny white greenhouse building drawn flat in 2D side-scroller style like a house in a childrens picture book, one triangular glass roof and one glass front wall bursting with red chili peppers, small door in the middle, completely flat, no perspective, no depth, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "fancy_restaurant_ingame": ("garden_structure", "the front facade of a tiny fancy restaurant, a flat 2D sticker drawn perfectly straight-on with no perspective, striped awning over a warm glowing window, ornate door with a bowtie sign, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "ice_cream_truck_ingame": ("turret_structure", "a small ice cream truck seen from the side with a giant plastic ice cream cone on the roof and an open serving window, flat front view facing the camera like a paper cutout, standing upright, wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated object on transparent background, game structure sprite"),
 "food_espresso": ("fruit_food", "a tiny white espresso cup full of dark coffee with a curl of steam" + TAIL),
 "food_steak": ("fruit_food", "a plump raw T-bone steak with pink marbling" + TAIL),
 "food_cake_slice": ("fruit_food", "a single slice of pink strawberry cake with a cherry on top" + TAIL),
 "food_honey_drop": ("bag_icon", "an irregular golden-yellow chunk of honeycomb beeswax, a flat wax slab densely packed with small hexagonal honeycomb cells across its face, a little honey glistening, chunky and blocky, absolutely not a round ball and not a fruit" + TAIL),
 "food_fried_rice": ("fruit_food", "a small bowl piled high with fried rice and a tiny shrimp on top" + TAIL),
 "food_popcorn": ("fruit_food", "a small red and white striped box overflowing with popcorn" + TAIL),
 "food_fries": ("fruit_food", "a small red carton of golden french fries" + TAIL),
 "food_sushi_roll": ("fruit_food", "a single fat sushi roll with rice, seaweed wrap and a salmon center" + TAIL),
 "food_warm_cookie": ("fruit_food", "a thick golden chocolate chip cookie with a bite taken out" + TAIL),
 "food_pizza_slice": ("fruit_food", "a single triangular slice of pepperoni pizza seen from the side, thick solid melted cheese with no holes or gaps, a crispy folded crust, a few round pepperoni on top, one clean whole slice" + TAIL),
 "food_golden_apple": ("fruit_food", "a shiny golden apple with a single leaf and a gleaming star sparkle" + TAIL),
 "food_mystery_meat": ("fruit_food", "a suspicious grey-green haunch of meat on a bone with stink lines" + TAIL),
 "food_cheese_cube": ("fruit_food", "a delicious appetizing wedge of yellow swiss cheese, a soft tasty triangular cheese wedge with a few round holes, warm golden and edible looking" + TAIL),
 "food_protein_shake": ("fruit_food", "a plastic protein shaker bottle with a scoop of powder beside it" + TAIL),
 "food_escargot": ("fruit_food", "a cooked snail in its shell on a tiny plate with a garlic butter shine" + TAIL),
 "food_fruit_salad": ("fruit_food", "a small glass bowl of mixed colorful fruit chunks" + TAIL),
 "food_mint": ("fruit_food", "a single round white mint candy with green stripes" + TAIL),
 "food_chili_pepper": ("fruit_food", "a single plump red chili pepper with a green stem" + TAIL),
 "food_leftovers": ("fruit_food", "a takeaway container overflowing with mixed leftover noodles" + TAIL),
 "food_ice_cream": ("fruit_food", "a single scoop of pink ice cream in a waffle cone" + TAIL),
 "alarm_clock": ("toolbox", "a round twin-bell alarm clock ringing hard, shaking with bold motion lines, hands spinning" + TAIL),
 "bottomless_pit": ("bag_icon", "a dark bottomless hole in cracked ground, endless black pit with a faint hungry glow deep inside, a single french fry tumbling down into it, depth lines" + TAIL),
 "buffet_insurance": ("toolbox", "a shiny metal lunchbox tin stamped with a bold red medical cross, latched shut" + TAIL),
 "burp_of_power": ("ugly_tooth", "a wide open cartoon mouth mid burp letting out a big round air-blast shockwave ring with green stink wafts" + TAIL),
 "caltrops": ("anvil_icon", "a small cluster of sharp metal caltrops, spiked iron jacks with pointy barbs" + TAIL),
 "cast_iron_stomach": ("extra_stomach", "an anatomical stomach organ forged entirely from rough dark black cast iron metal, the same material as a cast-iron skillet, worn iron texture with rivets and seams and a metallic sheen, a tough gritty grin face" + TAIL),
 "chicken_soup": ("bag_icon", "a warm bowl of chicken noodle soup with a drumstick and noodles poking out, steam curls" + TAIL),
 "compost_bin": ("toolbox", "a green plastic compost bin overflowing with food scraps, banana peels apple cores and eggshells spilling over, a couple of flies buzzing" + TAIL),
 "cooler_box": ("toolbox", "a chunky picnic cooler icebox with the lid cracked open, frosty mist and ice cubes spilling out, a drink bottle poking up" + TAIL),
 "echo_chamber": ("lucky_coin", "a brass megaphone bullhorn pointing to the right, with three clean simple curved sound-wave arcs coming out of the bell mouth, neat thin gold arcs with clear empty space between them, uncluttered and tidy" + TAIL),
 "food_coma": ("piggy_bank", "a chubby potato passed out asleep slumped over with a big full belly and floating Zzz letters, a half-eaten snack fallen beside it" + TAIL),
 "food_fight": ("bag_icon", "a gooey cream pie flying through the air mid-throw with a splat trail and motion lines" + TAIL),
 "full_belly": ("piggy_bank", "a fat over-stuffed potato leaning back and patting its bulging round belly with a satisfied grin" + TAIL),
 "grease_fire": ("toolbox", "a frying pan bursting into tall orange flames, a grease fire flaring up with smoke" + TAIL),
 "growling_stomach": ("piggy_bank", "a pink cartoon stomach organ with jagged GRRR sound-bolt lines and hungry drool, angry and starving" + TAIL),
 "intermittent_fasting": ("lucky_coin", "an empty white dinner plate drawn as a clock face with a fork and knife as the clock hands, a grumpy look" + TAIL),
 "loyalty_card": ("banner_icon", "a paper loyalty punch card with a row of stamp holes, most punched with little stars and a gold star stamp in the last slot" + TAIL),
 "magnifying_glass": ("lucky_coin", "a classic round magnifying glass with a wooden handle and a gleaming lens" + TAIL),
 "michelin_star": ("lucky_coin", "a shiny golden five-pointed star award medal with a small ribbon, gleaming with sparkles" + TAIL),
 "mosquito_jar": ("glass_cannon", "a glass jar with a lid holding one big cartoon mosquito buzzing inside, a red drop" + TAIL),
 "msg": ("glass_cannon", "a typical MSG seasoning container, a white plastic canister shaker with a bright red screw-on cap and an MSG umami label on the front, a few white crystals, clearly monosodium glutamate" + TAIL),
 "nine_lives": ("baby_gecko_icon", "a smug content cartoon cat curled up with a small round collar tag showing the number 9, cute" + TAIL),
 "panic_button": ("lucky_coin", "a big round red emergency panic button with a domed glass cover, shiny" + TAIL),
 "party_balloon": ("piggy_bank", "a single round shiny party balloon with a curly string and a little knot, bright color" + TAIL),
 "pepper_grinder": ("toolbox", "a tall wooden pepper grinder mill sprinkling out black pepper flakes" + TAIL),
 "pocket_sand": ("bag_icon", "a small drawstring cloth pouch bag with a little sand spilling out of its open top and a small separate pile of sand on the ground beside the bag, no hand and no person, just the little sack and the sand" + TAIL),
 "preservatives": ("glass_cannon", "a glass mason jar of preserved pickled food sealed with a lid, brine and a pickle inside" + TAIL),
 "second_helping": ("bag_icon", "a stack of two dinner plates piled with a second serving of food, a little sparkle" + TAIL),
 "set_menu": ("banner_icon", "a rustic wooden A-frame chalkboard sidewalk sign reading SPECIAL with a chalk star, on little legs" + TAIL),
 "slow_cooker": ("toolbox", "a round ceramic crock-pot slow cooker with a domed glass lid, thick stew bubbling inside, lazy steam curls" + TAIL),
 "snack_break": ("propeller_hat", "a bright clean shiny foil bag of potato chips with red and yellow packaging, torn open at the top with golden potato chips and a couple gold coins spilling out, new and crisp not dirty, clearly a chip bag not a burlap sack" + TAIL),
 "sous_vide_machine": ("toolbox", "a pot of water with a sous-vide immersion wand clipped to the rim and a vacuum-sealed bag of steak floating among rising bubbles" + TAIL),
 "space_heater": ("toolbox", "a small space heater with red-hot glowing orange coils and heat-shimmer waves rising off it" + TAIL),
 "static_cling": ("piggy_bank", "a fuzzy wool sock crackling with blue static electricity sparks and little lightning bolts, standing up stiff" + TAIL),
 "sticky_bomb": ("anvil_icon", "a round black cartoon bomb with a lit sparking fuse and sticky gooey globs stuck on it" + TAIL),
 "sugar_rush": ("frozen_heart", "a white sugar cube sparkling with energy and bold speed lines zipping off it, a sugar sprinkle" + TAIL),
 "sunscreen": ("glass_cannon", "a squeeze bottle of sunscreen lotion with a sun logo and a blob of white cream on top" + TAIL),
 "training_weights": ("anvil_icon", "a pair of grey velcro weighted ankle straps, heavy weighted training bands" + TAIL),
 "cleaver": ("weapon_melee", "a big heavy stainless steel meat cleaver with a wooden handle, sharp broad blade" + TAIL),
 "trident_fork": ("weapon_melee", "a large three-pronged silver dinner fork like a trident, sharp prongs" + TAIL),
 "frying_pan": ("weapon_melee", "a black cast iron frying pan with a long handle, wielded as a bludgeon" + TAIL),
 "rolling_pin": ("weapon_melee", "a chunky wooden rolling pin with two handles, a baking club" + TAIL),
 "meat_tenderizer": ("weapon_melee", "a heavy metal meat tenderizer mallet with a spiked textured head and a handle" + TAIL),
 "ladle": ("weapon_melee", "a big metal soup ladle with a deep round bowl and a long handle" + TAIL),
 "whisk": ("weapon_melee", "a metal wire kitchen whisk with looping wires and a handle" + TAIL),
 "baguette": ("weapon_melee", "a long crusty golden baguette bread loaf wielded like a club" + TAIL),
 "butchers_saw": ("weapon_melee", "a large butcher's bone saw with a toothed metal blade and a wooden grip" + TAIL),
 "cheese_grater": ("weapon_melee", "a metal box cheese grater with sharp punched grating holes, a handle on top" + TAIL),
 "golden_spatula": ("weapon_melee", "a shiny golden metal kitchen spatula with a flat slotted head and a handle" + TAIL),
 "skewer": ("weapon_melee", "a long metal skewer kebab with chunks of meat and vegetables stuck on it" + TAIL),
 "pizza_cutter": ("weapon_ranged", "a rolling pizza cutter with a sharp round steel wheel and a handle" + TAIL),
 "corn_cannon": ("weapon_ranged", "a short stubby brass and black cannon barrel with a fresh yellow corn cob loaded in the muzzle and a lit fuse, a clean simple cartoon corn cannon, no husks no leaves no jungle clutter" + TAIL),
 "sauce_blaster": ("weapon_ranged", "a squeeze sauce bottle shaped like a blaster gun squirting a blob of red sauce" + TAIL),
 "champagne_popper": ("weapon_ranged", "a champagne bottle popping its cork with a burst, held like a gun" + TAIL),
 "ice_cream_scoop": ("weapon_melee", "a classic shiny metal ice cream scoop utensil with a squeeze-lever trigger handle and a round steel scoop bowl cradling a scoop of pink ice cream, a real ice cream scoop not a gun" + TAIL),
 # food-system spawners (depict the MACHINE/SOURCE, not the food)
 "after_dinner_mints": ("lucky_coin", "a tilted open metal tin of striped after-dinner mints with mints spilling out and bouncing" + TAIL),
 "bakers_oven": ("toolbox", "a wonky old cast iron baking oven tilted at an angle, door hanging open with warm glow and a smoke puff" + TAIL),
 "beehive": ("bait_icon", "a wonky golden beehive tilted at an angle, dripping honey from the entrance hole, one angry cartoon bee buzzing beside it" + TAIL),
 "butchers_hook": ("anvil_icon", "a huge slab of marbled red meat hanging heavy on a curved metal butcher's hook pierced through the top of it, tilted at an angle, the meat is big and the hook is buried in it" + TAIL),
 "chili_greenhouse": ("bait_icon", "a wonky little glass greenhouse tilted at an angle stuffed full of red chili peppers pressing against the glass panes" + TAIL),
 "deep_fryer": ("toolbox", "a wonky metal deep fryer basket tilted at an angle overflowing with golden fries, hot oil bubbles splashing" + TAIL),
 "doggy_bag": ("bag_icon", "a crumpled brown paper bag tilted at an angle with the top folded wide open and a big white dog bone sticking up out of the opening, a small black paw print stamped on the front of the bag" + TAIL),
 "espresso_machine": ("toolbox", "a wonky little espresso machine tilted at an angle, steam bursting from the side, dark coffee pouring into a tiny crooked cup" + TAIL),
 "fancy_restaurant": ("lucky_coin", "a fancy restaurant menu in an ornate tilted golden frame with cursive scribble lines and a little black bowtie stuck on the corner" + TAIL),
 "farmers_market": ("banner_icon", "a wonky wooden market stall tilted at an angle with a red and cream striped cloth awning, light golden pale wood planks, two big crates of oversized bright vegetables, plump red tomatoes and orange carrots and green lettuce spilling forward, a small FRESH sign, simple bold chunky shapes, bright cheerful colors, no dark shadows" + TAIL),
 "fondue_set": ("frozen_heart", "a wonky fondue pot tilted at an angle overflowing with dripping melted yellow cheese, a long fork with a bread cube stuck in it" + TAIL),
 "grandmas_cookbook": ("banner_icon", "a thick worn old cookbook tilted at an angle with a stitched heart patch on the cover and loose dog-eared pages sticking out messily" + TAIL),
 "gym_membership": ("anvil_icon", "a wonky heavy dumbbell tilted at an angle with a slightly bent bar and one plate bigger than the other, sweat drops flying" + TAIL),
 "ice_cream_truck": ("propeller_hat", "a wonky little ice cream truck tilted at an angle leaning on squashed wheels, a giant plastic ice cream cone on the roof, serving window open" + TAIL),
 "pizza_delivery": ("banner_icon", "a squashed cardboard pizza box tilted at an angle with the lid half open and a cheesy pizza slice flopping out, grease stains on the cardboard" + TAIL),
 "popcorn_machine": ("propeller_hat", "a wonky red and white striped popcorn machine cart tilted at an angle with popcorn kernels bursting out of the top in all directions" + TAIL),
 "street_vendor": ("bag_icon", "a wonky street food cart tilted at an angle with a crooked patched umbrella and smoke puffs rising from the sizzling grill" + TAIL),
 "sushi_bar": ("bait_icon", "a plump salmon nigiri sushi piece tilted at an angle on a small wooden serving board, floppy orange salmon slice on a chunky rice base" + TAIL),
 "victory_feast": ("ugly_tooth", "a golden roasted turkey on a platter tilted at an angle with both drumsticks in the air and a tiny victory flag stuck in the top, steam curls" + TAIL),
 "wok_station": ("toolbox", "a wonky black wok pan tilted at an angle mid-toss with flames leaping up and vegetables flying out" + TAIL),
 # original basic-10 pack
 "iron_lung": ("anvil_icon", "a pair of wonky cast iron metal lungs with rivets along the seams and a small round pressure gauge, tilted at an angle" + TAIL),
 "overtime_pay": ("bag_icon", "a wonky messy stack of green banknotes tilted at an angle with loose bills fluttering off the top and a paper band around the middle" + TAIL),
 "loaded_dice": ("piggy_bank", "a wonky red casino die tilted at an angle with one cracked corner chipping off, clean solid red faces with plain round white pips, simple flat colors" + TAIL),
 "energy_drink": ("propeller_hat", "a wonky green energy drink can crushed in the middle, tilted at an angle, big yellow star logo, fizzy droplets spraying from the open tab" + TAIL),
 "overclocked_chip": ("energy_bracelet", "a wonky blue computer chip tilted at an angle with bent gold pins, a big yellow lightning bolt on top, and a little smoke puff with sparks from one overheating corner" + TAIL),
 "potato_peeler": ("bag_icon", "a wonky potato peeler with a worn wooden handle tilted at an angle, a long curly potato peel ribbon dangling off the blade" + TAIL),
 "second_mortgage": ("banner_icon", "a wonky cracked wooden FOR SALE yard sign tilted and half fallen over in a tuft of grass, a small sad house doodle painted on the plank" + TAIL),
 "tin_foil_hat": ("lucky_coin", "a wonky crumpled tin foil cone hat tilted at an angle with crinkled shiny facets and a little glint sparkle" + TAIL),
 "vampire_fang": ("ugly_tooth", "a wonky sharp vampire fang tilted at an angle with a fresh red blood drip, a tiny crack, and gross grungy detail" + TAIL),
 "voodoo_potato": ("adrenaline_icon", "a wonky stitched voodoo potato doll tilted at an angle with mismatched button eyes, crossed stitches on the belly, and two pins stuck in its head" + TAIL),
}

def style_b64(name):
    im = Image.open(f'{REAL}/{name}.png').convert('RGBA').resize((192, 192), Image.NEAREST)
    buf = io.BytesIO(); im.save(buf, 'PNG')
    return base64.b64encode(buf.getvalue()).decode()

def main():
    for slug in sys.argv[1:]:
        style, desc = JOBS[slug]
        args = {"description": desc, "view": "sidescroller",
                "style_images": [{"type": "base64", "base64": style_b64(style), "format": "png"}]}
        r = subprocess.run(['python3', 'pixellab_mcp.py', 'call', 'create_1_direction_object',
                            json.dumps(args)], capture_output=True, text=True)
        try:
            t = json.loads(r.stdout)['result']['content'][0]['text']
            oid = [l for l in t.splitlines() if l.startswith('id:')][0].split(': ')[1]
            print(f'{slug}={oid}')
        except Exception:
            print(f'{slug}=ERROR {r.stdout[:200]} {r.stderr[:200]}')

if __name__ == '__main__':
    main()
