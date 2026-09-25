# Task: procedural street buildings

Owner brief (2026-09-25): "look at buildings and make them better; the roads are done (procedural
textures), but the vertical walls / the buildings could be much better. Do everything you can:
make a giant plan, special things, random rare stuff, and make sure garage entrances are never
covered."

Owner decisions taken at the start of the task:

- The four hand-placed `Structure` variants in `corridor_segment.tscn` are **replaced** by the
  procedural system; their flavour (ribs, pipes, catwalks, scaffold) comes back as bay-safe
  district dressing.
- **Glow** is enabled on the `IndustrialEnvironment` in `van.tscn`, and up to two shadowless
  `OmniLight3D` per tile side are allowed (none on a bay side).
- Street layout is **deterministic per run seed**: seeded from `GameSession.run_seed` and the tile
  index, never from `TravelController._rng` (that RNG is shared with stop and fork picks).

## Why the current walls fail

- Walls are two 0.4 x 20 x 20 box slabs per side (a 40 m canyon) with one mesh-UV shader
  (`industrial_surface.gdshader`: seam grid + hash stain). BoxMesh UVs run 0..1 per face, so the
  same material tiles at a different scale on every differently sized box.
- Dressing is four hand-placed `Structure/VariantN` groups of box primitives. `open_bay` hides
  nodes by **name prefix**; `Pillar*` (Variant3: three 18 m pillars at x = +-6.5), `ThinPipe*`
  (Variant2, x = +-7) and every cross-street piece slip past the rule and stand in front of the
  stop mouth. This is the "garage entrance covered" bug.
- Opening a bay hides the whole 20 x 40 m flank; the vestibule fills 8.6 x 8 m of it and the rest
  is black void.
- Nothing is emissive, there is no glow, lamps are unshaded orange boxes. Fog runs 20..56 m, eye
  height is 1.7 m, the van roof is 3.4 m: the ground floor and the next three tiles carry all the
  visual weight, and today they carry nothing.
- Junction (`corridor_t_junction.tscn`, `corridor_crossroads.tscn`) and side-street
  (`side_street_branch.tscn`) walls are the same flat slabs; the wall material is duplicated inline
  in five scenes.

## Geometry every spec must respect (tile-local, metres)

| Thing | Where |
|---|---|
| Tile | 20 m along Z (z -10..10); route curve at y 0; road surface y -0.2 |
| Wall plane | x = +-9, faces at +-8.8; collision boxes 0.4 x 20 x 20 at (+-9, 9.6) and (+-9, 29.59) |
| Sidewalk | x 7.25..9 (1.75 m), curb 0.14 |
| Raider lane | raiders spawn and run at abs(x) <= 7.5, y ~1.6, no wall collision |
| Van | 4.72 wide, 9.4 long, roof 3.4 m; eye 1.7 m; fov 78 |
| Stop mouth (right bay) | vestibule x 9..14.6, z -4.3..4.3, y -0.3..7.8; roll-up at x 14.6 (8.2 x 6.2); lintel to y 6.6; DockPoint x 8 on the carriageway; bay interiors run x 14.6..22.6 (garage, mechanic), ..19.8 (shop), ..34.6 with z +-6 (warehouse) |
| Left bay | mirror in x (vestibule placed at host * (yaw PI, (-9, 0, 0))) |
| Side street | branch at x = +-9, road 20 wide, 48 m deep, flank walls 48 x 20 x 0.4 at z = +-10, black `FarVoid` at x -49.5 |
| Projectiles | ray mask 7, ricochet off any collider without a damageable: every facade collider is a bounce surface |
| Fog | 20..56 m, near black; ambient 0.24; one 0.45 directional + door/rear lights on the van |
| Tiles alive | 4-5 ahead (80 m), up to 7 behind (140 m) |

## Keep-out rule (the "never covered" mechanism)

Every node the facade system places goes through one gate, `FacadeKeepOut.allows(aabb)`, and the
gate is built from the side's opening:

- `LANE` (always, both sides): AABB x -7.6..7.6, y -1..5, z -12..12. Nothing below 5 m may enter
  the raider lane or the road. Ground furniture lives on the sidewalk strip x 7.6..8.8 only.
- `OVERHEAD` (always): anything that crosses abs(x) < 7.6 must have its bottom at y >= 6.0.
- `MOUTH` (bay side only, mirrored for left): x 6.0..15.0, y -1..8.5, z -5.2..5.2, plus
  `APPROACH`: x 6.0..9.4, y -1..8.5, z -10..10 (the sidewalk is dropped on a bay side and the van
  reverse-parks through it, so a bay side gets **no ground props at all**), plus `MOUTH_SKY`: x
  6.0..9.4, y 8.5..9.5, z -6..6 (nothing hangs just above the mouth).
- Bay side facades are built as one building spanning the tile: a header quad from y 7.9 up, two
  ground flanks at abs(z) >= 4.5, nothing else below y 9 on that side; no lights, signs, awnings
  or set-pieces on a bay side.
- Side-street side: the tile builds nothing on that side; the branch builds its own facades.
- The smoke test asserts after the rear-park garage stop docks that no visible
  `VisualInstance3D` under the host tile's `Facades` subtree has an AABB intersecting `MOUTH` or
  `APPROACH`.

## Architecture

New folder `scripts/travel/facades/` (all helpers `RefCounted`, no `class_name`, no `await`, take
the owner node; the only `class_name`s are the two `Resource` types):

| File | Role | Size target |
|---|---|---|
| `facade_keep_out.gd` | keep-out boxes for a side + `allows(aabb)`, `box_aabb(pos, size, yaw)` | 90 |
| `facade_plan.gd` | subdivides a side into 1-3 buildings, picks style, height, floors, ground kind, sign word, lit ratio, rare candidate; pure data (Array of Dictionary) | 260 |
| `facade_body.gd` | SurfaceTool quads for the body (UV in metres, mouth cut, end returns), ShaderMaterial per building, bay flank collision | 220 |
| `facade_props_ground.gd` | storefront frames, awnings, roll-ups, stoops, boarded fronts, loading docks, sidewalk furniture, lamps + lights | 280 |
| `facade_props_upper.gd` | ledges, cornices, parapets, AC units, fire escapes, balconies, downspouts, roof clutter (single ArrayMesh per cluster) | 280 |
| `facade_signs.gd` | block-letter textures (reuses `shop_booth_flyers.gd` glyphs), box signs, neon, banners, billboards | 220 |
| `facade_materials.gd` | static factories with a cache: facade ShaderMaterial from a plan, prop StandardMaterials by key, sign shader | 120 |
| `facade_registry.gd` | scans `resources/facades/districts/` and `resources/facades/set_pieces/` with DirAccess (like `SideStopRegistry`) | 80 |
| `facade_district.gd` | `class_name FacadeDistrict extends Resource`: palettes, height range, style weights, ground kinds, sign words, lamp colour, lit ratio, prop chances, overhead dressing kinds | 80 |
| `facade_set_piece.gd` | `class_name FacadeSetPiece extends Resource`: `id`, `weight`, `districts`, `min_segment_index`, `whole_tile`, `needs_both_sides_clear`, virtual `apply_plan(plan, rng)` and `build(ctx)` | 60 |
| `set_pieces/*.gd` | one subclass per rare (<= 120 lines each), one `.tres` each in `resources/facades/set_pieces/` | |
| `corridor_facades.gd` | owner-side helper for `corridor_segment.gd`: per-side opening + plans + built root, `rebuild_side`, orchestrates plan -> body -> props -> signs -> rare through the keep-out gate | 200 |

Shaders in `scenes/corridor/`: `facade_surface.gdshader` (the building skin), `facade_sign.gdshader`
(emissive text/neon with flicker and dead letters), `facade_marquee.gdshader` (chasing bulbs).

Scene and script changes:

- `corridor_segment.tscn` keeps root, `RoadFloor`, `Surfaces` (4 collisions), `SideStreets`; deletes
  `LeftWall`, `RightWall` (+ nested upper walls), `Structure` and every sub_resource only they used;
  adds an empty `Facades` Node3D. Existing ids are never renumbered.
- `corridor_segment.gd` (rewrite, <= 200 lines): `configure(seed: int, district: int,
  neighborhood_seed: int, allow_rare: bool)`, `apply_side_streets(left, right)`, `open_bay(side)`,
  `set_carriageway_visible(on)`, `opening_of(side) -> int`, `facade_root(side) -> Node3D`, and
  `enum Opening { NONE, SIDE_STREET, BAY }`. `open_shop_bay` is deleted (dead fallback in
  `travel_stops.gd` goes with it).
- `travel_world.gd`: `spawn_world_segment` computes `seed = hash([GameSession.run_seed,
  tc._segment_index])`, `neighborhood_seed = hash([GameSession.run_seed, tc._segment_index -
  (NEIGHBORHOOD_MAX_LENGTH - tc._neighborhood_remaining)])` (stable for a whole neighborhood),
  the rare cooldown, and calls `configure` before `apply_side_streets`; junctions get
  `configure(seed, district)` too. `pick_segment_variant` becomes `pick_district` (same RNG call
  order: it must not change what `tc._rng` draws).
- `travel_controller.gd`: `SEGMENT_VARIANT_COUNT` 4 -> 5 (`DISTRICT_COUNT`), one new
  `var _rare_cooldown := 0`. Nothing else.
- `corridor_t_junction.gd`: deletes the wall MeshInstance3Ds from both junction scenes (collisions
  stay), builds facade spans for stem, branches, outgoing / far wall in `configure`.
- `side_street_branch.tscn`: an empty `Facades` Node3D (mirrored by `_ready` so later children
  inherit the flip); `side_street_branch.gd` gets `configure(seed, district)` building two
  48 m flanks (2-3 buildings each, no ground props, no signs) and a far-end building face instead of
  `FarVoid`.
- `van.tscn`: glow on the environment (one commit, scene dump re-blessed).
- `scripts/debug/debug_facade_commands.gd`: `facade district <n>`, `facade rare <id>`,
  `facade reseed`, `facade stats`, `facade list`.
- `tools/smoke/smoke_route.gd`: `assert_bay_mouth_clear(travel)` after the garage dock.

## Facade look

Body mesh: SurfaceTool quads, UV.x = metres along the building from its left end (as seen from
the road), UV.y = metres above the building base (y -0.4). Face at x = +-(8.8 + setback),
setback in {0, 0.15, 0.3} so rooflines and faces step. End returns (0.4 m deep) at every building
end; roof plate 1.2 m deep. Building heights per district; a tile side is 1 building (20 m), 2
(8+12, 12+8, 10+10) or 3 (6+7+7 permutations); walls next to a side-street tile always end flush at
z = +-10.

`facade_surface.gdshader` (spatial, diffuse_burley, specular_schlick_ggx) uniforms:
`style` (0 brick, 1 concrete panel, 2 plaster, 3 glass curtain, 4 corrugated, 5 stone, 6 bare
frame), `base_color`, `accent_color`, `mortar_color`, `glass_color`, `lit_color`, `seed`,
`floor_height` (3.2), `ground_height` (4.6), `window_pitch`, `window_w`, `window_h`,
`window_sill`, `windows_on`, `lit_ratio`, `boarded_ratio`, `broken_ratio`, `band_every` (a
string course every N floors), `grime`, `damage`, `soot`, `overgrowth`, `collapse_y` (0 = off;
discard above a noisy edge and draw exposed slab bands), `flicker` (0/1, TIME-driven emission),
`ground_kind` (0 blank, 1 storefront glass, 2 boarded, 3 roll-up, 4 loading dock, 5 arcade
pilasters, 6 garage header), `ground_units`, `emission_energy`.

Shader features: hash21 / value noise / 4-octave fbm / Worley cracks as in
`asphalt_surface.gdshader`; window grid from `floor_height` and `window_pitch` starting above
`ground_height`; per-window hash decides lit / dark / boarded / broken; lit windows emit
`lit_color * energy` with a vertical curtain gradient and 3 warmth variants; window frames 0.08 m;
relief height field (windows -0.15, frames +0.03, brick courses +-0.01, panel seams -0.02, string
courses +0.06) turned into `NORMAL_MAP` by two extra taps (`NORMAL_MAP_DEPTH` 0.6); grime rises
from the ground and streaks below sills; brick = 0.22 x 0.065 courses with per-brick tint;
concrete = 2.4 x 1.2 panels with stains; plaster = fbm blotches + cracks; glass = 1.5 m mullion
grid, METALLIC 0.2, ROUGHNESS 0.15, reflect-ish tint; corrugated = 0.1 m sine ridges; stone =
1.0 x 0.5 blocks with bevels; bare frame = slabs and columns, no infill.

Ground floor (y -0.4..4.6) drawn by `ground_kind` and dressed with props: storefront = dark glass
strip with a lit interior band (emissive shelves stripes) between piers, awning box (2.2 x 0.9,
angled 15 deg, protrudes 0.9 m at y 3.2..3.6), box sign above; boarded = plank stripes + a torn
poster (sign texture); roll-up = 0.15 m slats + a lintel + a caged floodlight; loading dock = raised
dock 1.2 m with bumpers and a dark door; arcade = pilasters every 4 m with a lantern; garage header
= plain concrete band above the mouth (bay side only).

## Districts (`resources/facades/districts/*.tres`, index = neighborhood variant)

| # | id | Skin | Heights | Ground | Props | Lamps / lit |
|---|---|---|---|---|---|---|
| 0 | tenement | brick reds/browns, plaster tan | 16-26, 20 % up to 34 | bodega / laundry / pawn storefronts, stoops | fire escapes 40 %, AC units, laundry balconies, cornices | sodium orange sconces, lit 0.35 |
| 1 | industrial | concrete panel, corrugated | 12-20 warehouses, chimneys | roll-ups, loading docks, blank | wall pipes, ribs, cross-street pipe bridges (bottom >= 9.5), catwalks (>= 8), stacks, tanks | cool white caged floods, lit 0.15 |
| 2 | commercial | glass curtain, concrete | 28-40 | storefront strips, marquee canopies, arcades | box signs, neon, billboards, glass crowns | white/blue neon, lit 0.5 |
| 3 | derelict | plaster, brick, grime 0.8 | 14-24, some collapsed | boarded, blown-out, scaffolded | graffiti tags, broken windows 0.4, exposed slabs, rubble | 50 % dead / flicker, lit 0.05 |
| 4 | civic | stone, plaster | 14-20 | arcades with pilasters, lanterns | cornices, string courses, arched windows, clock | warm yellow lanterns, lit 0.25 |

Each district also gives a neighborhood palette drift (hue +-0.03, value +-0.08) from
`neighborhood_seed` so consecutive tiles read as one street.

## Signage

Words drawn per district from the district resource (glyph table in `shop_booth_flyers.gd` has A-Z,
0, 5, space, !; words must use only those). Tenement: BODEGA, LAUNDRY, PAWN, LIQUOR, CHECKS CASHED,
KEYS, NOODLES, PIZZA, TATTOO, BAIL BONDS. Industrial: FREIGHT, COLD STORE, STEEL, PARTS, TIRES,
STORAGE, FOUNDRY, GARAGE, REPAIR, SCRAP. Commercial: HOTEL, DINER, BAR, CINEMA, ARCADE, RECORDS,
CAFE, DONUTS, OPEN, LIVE, VIDEO, PHARMACY, MARKET. Derelict: CLOSED, FOR SALE, KEEP OUT, NO ENTRY.
Civic: CLINIC, LIBRARY, COURT, POST, CHURCH, HALL, BANK.

Sign kinds: box sign (emissive face, 0.25 m deep, above the storefront), neon (text quad with
`facade_sign.gdshader`: dead-letter hash, flicker, halo), vertical blade sign (perpendicular, y 6..12,
protrudes 1.4 m), banner (cloth quad between two windows), poster (torn paper on boarded fronts),
billboard (rooftop, 9 x 4 m).

## Lighting and glow

- Sconce / caged flood / lantern fixture: emissive box (energy 2.5) + optional `OmniLight3D`
  (energy 1.2, range 9, attenuation 1.5, no shadows, district colour) 0.45 m off the face at
  y 4.8-5.6. Max 2 per side, 0 on a bay side, 0 on a side-street side.
- Lit windows: emission energy 1.8-2.6 (above the glow threshold).
- Environment: `glow_enabled = true`, `glow_intensity = 0.45`, `glow_bloom = 0.03`,
  `glow_hdr_threshold = 1.1`, `glow_blend_mode = 0` (additive), levels 3 and 5. One commit,
  `tools/scene_dump.py --bless`.

## Rare set-pieces (`resources/facades/set_pieces/*.tres`)

Base roll: `RARE_CHANCE = 0.07` per tile (not per side) once `_segment_index >= 6`, then
`_rare_cooldown = 3` tiles. A rare picks a side that is `Opening.NONE`; `needs_both_sides_clear`
rares need both sides `NONE`. Never on a bay side.

| id | w | districts | recipe | keep-out notes |
|---|---|---|---|---|
| burning_tenement | 3 | 0,3 | brick, `flicker` 1, orange `lit_color`, `soot` 0.9 above windows, two flame quads in upper windows, one warm OmniLight range 12 | whole tile side |
| collapsed_block | 3 | 0,1,3 | `collapse_y` 12-20, exposed slab bands, 8-14 rubble boxes on the sidewalk strip, rebar cylinders | rubble x 7.6..8.8 only |
| rooftop_billboard | 4 | 0,1,2 | building <= 28 m; 9 x 4 panel on two posts above the roof; block-text ad; two flood boxes | above roof only |
| neon_blade | 5 | 0,2 | vertical blade sign y 6..12, stacked letters, dead letters | protrudes 1.4 m, above 6 m |
| water_tower | 4 | 0,1 | roof <= 30 m: tank r 1.6 h 3 on 4 legs 3 m, cone lid | roof |
| antenna_farm | 4 | all | 6-10 masts + 2 dishes on a roof <= 32 m, red blinking top | roof |
| pedestrian_bridge | 3 | all | enclosed bridge 18 x 3 x 3 at y 9..12 with an emissive window strip; pylons on both sidewalks | `needs_both_sides_clear`; bottom 9 m |
| pipe_bridge | 3 | 1 | three r 0.6 pipes crossing at y 10-13 with valve wheels | `needs_both_sides_clear` |
| crane_site | 2 | 1,2,3 | bare-frame building, scaffold net over the lower floors, tower crane mast behind the face, jib 14 m over the street at y 42, red light | jib above 40 m |
| chapel | 2 | 0,4 | stone, arched windows, rose window (stained-glass emissive), 6 m bell tower 34 m with a clock | whole tile side |
| cinema_marquee | 3 | 2 | marquee canopy 8 x 1.2 x 2.2 at y 4.5, `facade_marquee` bulbs, block-text title | protrudes 2.2 m above 4.5 m |
| mural | 3 | 0,3 | blank plaster wall with a generated abstract mural texture (shapes, an eye, bars) | none |
| scaffolded | 3 | all | scaffold grid (r 0.04 tubes, planks, green net quad) 0.6 m off the face on the sidewalk strip | x 7.6..8.8 |
| parking_deck | 2 | 1,2 | open-deck floors: dark voids between slab bands, fluorescent strips, ramp stripe | none |
| overgrown_ruin | 2 | 3 | `overgrowth` 0.7, `collapse_y` 60 %, no roof plate | none |
| laundry_balconies | 4 | 0 | balconies every floor (slab + rail ArrayMesh), coloured laundry quads | protrude 0.9 m above 4 m |
| blown_out_shop | 3 | 0,2 | ground floor blackened, open dark interior with debris boxes, police-tape quad at y 1.2 on the sidewalk strip | tape x 7.7 |
| gas_canopy | 3 | 1,2 | 8 m building, canopy 8 x 0.5 x 3 on two posts, emissive underside, price pole with a 0/5 digit panel | canopy bottom 5 m, posts x 7.7..8.3 |
| searchlight | 2 | 2,4 | rooftop cone (additive unshaded, vertex-rotated by TIME) sweeping the sky | roof |
| power_outage | 3 | all | whole tile: `lit_ratio` 0, lamps dead, signs off | none |
| glass_crown | 3 | 2 | 40 m glass tower with an emissive crown band and a red beacon | none |
| radio_mast | 3 | 1,3 | 15 m lattice mast on the roof, guy lines, red light | roof |

## Grafted from the design panel (2026-09-25)

Four independent designs were judged; these verified points are folded into the steps below:

- Godot front faces are **clockwise** (its BoxMesh emits top-left, top-right, bottom-left). A
  cross-product guard that assumes counter-clockwise culls every facade, and headless cannot see
  it. `facade_body.add_quad` reads the sign off a `BoxMesh` at runtime (winding oracle) and every
  builder emits quads through it; never write a second quad emitter.
- `MultiMesh` readback (`get_aabb`, instance transforms) returns zeros under the headless renderer,
  so every prop family is an `ArrayMesh` per building and the smoke assertion can trust
  `MeshInstance3D.get_aabb()`.
- The block-letter glyph table in `shop_booth_flyers.gd` only has A B C D E F H I K L N O P R S T U
  W Y, `0`, `5`, `!` and space. Step 7 moves it into `scripts/stops/block_glyphs.gd`
  (`class_name BlockGlyphs`, static) and adds G J M Q V X Z, digits, `-` and `&`; the flyers
  delegate to it (drawing consumes no RNG, so flyer placement is unchanged).
- Every facade `GeometryInstance3D` gets `visibility_range_end = 64` (fog ends at 56 m), so only the
  tiles in view render.
- Facade `OmniLight3D`s use `light_cull_mask` layer 1 only (never the van interior on layer 2), no
  shadows, `visibility_range_end` 60, group `facade_lights`, world-wide cap 12 counted through the
  group at build time.
- No sign word may read like a stop: GARAGE and REPAIR are not in any word list. Roll-ups and
  dock doors on ordinary tiles are always closed.
- `facade stress` (debug command, step 12, also run by the smoke before the first fork): one
  hidden tile per district rebuilt for every set-piece forced x openings {(NONE, NONE),
  (BAY, NONE), (NONE, BAY)}, mouth audit each time, so the "never covered" guarantee is proven for
  districts and rares the smoke drive never visits.
- Optional (step 14): `tools/facade_probe.py` writing an SVG elevation per district for the owner's
  browser.

## Determinism and performance

- `seed = hash([run_seed, _segment_index])`; per side `rng.seed = hash([seed, side_index])`;
  junctions `hash([run_seed, &"junction", _segment_index])`; branch `hash([seed, &"branch",
  side_index])`. No global `randi`/`randf`. `tc._rng` call order is unchanged.
- Budget: <= 24 nodes per side (body 1, ledges/cornice <= 3, ground props <= 6, upper clusters
  <= 4 ArrayMeshes, signs <= 2, lights <= 2, fixtures <= 2, rare <= 6), so <= 50 per tile and
  ~600 alive; small props `cast_shadow` OFF; bodies ON. Materials: prop `StandardMaterial3D`
  cached by key in `facade_materials.gd`; one `ShaderMaterial` per building (<= 6 per tile).
- Lights <= 4 per tile, no shadows.

## Verification

- `py -3 tools/check.py` (every new `.gd`, `.tscn`, `.tres`, `.gdshader` loads; shader compile
  errors surface here), `py -3 tools/smoke.py` (unchanged fingerprint), `py -3 tools/scene_dump.py`
  (bless only on the glow commit).
- Smoke: `assert_bay_mouth_clear` after the garage dock (step 3 onward).
- Shader preview: a numpy port of the albedo/emission in the scratchpad renders PNGs for review
  (no Godot window is ever opened).
- Owner tuning: debug `facade` commands, exported constants on `corridor_segment.gd`, district and
  set-piece `.tres` files.

## Steps (one commit each; tick when the commit lands)

- [x] 1. This task file; fix the stale "side streets are unseeded" line in
  `.claude/rules/run-loop-and-acts.md`.
- [x] 2. `facade_surface.gdshader` + `facade_materials.gd` (style presets, cache) + scratchpad
  preview render.
- [x] 3. Core: `facade_keep_out.gd`, `facade_plan.gd` (bodies only, heights, styles),
  `facade_body.gd`, `corridor_facades.gd`; `corridor_segment.tscn` reshape and `.gd` rewrite;
  `travel_world.gd` + `travel_controller.gd` changes; `travel_stops.gd` dead fallback removed;
  smoke `assert_bay_mouth_clear`. Check + smoke. (The mouth building is three meshes, header +
  two flanks, so no body AABB can enclose the mouth; `MOUTH_TOP_Y` 7.85 sits under the header.)
- [x] 4. Districts as resources (`facade_district.gd`, 5 `.tres`, `facade_registry.gd`) and
  `facade_props_upper.gd` (ledges, cornices, AC units, fire escapes, balconies, roof clutter).
  Lesson: in a merged ArrayMesh, child parts (rails, rungs, brackets) may only be emitted when
  their parent box passed the gate, or the mesh AABB straddles the mouth.
- [x] 5. `facade_props_ground.gd` (storefronts, awnings, roll-ups, docks, stoops, sidewalk
  furniture) + `facade_mesh_kit.gd` (shared gated box/quad/commit helpers); fixtures + lights
  split into `facade_fixtures.gd`. (`visibility_range_end` is a GeometryInstance3D property:
  lights don't have it.)
- [ ] 6. Glow on the environment (`van.tscn`), scene dump re-blessed.
- [ ] 7. Signs: `shop_booth_flyers.gd` `draw_block_text` made static, `facade_signs.gd`,
  `facade_sign.gdshader`, box / neon / blade / banner / poster.
- [ ] 8. Set-piece framework (`facade_set_piece.gd`, registry scan, rare roll + cooldown) and
  batch 1: burning_tenement, collapsed_block, rooftop_billboard, neon_blade, water_tower,
  antenna_farm, power_outage.
- [ ] 9. Rares batch 2: pedestrian_bridge, pipe_bridge, crane_site, chapel, cinema_marquee
  (+ `facade_marquee.gdshader`), mural, scaffolded, laundry_balconies.
- [ ] 10. Rares batch 3: parking_deck, overgrown_ruin, blown_out_shop, gas_canopy, searchlight,
  glass_crown, radio_mast; industrial overhead dressing (pipe bridges, catwalks, ribs) as district
  props.
- [ ] 11. Junction facades (`corridor_t_junction.gd`, both junction scenes lose their wall meshes)
  and side-street facades (`side_street_branch.tscn/.gd`, far-end building).
- [ ] 12. Debug `facade` commands.
- [ ] 13. Docs: `.claude/rules/travel-and-stops.md` facade section (keep-out, seeding, budgets),
  CLAUDE.md table row + token-budget list, `py -3 tools/gen_context.py`; delete this file.
