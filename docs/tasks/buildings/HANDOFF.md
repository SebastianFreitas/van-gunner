# Buildings task: full handoff

Written 2026-09-25 at the end of the first session. Everything a new session needs is in this
folder plus `docs/tasks/buildings.md` (the plan and its ticked checklist). Start a new session
with:

> Continue the buildings task: read docs/tasks/buildings/HANDOFF.md first, then
> docs/tasks/buildings.md, and carry on from the "What is next" section.

The end-of-session note at the very bottom says what state the working tree was left in.

---

## 1. The brief and the decisions already taken

Owner brief (verbatim): "look at buildings, and make them better; if you noticed the roads are
kinda done, we have procedural textures on them, but the vertical walls / the buildings could be
much better and many things, plz do everything you can. make a giant plan, make special things,
random rare stuff. make sure that garages entrances are never covered".

Owner decisions taken in the first session (do not re-ask):

1. The four hand-placed `Structure/VariantN` groups in `corridor_segment.tscn` are **gone**,
   replaced by the procedural system. Their flavour (ribs, pipe bridges, catwalks, scaffold)
   comes back as bay-safe "industrial overheads" (spec 10b, not done yet).
2. **Glow is enabled** on the `IndustrialEnvironment` in `scenes/van/van.tscn` (committed,
   scene dump re-blessed), and up to two shadowless `OmniLight3D` per tile side are allowed
   (world cap 12, none on a bay or side-street side).
3. Street layout is **deterministic per run seed**: `hash([GameSession.run_seed, tile_index])`;
   the facade code never draws from `TravelController._rng` (that RNG also drives stop picks,
   bay side and auto route choice, so any extra draw shifts what the player gets).
4. Owner-level questions that came up and were NOT asked (defaults chosen, flag them if it
   matters): five districts (not six), rares never on a bay side, GARAGE/REPAIR banned from sign
   words, the stop tile's ordinary roll-ups/docks always closed and unlit.

Why the old walls failed (for context; all of this is fixed now): two 0.4x20x20 box slabs per side
with one mesh-UV shader; four box-primitive dressing variants; `open_bay` hid nodes by name prefix
so `Pillar*`, `ThinPipe*` and cross pipes stood in front of the stop mouth; opening a bay left a
20x40 m black void around the 8.6x8 m vestibule; nothing emissive; no glow; junction and branch
walls flat; the wall material duplicated inline in five scenes.

---

## 2. Commits on `main` from this task (oldest first)

| Hash | Step | What |
|---|---|---|
| `26c17fd` | 1 | Task plan `docs/tasks/buildings.md`; fixed the stale "side streets are unseeded" line in `.claude/rules/run-loop-and-acts.md` |
| `19a5872` | 2 | `scenes/corridor/facade_surface.gdshader` + `scripts/travel/facades/facade_materials.gd` |
| `93da90c` | 3 | Core: keep-out, plan, body, `corridor_facades.gd`; `corridor_segment.tscn` reshaped (11 nodes) and `.gd` rewritten; `travel_world.gd`/`travel_controller.gd`/`travel_stops.gd` wiring; smoke `bay mouth clear` assertion |
| `0236d8f` | 7a | `scripts/stops/block_glyphs.gd` (`BlockGlyphs`, full font); flyers delegate |
| `2ee861a` | 4 | `FacadeDistrict` resource + 5 `.tres` + `facade_registry.gd`; `facade_props_upper.gd` |
| `4ba75ff` | 5 | `facade_props_ground.gd` + `facade_mesh_kit.gd`; fixtures + lights |
| `d821381` | 5b | Fixtures split into `facade_fixtures.gd` (`force_dead` param) |
| `41e06d0` | 6 | Glow keys on `van.tscn`'s environment; `tools/scene_dump/van.baseline.txt` re-blessed |
| `830f073` | — | First handoff section + specs copied into `docs/tasks/buildings/` |
| `b8707a6` | 7b | `facade_signs.gd`, `scenes/corridor/facade_sign.gdshader`, label textures in `facade_materials.gd` |
| `9755c5e` | 11 | `facade_spans.gd`; junction scenes and the side-street branch lose their slabs and get spans; `plan_length` in `facade_plan.gd` |

Step numbers refer to the checklist in `docs/tasks/buildings.md` (steps 8, 9, 10, 12, 13 remain;
see section 9 below). The owner's uncommitted `resources/balance/game_balance.tres` edit and the
untracked `export_presets.cfg` were never staged and must stay out of every commit.

---

## 3. As-built architecture (read this before touching anything)

### 3.1 Files

All in `scripts/travel/facades/` unless noted. Sizes are lines at handoff time. Helpers are
`RefCounted`, no `class_name`, no `await`, and never reference an autoload; the only
`class_name`s are the two Resource types and `BlockGlyphs`.

| File | Lines | Role |
|---|---|---|
| `corridor_facades.gd` | 139 | Per-tile owner-side helper: openings, plans, built roots; `rebuild_side` runs plan -> body -> flank collision (mouth) -> upper props -> ground props -> signs, then fixtures per side, then the `visibility_range_end = 64` post-pass |
| `facade_keep_out.gd` | 162 | The gate. Boxes per side and opening; `allows(aabb)` (props), `allows_body(aabb)`, `box_aabb(center, size, yaw)`, `conflict_name` |
| `facade_plan.gd` | 190 | Pure data: `plan_side(rng, district: FacadeDistrict, opening, neighborhood_seed)` and `plan_length(rng, district, length, neighborhood_seed)`; heights snapped to floors; per-building shader params with a neighborhood hue/value drift |
| `facade_body.gd` | 259 | SurfaceTool quads with UV in metres; end returns (u offset by width), roof plate; the mouth building as THREE meshes; `build_flank_collision`; the public `add_quad` with the runtime winding oracle |
| `facade_materials.gd` | 284 | Facade `ShaderMaterial` from a params dict; cached prop materials by key; ten skin presets; label textures (mipmapped, cached by text/scale/vertical); `sign_material` |
| `facade_mesh_kit.gd` | 87 | `add_box` (gated) / `add_box_ungated` / `commit` / `add_box_node` (rotated BoxMesh node, conservative AABB) |
| `facade_district.gd` | 51 | `class_name FacadeDistrict extends Resource`; all district knobs as exports |
| `facade_registry.gd` | 59 | DirAccess scan of `resources/facades/districts/`, sorted by `index`; `district(i)`, `district_count()`, `reset()` |
| `facade_props_upper.gd` | 344 | Trim (parapet cap, cornice, ledges, downspout), AC units, fire escape, balconies + rails, roof clutter, wall pipes; one ArrayMesh per family |
| `facade_props_ground.gd` | 318 | Storefront frames, awnings (pitched BoxMesh nodes), roll-up lintels + rails, loading dock, arcade pilasters, stoop, sidewalk furniture (8 kinds) |
| `facade_fixtures.gd` | 94 | Wall lamp fixtures per side + `OmniLight3D` (energy from the district, range 9, attenuation 1.5, no shadows, `light_cull_mask = 1`, group `facade_lights`, world cap 12); `force_dead` param |
| `facade_signs.gd` | 273 | One sign per building max: box (storefront), neon, blade (perpendicular, bottom 6.6 m above base), banner (arcade), poster (boarded) |
| `facade_spans.gd` | 49 | `build_span(parent, name, face_mid, normal, length, rng, district, neighborhood_seed)` and `build_corner_tower` for junctions and branches |
| `scenes/corridor/facade_surface.gdshader` | ~520 | The building skin (section 3.7) |
| `scenes/corridor/facade_sign.gdshader` | 53 | Sign label shader: mode 0 backlit box, 1 neon (dead letters + flicker + mip halo), 2 poster (unlit) |
| `scenes/corridor/corridor_segment.gd` | 169 | The tile node script (section 3.2) |
| `scenes/corridor/corridor_segment.tscn` | 11 nodes | Root, `RoadFloor`, `Surfaces` + 4 wall collisions, `Facades` (empty host, unique_id 1337420017), `SideStreets/Left|Right` |
| `scenes/corridor/corridor_t_junction.gd` | 131 | Shared by T and crossroads; `configure(seed, district, neighborhood_seed)` builds spans + 4 corner towers under `Facades` |
| `scenes/corridor/side_street_branch.gd` | 56 | `configure(...)` builds two 48 m flanks and a 20 m far-end face under a `Facades` node created after `_ready` (so the mirror loop never touches it) |
| `scripts/stops/block_glyphs.gd` | 171 | `class_name BlockGlyphs`: 5x7 font A-Z 0-9 and punctuation; `pattern`, `text_width_px`, `draw_text`, `make_label`, `make_vertical_label` |
| `resources/facades/districts/*.tres` | 5 files | tenement (0), industrial (1), commercial (2), derelict (3), civic (4) |
| `resources/facades/set_pieces/` | not yet | created by spec 08a |

Travel wiring (`scripts/travel/`): `travel_world.gd` computes the seeds and calls
`segment.configure(seed, district, neighborhood_seed, allow_rare)` BEFORE `apply_side_streets`
in `spawn_world_segment`; `pick_district()` (renamed from `pick_segment_variant`) keeps the exact
two `tc._rng` draws per neighborhood and stamps `tc._neighborhood_start`; `spawn_special_ahead`
calls `junction.configure(hash([run_seed, &"junction", _segment_index]), tc._neighborhood_variant,
hash([run_seed, _neighborhood_start]))`. `travel_controller.gd` (over the cap on purpose) changed
only: `SEGMENT_VARIANT_COUNT` -> `DISTRICT_COUNT := 5`, plus `var _neighborhood_start := 0` and
`var _rare_cooldown := 0`. `travel_stops.gd` lost the dead `open_shop_bay` fallback.
`travel_world.gd` also holds `RARE_START_SEGMENT := 6` and `RARE_COOLDOWN := 3`; `configure`'s
bool return ("took a rare") drives the cooldown — today it always returns false (spec 08a makes
it real).

### 3.2 The tile API (`corridor_segment.gd`)

```
enum Opening { NONE, SIDE_STREET, BAY }
const DISTRICT_COUNT := 5
func configure(seed: int, district: int, neighborhood_seed: int, allow_rare: bool) -> bool
func apply_side_streets(left: bool, right: bool) -> void
func open_bay(side: StringName) -> void          # _set_side_street(side, true, Opening.BAY), hides the branch
func set_carriageway_visible(road_on: bool)      # unchanged (elevator stops)
func opening_of(side: StringName) -> int         # 0 NONE, 1 SIDE_STREET, 2 BAY
func facade_root(side: StringName) -> Node3D     # Facades/Left or Facades/Right
func district() -> int
func describe_facades() -> String
```
`_set_side_street(side, enabled, opening := -1)` disables that side's two wall collisions, shows
the branch, sets the facade opening (rebuild only when it changed), and configures the branch's
facades when enabling a side street (not for a bay). Call order on a stop tile (from
`travel_stops.place_bay_stop`): `apply_side_streets(false, false)` then `open_bay(side)`.
Openings are rebuilt by renaming the old side root to `LeftOld`/`RightOld` and `queue_free()`,
then building a fresh `Left`/`Right`.

### 3.3 Node tree under a tile after build

```
CorridorSegment
  RoadFloor, Surfaces/{Left,Right}Wall{,Upper}Collision (disabled on an open side)
  Facades
    Left / Right
      Body0 [Body1 Body2]                      one MeshInstance3D per building (non-bay side)
      Body0Header, Body0FlankNeg, Body0FlankPos, BayFlankSurfaces (StaticBody3D)   bay side
      Trim, AcUnits, FireEscape, Balconies, BalconyRails, RoofBulkhead, RoofVents, WallPipes
      Storefront, Awning%d, AwningValance%d, RollupFrames, DockPlatform, DockBumpers, Pilasters,
      Stoop, StoopRail, furniture nodes (Hydrant, NewsBox, Dumpster, Booth, Vending, Bollards,
      Crates, Bench + *Glow)
      SignBox | SignNeon | SignBlade | SignBanner | SignPoster   (<= 1 per building)
      Fixture%d, Light%d (OmniLight3D)
    (spec 08a adds Span for street-crossing rares; spec 10b adds Overhead)
  SideStreets/Left|Right (side_street_branch instances; Facades child appears on configure)
  SideStreetCorners (road corner returns, unchanged from before)
```
Every `GeometryInstance3D` under a side root gets `visibility_range_end = 64.0` (fog ends at 56).
Node names starting with `Body` are audited against the body boxes; everything else against the
prop boxes (section 3.4).

### 3.4 The keep-out volumes (tile-local metres; `facade_keep_out.gd`)

Right side shown; the left mirrors x. `AABB.intersects` excludes touching edges.

| Box | x | y | z | Applies to |
|---|---|---|---|---|
| LANE (always) | -7.6..7.6 | -1..6.0 | -12..12 | bodies and props (nothing below 6 m over the road or the raider lane; raiders run at abs(x) <= 7.5, sidewalk is x 7.25..9) |
| MOUTH (bay side) | 6.0..15.0 | -1..7.85 | -4.45..4.45 | bodies and props (the vestibule mouth; header starts at 7.9; vestibule walls are at z +-4.1..4.5) |
| APPROACH (bay side) | 6.0..9.4 | -1..8.5 | -10..10 | props only (the reverse-park sweep: no furniture, fixtures, lights, signs or awnings anywhere on a bay side) |
| MOUTH_SKY (bay side) | 6.0..9.4 | 8.5..9.5 | -6..6 | props only |
| FLANK (side-street side) | 7.6..60 | -1..60 | -12..12 | everything (that side builds nothing; the branch does) |

Constants: `LANE_HALF_X 7.6`, `LANE_TOP_Y 6.0`, `MOUTH_NEAR_X 6.0`, `MOUTH_FAR_X 15.0`,
`MOUTH_HALF_Z 4.45`, `MOUTH_TOP_Y 7.85`, `APPROACH_TOP_Y 8.5`, `APPROACH_FAR_X 9.4`,
`MOUTH_SKY_TOP_Y 9.5`, `MOUTH_SKY_HALF_Z 6.0`, `FLANK_FAR_X 60`. Vestibule facts they derive from
(`scripts/stops/stop_vestibule.gd`): `DOOR_X 5.6`, `DOCK_X -1` (corridor x 8), `MOUTH_WIDTH 8.6`,
`MOUTH_HEIGHT 8`, floor -0.3, ceiling slab 0.35 thick centred 7.8, roll-up 8.2 x 6.2 at corridor
x 14.6; bays run x 14.6..22.6 (garage, mechanic), ..19.8 (shop), ..34.6 with z +-6 (warehouse).

The bay-side building: one plan spanning the tile with `mouth = true`, setback 0, built as
`Body%dHeader` (header quad from y 7.9 up, soffit under it out to x 9.6, roof plate, end returns
above 7.9), `Body%dFlankNeg` (z -10..-4.5 up to 7.9, reveal quad at z -4.5, end return), and
`Body%dFlankPos` (mirror), plus `BayFlankSurfaces` (`StaticBody3D`, three `BoxShape3D`: flanks
0.4x8.4x5.5 at (+-9, 3.8, +-7.25), header 0.4x32x20 at (+-9, 24, 0)) so bullets still bounce
beside the mouth while the tile's own wall collision on that side is disabled.

### 3.5 Geometry conventions used by every builder

- Tile: 20 m along Z (z -10..10); road surface y -0.2; route curve y 0; walls at x +-9;
  `BASE_Y = -0.4` is the bottom of every facade; `FACE_X = 8.8`; a building's face is at
  `x = side_sign * (8.8 - setback)`, setback in {0, 0.15, 0.3}; `FLOOR_HEIGHT 3.2`,
  `GROUND_HEIGHT 4.6` (ground-floor zone top), `PARAPET 0.6`, `MIN_FLOORS 2`, `MAX_HEIGHT 40`.
- Heights snap to `GROUND_HEIGHT + floors * FLOOR_HEIGHT + PARAPET`; plan keys: `z0`, `z1`,
  `width`, `height`, `floors`, `setback`, `preset`, `ground_kind`, `ground_units`, `mouth`,
  `params` (shader uniforms), `tags`, `rare` (`&""`), `district_id`.
- u (metres along the building, from its left end as seen from the road) maps to z: right side
  `z = z0 + u`, left side `z = z1 - u`. "Out" toward the road is `-side_sign` on X. A box
  protruding `d` from the face is centred at `x_face - side_sign * (FACE_GAP + d/2)`.
- Window columns: `u = (col + 0.5) * window_pitch` for `col` in `0 .. floor((width - 0.3) /
  pitch) - 1`; floor line k at `BASE_Y + GROUND_HEIGHT + k * FLOOR_HEIGHT`; pane bottom at
  floor line + `window_sill`. Read `window_pitch/window_w/window_h/window_sill/windows_on` from
  `plan.params` with the shader defaults 2.6/1.3/1.7/0.9/1.0 as fallbacks.
- Sidewalk furniture lives at abs(x) 7.7..8.8 (centre `STRIP_X 8.25`), y from the sidewalk top
  (-0.06); nothing below 6 m may cross abs(x) < 7.6.
- Splits of a 20 m side: `[20]`, `[8,12]`, `[12,8]`, `[10,10]`, `[6,7,7]`, `[7,6,7]`, `[7,7,6]`
  with weights `0.34 0.15 0.15 0.16 0.07 0.07 0.06`; `plan_length` scales a row by `length/20`.

### 3.6 Determinism

- Tile: `seed = hash([GameSession.run_seed, tc._segment_index])` (before the increment);
  per side `rng.seed = hash([seed, side_idx])` (0 left, 1 right).
- Neighborhood: `neighborhood_seed = hash([run_seed, tc._neighborhood_start])` gives every tile
  in a neighborhood the same hue (+-0.03) and value (0.92..1.08) drift on base/accent/mortar.
- Junction: `hash([run_seed, &"junction", _segment_index])`, then `hash([that, &"junction"])`
  inside `configure`. Branch: `hash([tile seed, &"branch", side_idx])` then `hash([that,
  &"branch"])`.
- Spec 08a adds a tile rare RNG `hash([seed, &"rare"])` and a span RNG `hash([seed, &"span"])`.
- Family order inside a builder is fixed and every family rolls its chance first, so adding a
  family at the END of the order keeps earlier output stable for a given seed.
- Nothing draws `randi()/randf()` globally; `TIME` is used only in shaders.

### 3.7 The skin shader (`facade_surface.gdshader`)

UV is facade space in METRES (u along the wall, v above the base); never scale by a tile count.
Uniforms: `style` (0 brick, 1 concrete panel, 2 plaster, 3 glass curtain, 4 corrugated, 5 stone,
6 bare frame), `base_color`, `accent_color`, `mortar_color`, `glass_color`, `lit_color`, `seed`,
`facade_width`, `facade_height`, `floor_height`, `ground_height`, `window_pitch`, `window_w`,
`window_h`, `window_sill`, `windows_on`, `lit_ratio`, `boarded_ratio`, `broken_ratio`,
`band_every`, `grime`, `damage`, `soot`, `overgrowth`, `collapse_y`, `flicker`, `ground_kind`
(0 blank, 1 storefront, 2 boarded, 3 roll-up, 4 loading dock, 5 arcade), `ground_units`,
`emission_energy`, `roughness_value`. Structure: `facade_relief` (grid-only height, tapped three
times for `NORMAL_MAP`, depth 0.6) and `facade_shade` (skin by style, window states by per-window
hash: lit / boarded / broken / dark, ground zone by kind, overlays: string course, grime, sill
streaks, soot, overgrowth, damage), collapse discard above a noisy edge with rubble/slab bands.
Lit windows emit `lit_color * emission_energy (2.2) * 0.55..1.0` (glass towers x0.7), above the
glow threshold 1.1. Presets (`facade_materials.preset`): brick_red, brick_brown, concrete_grey,
plaster_tan, plaster_green, glass_blue, corrugated_green, corrugated_rust, stone_grey, bare_frame.
A numpy port for previewing is `facade_preview.py.txt` here (copy to the scratchpad as `.py`,
`py -3` it, Read the PNG). The bitangent sign of the normal map (windows recessed vs raised) was
never seen in-game: if windows look raised, flip the y component in `fragment()`'s `n`.

### 3.8 Districts (`resources/facades/districts/*.tres`)

Fields (all exported on `FacadeDistrict`): `id`, `index`, `presets` (repetition = weight),
`height_min/max`, `tall_chance/min/max`, `ground_kinds`, `lit_ratio`, `grime`, `boarded_ratio`,
`broken_ratio`, `damage`, `band_every` (list), `cornice_chance`, `ledge_chance`, `ac_unit_chance`,
`fire_escape_chance`, `balcony_chance`, `downspout_chance`, `roof_clutter_chance`,
`wall_pipe_chance`, `lamp_color`, `lamp_energy`, `lamps_per_side`, `dead_lamp_chance`,
`sign_words`, `sign_chance`, `awning_chance`, `furniture_chance`. Spec 10b adds
`overhead_chance`. Neighborhoods are runs of 2-5 tiles of one district (unchanged logic in
`pick_district`); the district index comes from `tc._neighborhood_variant`.

| index | id | look |
|---|---|---|
| 0 | tenement | brick/plaster 16-26 m, storefronts, stoops, fire escapes, AC units, sodium sconces, lit 0.35 |
| 1 | industrial | concrete/corrugated 12-20 m, roll-ups and docks, wall pipes, cool floods, lit 0.15, words FREIGHT/COLD STORE/STEEL/... |
| 2 | commercial | glass/concrete 28-40 m, storefronts + arcades, most signs, lit 0.5 |
| 3 | derelict | plaster/brick 14-24 m, boarded/broken, grime 0.85, half the lamps dead, lit 0.05 |
| 4 | civic | stone/plaster 14-20 m, arcades with pilasters, string courses, warm lanterns, lit 0.25 |

### 3.9 Signs, fixtures, junctions, branches

- Signs: `facade_signs.build(host, plan, side_sign, keep_out, rng, district)`; rolls
  `sign_chance` first; kind by ground kind (storefront: box 70 % / neon 30 %; boarded: poster;
  arcade: banner; else blade when width >= 8; commercial boxes upgrade to blades 35 %); label
  textures are white-on-black `BlockGlyphs` images with mipmaps, cached by (text, scale,
  vertical); the label quad's TOP edge has v = 0 (Image row 0 is the top). `_build_blade` is
  private today; spec 08b makes a public `build_blade` out of it.
- Fixtures: `facade_fixtures.build_fixtures(host, plans, side_sign, keep_out, rng, district,
  force_dead := false)`; `lamps_per_side` positions spread along the tile at y 5.2, head 0.45 m
  off the face with an emissive material (`lamp_<district id>`, energy 2.5) or `lamp_dead`;
  `OmniLight3D` only under the world cap (group `facade_lights`, counted live), never on a bay
  side (the approach box rejects the fixture).
- Junctions (`corridor_t_junction.gd configure`): spans StemLeft (-9, 0, 14.47) +X 11.184,
  StemRight (9, 0, 14.52) -X, BranchLeftNorth (-14.5, 0, -9) +Z 11.172, BranchLeftSouth
  (-14.5, 0, 9) -Z, BranchRightNorth/South mirrored, OutgoingLeft/Right (crossroads only,
  (+-9, 0, -14.47/-14.52)), FarWall (0, 0, -9) +Z 18.0 (T only), corner towers 0.8x40x0.8 at
  (+-9, 0, +-9). Both scenes keep their `Surfaces` collisions, roads and `Beam*` nodes; all wall
  meshes, lamps, `NorthWall2/3` and their resources are gone (T: 17 nodes, crossroads: 21,
  `load_steps` 7).
- Branch (`side_street_branch.gd configure`): FlankNorth (m*-24, 0, -10) +Z 48, FlankSouth
  (m*-24, 0, 10) -Z 48, FarEnd (m*-48, 0, 0) normal (m, 0, 0) 20, where `m = -1` when
  `mirror_x`; the `Facades` node is created in `configure` (after `_ready`'s mirror loop). The
  scene is 2 nodes now (script root + RoadFloor); `FlankWall*`, `FarVoid`, `Lamp*` are gone.
- `facade_spans.build_span`: host transform `Basis(into, UP, into.cross(UP))` with origin
  `face_mid - into * 8.8`, so the tile body builder's right-side frame lands its face on the
  plane through `face_mid`; verified by `span_sanity.gd.txt` (T: 7 spans + 4 towers = 17 meshes;
  crossroads 20; mirrored branch far end at +x).

---

## 4. Verification (what "done" means for a step)

1. `py -3 tools/check.py` from the repo root: imports assets (writes missing `.gd.uid` /
   `.gdshader.uid` files — always commit them with the script), then loads every `.gd`, `.tscn`,
   `.tres`, `.gdshader`. Any line containing `SCRIPT ERROR`, `Parse Error` or `ERROR:` fails,
   including shader compile errors. Rerun once after moving files (stale `uid_cache`).
2. `py -3 tools/smoke.py`: headless run with an elevator shop stop and a rear-park garage stop.
   It must print `SMOKE: bay mouth clear: 1 bay side(s), N facade nodes checked` (the assertion in
   `tools/smoke/smoke_route.gd::_assert_bay_mouth_clear`: every visible `VisualInstance3D` under
   the docked tile's bay-side `Facades` root, AABB transformed to tile space, `Body*` nodes
   against `body_boxes_for(side, 2)`, others against `prop_boxes_for(side, 2)`), and the
   fingerprint must not change (facades never feed it; never `--bless` for facade work).
3. `py -3 tools/scene_dump.py` only when `scenes/van/van.tscn` changes (bless only then; done
   once for glow).
4. A one-off sanity script OUTSIDE the repo (scratchpad), run as
   `"C:\Users\Traff\Desktop\Godot_v4.7-stable_win64_console.exe" --headless --path . --script
   <file>` (the `GODOT` env var points at the non-console exe; `tools/check.py` swaps in the
   `_console` sibling; Bash may not see the variable — read it with
   `powershell.exe -NoProfile -Command '[Environment]::GetEnvironmentVariable("GODOT","User")'`).
   Pattern: `extends SceneTree`, `_initialize` -> `call_deferred(&"_run")`, `await process_frame`
   after every `add_child` before touching `@onready` fields or `is_inside_tree()`, free nodes
   before `quit()` (otherwise RID-leak `ERROR:` lines at exit). See `span_sanity.gd.txt`.
5. Only one headless Godot run at a time on this machine (parallel runs collide). Two
   implementers may run concurrently only if one is told "edit only, no Godot, leave every file
   syntactically valid at every save"; then the other's run (or the main session) verifies both.

---

## 5. Process (how every code change was made)

- The main session never edits source; it writes a spec (`docs/tasks/buildings/spec_*.md`) and
  launches the `implementer` subagent with: the spec path, a "notes on the committed tree"
  paragraph (what changed since the spec was written: renamed helpers, new params, line counts),
  the timing rule about Godot, and "report check tail, smoke tail, sanity output, wc -l, git
  status; do not commit". The implementer never sees CLAUDE.md, so each spec restates the rules it
  needs (GDScript style, helper rules, .tscn text-editing rules, the gate, no window).
- The main session reviews the report and the diff, runs anything the implementer could not,
  commits by path with a one-sentence message, ticks the step in `docs/tasks/buildings.md`.
- Implementers run on Sonnet in fresh contexts; the account's session usage limit can cut one
  off mid-file (it happened on step 4 at "creating the big file"): relaunch with "a previous
  agent was cut off; its partial UNVERIFIED work is on disk (list files); audit against the spec,
  complete, verify".
- Implementers are told to run the check/smoke only once at the end (never mid-way), to write
  each file completely, and to stop and report when the spec contradicts the code (this caught
  the one-mesh mouth building).
- Every spec must say which files are off-limits (shaders, `travel_controller.gd`, baselines,
  `game_balance.tres`, `export_presets.cfg`) and that new `.gd.uid` files are deliverables.

---

## 6. Lessons that cost a retry (already encoded in the specs; keep them)

1. **Godot front faces are clockwise** as seen from the front (its own BoxMesh emits top-left,
   top-right, bottom-left). A cross-product guard that assumes counter-clockwise culls every
   facade and headless cannot see it. `facade_body.add_quad` reads the sign of
   `cross(b-a, c-a).dot(normal)` off a `BoxMesh` once (`front_sign()`) and reverses a quad when
   its sign disagrees. Every builder emits quads through `add_quad`; never write another emitter.
2. **The smoke audits merged-mesh AABBs.** The mouth building had to become three meshes
   (header + two flanks); and inside any family mesh, child parts (rails, rungs, brackets,
   valance strips) may only be emitted when their parent box passed the gate, or the merged AABB
   straddles the mouth (found on `WallPipes` brackets in step 4).
3. `MOUTH_TOP_Y` must sit under the header (7.85 < 7.9); the vestibule ceiling covers the
   opening above 7.8. `APPROACH_TOP_Y` 8.5 is for props.
4. `visibility_range_end` is a `GeometryInstance3D` property; setting it on a light is a script
   error (found in step 5).
5. `MultiMesh` readback (`get_aabb`, instance transforms) returns zeros under the headless
   renderer: every prop family is an `ArrayMesh` per building so `MeshInstance3D.get_aabb()` is
   trustworthy. Do not introduce MultiMesh for anything the audit must see.
6. A SceneTree `--script` sanity must `await process_frame` after `add_child` before `@onready`
   fields resolve; free what you instantiate before `quit()`.
7. The block font only had 19 letters; `BlockGlyphs` now has A-Z, 0-9, space, `! - & . ' / :`.
   Unknown characters draw as a "?" placeholder (kept from the flyers).
8. End-return quads must offset their u by the building width or the shader draws a window
   sliver on them.
9. `facade_props_upper.gd` (344) and `facade_props_ground.gd` (318) are near the cap: new
   families go into new helpers.
10. The design panel's judges verified: BoxMesh UVs are a 3x2 atlas (so never rely on BoxMesh UVs
    for metric mapping; we use SurfaceTool quads with metric UVs), `INSTANCE_CUSTOM` is
    vertex-only in 4.7 spatial shaders (not used), Godot 4.7 headless prints `SHADER ERROR` for
    bad shaders (the check catches them).
11. `.claude/rules/run-loop-and-acts.md` used to claim side streets were unseeded; they draw from
    the seeded `tc._rng`. Fixed in commit `26c17fd`.
12. Bash heredocs in this harness write CRLF; write scripts with the Write tool (see the memory
    note `van-gunner-windows-tooling-quirks`).

---

## 7. What the owner should look at in-game (nothing was ever seen by the session)

Launch normally and drive a run. Check, in this order:

1. Walls are visible at all (winding oracle) and windows look recessed, not raised (bitangent
   sign, section 3.7).
2. Brick/concrete/plaster/glass/corrugated/stone read at 9 m; lit windows bloom softly (glow
   0.45 additive, threshold 1.1). If bloom is too strong on the van's own lights, lower
   `glow_intensity` in `van.tscn`'s `IndustrialEnvironment` and re-bless the scene dump.
3. Ground floors: storefront glass with lit interiors, awnings sloping down away from the wall,
   roll-ups closed, docks dark, arcades with pilasters, stoops, furniture only on the sidewalk.
4. Lamps: warm sconces in tenements, cool floods in industrial; pools on the sidewalk; none on a
   stop tile's bay side.
5. Signs readable at 8 m/s (box signs on fascias, neon strips, blades above 6.6 m, posters on
   boarded fronts). Words come only from the district `.tres`.
6. The stop tile: the vestibule mouth is framed by a building (header + flanks), nothing stands
   in front of it, nothing hangs above it below 9.5 m; the van reverse-parks cleanly.
7. Side streets: the alley has buildings on both flanks and a building face closing the far end
   (no black void); the right-side alley is mirrored correctly.
8. Junctions: stems, branches and the T's far wall are buildings; corner towers hide seams.
9. Performance: ~12 tiles alive, <= ~50 nodes each, <= 12 facade lights. If it stutters, halve
   `lamps_per_side`, drop `roof_clutter_chance`, or lower `MAX_WORLD_LIGHTS` in
   `facade_fixtures.gd`.

Tuning knobs without code: every `resources/facades/districts/*.tres` field; `SPLITS` /
`SPLIT_WEIGHTS` / `SETBACKS` / height constants in `facade_plan.gd`; presets in
`facade_materials.gd`; keep-out constants in `facade_keep_out.gd` (change only with the vestibule
numbers in mind); `MAX_WORLD_LIGHTS`, `LIGHT_RANGE`, `LAMP_Y` in `facade_fixtures.gd`;
`RARE_START_SEGMENT` / `RARE_COOLDOWN` in `travel_world.gd`; `RARE_CHANCE` (spec 08a).

---

## 8. Design-panel material kept for reference

`design_panel_final.md` is the synthesized design from four independent designs and three
judges; `design_panel_judges.md` has the verdicts. Ideas from it that are NOT implemented yet and
would be reasonable follow-ups after the checklist: a `tools/facade_probe.py` SVG elevation per
district for the owner's browser; a hood block behind the bay header (x 9..15, y 8..12) in case
the vestibule ever changes; `tc._active_stop.set_meta(&"host_segment", host_segment)` in
`place_bay_stop` so audits find the host directly; per-plot colliders instead of the flat
`Surfaces` boxes (ricochets currently bounce up to 0.3 m in front of set-back faces); a `warm_up`
material pass in IDLE if the first tile with a new material hitches; a sixth "estate" district.
`codebase_map_before_facades.txt` is the pre-change survey of the corridor system with file:line
anchors (partly obsolete now, still the best description of the travel/stop pipeline, raider
lane, projectile ricochet and camera facts).

---

## 9. What is next (in this order; one implementer each; one commit each)

| Step | Spec | Notes for the launcher |
|---|---|---|
| 8a set-piece framework + rooftop_billboard, water_tower, antenna_farm, power_outage | `spec_08a_set_pieces.md` | Adds `facade_set_piece.gd` (`class_name FacadeSetPiece`), `facade_set_pieces.gd` (roll, `RARE_CHANCE 0.07`), registry scan of `resources/facades/set_pieces/`, hooks in `corridor_facades.gd` (rare targets a NONE side; spans under `Facades/Span`; any opening change drops the rare), `add_cylinder_node` in the mesh kit. `configure` must return true only when a piece applied. See the end-of-session note for its status. |
| 8b burning_tenement, collapsed_block, neon_blade, pedestrian_bridge, pipe_bridge, laundry_balconies, mural, scaffolded | `spec_08b_set_pieces_batch2.md` | Needs 8a. Makes `facade_signs.build_blade` public. |
| 10a parking_deck, overgrown_ruin, glass_crown, radio_mast, blown_out_shop, gas_canopy | `spec_10a_set_pieces_batch3.md` | Needs 8a. Its file list mentions `facade_props_ground.build_fixtures`: that function now lives in `facade_fixtures.gd`. |
| 10b chapel, cinema_marquee (+ `facade_marquee.gdshader`), crane_site, searchlight (+ a 12-line pivot script), industrial overheads (`facade_overheads.gd`, `overhead_chance` on districts, `Facades/Overhead`) | `spec_10b_set_pieces_overheads.md` | Needs 8a. Overheads are dropped by any opening change, like `Span`. |
| 12 debug `facade` commands (`list`, `district`, `rare`, `reseed`, `stats`, `dump`, `check`, `stress`) + `facade_audit.gd` shared with the smoke + `facade stress 1` run by the smoke before the first fork | `spec_12_debug_stress.md` | Needs 8a (forcing a rare). `debug_commands.gd` must stay under 300 lines. |
| 13 docs | below | Last. |

Step 13, done by the main session directly (Markdown only):

- `.claude/rules/travel-and-stops.md`: add a "Facades" section: the keep-out boxes and their
  numbers, the three-mesh mouth building and flank collision, the parent-gating rule, the
  winding oracle, seeding, districts/set-pieces as `.tres` under `resources/facades/`, the light
  cap and cull mask, the smoke assertion and stress command, the two near-cap helpers, junction
  spans and branch `configure`. Check its `paths:` still cover `scripts/travel/**` and
  `scenes/corridor/**` (they do).
- `CLAUDE.md`: table row `| Street facades, districts, set-pieces | scripts/travel/facades/,
  resources/facades/, scenes/corridor/facade_*.gdshader |`; the Token budget list gains
  `facade_props_upper.gd` (344) and `facade_props_ground.gd` (318) (and any later script over
  300); add always-on invariant 14: "Nothing the facade system places may enter a stop-bay
  mouth, the reverse-park approach or the raider lane: every placement passes
  `FacadeKeepOut.allows`, bodies are gated by construction, and the smoke test asserts it after
  the garage dock."
- `py -3 tools/gen_context.py` (regenerates `docs/PROJECT_MAP.md`), commit, then delete
  `docs/tasks/buildings.md` and `docs/tasks/buildings/` in the final commit.

Adjustments to make to the specs before launching them (learned after they were written):

- Any mention of `facade_props_ground.build_fixtures` means `facade_fixtures.build_fixtures`.
- `corridor_facades.gd` is 139 lines; if a spec's hooks push it past 300, move the rare/overhead
  orchestration into a small helper it delegates to.
- `facade_signs._build_blade` exists as a private function; 8b's instruction to add a public
  `build_blade` by extracting it stands.
- In spec 12, the smoke's `facade stress 1` must stay well under the 300 s smoke timeout; the
  spec already allows reducing seeds.

---

## 10. Open questions and risks

- Nobody has seen the result: expect a palette/scale pass by the owner. The numpy preview covers
  the shader only; geometry composition (heights, splits, prop density) is judged by reading.
- The normal-map bitangent sign and the exact glow strength are the two most likely visual
  surprises; both are one-line fixes.
- Performance was never measured; the budget is by construction (<= ~50 nodes per tile, one
  ShaderMaterial per building, <= 12 lights, visibility ranges at 64 m).
- The bay-side facade rebuild happens when the stop attaches (1-2 tiles ahead after a turn),
  which is the same moment the old code hid the whole wall, so no new pop-in was introduced.
- `TravelController._rng` draw order is unchanged, so runs with the same `run_seed` still get the
  same stops and forks as before this task.
- Ricochets: walls bounce bullets off the flat `Surfaces` boxes at x +-9 (and `BayFlankSurfaces`
  beside a mouth); facades are visual only, so a bullet can pass up to 0.3 m into a set-back face
  before bouncing.

---

## End-of-session note

(Filled in by the session that stops; the newest entry is at the top.)
