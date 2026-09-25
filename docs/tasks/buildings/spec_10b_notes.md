# Step 10b: notes on the committed tree (read with spec_10b_set_pieces_overheads.md)

These override the spec where they differ.

## Where to work

Same as `spec_08b_notes.md` "Where to work": the repo root is the worktree
`C:\Users\Traff\Documents\van-gunner\.claude\worktrees\continue-previous-work-605228`, never
edit or stage `resources/balance/game_balance.tres` or `export_presets.cfg`, read `GODOT` through
powershell, sanity scripts in the scratchpad, write files with the Write tool, never
`git stash` / `git worktree`.

## As built by steps 8a, 8b, 10a

- Eighteen pieces exist. Templates: `set_pieces/pipe_bridge.gd` and `pedestrian_bridge.gd`
  (span), `gas_canopy.gd` (a canopy over the lane edge, a light with the cap guard, a
  `build_boxed` text panel), `scaffolded.gd` (the `net` material), `neon_blade.gd`
  (`build_blade`), `collapsed_block.gd` (suppress list), `glass_crown.gd` (height change in three
  places).
- `facade_signs.gd` public API: `build_boxed`, `emit_face_x`, `emit_face_z`, `emit_dark_faces`,
  `build_blade(host, node_name, plan, side_sign, keep_out, u_center, word, size, bottom_y, color,
  energy, seed_value, dead_ratio, flicker_amount)` (`bottom_y` is metres ABOVE `BASE_Y`: pass
  `8.0`, not `y0 + 8.0`), `NEON_COLORS`.
- `facade_mesh_kit.add_cylinder_node(..., rotation_rad := Vector3.ZERO)`; a quarter turn about z
  lays the cylinder along x (a disc facing the road when short) and the gate AABB follows.
- `corridor_facades.gd` is 223 lines; `configure` rolls the rare, rebuilds both sides, then
  `_build_span()` for a span rare; `set_opening` drops the rare and frees `Span` when a side
  opens. `travel_world` calls `configure` BEFORE `apply_side_streets`, so every tile configures
  with both sides NONE and openings arrive afterwards through `set_opening`.
- Per-plan suppress lists: `plan[&"suppress"] = [...]` in `apply_plans`; keys `&"trim"`,
  `&"ac_units"`, `&"fire_escape"`, `&"balconies"`, `&"roof_clutter"`, `&"wall_pipes"`,
  `&"awnings"`, `&"furniture"`, `&"signs"`.

## Rules the spec gets wrong or leaves out

- `OmniLight3D` has no `visibility_range_end`; never set it on a light. Guard every light with
  `if not host.is_inside_tree() or host.get_tree().get_nodes_in_group(&"facade_lights").size() >= 12`.
- Ground kind/units live in both `plan` (ints, read by the ground props) and `params` (shader);
  height lives in `plan[&"height"]`, `plan[&"floors"]` and `params[&"facade_height"]`
  (`floors = maxi(1, int(floor((height - GROUND_HEIGHT - PARAPET) / FLOOR_HEIGHT)))`). A piece
  that changes one sets all of them.
- BoxMesh UVs are a 3x2 atlas, so the marquee shader's `UV.x` bulb grid would be scrambled on a
  BoxMesh. Build every `MarqueeBulbs*` strip as a quad (or a thin box whose faces you emit
  yourself) through `facade_body.add_quad` with u running 0..1 along the strip and v 0..1 across
  it, like the sign faces in `facade_signs.gd`.
- `net` material: `prop_material(&"net", ...)` is cached by key, and `scaffolded.gd` sets
  `transparency = BaseMaterial3D.TRANSPARENCY_ALPHA` on it after fetching. `crane_site` must do
  the same (setting it again is harmless), or a crane built before any scaffold gets an opaque
  net.
- Place wall-hugging parts relative to `x_face` (a set-back face is at abs(x) 8.5): crane_site's
  net goes at `x_face - side_sign * 0.6`, not at absolute 8.2.
- Pieces may be up to 150 lines (not 120); no line over 100 columns (tab = 4); no alias
  variables for preloaded helpers.
- Mind tile y vs `BASE_Y`: `_BASE_Y` is -0.4, and the lane box is tile y < 6.0 at abs(x) < 7.6.
  A part over the road must have its whole box above tile y 6.0 (so `y0 + 6.4` or higher for its
  bottom edge).

## Piece specifics

- chapel: suppress `[&"ac_units", &"fire_escape", &"balconies", &"wall_pipes", &"roof_clutter", &"signs", &"awnings"]`;
  ground kind 5 in both places; height `maxf(height, 18.0)` in all three places.
- cinema_marquee: suppress `[&"awnings", &"signs", &"fire_escape"]`. The CINEMA blade is
  `build_blade(host, "CinemaBlade", plan, side_sign, keep_out, width * 0.5, "CINEMA",
  Vector3(1.2, 5.0, 0.3), 8.0, Color(0.4, 0.9, 1.0), 2.4, rng.randf() * 1000.0, 0.0, 0.1)`. The
  light at `y0 + 6.7` sits inside the canopy slab's height range; with shadows off it still lights
  the sidewalk. Keep it.
- crane_site: suppress `[&"ac_units", &"fire_escape", &"balconies", &"wall_pipes", &"roof_clutter", &"signs"]`;
  ground kind 0 in both places; height clamp in all three places.
- searchlight: suppress `[&"roof_clutter"]`. The pivot script
  (`scripts/travel/facades/set_pieces/searchlight_pivot.gd`, `extends Node3D`, no class_name,
  `##` summary) exports `tilt := 0.6` and `degrees_per_second := 20.0`. `_ready` sets
  `rotation.z = tilt`; `_process` calls `rotate_y(deg_to_rad(degrees_per_second) * delta)` (parent
  space, so the tilted beam sweeps a cone). The builder sets `tilt = -side_sign * 0.6`, so the
  beam starts leaning out over the street, before `add_child`. Gate the beam with a box that
  starts at the pivot and goes UP:
  `AABB(pivot_pos + Vector3(-15.0, 0.0, -15.0), Vector3(30.0, 30.0, 30.0))`, not one centred on
  the pivot (half of that would hang 15 m below the roof).
- Overheads: build them only when `_rare.is_empty()` (no rare of any kind on the tile), so a
  bridge never runs through a set-piece. Frames and pipes end at abs(x) 9.2 (behind the faces).
  Keep `corridor_facades.gd` under 300 lines; if the hooks would push it over, put the
  orchestration in the overheads helper. Free `Facades/Overhead` in `set_opening` with the same
  rename-then-`queue_free` pattern `rebuild_side` uses, so a same-frame rebuild can't collide on
  the name.
- `facade_district.gd` gains `@export var overhead_chance := 0.0` (with a `##` doc) at the END of
  the exports. `industrial.tres` gets `overhead_chance = 0.55`, `derelict.tres` gets `0.15`; the
  other three stay at the default, so write nothing into them.

## Verification additions

- The `allow_rare = false` hash over the side roots (30 seeds x 5 districts, the scratchpad
  `hash_sanity.gd`) must still be `855533371`: overheads build under `Facades/Overhead`, not under
  a side root, and use their own RNG.
- Sanity for the four ids (seed, node names, suppression, rare cleared after `open_bay`), plus:
  on district 1 find a seed with `Facades/Overhead`, print its children and which kind was built,
  then `open_bay(&"left")` and assert that `Overhead` is gone. Confirm no `Overhead` is built on a
  tile whose `rare_id()` is non-empty.
- The check must compile `facade_marquee.gdshader` with no `SHADER ERROR`.
