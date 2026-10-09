---
paths:
  - "scenes/**/*.tscn"
  - "scenes/**/*.gdshader"
  - "scenes/**/*.gdshaderinc"
  - "scenes/van/van.tscn"
  - "scenes/corridor/**"
  - "scenes/shop/**"
  - "scenes/mechanic/**"
  - "scenes/items/**"
  - "scenes/enemies/**"
  - "resources/facades/**"
  - "resources/items/**"
  - "scripts/travel/facades/**"
  - "scripts/stops/**"
  - "scripts/van/look/**"
  - "scripts/player/arms/**"
  - "tools/gen_enemy_sprites.py"
  - "tools/generate_boon_icons.py"
  - "tools/shot_stats.py"
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

The rest of the art direction is split by topic, each file loaded only
for the paths it covers; a spec for a visible change names this file and
the topic file for its area under Read first:

- `art-shots.md`: the `--shots` brightness targets and how to read them.
- `art-3d.md`: procedural 3D (geometry, surfaces in the road's recipe,
  props, stop steel, the van's war-rig look, street art).
- `art-arms.md`: the first-person arms' mesh and skin (the one imported
  model); `art-arms-pose.md`: their motion, grip, dressing and inspect.
- `art-pixel.md`: pixel-art sprites, items and icons; `art-loper.md`: the
  loper (door and window raider) sheet.

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
- **Van interior lamp map:** two caged work lamps (centre floor) plus two
  `VanJunkLamp` cans (rear doors and floor, cab end and side doors); about 5 lights, no fills, no shadows. The
  interior is readable but never by ambient: every light has a fixture. Budget
  and per-lamp knobs are in `art-shots.md`.
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
  A visible change that moves a shot past its target (the table and how
  to read it are in `art-shots.md`) is a regression.

## Checking it

- Anything visible gets `tools/smoke.py --shots` from the implementer:
  `tools/shot_stats.py` on the folder, the PNGs read only for what no
  number measures, compared with the references and this file before
  reporting. The main session never Reads them.
- A new sprite: check it with `py -3 -c` and PIL before wiring it in
  (colour count, alpha levels only 0 and 255, size matches its canvas).
- A spec for anything visible names this file and the area's topic file
  under Read first; the implementer reads them and applies their numbers (albedo budget, roughness
  and metallic ranges, emission rule, `pixel_size`, `texture_filter`,
  `alpha_cut`).
