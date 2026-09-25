# Step 8b: notes on the committed tree (read with spec_08b_set_pieces_batch2.md)

These override the spec where they differ.

## Where to work

The repo root for this session is the worktree
`C:\Users\Traff\Documents\van-gunner\.claude\worktrees\continue-previous-work-605228`, not the
path in the spec. Run every command from there. It has no `.godot/` yet: the first
`py -3 tools/check.py` imports the whole project (slow once). `resources/balance/game_balance.tres`
there is a mirror of the owner's local test edit so the smoke fingerprint matches the baseline:
never edit or stage it, nor `export_presets.cfg`. The Bash tool may not see `GODOT`; read it with
`powershell.exe -NoProfile -Command '[Environment]::GetEnvironmentVariable("GODOT","User")'` and
export it; for one-off sanity scripts use
`"C:\Users\Traff\Desktop\Godot_v4.7-stable_win64_console.exe" --headless --path . --script <file>`
with the script in the scratchpad (see `docs/tasks/buildings/span_sanity.gd.txt` for the pattern:
`extends SceneTree`, `_initialize` -> `call_deferred(&"_run")`, `await process_frame` after every
`add_child`, free everything before `quit()`). Bash heredocs write CRLF: write files with the
Write tool.

## As built by step 8a

- `facade_set_piece.gd` (45 lines), `facade_set_pieces.gd` (61), `facade_registry.gd` (103:
  `set_pieces()`, `set_piece(id)`), `corridor_facades.gd` (223: `_rare`, `_rare_plan_index`,
  `rare_id()`, `_rare_targets()`, `_build_span()`; `power_outage` special-cased),
  `facade_mesh_kit.gd` (112, has `add_cylinder_node`), `corridor_segment.rare_id()`.
- Templates: `scripts/travel/facades/set_pieces/{rooftop_billboard,water_tower,antenna_farm,power_outage}.gd`
  and `resources/facades/set_pieces/*.tres` (no `uid=`; exports equal to the class default are
  omitted).
- Fixtures live in `facade_fixtures.gd::build_fixtures`, not in `facade_props_ground.gd`.
- `facade_props_upper.gd`'s column/floor helpers (`_cols`, `_col_u`, `_floor_y`, `_param_f`,
  `_z_at`) are private: copy the formulas into the pieces, do not call them across files.

## Change 1: public sign builders (fixes a cross-file private call)

In `scripts/travel/facades/facade_signs.gd` (273 lines):

1. Rename `_build_boxed` -> `build_boxed`, `_emit_face_x` -> `emit_face_x`, `_emit_face_z` ->
   `emit_face_z`, `_emit_dark_faces` -> `emit_dark_faces` (only those four); update every call
   inside the file and switch `scripts/travel/facades/set_pieces/rooftop_billboard.gd` to the new
   public names. Grep the whole repo afterwards for the old names: zero hits.
2. Replace `_build_blade` with a public
   `static func build_blade(host: Node3D, node_name: String, plan: Dictionary, side_sign: float, keep_out: RefCounted, u_center: float, word: String, size: Vector3, bottom_y: float, color: Color, energy: float, seed_value: float, dead_ratio: float, flicker_amount: float) -> void`.
   Body = today's body generalised: `center.x = face_x - side_sign * (FACE_GAP + size.x * 0.5)`,
   `center.y = BASE_Y + bottom_y + size.y * 0.5`, `size` instead of `BLADE_SIZE`, the given
   colour/energy/dead_ratio/flicker/seed into `sign_material(word, 4, true, color, energy, 1,
   seed_value, dead_ratio, flicker_amount, float(word.length()))`, node named `node_name`.
   `bottom_y` is metres above `BASE_Y` (like `BLADE_BOTTOM_Y`).
3. The existing caller in `build()` becomes: compute `u_center` with the SAME rng draw as today,
   then `seed_value = rng.randf() * 1000.0` (same order as today), then call `build_blade(host,
   "SignBlade", plan, side_sign, keep_out, u_center, word, BLADE_SIZE, BLADE_BOTTOM_Y,
   _DEFAULT_COLOR, _DEFAULT_ENERGY, seed_value, 0.0, 0.0)`. Output for a given seed must be
   byte-for-byte the same as before (same draws in the same order).
4. `neon_blade` calls `build_blade(host, "RareBlade", ...)` with size `(1.6, 7.0, 0.3)`,
   bottom `6.6`, `u_center = width * 0.5`, word/colour from rng (colour: pick from the file's
   `_NEON_COLORS`; expose it as a public `NEON_COLORS` const if needed, renaming its uses),
   energy `_DEFAULT_ENERGY` (or the public equivalent), `seed_value = rng.randf() * 1000.0`,
   dead 0.15, flicker 0.4.

## Change 2: per-plan family suppression (rares must not collide with ordinary props)

The ordinary prop, sign and fixture passes run on the rare's building too, so without this a
laundry building gets two sets of balconies, a collapsed block keeps AC units and a cornice
floating above the collapse, the scaffold goes through a fire escape, and neon_blade doubles a
blade.

1. A plan may carry `&"suppress": Array[StringName]` (absent = nothing suppressed; read it as
   `plan.get(&"suppress", [])`). A piece sets it in `apply_plans` on the plan it takes.
2. `facade_props_upper.gd::build` skips a family when its key is in the list, BEFORE that
   family's chance roll: keys `&"trim"`, `&"ac_units"`, `&"fire_escape"`, `&"balconies"`,
   `&"roof_clutter"`, `&"wall_pipes"`. Keep the change to a few lines (the file is 344 of a
   400 cap; report its new line count).
3. `facade_props_ground.gd::build` likewise for `&"awnings"` and `&"furniture"`.
4. `facade_signs.gd::build` returns immediately (before any rng draw) when `&"signs"` is in the
   list.
5. Empty/absent list = identical rng stream and output to today, so non-rare tiles are unchanged.
6. Suppress lists per piece:
   - burning_tenement: `[]` (none)
   - collapsed_block: `[&"trim", &"ac_units", &"fire_escape", &"balconies", &"roof_clutter", &"wall_pipes", &"signs"]`
   - neon_blade: `[&"signs", &"fire_escape"]`
   - laundry_balconies: `[&"balconies", &"fire_escape", &"ac_units"]`
   - mural: `[&"balconies", &"fire_escape", &"ac_units", &"wall_pipes", &"signs"]`
   - scaffolded: `[&"balconies", &"fire_escape", &"ac_units", &"wall_pipes", &"signs"]`
7. collapsed_block: check (and report) whether the body's roof plate and end returns use the
   facade ShaderMaterial so the shader's `collapse_y` discard removes them too. If the roof plate
   uses a separate material and would float above the collapse, report it; do not edit
   `facade_body.gd`.

## Geometry corrections to the spec

- scaffolded: place relative to the face, not at absolute x (a set-back face sits at 8.5, so an
  absolute 8.75 row would be inside the building). Rows at `x_face - side_sign * 0.35` and
  `x_face - side_sign * 0.8`; transoms and planks centred at `x_face - side_sign * 0.575`; net at
  `x_face - side_sign * 0.85`. With setback 0.3 the innermost part is then at abs(x) 7.65, clear of
  the lane box (x < 7.6 below y 6).
- mural: cap the static texture cache: clear the Dictionary when it holds more than 16 entries
  before inserting.
- pipe_bridge: `add_cylinder_node` gains a trailing `rotation_rad: Vector3 = Vector3.ZERO`
  parameter; existing callers unchanged. When rotated a quarter turn about z the gate AABB is
  `box_aabb(center, Vector3(height, 2*r, 2*r), 0.0)`; about x, `Vector3(2*r, 2*r, height)`;
  otherwise the upright AABB. The valve wheels face +-X: rotation z = PI/2 on a short cylinder
  gives a disc facing X.
- Every node a piece adds has a fixed name (listed in the spec); if a name could repeat on one
  side root, suffix an index.

## Sanity (in addition to the spec's)

- For pedestrian_bridge and pipe_bridge: assert `Facades/Span` exists and has at least one
  `MeshInstance3D` child after `configure`, and is gone after `open_bay(&"left")` (the span code
  path has never run before).
- For neon_blade, laundry_balconies, mural, scaffolded, collapsed_block: print the node names
  under the target side root and confirm the suppressed families are absent on that tile (e.g.
  no `SignBlade`/`SignBox` next to `RareBlade`).
- Before/after the change: for 30 seeds on each district with `allow_rare = false`, print a hash
  of the sorted node names + mesh AABBs under both side roots; the numbers must match a run on
  the unmodified tree (take the "before" snapshot first, with `git stash` forbidden: copy the
  script output to the scratchpad before editing anything).
