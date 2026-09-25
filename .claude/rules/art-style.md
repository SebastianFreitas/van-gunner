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
- **Screen check:** `tools/shot_stats.py` (added by the art-pass plan) gives
  each `--shots` PNG its mean luminance, its 95th percentile and its
  clipped-pixel share. The targets live in the table below once step 1 of
  the art pass calibrates them; a visible change that moves a shot past
  its target is a regression.

Calibrated in art-pass step 1 (2026-09-25) from the stop shots, which are
the "dark enough" line (`09` mean 0.0052, `12` mean 0.0123, p95 0.019).
Values are linear luminance; clip% is the share of pixels with any channel
at 250 or more. `*-outside` is the camera above the cab; `*-back` the van
interior facing the rear doors; `*-front` the player's view with the HUD.

| Shots | Mean max | p95 max | Clip% max |
|---|---|---|---|
| `*-outside` (street and stops) | 0.015 | 0.030 | 1.0 |
| `*-back` (van interior, liked as is) | 0.011 | 0.025 | 0.05 |
| `*-front` (HUD on, loose check) | 0.030 | 0.10 | 0.20 |

Baseline breaks: `06-combat-outside` (mean 0.099, p95 0.85, clip 7.4%:
the lit windows) and `03-idle-outside` (mean 0.018, clip 1.0%).

## Procedural 3D (street, facades, stops, props, van)

Geometry:

- Low-poly: primitives and `SurfaceTool` quads with hard edges. No imported
  realistic models, no subdivided or sculpted surfaces.
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

The van: the owner likes it as it is. Its shaders are a reference, not a
migration target; change the van only to fix a break of the dark budget,
and say so in the report.

Off-style today, to migrate (don't extend): `facade_surface.gdshader`'s lit
windows (emission 2.2 blows past the glow threshold into white panes) and
its fine patterns (moiré on distant walls); `industrial_surface.gdshader`
(a 26-line seam grid with none of the grime layers, on every bay wall);
the shop booth's metals (metallic 0.78 to 0.92 in
`shop_booth_materials.gd`); bay materials with metallic 0.5 to 0.72.

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

Off-style today, to redraw to this rule (not to copy from): the mechanic,
door raider, agile raider and Wanjna PNGs (painted, 10,000+ colours,
soft red outline), every world sprite's `pixel_size` (0.006 NPCs, 0.005
pickups), the shopkeeper's linear filtering, the boss's 1.5x node scale,
and the boon icons (`tools/generate_boon_icons.py` draws anti-aliased
128 px SVG strokes with round caps). The pixel-art pass is a later task.

## Checking it

- Anything visible gets `tools/smoke.py --shots`; Read the PNGs, run
  `tools/shot_stats.py` on the folder once it exists, and compare with the
  references and with this file before reporting.
- A new sprite: check it with `py -3 -c` and PIL before wiring it in
  (colour count, alpha levels only 0 and 255, size matches its canvas).
- The implementer never sees this file: copy the rules that apply into
  the spec's Rules section, with the exact numbers (albedo budget,
  roughness and metallic ranges, emission rule, `pixel_size`,
  `texture_filter`, `alpha_cut`).
