FINAL: Street facades: final design (synthesis of the four designs and three judges, aligned to the owner's task plan and the existing facade shader)
# Street facades: final design (synthesis)

Base: geometry-first (two of three judges), aligned to the owner's committed plan `docs/tasks/buildings.md` and to the untracked `scenes/corridor/facade_surface.gdshader` (569 lines, already written: seven wall styles, a shader-drawn window grid with lit / dark / boarded / broken panes, six ground kinds, relief normal map, `collapse_y`, `flicker`). Windows and ground faces are shader work, so geometry-first's MultiMesh windows and `INSTANCE_CUSTOM` are dropped. Owner decisions stand: `Structure` is deleted, glow is on, at most two shadowless lights per side and none on a bay side, streets are seeded from `run_seed` and the tile index, never `tc._rng`.

## Architecture

New folder `scripts/travel/facades/`. Helpers are `RefCounted`, no `class_name`, no `await`, take the owner node; only Resources and static registries carry `class_name`.

| File | Kind | Lines | Does |
|---|---|---|---|
| `facade_district.gd` | `class_name FacadeDistrict extends Resource` | 90 | Fields in Districts. |
| `facade_set_piece.gd` | `class_name FacadeSetPiece extends Resource` | 60 | `id`, `weight`, `districts: PackedStringArray` (empty = all), `min_segment_index := 6`, `is_span`, `light_cost`, virtual `build(ctx: Dictionary, root: Node3D) -> bool`. |
| `facade_tuning.gd` | `class_name FacadeTuning extends Resource` | 40 | `set_piece_stride 4`, `set_piece_chance 0.3`, `lit_multiplier 1.0`, `prop_density 1.0`, `max_lights_per_side 2`, `max_lights_world 12`, `visibility_range_m 64.0`, `light_energy 1.2`, `light_range 9.0`; `resources/facades/facade_tuning.tres`. |
| `facade_registry.gd` | `class_name FacadeRegistry`, static | 90 | `DirAccess` scan of `resources/facades/districts/` and `set_pieces/`, file-name order; `district_count()`, `district_at(i)`, `district_by_id`, `set_pieces()`, `tuning()`. |
| `facade_keep_out.gd` | RefCounted | 120 | Boxes per (side, opening); `allows(aabb) -> bool` (strict `intersects`); `box_aabb(pos, size)`; `rejected`; `violations(records)`; preloads `StopVestibule` constants. |
| `facade_plan.gd` | RefCounted, pure | 260 | `plan_side(rng, district, side, opening)` -> plots (`u0, u1, height, storeys, style, setback, ground_kind, ground_units, palette, lit, sign_word, is_mouth`); `plan_span`. |
| `facade_mesh.gd` | RefCounted | 200 | Packed-array quad/box emitter, UV in metres, rectangular holes, winding oracle, `commit(material) -> ArrayMesh`, records every AABB. |
| `facade_body.gd` | RefCounted | 240 | Plot bodies, per-plot `ShaderMaterial`, end returns, roof plate, backdrop, mouth hole, bay returns, hood, `BayBody`. |
| `facade_trims.gd` | RefCounted | 220 | Cornices, string courses, piers, parapet cap, party and end caps, sill MultiMesh. |
| `facade_props_upper.gd` | RefCounted | 280 | AC, fire escapes, balconies, laundry, downspouts, dishes, roof clutter (MultiMesh layers). |
| `facade_props_ground.gd` | RefCounted | 280 | Storefront frames, awnings, lintels, stoops, docks, pilasters, sidewalk furniture, fixtures, lights. |
| `facade_signs.gd` | RefCounted | 220 | Box, neon, blade, banner, poster, billboard from `BlockGlyphs` textures. |
| `facade_overheads.gd` | RefCounted | 150 | District cross-street dressing under `Facades/Span`, bottom >= 9.5. |
| `facade_materials.gd` | static | 120 | Shader loaded once; `wall_material(plot, district)`; prop and sign materials cached by key; `warm_up()`. |
| `corridor_facades.gd` | RefCounted, owner = segment | 220 | Per-side seed, district, opening, records; `rebuild_side`, `clear_side`, `rebuild_span`, `records(side)`, `stats()`; plan -> body -> trims -> props -> signs -> set-piece through the gate; `free()` the old container, never `queue_free()`. |
| `facade_audit.gd` | `class_name FacadeAudit`, static | 150 | `mouth_violations(host, side)`, `lane_violations(tiles)`, `stress()`. |
| `set_pieces/sp_<id>.gd` | subclasses, <= 120 each | | `.tres` in `resources/facades/set_pieces/`. |
| `scripts/travel/travel_districts.gd` | RefCounted, holds `tc` | 130 | `tile_seed`, `neighborhood_seed`, `pick_district`, eligibility, `strip_set_pieces_near(progress)`. |
| `scripts/stops/block_glyphs.gd` | `class_name BlockGlyphs`, static | 140 | Glyph table from `shop_booth_flyers.gd` plus G J M Q V X Z, 1-9, `-`, `&`; `pattern`, `draw_text(img, text, origin, color, scale)`, `text_width_px`. |
| `scripts/debug/debug_facade_commands.gd` | RefCounted | 130 | The `facade` command family. |
| `scenes/corridor/facade_sign.gdshader` | shader | 60 | `text_tex`, `color`, `energy`, `mode` (0 static, 1 flicker, 2 dead letters, 3 chase, 4 colour cycle), `phase`. |

`corridor_segment.tscn` (text edit, ids untouched): keep root, `RoadFloor`, `Surfaces` with its four shapes, `SideStreets`; delete `LeftWall`, `RightWall`, the nested upper walls, `Structure` (66 nodes), every sub_resource only they used (`WallShape` stays) and the unreferenced shader ext_resource; add one `Facades` Node3D. The helper creates and frees `Facades/Left|Right|Span`: hiding is by container, never by name prefix.

`corridor_segment.gd` (rewrite, <= 200 lines): `enum Opening { NONE, SIDE_STREET, BAY }`; `configure(seed: int, district: int, neighborhood_seed: int, allow_rare: bool) -> void` stores, builds nothing; `apply_side_streets(left: bool, right: bool) -> void` sets openings, then builds each `NONE` side whose opening changed or was never built (`configure(0, 0, 0, false)` first if never configured); `open_bay(side: StringName) -> void` sets `BAY`, rebuilds that side, frees `Span`, syncs road openings; `set_carriageway_visible`; `opening_of(side) -> int`; `facade_root(side) -> Node3D`; `facade_records(side) -> Array[Dictionary]`. `_sync_road_openings` reads the openings, not `collision.disabled`.

`travel_world.gd` (+8 lines): `spawn_world_segment` replaces `apply_variant(pick_segment_variant())` with `configure(districts.tile_seed(), districts.pick_district(), districts.neighborhood_seed(), districts.allow_rare())`, then `apply_side_streets(...)` as today. `pick_district` keeps its two `tc._rng` draws (`randi()`, `randi_range(2, 5)`); only the modulus becomes `FacadeRegistry.district_count()`, and it stores `tc._neighborhood_start_index` when a run begins. `spawn_special_ahead` calls `strip_set_pieces_near(progress)` and the junction's `configure`. `travel_controller.gd`: delete `SEGMENT_VARIANT_COUNT`, add `var _neighborhood_start_index := 0`. `travel_stops.place_bay_stop`: `tc._active_stop.set_meta(&"host_segment", host_segment)`. A side builds once at spawn; `place_bay_stop` calls `apply_side_streets(false, false)` (rebuilds only a side that was `SIDE_STREET`) then `open_bay(side)` (one `BAY` rebuild from the stored seed) before placing the vestibule.

## Facade look and shader

Plots: a side is 1 building (20 m), 2 (8+12, 12+8, 10+10) or 3 (6+7+7 permutations), weights per district; setback in {0, 0.15, 0.3} (faces at x 8.8, 8.95, 9.1, inside the 0.4 m collision box); end returns 0.4 m deep; roof plate 1.2 m deep; parapet 0.9 m with a 0.3 m cap; party cap where a neighbour is shorter; end caps at u +-10; a 0.25 m pier at every plot boundary (face x 8.55). Plots never cross the tile edge and end flush beside a side-street tile.

Body mesh: one front quad per plot (holed on a bay side), `UV.x` = metres from the building's left end as seen from the road (both sides), `UV.y = y + 0.4` (above the wall base at y -0.4); returns use (depth, height). Normals explicit; tangents from `SurfaceTool.create_from_arrays` + `generate_tangents()` once per plot (the shader writes `NORMAL_MAP`). Winding oracle: `facade_mesh` reads `QuadMesh.new().get_mesh_arrays()` once (normal +Z), takes the sign of `((v1 - v0).cross(v2 - v0)).z` as the front-face rule and orders every triangle so `sign(((b - a).cross(c - a)).dot(n))` matches; no vertex-swap conventions, no negative scale anywhere.

One `ShaderMaterial` per plot on the existing shader, every uniform set from district and plot: `style` (0 brick, 1 concrete panel, 2 plaster, 3 glass curtain, 4 corrugated, 5 stone, 6 bare frame), the five colours, `seed`, `facade_width`, `facade_height`, `floor_height`, `ground_height` (4.6), window pitch / w / h / sill, `windows_on`, lit / boarded / broken ratios, `band_every`, `grime`, `damage`, `soot`, `overgrowth`, `collapse_y`, `flicker`, `ground_kind` (0 blank, 1 storefront, 2 boarded, 3 roll-up, 4 loading dock, 5 arcade), `ground_units`, `emission_energy` (2.2), `roughness_value`. The shader is not edited in v1; no halo term because glow is on.

Backdrop: one quad per side at x +-13.8, y -0.4..40, z -10..10, style 1, `lit_ratio` 0.03, `grime` 0.9, built only when the side's tallest plot is under 34 m.

Trims (one `ArrayMesh` per side, vertex-coloured `StandardMaterial3D`, roughness 0.9): cornice 0.45 out x 0.6 tall in three stepped quads (tenement, civic, commercial concrete), string course 0.12 x 0.15 per storey where `band_every >= 1`, sill MultiMesh 0.12 x 0.1 x `window_w` per cell (cap 66 per side), piers, parapet cap, party and end caps, a 0.6 m corner pilaster at u +-10 beside a side street. All at |x| >= 8.35.

## Districts

Six `.tres` in `resources/facades/districts/`, index = neighborhood district, runs of 2-5 tiles never repeating the previous one. Fields: `id`, the five palette colours, `style_weights`, every shader uniform above as a value or range, `height_min/max`, `tall_chance`, `tall_max`, `flicker_chance`, `ground_kind_weights`, `unit_width`, `width_set_weights`, `setback_weights`, prop chances (`fire_escape`, `ac_per_window`, `balcony`, `laundry`, `downspout`, `dish`, `roof_clutter`, `stoop`, `furniture`), `overhead_weights`, `sign_words`, `sign_kind_weights`, `lamp_color`, `lights_per_side`, `set_piece_mult`. Palette drift per neighborhood: hue +-0.03, value +-0.08 from `neighborhood_seed`.

| id | styles | heights | floor | windows pitch x w x h, sill | lit | ground kinds | props / overheads | lamp, lights |
|---|---|---|---|---|---|---|---|---|
| tenement | brick 70, plaster 30 | 16-26, 20 % to 34 | 3.2 | 2.6 x 1.3 x 1.7, 0.9 | 0.35 (1.0, 0.72, 0.42) | storefront 50, blank 30, boarded 20 | fire escapes 40 %, AC 0.3 / window, laundry 15 %, stoops, cornice | sodium (1.0, 0.62, 0.25), 2 |
| industrial | concrete 50, corrugated 50 | 12-20 | 4.5 | 4.0 x 2.0 x 2.4, 1.2 | 0.15 (0.85, 0.9, 1.0) | roll-up 50, dock 30, blank 20 | pipes, ribs, stacks, tanks; pipe bridge 40 %, catwalk 30 % | caged flood (0.8, 0.9, 1.0), 2 |
| commercial | glass 60, concrete 40 | 28-40 | 3.6 | 3.0 x 1.6 x 2.0, 0.8 (glass: fixed 1.5 m mullions) | 0.5 (0.75, 0.85, 1.0) | storefront 70, arcade 30 | box signs, neon, billboards, marquee awnings | neon (0.55, 0.75, 1.0), 2 |
| estate | concrete 90, plaster 10 | 24-36 | 2.9 | 3.0 x 2.6 x 1.2, 1.0 | 0.08 (0.6, 0.9, 0.8) | arcade 60, blank 40 | balconies 50 %, dishes, `band_every` 1 | mercury (0.55, 0.8, 0.7), 1 |
| derelict | plaster 50, brick 50; grime 0.8, damage 0.5 | 14-24 | 3.2 | 2.6 x 1.3 x 1.7, 0.9 | 0.05; boarded 0.3, broken 0.4, flicker 50 % | boarded 60, blank 40 | rubble, posters, exposed slabs; no overheads | dead / flicker, 1 |
| civic | stone 70, plaster 30 | 14-20 | 3.6 | 2.2 x 1.2 x 2.2, 0.8; `band_every` 1 | 0.25 (1.0, 0.8, 0.5) | arcade 60, storefront 40 | cornices, string courses, lanterns | warm (1.0, 0.85, 0.5), 2 |

Words (every glyph exists after the extension): tenement BODEGA, LAUNDRY, PAWN, LIQUOR, CHECKS CASHED, KEYS, NOODLES, PIZZA, TATTOO, BAIL BONDS; industrial FREIGHT, COLD STORE, STEEL, PARTS, TIRES, STORAGE, FOUNDRY, SCRAP; commercial HOTEL, DINER, BAR, CINEMA, ARCADE, RECORDS, CAFE, DONUTS, OPEN, LIVE, VIDEO, PHARMACY, MARKET, 24H; estate BLOCK C, TOWER 4, LIFT OUT, ESTATE OFFICE; derelict CLOSED, FOR SALE, KEEP OUT, NO ENTRY; civic CLINIC, LIBRARY, COURT, POST, CHURCH, HALL, BANK.

## Ground floor vocabulary

The shader draws the face by `ground_kind` (`ground_units = round(width / unit_width)`, `unit_width` 4-8 m); props dress it. Rule: no roll-up or dock door on a non-stop tile is ever open or lit inside; the dock kind's lamp strip above its closed door is the only light.

| Kind | Shader face | Props |
|---|---|---|
| storefront (1) | dark glass between 0.5 m piers, lit interior band on 60 % of units, transom | fascia box sign 0.25 deep at y 3.5..4.3; awning 2.2 x 0.9 at y 3.2..3.6, 15 deg, on 30 % of units (edge x 7.9); fixture |
| boarded (2) | planks and gaps | torn poster, unlit |
| roll-up (3) | closed 0.15 m slats to y 3.8 | lintel 0.2 x 0.3 x unit at y 3.9; caged floodlight fixture |
| loading dock (4) | raised dock, bumpers, dark door | platform 1.2 x 1.1 x (unit - 1.5) at x 7.6..8.8; two bollards r 0.1 h 0.9; industrial only |
| arcade (5) | pilasters per unit, arch | pilaster box 0.5 x 4.6 x 0.5 at x 8.3..8.8 per unit; lantern fixture at y 3.6 |
| blank (0) | plinth band 0.4 | poster 30 %; barred window box 1.2 x 0.6 x 0.1 at y 0.8 (10 %); downspout |

Stoops (tenement): step 1.2 x 0.18 x 0.9 at x 7.9..8.8. Sidewalk furniture on the strip x 7.6..8.8, `NONE` sides only, <= 3 per side, density `prop_density`: newspaper box 0.5 x 1.1 x 0.4, vending machine 0.9 x 1.8 x 0.7 (emissive face), phone booth 0.9 x 2.2 x 0.9 (lit), hydrant r 0.12 h 0.7, dumpster 1.8 x 1.3 x 1.0, bins.

## Props

Upper props are MultiMesh layers per side (`cast_shadow` OFF, `visibility_range_end` 64, `set_instance_color` with `vertex_color_use_as_albedo`): AC units 0.6 x 0.5 x 0.4 at d 0.45 under `ac_per_window` of windows; fire escapes (tenement, 40 % of brick plots) per storey a platform 2.4 x 0.12 x 0.9 at d 0.9, a 1.0 rail and a stair box; balconies (estate) slab 2.2 x 0.15 x 0.9 at d 0.9 with a 1.0 parapet; laundry lines (tenement) coloured quads 0.5 x 0.7 between two windows at y >= 9; downspouts `CylinderMesh` r 0.06 full height at party walls (d 0.1); dishes r 0.4; roof clutter (vents 0.6 x 0.8 x 0.6, tanks r 0.5 h 1.2, <= 3 per plot). Above 6 m protrusions reach 1.4 m (x 7.4); below, the keep-out boxes rule.

Overheads (`Facades/Span`, both sides `NONE`, freed by `open_bay`): industrial pipe bridge (three r 0.36 pipes at y 10..13 across x -9.2..9.2), catwalk 14 x 0.22 x 2.4 at y 9.5 with rails, truss 16.5 x 0.45 x 0.65 at y 12 and 17.5, cross beams 18 x 0.5 x 0.55 at y 14.6 (tenement 30 %). Nothing crossing |x| < 7.6 has its bottom below 9.0.

## Signage

`BlockGlyphs.draw_text` renders 5 x 7 glyphs at scale 3-6 into an `Image` (<= 128 x 32), cached by (word, fg, bg). `shop_booth_flyers.glyph_pattern` and `_draw_block_text` become one-line delegates; drawing consumes no RNG, so flyers are unchanged. Sign material: `facade_sign.gdshader`, shaded, `EMISSION = texture * color * energy * f(TIME)`, `ALBEDO` near black (unshaded `StandardMaterial3D` ignores emission). Kinds: box (0.25 deep at y 3.5..4.3), neon (mode 1 or 2; 20 % dead letters in derelict), blade (0.25 x 6 x 1.4 perpendicular at y 6.2..12.2, 1.4 m out), banner (between two windows), poster (torn, unlit), billboard (rooftop 9 x 4). At most 3 signs per side, none on `BAY` or `SIDE_STREET` sides, one word per building from the district list.

## Lighting and glow

Fixture = emissive box 0.12 x 0.42 x 1.3 (energy 2.5) 0.45 m off the face at y 4.8-5.6, plus an optional `OmniLight3D`: energy 1.2, range 9, attenuation 1.5, `shadow_enabled` false, district colour, `light_cull_mask` layer 1 only (never the interior on layer 2), `visibility_range_end` 60, group `facade_lights`. Budget: `lights_per_side` <= 2, 0 on `BAY` and `SIDE_STREET` sides, <= 4 per tile, world cap 12 counted through the group at build time (set-piece lights count). Lit windows emit 2.2 x `lit_color`, above the threshold. Environment (`van.tscn` `IndustrialEnvironment`, own commit with `scene_dump.py --bless`): `glow_enabled = true`, `glow_intensity = 0.45`, `glow_bloom = 0.03`, `glow_hdr_threshold = 1.1`, `glow_blend_mode = 0`, `glow_levels/3 = true`, `glow_levels/5 = true`. If glow is ever reverted, add shader-first's halo `halo_strength * lit * smoothstep(0.45, 0.0, edge)` to the wall shader.

## Rare set-pieces

Eligible when `(tc._segment_index + run_seed) % set_piece_stride == 0` (stride 4 = minimum gap) and `_segment_index >= 6` (IDLE intro stays calm); the set-piece RNG rolls `set_piece_chance` (0.3) x `district.set_piece_mult`, then a weighted pick among pieces allowing the district. SIDE pieces take a `NONE` side; SPAN pieces need both sides `NONE` and own nothing below y 9. Every box passes `allows`; a refused box aborts the piece (container freed, `rejected` counted). `open_bay` frees the bay side's piece and `Span`; `strip_set_pieces_near` frees both within 1.5 tiles of a junction. Light pieces skip at the world cap. No particles in v1.

| id | w | districts | recipe | keep-out |
|---|---|---|---|---|
| burning_tenement | 3 | tenement, derelict | plot `flicker` 1, `lit_ratio` 0.55, `lit_color` (1.0, 0.45, 0.12), `soot` 0.9; orange OmniLight range 12 energy 2.5 at y 8, d 1.0 | SIDE, light 1 |
| collapsed_block | 3 | tenement, industrial, derelict | `collapse_y` 12-20 on one plot; 8-14 rubble boxes 0.3-0.9 m; 4 rebar cylinders r 0.03 h 1.5 | rubble on the strip x 7.6..8.8 |
| rooftop_billboard | 4 | tenement, industrial, commercial | plot <= 28 m: 9 x 4 panel on two posts 1.5 above the roof, word texture, 30 % torn (mode 2), two flood boxes | roof |
| neon_blade | 5 | tenement, commercial | blade 0.25 x 6 x 1.4 at y 6.2..12.2, stacked letters, mode 2 | 1.4 m out (x 7.4), bottom 6.2 |
| water_tower | 4 | tenement, industrial | roof <= 30 m: tank r 1.6 h 3 on four legs r 0.15 h 3, cone lid 0.8 | roof, d >= 2 |
| antenna_farm | 4 | all | 6-10 masts 0.08 x 6-14 m, 2 dishes r 0.6, red top (mode 1), roof <= 32 m | roof |
| pedestrian_bridge | 3 | all | enclosed bridge 18.4 x 3 x 3 at y 9..12 across x -9.2..9.2, emissive window strip, no pylons | SPAN, bottom 9 |
| pipe_bridge | 3 | industrial | three pipes r 0.6 at y 10, 11.5, 13 across x +-9.2, two valve wheels r 0.5 | SPAN |
| crane_site | 2 | industrial, commercial, derelict | plot style 6, green net quad over floors 1-3 at x 8.2, mast 1.2 x 1.2 from roof to 44 m behind the face, jib 14 m over the street at y 42, red tip (mode 1) | jib >= 40 |
| chapel | 2 | tenement, civic | plot style 5, `window_h` 2.8, rose window disc r 1.5 (emissive ring texture) at y 9, bell tower 6 x 6 to 34 m with a clock disc | SIDE, whole plot |
| cinema_marquee | 3 | commercial | canopy 8 x 1.0 x 2.0 at y 6.2..7.2 (x 6.8..8.8), chasing bulbs (mode 3), title both faces, white OmniLight under it | bottom 6.2, light 1 |
| mural | 3 | tenement, derelict | plot `windows_on` 0; 8 x 12 Image (bands, circles, 2-4 giant glyphs, faded) as a quad at d 0.02 | none |
| scaffolded | 3 | all | tubes r 0.04 on a 2 m grid at x 8.2 over floors 1-4, planks 0.3 per floor, green net quad alpha 0.6 at x 8.15 | strip, `NONE` side |
| parking_deck | 2 | industrial, commercial | plot style 6, five decks: dark void quads at d +1, waist bands 0.5, fluorescent strips (static, cool), ramp stripe | none |
| overgrown_ruin | 2 | derelict | `overgrowth` 0.7, `collapse_y` at 60 % height, no roof plate | none |
| laundry_balconies | 4 | tenement | balconies every floor (slab 2.2 x 0.15 x 0.9 + rail) with coloured laundry quads | 0.9 m out above y 4 |
| blown_out_shop | 3 | tenement, commercial | one ground unit cut as a hole, black quad at x 9.3 behind it, 3 debris boxes, police-tape quad 0.05 x 0.1 x unit at y 1.2, x 7.7 | tape x 7.7 |
| gas_canopy | 3 | industrial, commercial | plot height 8; canopy 8 x 0.5 x 3 at y 6.2..6.7 (x 5.8..8.8), emissive underside; posts 0.3 x 6.2 x 0.3 at x 7.7..8.3; pumps 0.6 x 1.2 x 0.4 at x 7.9..8.5; price pole 0.15 x 5 x 0.15 with a digit panel; white OmniLight | canopy bottom 6.2, posts and pumps on the strip, light 1 |
| searchlight | 2 | commercial, civic | roof pedestal 1 x 1 x 1 and a cone (top r 0.3, bottom r 4, h 30) with an unshaded additive material alpha 0.15, rotated 20 deg/s by a 12-line script on the piece node; no real light | roof |
| power_outage | 3 | all | whole tile: `lit_ratio` 0, fixtures dark, signs energy 0, no lights | none |
| glass_crown | 3 | commercial | plot style 3 to 40 m, 2 m emissive crown band (0.6, 0.8, 1.0) at the parapet, red beacon (mode 1) | none |
| radio_mast | 3 | industrial, derelict | 15 m lattice mast (three 0.08 boxes, three rings) on the roof, two guy-line boxes, red top (mode 1) | roof |

## Bay, side-street and junction integration; keep-out mechanism

Facts (tile-local, right side; left mirrors x): tile z -10..10, road surface y -0.2, wall face x 8.8 (collision 0.4 x 20 x 20 at (9, 9.6) and (9, 29.587)), sidewalk x 7.25..9, raiders |x| <= 7.5. Vestibule: floor x 9..14.6, walls centred z +-4.3, 0.4 thick (outer faces +-4.5), y -0.3..7.7, ceiling slab 0.35 thick centred 7.8 (top 7.975), roll-up at x 14.6, DockPoint x 8; interiors x 14.6..22.6 (garage, mechanic), ..19.8 (shop), ..34.6 with z +-6 (warehouse).

Boxes pushed into `facade_keep_out` before any placer runs; `allows` is strict `AABB.intersects` and every number keeps >= 0.05 m clearance:

- `LANE` (always, both sides): x -7.6..7.6, y -1..5, z -12..12. Ground furniture lives on the strip |x| 7.6..8.8 only.
- `OVERHEAD` (always): anything crossing |x| < 7.6 has its bottom at y >= 6.0; recipes use >= 9.0 except blade, marquee and gas canopy (6.2).
- `MOUTH_VOID` (bay side, the body included): x 7.9..15.0, y -0.5..8.0, z -4.55..4.55, derived from `StopVestibule`: x from DockPoint 8.0 - 0.1 to 9 + `DOOR_X` + 0.4; y `FLOOR_Y` - 0.2 to `CEILING_Y` + 0.2; z +-(`MOUTH_WIDTH` / 2 + 0.25).
- `BAY_APPROACH` (bay side; props, trims, signs, lights, overheads, set-pieces): x 6.0..9.4, y -1..9.5, z -10..10; the owner's APPROACH, MOUTH and MOUTH_SKY merged. It covers the reverse-park sweep (radius 6, then 8 m straight to x 8), so a bay side gets no props, signs, awnings, lights or set-pieces, and trims only with bottom >= 9.5.

Bay side body: plots overlapping u -4.6..4.6 merge into one mouth building (style of the plot containing u 0, tallest height; with the width sets above, always the whole side), setback 0. Front face = three quads: flanks u -10..-4.6 and 4.6..10 for v -0.4..8.2, header u -10..10 for v 8.2..H (windows resume at y 8.7). Two returns close the slot beside the vestibule walls: quads at z +-4.6, x 9.0..14.4, y -0.4..8.05, facing the mouth, same material. A hood `BoxMesh` x 9.0..15.0, y 8.05..12.0, z +-4.9 (trim material) plugs the space above the vestibule ceiling so no crack shows void; it clears the warehouse ceiling (top 7.975) and every interior. `BayBody` `StaticBody3D` (layer 1, ricochet surface): flanks x 8.8..9.2, y -0.4..8.2, |z| 4.6..10; header x 8.8..9.2, y 8.2..19.6, z +-10. The tile's `Surfaces` shapes on that side stay disabled. The van rig is a `Node3D` on a `PathFollow3D` with static interior bodies; static bodies never collide, so `BayBody` cannot touch the park.

Side street: the tile builds nothing on a `SIDE_STREET` side (container freed, shapes disabled). `side_street_branch.gd` gains `configure(seed: int, district: int) -> void`, called by `_set_side_street` when enabling: two 48 m flanks of 2-3 buildings (16+16+16, 20+28, 48; no ground props, signs or lights) and a far-end building face 22 x 40 at x -49.5 replacing `FarVoid`. Its `_ready` mirror loop skips the child named `Facades`; the builder takes `mirror_x`, flips x positions itself, and the oracle orders the triangles.

Junctions: `junction_facades.gd` (RefCounted, ~150 lines) serves `corridor_t_junction.gd`'s new `configure(seed: int, district: int)`: stem left/right 11.18 m, branch north/south 11.17 m, outgoing left/right (crossroads), the T far wall as one 18.4 m span at z -9.2 replacing `NorthWall2`/`NorthWall3`, corner towers 0.6 x 40 x 0.6 at (+-9, +-9); spans are 1-2 plots, 40 m tall, no ground props, box signs allowed, <= 1 light per junction. Both junction scenes lose their wall `MeshInstance3D`s, `WallMesh`, `BranchWallMesh`, `WallMaterial` and the shader ext_resource; the eight colliders and the `uid://brodfloor01seg` lines stay. `spawn_special_ahead` passes `hash([run_seed, &"junction", tc._segment_index])` and `tc._neighborhood_variant`.

## Determinism

`seed = hash([GameSession.run_seed, tc._segment_index])` computed in `spawn_world_segment` before the increment; per side `hash([seed, side_index, salt])` with salts plan 0x11, trims 0x23, props 0x37, signs 0x59, set-piece 0x71; `neighborhood_seed = hash([run_seed, tc._neighborhood_start_index])`; junctions `hash([run_seed, &"junction", _segment_index])`; branch `hash([seed, &"branch", side_index])`. Rebuilds reuse the stored seed. `tc._rng` draw count and order are unchanged; no global `randi`/`randf`; `TIME` only in shaders; sign textures cached by content. A save reload restarts the street as today.

## Performance budget

Per side <= 24 nodes (bodies <= 3 + backdrop, trims 1-2, MultiMesh layers <= 6, ground props <= 6, signs <= 3, fixtures 2, lights 2, set-piece <= 6; a bay side adds hood 1 and `BayBody` 4), <= 50 per tile, ~600 alive. Every facade `GeometryInstance3D` has `visibility_range_end` 64 (fog ends at 56): ~7 tiles render, ~25 draw calls each, <= 200 plus road. Shadow casters: bodies only. Materials: the Shader once, <= 8 `ShaderMaterial` per tile, props and signs cached by key. Lights <= 4 per tile, 12 world-wide, none shadowed. Build < 3 ms per tile with packed arrays and one `commit` per mesh; `facade stats` prints microseconds.

## Verification

- `py -3 tools/check.py` after every commit.
- Smoke (`smoke_route.gd`): in `fork_pass` before the first fork, `driver._log(DebugCommands.run("facade stress"))`, fail unless it starts with `OK`; in `drive_side_stop` after the STOP wait and the 10 frames, rear-park label only, `facade check` must start with `OK`; after TRAVELLING, `facade check lane`. The fingerprint is untouched, never blessed.
- `facade check` = `FacadeAudit.mouth_violations(host, side)`: host from `travel._active_stop.get_meta(&"host_segment")`, side `tc._stop_bay_side`; every build-time record of that side and `Span` against `MOUTH_VOID` and `BAY_APPROACH`, then every visible non-MultiMesh `VisualInstance3D` under `host/Facades` with `get_aabb()` in host space (MultiMesh readback is zeros headless; instances come from records). Prints `OK mouth clear (N records, M nodes)` or `ERROR: facade covers bay mouth: <name> <aabb>`; the `ERROR:` line alone fails the run.
- `facade stress`: one hidden tile per district in the tree (`@onready` needs it; branch instances hidden), reconfigured for every set-piece forced x openings {(NONE, NONE), (BAY, NONE), (NONE, BAY)} (~400 rebuilds), both audits each; `OK stress N builds` or FAIL lines.
- `tools/facade_probe.py` -> `res://tools/facade_probe/facade_probe.gd`, outside the smoke budget: the same matrix x 8 seeds; writes `tools/facade_probe/facades.txt` (plots, styles, props, records, violations, per-triangle winding check against the oracle, build microseconds) and `facades.svg` (one elevation per district: quads by style, lit fraction, signs, set-pieces) for the owner's browser. Fails on any violation or error line; not baselined.
- Console (`H`): `facade list`, `facade district <id|off>`, `facade piece <id|off>`, `facade seed <n>`, `facade rebuild`, `facade stats`, `facade dump [left|right]` (plan text plus an ASCII elevation of the tile beside the van: `#` wall, `o` dark window, `*` lit, `=` ledge, `S` sign, `~` awning, space = mouth), `facade check [lane]`, `facade stress`, `facade lights <n>`; `list districts|pieces` in `debug_catalog.gd`.

## Ordered commit plan

Every commit passes check + smoke; stage by path (`game_balance.tres` and `export_presets.cfg` stay out).

1. BlockGlyphs: glyph table moved, missing glyphs added, flyer delegates. `scripts/stops/block_glyphs.gd`, `shop_booth_flyers.gd`.
2. Commit the shader as is; Resources, registry, materials, tuning, six district `.tres`; nothing wired. `facade_surface.gdshader`, `facade_district.gd`, `facade_set_piece.gd`, `facade_tuning.gd`, `facade_registry.gd`, `facade_materials.gd`, `resources/facades/**`.
3. Core: keep-out, plan, mesh, body, `corridor_facades`, `travel_districts`; `Facades` node; `configure` and openings on the segment with legacy walls and `Structure` hidden once a facade exists; `pick_district`; `host_segment` meta; `FacadeAudit` and the smoke mouth and lane assertions. Those seven scripts plus `travel_world.gd`, `travel_controller.gd`, `travel_stops.gd`, `corridor_segment.tscn/.gd`, `smoke_route.gd`.
4. Delete `Structure`, the wall meshes and orphan sub_resources; delete `apply_variant`, `VARIANT_COUNT`, the prefix hider, `open_shop_bay` and its fallback; `git grep` proof. `corridor_segment.tscn/.gd`, `travel_stops.gd`.
5. Trims and upper props. `facade_trims.gd`, `facade_props_upper.gd`.
6. Ground props, fixtures, light budget. `facade_props_ground.gd`.
7. Glow on the environment; `scene_dump.py --bless`. `van.tscn`, `van.baseline.txt`.
8. Signs and the sign shader. `facade_signs.gd`, `facade_sign.gdshader`.
9. Overheads and the probe tool (run it). `facade_overheads.gd`, `tools/facade_probe.py`, `tools/facade_probe/facade_probe.gd`.
10. Set-piece framework, junction stripping, `facade stress` in the smoke, batch 1: rooftop_billboard, water_tower, antenna_farm, mural, scaffolded, neon_blade. `travel_districts.gd`, `set_pieces/`, `resources/facades/set_pieces/`, `smoke_route.gd`.
11. Batch 2: collapsed_block, laundry_balconies, parking_deck, overgrown_ruin, blown_out_shop, power_outage, glass_crown, radio_mast, pedestrian_bridge, pipe_bridge. Probe.
12. Batch 3 (lights, animation): burning_tenement, cinema_marquee, gas_canopy, chapel, crane_site, searchlight. Probe.
13. Junction spans and far wall; branch flanks and far-end face. `junction_facades.gd`, `corridor_t_junction.gd/.tscn`, `corridor_crossroads.tscn`, `side_street_branch.gd/.tscn`, `travel_world.gd`.
14. Debug `facade` commands and `list districts|pieces`. `debug_facade_commands.gd`, `debug_commands.gd`, `debug_catalog.gd`.
15. Docs: facade section in `travel-and-stops.md`, CLAUDE.md table row and token-budget list, `gen_context.py`; delete the task file.

## Open decisions for the owner

1. Collision stays the flat `Surfaces` boxes plus `BayBody`: ricochets bounce up to 0.3 m in front of set-back faces; per-plot colliders are the alternative.
2. World-wide light cap 12 (per side 2 is yours), in `facade_tuning.tres`.
3. Six districts, your five plus `estate`; more are a `.tres` drop-in, and the count changes which district a `run_seed` gets.
4. The T far wall becomes one 18.4 m span with corner towers.
5. GARAGE and REPAIR left the industrial words so no sign reads like a stop.
6. Bay sides carry no set-pieces; roof-only pieces above 9.5 m could be allowed later.
7. The dock kind's lamp strip above closed dock doors (50 % of units) stays.

## Risks

- Nobody can look at the result: SVG elevations, the ASCII dump and `.tres` knobs are the review path; expect a palette pass.
- Build hitches if a helper emits per-vertex `SurfaceTool` calls; `facade stats` must show < 3 ms.
- A wrong front-face order hides walls with no headless symptom; the QuadMesh oracle and the probe's per-triangle check guard it.
- `MOUTH_VOID` margins are 0.05 m; a vestibule change must re-run the probe (constants are read, thicknesses are not).
- Text surgery on four editor-saved scenes; the check catches dangling ids.
- Scripts pitched at 220-280 lines can creep; specs fix each file's function list.
- Glow blooms the van's own lights too; the owner's call, already taken.

