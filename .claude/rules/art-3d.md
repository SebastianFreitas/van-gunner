---
paths:
  - "scenes/corridor/*.gdshader"
  - "scenes/van/*.gdshader"
  - "scenes/shaders/**"
  - "resources/facades/**"
  - "scripts/travel/facades/**"
  - "scripts/travel/road_floor*.gd"
  - "scripts/stops/**"
  - "scripts/van/look/**"
---

# Art style: procedural 3D (street, facades, stops, props, van)

The mood, albedo, colour and emission rules are in `art-style.md`.

Geometry:

- Low-poly: primitives and `SurfaceTool` quads with hard edges. No imported
  realistic models, no subdivided or sculpted surfaces.
  One owner exception (2026-10-01): the first-person arms are the CC0
  low-poly rigged model `assets/models/arms/arms.glb`; its rules are in
  `art-arms.md`.
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
  rig are the one exception (`art-arms.md`).
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

## Street art (graffiti and posters)

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
