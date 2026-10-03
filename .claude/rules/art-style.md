---
paths:
  - "scenes/**/*.tscn"
  - "scenes/**/*.gdshader"
  - "scenes/**/*.gdshaderinc"
  - "resources/facades/**"
  - "resources/items/**"
  - "scripts/travel/facades/**"
  - "scripts/stops/**"
  - "tools/generate_boon_icons.py"
---

# Art style

Owner's direction (2026-09-25): two styles, one dark look. The 3D world is
low-poly geometry skinned with procedural grime shaders, built the way the
road is built. Everything that is a character or a thing you pick up is
pixel art. The game is night-dark. None of the current art is final, but
every new or changed asset follows this file, so the game converges
instead of drifting.

References the owner signed off on: the road
(`scenes/corridor/asphalt_surface.gdshader`, with `sidewalk_surface`) and
the van interior (`scenes/van/van_*.gdshader`) for 3D; the shopkeeper
(`scenes/shop/vendor.png`) for pixel art. When this file and a reference
disagree, the reference wins and this file gets fixed.

## Mood: dark

It is always night. The world is near black; light comes only from things
you can point at: street lamps, lit windows, signs, fire, the van's own
lights, muzzle flash. Away from a source a surface falls to near-black
within about 20 m, and the fog takes everything by 56 m.

One deliberate exception (owner, art-pass step 13): the van's own mask-1
lights in `scenes/van/van.tscn` stay as they are: `DoorSpill` (energy 6.5,
18 m, shadowed; it is what lets the player see raiders at the doors),
`RearCone` (5.5) and the `ExteriorLight` directional "moon", which is light
from nothing you can point at. Don't dim or remove them to meet a shot
target, and don't add another sourceless light on their precedent.

- **Environment baseline** (`IndustrialEnvironment` in `scenes/van/van.tscn`):
  background (0.018, 0.024, 0.025), ambient (0.24, 0.29, 0.29) at energy
  0.24, depth fog 20..56 m in (0.008, 0.012, 0.011), glow threshold 1.1.
  Never raise ambient or fog-begin to make something readable: add a light
  that belongs there (a lamp, a lit doorway, a sign).
- **Albedo budget** (linear RGB luminance, the road's range): large surfaces
  0.02..0.25; wear, trims and highlights up to 0.40; small bright litter
  (paper) up to 0.45. Nothing non-emissive above 0.5.
- **Colour:** the world is desaturated warm grey, soot brown and oxide
  green-grey. Saturated colour belongs to light sources (sodium amber,
  tungsten, sick fluorescent green, neon red and cyan), to danger (raiders,
  blood, fire) and to things the player can use (the red button, pickups,
  shop wares).
- **Emission budget:** light sources you look at directly (lamp heads, signs,
  neon, fire, marquee bulbs, muzzle flash) may cross the glow threshold and
  bloom. Lit windows stay under it: they read as a warm dim glow, never a
  white or blue-white pane. At most about a third of a facade's windows are
  lit, fewer in derelict districts.
- **Light pools:** street and stop lights are pools with dark gaps between
  them. Shadows stay crisp (shadow blur and light angular distance at or
  near 0). No SSAO, no GI.
- **Every stop light has a fixture:** a light in a stop, a junction or on a
  statue hangs under a mesh you can point at (a tungsten ceiling lamp, a
  caged lamp, a wall lamp, a trouble lamp, a drop bulb, an emissive orb). A
  glow floating in air is a break; add the fixture, keep the energy.
- **Screen check:** `tools/shot_stats.py <shots dir>` gives each `--shots`
  PNG its mean luminance, its 95th percentile and its clipped-pixel share.
  A visible change that moves a shot past its target below is a
  regression.

Calibrated in art-pass step 1 (2026-09-25) from the stop shots, which are
the "dark enough" line (`09` mean 0.0052, `12` mean 0.0123, p95 0.019).
Values are linear luminance; clip% is the share of pixels with any channel
at 250 or more. `*-outside` is the camera above the cab; `*-back` the van
interior facing the rear doors; `*-front` the player's view with the HUD.

| Shots | Mean max | p95 max | Clip% max |
|---|---|---|---|
| `*-outside` (street and stops) | 0.015 | 0.030 | 1.0 |
| `*-back` (van interior) | 0.011 | 0.025 | 0.05 |
| `*-front` (HUD on, loose check) | 0.030 | 0.10 | 0.20 |

After the 3D art pass (2026-09-25) every shot is inside its target except
`06-combat-outside` (mean 0.036, p95 0.178, clip 1.6%; it was 0.099, 0.85
and 7.4% before). That is accepted: the overhead camera sits at
second-floor height right beside the big vertical sign and near lit panes,
so `06` reads emissives close to a high camera, not the street's ambient
darkness. Judge a change by how far it moves `06`, not by the table.

Reading the numbers:

- Shots are not pixel-deterministic between runs, and facade layouts are
  seeded per run, so street numbers move with the buildings on screen.
  Compare against a before run of the same session, and treat about
  ±0.001 mean and ±0.1 clip% as noise.
- A change to a large surface reads on near walls, docks and stoops, not in
  the means: look at the PNGs as well.
- The smoke shots visit only the street, the elevator stop (shop) and the
  rear-park stop (garage). For the mechanic, the warehouse, a junction, a
  statue or an overhead, check with a temporary debug swap (`stop elevator
  mechanic`, `stop warehouse`) that is never committed.

## Procedural 3D (street, facades, stops, props, van)

Geometry:

- Low-poly: primitives and `SurfaceTool` quads with hard edges. No imported
  realistic models, no subdivided or sculpted surfaces.
  One owner exception (2026-10-01): the first-person arms are the CC0
  low-poly rigged model `assets/models/arms/arms.glb`, posed by `ArmRig`
  and skinned only with the grime shader as `material_override` (no bitmap).
  Its claw-nails (`ArmClaw`) are smooth-shaded, 12-segment arcs that hug
  the fingertip from the tube's own recorded rings (`tip_rings`), sunk 3 %
  into the skin so they never float, then taper to a point curving 15-30
  degrees toward the pad (owner, 2026-10-03: the old 6-sided horns floated
  and looked too low-poly).
  The hands never rest: `ArmWeave` (`scripts/player/arms/arm_weave.gd`)
  rolls both hands' fingers index to pinky in hooked witch curls on a 3.6 s
  period with a slow second harmonic, wrists circling, both hands
  raised in front, palms down and inward; the free left thumb swings out
  opposite the index and curls back toward its tip in an open C, as if holding
  an invisible can (`LEFT_THUMB_*`, console `arms lthumb` tunes it live); it runs
  through idle, walking, shooting and reloading, and holds still at t 1.1 under `SaveSandbox` so shots
  compare (`arms weave <s>|off` pins it). With the gun shown the right hand
  grips it instead (`ArmWeave._update_grip`: squeeze, trigger lift, thumb
  wave), the thumb wrapping the grip's far side under the slide and pointing
  forward, a C with the trigger finger (`RIGHT_THUMB_AIM`, `RIGHT_THUMB_CURL`);
  `arms fit` prints the thumb's clearance from the gun parts and must say
  `FIT OK`. `arms thumbs` prints per hand the thumb's angle to the index,
  gap/p, hook, up and fwd against the bars in `debug_arms_thumbs.gd`, then
  `THUMBS OK` or `THUMBS CHECK`.
  Arm dressing (`ArmsBuilder.dress_style`, console `arms dress gear|rags|none`):
  `gear` (default) is one wrecked T-shirt sleeve on each arm (`ArmSleeve`, a
  skinned tube on the upper arm only, hem torn and open just above the elbow at
  `DEF-upper_arm.001` t 0.72, hem rings weighted to the upper arm only) plus the
  skin layers: the van-name tattoo in faded block letters on the LEFT lower
  forearm (where the player camera sees it), scars, wounds, dirt. Owner
  (2026-10-02): no rings, straps, bands or other bolt-ons on the arms; "the
  sleeve is enough". `rags` is the old rag and glove dress. Skin layers paint
  in LINEAR colours (the skin albedo is a `source_color` uniform) from the
  rest-pose chart in CUSTOM1/CUSTOM2; cloth tints are `source_color`. Gear is
  built after the arms join the camera (facing angles need it). `arms gear`
  checks each sleeve's own-bone (upper-arm) skin through every pose and must say
  `GEAR OK`.
- No bitmap textures on 3D surfaces (no photos, no painted PNGs, no
  `NoiseTexture2D`). All surface detail comes from the shader.

Surfaces, in the road's recipe:

- **Patterns are laid out in metres**: world XZ for the ground (as the
  asphalt does), metre UVs for walls (as `facade_body.gd` emits them), or a
  `surface_size_m` uniform when the mesh UV is 0..1 per face (as the
  sidewalk does). The same detail must be the same size on every box.
- **Layered grime**: a dark base tone, then grit or grain, wear where things
  rub, stains and oil, cracks, edge dirt where surfaces meet, and sparse
  litter or damage, each layer from hash, value noise, fbm or the Voronoi
  `crack_field`, mixed in that order. Noise, fbm and `smoothstep` edges are
  the style; they are not a problem to remove.
- **Big shapes read first**: seams, panels, courses, windows and slabs are
  the structure; grime breaks them up and never hides them.
- **Chunky, not fine** (owner, 2026-10-01): hard repeating lines on
  buildings are low-poly scale: bricks 0.60 x 0.20 m with 3 cm mortar,
  corrugation 0.30 m, roll-up slats 0.40 m, planks 0.35 m, mullions 12 cm,
  seams and joints 3..4 cm; no hard repeating pitch under 0.20 m, no line
  under 3 cm; wall grain about 10/m, prop and plank grain about 8/m.
  Street paving: tiles 0.5 m, setts 0.25 m, granite curb blocks 1 m,
  joints 3 cm, chamfers 1.2 cm; tiles dark (albedo 0.33), setts 0.25, and
  the paving's glare fades out over 18-45 m so a far grid never glows.
  Viewmodel surfaces under 0.4 m from the camera on the 0.18-scaled arms
  rig are the one exception: grain about 60/m virtual, mottle about 6/m,
  ribs 2..3 cm, with the same albedo, roughness and metallic budget.
  The arms draw through their own 50 degree lens (`GunViewmodel.VIEWMODEL_FOV`,
  `scenes/player/viewmodel_fov.gdshaderinc`): the include must keep the signs
  of `PROJECTION_MATRIX[0][0]` and `[1][1]` (Godot Vulkan bakes a Y flip in, so
  [1][1] is negative); a positive focal term drew the arms rotated 180 degrees
  while `arms frame` (Godot-native `fov_override`) still counted them right.
  After any lens change, Read one player-view shot.
  Sidewalk dirt (where the walk is gone) is packed earth with broad tone
  drift and damp darker spots (`packed`), gravel only in noise patches
  about a fifth of the ground (coarse 0.22 m cells at 15%, fine 0.07 m at
  45%), pebble albedo factor 0.6-0.95, faded by `fwidth`.
- **Lighting model**: `diffuse_burley`, `specular_schlick_ggx`, roughness
  0.78..0.95 on base surfaces (wet oil and polished tyre lanes may drop to
  about 0.3 locally), metallic 0..0.3 (oil, cans, bolts). A shader may
  perturb `NORMAL_MAP` from the same grime values (the road does). No
  mirror sheen and no metallic above 0.3 on anything.
- **No shimmer**: a repeating pattern finer than about 0.25 m (brick
  courses, corrugation, mullions, ribs, grain) fades to its average colour
  with `fwidth` before it gets smaller than a couple of screen pixels, so
  walls never moiré at distance.
- **One noise library**: world shaders
  `#include "res://scenes/shaders/grime.gdshaderinc"` (`hash21`, `hash22`,
  `noise21`, `fbm`, `crack_field`, and the sidewalk's `crack_field_h21`)
  instead of pasting their own copies.
- **Small props** (under about 1 m, or anything built by `prop_material()`)
  may use a flat `StandardMaterial3D` colour, inside the albedo budget,
  roughness 0.7 or more, metallic 0.3 or less. `prop_material()` in
  `facade_materials.gd` enforces this (non-emissive albedo capped at 0.40
  linear luminance, hue kept): still write literals inside the budget, since
  the clamp only hides a wrong value.
- **Large props** (over about 1 m: awnings, lintels, docks, stoops, pilasters,
  set-piece bodies) wrap their `prop_material()` in
  `facade_grime_materials.gd`'s `from_prop()`, which puts the same budgeted
  colour on `facade_prop_grime.gdshader` (grime in model-space metres, so
  merged prop meshes with 0..1 UVs per face still get same-size detail).
  Furniture, bumpers, rails, hangers, diagonals and every emissive part
  stay flat.
- **Stop, bay and junction steel** that is large (walls, ceilings, roll-up
  slats, counter decks, cabinet runs, cross beams) goes on
  `scenes/corridor/industrial_surface.gdshader`: panels of `panel_size_m`
  laid out in model-space metres, seams and rivets faded with `fwidth`,
  rust, streaks, dust and oil, and a `foot_y_m` dirt band on walls. It
  assumes an unscaled, centred `BoxMesh`: size the mesh, never the node, or
  the panels stretch. Ceilings and cross beams use the garage's rib recipe
  (about 3 x 0.5 m panels, roughness 0.9, metallic 0.25); pick a panel size
  large enough that seams rarely land on a thin trim (the shop booth's steel
  uses 2.4 m). Small steel (grills, rivets, guides, rails) is flat at
  metallic 0.3, roughness 0.75.

The van (owner, 2026-09-25, task `docs/tasks/van-war-rig.md`): a scrap war
rig built from a seed, a new look every run. Doors, windows, breach points,
machines' positions and the walk space never vary; only the look does,
drawn from hand-made kits with seeded jitter, one RNG stream per part. The
interior shaders (`scenes/van/van_*.gdshader`) stay the reference for the
interior's grime; the outside gets its own exterior shader on the grime
include. Machines and junk are redneck technology (scavenged parts, welds,
tape, cables that go somewhere), still low-poly primitives inside the
budget above.

Machines read as machines (owner play notes, 2026-09-26): 20+ parts of varied
size, one desaturated accent colour each (generator safety orange, relay rack
oxide green, bench oxblood and steel, hopper ochre), and a lamp you can point
at that lights it (an `OmniLight3D` under a caged trouble lamp,
energy 0.35 to 0.9, range 1.6 to 2.4, no shadow). Cables have logic: each one
runs from a machine's `PowerPort` to another's along a trunk, with junction
boxes at joins and clamps or tape along the way; nothing hangs from nowhere,
and nothing intersects the bowed wall, a machine or the aisle. The game never
leaves the van, so the exterior is seen only from the debug `ghost` flight
and is not detailed further.

### Street art (graffiti and posters)

Generated pixel-art images on wall quads are the one bitmap exception on
the 3D street: they are things stuck to a wall, not a surface. Built in
code per run (`scripts/travel/facades/street_art/`), packed into one
per-run atlas, graffiti at 0.024 m/px and posters at 0.016 m/px, filter
`TEXTURE_FILTER_NEAREST_WITH_MIPMAPS`, alpha scissor 0.5, lit (never
unshaded), roughness 0.9. Faded: paint at most 0.40 and paper at most
0.45 linear luminance, so they sit in the wall's light like everything
else.

Off-style today (3D): nothing known. The 3D art pass (2026-09-25) brought
the facades, props, set-pieces, stops, junctions, statue and overheads onto
this file; a new break found later goes here.

## Pixel art (NPCs, raiders, bosses, items, pickups, wares, icons)

Reference: the shopkeeper, `scenes/shop/vendor.png` (23 flat colours, hard
edges, shading baked in as flat tones). Its pose and palette are the
target; its grid is not (it is upscaled about 3.2x off any exact grid).

- Drawn at native size, one image pixel = one art pixel. Never upscale a
  PNG; the size on screen comes from `pixel_size`.
- One world density: every world `Sprite3D` uses `pixel_size = 0.024`
  (one art pixel = 2.4 cm). A human is a 64 x 96 canvas (2.3 m, today's
  raider height). A bigger enemy gets a bigger canvas (the boss about
  96 x 144), never a node scale or a different `pixel_size`. Items use
  the smallest canvas that holds them (a shell about 8 px, a medkit about
  16 px).
- HUD and boon icons: 32 x 32 art pixels, shown at a whole-number scale.
- Flat colour only: a limited palette (about 16 to 32 colours per sprite),
  no anti-aliasing, no soft outlines or glows, no gradients and no
  dithered ramps. Alpha is 0 or 255, nothing between.
- Hard shadows: light from the upper left, each material gets a base tone,
  one shadow tone and at most one highlight tone, split by a hard edge.
- An outline, if any, is a hard one-art-pixel line.
- Display: `texture_filter = 0` (nearest), no mipmaps, `alpha_cut = 1`
  (discard), unshaded (the art carries its own shading), billboard for
  characters and pickups. Sprites are unshaded on purpose: in a dark world
  they are what the eye finds first.

**Creepy, not cute** (owner, 2026-10-01, second pass): the raiders are Darkest
Dungeon dark, never bright or rounded. The door raider is a humanoid gone
feral, the loper: a 64 x 80 frame (1.54 x 1.92 m, claws on the van floor) on a
832 x 560 sheet (row 0 the thirteen-frame run; row 1 a five-frame front-on jump take-off (the run's rising half, pushed further), frames J0-J3 keep a claw row on the floor row and J4 is airborne; row 2 a four-frame latch, clip `latch`: reach, impact, pull in, cling; row 3 an eight-frame front-on wall crawl, clip `climb`, diagonal pairs (left fore paw with right hind foot, then the mirror), never flipped; row 4 a six-frame bar rake, clip `rake`, a window loper's swing at the bars (ready, wind-up, strike, impact at frame 3, recoil, recover); row 5 a six-frame on-foot claw swipe, clip `swipe`, inside the van (left paw braced on the floor, legs planted, right paw rears up and strikes down across the body at the viewer, impact at frame 3); row 6 a five-frame climb in over the sill, clip `enter`, played while a window loper is ENTERING (6 fps, holds the last frame); animation is frame-swapping on one sheet,
never a node tween: a bounding charge seen from the front at 18 fps, crouch,
push, paws-rise, lift-off, tip-over, kick, fall, drop, reach, rump-down, land,
gather; the kick, fall and drop frames are airborne, the kick 4 px off the floor
and the hindquarters over the skull, a two-lobed rump with a tail-bone stub
standing above the dropped hump and both hind feet sole-on at the top corners
with the claws up, while every other frame keeps a claw row on the floor row;
the hump may rise at most 5 px since its top knob is on row 5, the head drops
up to 13 px on the kick, and the jaw and strands trail the bob),
a hyena-ape hunched so the skull hangs forward from a furred ruff below one
furred mantle (shoulders, neck and spine hump in a single polygon, bone spine
knobs poking through), in a mangy soot-black coat (sRGB 42,34,28 fur, 25,21,18
shadow, 64,53,42 highlight, bare skin patches), never balls joined by
ellipses: tapered limbs with fur sleeves and hip tufts, a furred rump, and hair
tufts on every edge that trail the bob by a frame and flare on landing; arms
longer than the legs with the claws on the floor, a torn shoulder and blood
down the belly. The head is the feral face (owner, 2026-10-03, every run frame,
`draw_feral_head`): a long angular skull, never round, under a matted hair cap,
a hard V brow over slanted black sockets with red eyes (sRGB 214,30,22, one
255,214,120 hot pixel each), a bare nasal pit, and a maw split into the cheeks
with red gums, tapered hooked fangs (two long upper canines, never even human
teeth) and a hanging pointed jaw with its fangs up. Corpse grey-green skin
(sRGB 72,78,68 base, 42,46,40 shadow, 104,110,96 highlight), so the body reads
as a shape the dark swallows. The one exception is the face, so the player
finds the head hitbox: pale rim pixels (sRGB 176,172,150, mid 134,132,114) only
on the face's edges that face the upper-left light (left temple and cheek, the
jaw's left edge), about 20 pixels; never a pale fill, never on the chin or the
right side, and no marks under the eyes (they read as blushing).
Asymmetry (the tilted head, one arm lower, uneven teeth) is what keeps a
sprite from reading as cute. The loper is also the window raider
(the first-pass crawler was retired, 2026-10-03). It is drawn by `tools/gen_enemy_sprites.py`
(19 flat colours, outlined, lit from the upper left) and shown at
`pixel_size 0.024`, `texture_filter 0`, `alpha_cut 1`; re-run the script
after changing a colour or a shape, never paint over the PNGs.

Off-style today, to redraw to this rule (not to copy from): the mechanic
and Wanjna PNGs (painted, 10,000+ colours, soft red outline), the other
world sprites' `pixel_size` (0.006 NPCs and Wanjna, 0.005 pickups), the
shopkeeper's linear filtering, the boss's 1.5x node scale, and the boon
icons (`tools/generate_boon_icons.py` draws anti-aliased 128 px SVG
strokes with round caps). The pixel-art pass is a later task.

## Checking it

- Anything visible gets `tools/smoke.py --shots`; Read the PNGs, run
  `tools/shot_stats.py` on the folder, and compare with the
  references and with this file before reporting.
- A new sprite: check it with `py -3 -c` and PIL before wiring it in
  (colour count, alpha levels only 0 and 255, size matches its canvas).
- The implementer never sees this file: copy the rules that apply into
  the spec's Rules section, with the exact numbers (albedo budget,
  roughness and metallic ranges, emission rule, `pixel_size`,
  `texture_filter`, `alpha_cut`).
