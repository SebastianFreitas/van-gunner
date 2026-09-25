# Step 10a: notes on the committed tree (read with spec_10a_set_pieces_batch3.md)

These override the spec where they differ.

## Where to work

Same as `spec_08b_notes.md` "Where to work": the repo root is the worktree
`C:\Users\Traff\Documents\van-gunner\.claude\worktrees\continue-previous-work-605228` (its
`.godot/` is imported now), never edit or stage `resources/balance/game_balance.tres` or
`export_presets.cfg`, read `GODOT` through powershell, sanity scripts in the scratchpad, write
files with the Write tool.

## As built by steps 8a and 8b (commit `f84340d`)

- Twelve pieces exist; good templates: `set_pieces/collapsed_block.gd` (suppress list, rubble,
  collapse), `burning_tenement.gd` (light with the cap guard), `neon_blade.gd` (calls
  `facade_signs.build_blade`), `scaffolded.gd` (face-relative x, `net` material),
  `rooftop_billboard.gd` (`facade_signs.build_boxed` + `emit_face_x` two-surface panel).
- `facade_signs.gd` public API: `build_boxed`, `emit_face_x`, `emit_face_z`, `emit_dark_faces`,
  `build_blade(host, node_name, plan, side_sign, keep_out, u_center, word, size, bottom_y, color,
  energy, seed_value, dead_ratio, flicker_amount)`, `NEON_COLORS`. `bottom_y` is metres above
  `BASE_Y`.
- `facade_mesh_kit.add_cylinder_node(..., rotation_rad := Vector3.ZERO)`.
- Existing prop material keys to reuse with the same values: `rubble`, `net`, `flame`,
  `beacon_red` (see `antenna_farm.gd`), `plank`, `tank_wood`.
- `facade_body.gd` now skips the roof plate when `params.collapse_y > 0`, so collapsing pieces
  need not worry about it.

## Rules the spec gets wrong

- `OmniLight3D` has no `visibility_range_end` (it is a `GeometryInstance3D` property; setting it
  is a SCRIPT ERROR). Do not set it on lights. Guard lights with
  `if not host.is_inside_tree() or host.get_tree().get_nodes_in_group(&"facade_lights").size() >= 12: skip`.
- Ground kind and units live in TWO places: `plan[&"ground_kind"]` (int) and
  `plan[&"ground_units"]` (int) are what `facade_props_ground.gd` reads, while
  `params[&"ground_kind"]` (int) and `params[&"ground_units"]` (float) feed the shader. A piece
  that changes either sets both.
- Height lives in three places: `plan[&"height"]`, `plan[&"floors"]` and
  `params[&"facade_height"]`. A piece that changes the height sets all three, with
  `floors = maxi(1, int(floor((height - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT)))` using the
  `facade_plan.gd` constants.
- `blown_out_shop`: ignore the spec's thinking-aloud about `ground_kind = 2`; keep ground kind 1
  and set `params.lit_ratio = 0.05`, `params.soot = 0.8`.

## Per-plan suppress lists (step 8b mechanism)

A piece sets `plan[&"suppress"] = [...]` (an Array of StringName) in `apply_plans` on the plan
it takes. Keys: upper `&"trim"`, `&"ac_units"`, `&"fire_escape"`, `&"balconies"`,
`&"roof_clutter"`, `&"wall_pipes"`; ground `&"awnings"`, `&"furniture"`; `&"signs"`.

- parking_deck: `[&"ac_units", &"fire_escape", &"balconies", &"wall_pipes", &"signs", &"awnings"]`
- overgrown_ruin: `[&"trim", &"ac_units", &"fire_escape", &"balconies", &"roof_clutter", &"wall_pipes", &"signs"]`
  (as collapsed_block: nothing may float above the collapse)
- glass_crown: `[&"fire_escape", &"balconies", &"ac_units", &"roof_clutter"]` (the crown band
  and beacon own the top)
- radio_mast: `[&"roof_clutter"]`
- blown_out_shop: `[&"awnings", &"furniture", &"signs"]`
- gas_canopy: `[&"ac_units", &"fire_escape", &"balconies", &"roof_clutter", &"wall_pipes", &"signs", &"awnings", &"furniture"]`

## Geometry notes

- `can_apply` must use exactly the same criteria as `pick_plan` (return false when no plan
  qualifies), as the 8b pieces do.
- Place everything relative to `x_face` (a set-back face sits at abs(x) 8.5), except sidewalk
  items, which sit on the strip (abs(x) 7.7..8.8) and must stay clear of the lane box
  (abs(x) < 7.6 below y 6): compute their extents so the innermost edge is >= 7.65.
- gas_canopy: canopy bottom at tile y 6.2 (`y0 + 6.6`) as the spec concludes; the building
  height is 8.4 (ground 4.6 + one floor 3.2 + parapet 0.6), floors 1. The spec's canopy centre
  x `x_face - side_sign * 1.5` with size x 3.0 is right. The light sits just under the canopy
  underside (tile 6.2): position `(x_face - side_sign * 1.5, y0 + 6.5, z_mid)` (tile y 6.1),
  gated with a flat box `(0.2, 0.05, 0.2)` (tile y 6.075..6.125, clear of the lane top 6.0).
  The glow strip under the slab goes at tile y 6.2 - 0.025 as its own gated box.
- Nodes are single meshes per family as named in the spec; if a name could repeat on one side
  root, suffix an index.

## Sanity

Like 8b: for each new id find a seed (1..800) whose `rare_id()` matches after
`configure(seed, d, 7, true)` on a district that allows it; print the seed and the node names
under the target side root; confirm the suppressed families are absent on that plan (single-plan
sides only, as in 8b); `open_bay` on that side and assert `rare_id()` is empty. For glass_crown
and gas_canopy also print the target body's mesh AABB height to confirm the height change took.
Also re-run the 8b before/after hash (30 seeds x 5 districts, `allow_rare = false`): it must be
`855533371`-identical to the tree before your edits (you only add files, so it should be).
