---
paths:
  - "scripts/van/iron_cross*.gd"
  - "scripts/van/broken_iron_cross.gd"
  - "scripts/van/breakable_glass.gd"
  - "scripts/van/rear_door*.gd"
  - "scripts/van/rear_window_lip.gd"
  - "scripts/van/roof_edge_seal.gd"
  - "scripts/van/side_door*.gd"
  - "scripts/van/side_window*.gd"
  - "scripts/van/van_body_profile.gd"
  - "scripts/van/van_bulkhead*.gd"
  - "scripts/van/van_ceiling*.gd"
  - "scripts/van/van_floor.gd"
  - "scripts/van/van_front_wall.gd"
  - "scripts/van/van_gun_port*.gd"
  - "scripts/van/van_hull_mesh.gd"
  - "scripts/van/van_side_wall*.gd"
  - "scripts/van/look/van_hull*.gd"
  - "scripts/van/look/van_marker_lights.gd"
  - "scripts/van/look/van_roof.gd"
  - "scripts/player/fps_player.gd"
  - "scenes/van/van_shell.tscn"
  - "scenes/van/van_side_wall.tscn"
  - "scenes/van/*iron_cross.tscn"
  - "scenes/van/van_bulkhead.tscn"
  - "scenes/van/van_ceiling.tscn"
  - "scenes/van/van_floor.tscn"
  - "scenes/van/van_exterior.gdshader"
  - "tools/van_audit/**"
  - "tools/gap_check.py"
---

# Van shell geometry and seams

Render layers and light pairing (set `layers` before `add_child`) are in `van-render-layers.md`.

## Van shell geometry

`VanSideWall` exposes the bow profile (`wall_x_at`, `local_x_on_wall`) and the curved mesh builders (`build_curved_shell_mesh`, `build_curved_pane_from_poly`, `build_curved_frame_ring_mesh`) that doors, windows, iron crosses, bulkhead and hull use. The builders delegate to `van_side_wall_shell.gd`; the wall's own panel is `van_side_wall_panel.gd`. Keep those public names on `VanSideWall`.

`VanBodyProfile` (`scripts/van/van_body_profile.gd`, RefCounted, built by `VanBodyProfile.from_interior(Interior)`) is the one cross-section inside and outside sample: `inner_x_at(y)`, `outer_x_at(y)` (+0.12 wall), `roof_y_at(x)`, `outer_roof_y_at(x)`, `section_points(steps, outer)` and `build_reveal_mesh`. It lives beside `VanSideWall` because that script is near the 400-line cap. Anything new that must meet the walls or the vault (a partition, a cab back, a skin) takes its outline from here, never from its own constants: the old front end was three slabs with their own insets and it deformed against the vault.

The cab end is one piece, `Interior/FrontWall` (`VanFrontWall`): a slab triangulated from `section_points` with a doorway notch (x ±0.775, y 0..2.30), a `CollisionPolygon3D` from the same outline, and casings. `CabDoor` is a recessed barred leaf inside that notch. Change the outline only through the profile or the notch constants, so mesh and collision stay one shape.

Side windows: each sash hangs on two gooseneck strap hinges (`StrapHinge0/1` under its `Hinge`) whose knuckles sit on a welded `HingeRail` (window root child) at the `HINGE_OUT_M` 0.32 pivot, all built by `side_window_fixtures.gd` (also the `WindowStop` ring); the audit exempts `/HingeRail/` from the window opening like the frame. The front windows sit where the sliding door parks open, so `SideWindows.set_front_hinges_visible` hides their hinge hardware while that door is open (`door_changed`; the audit's `_pose_door` mirrors it); the interlock keeps the sash shut then. The `IronCross` sits outside the glass (owner, 2026-10-01: between the panes it read as bars through the glass) and is redneck scrap, not clean primitives (owner, 2026-10-01): two mismatched ribbed rebar rods in a + from `BAR_BACK_Z` off the liner (past `ExteriorPane` at 0.055), a scrap pipe sleeve with hose clamps on one arm, and at the crossing a fillet weld bead plus chain wrapped over both diagonals (an X of interlocking links that shows on the street and the cabin face, a short loose end, a round padlock hanging off one seeded lower corner). The owner kept only the chain (2026-10-01) and rejected diagonal wire coils ("giant nails"), a backing-plate box ("the cube"), loose weld lumps, a bolted flange and a tie wire there. All of it is rolled from `VanLook.rng_for` (rebuilt on `look_rebuilt`; a hash seed when no `VanLook`). The geometry lives in the helper `iron_cross_build.gd` (`end_path` is shared with `BrokenIronCross`), the builders in `iron_cross_geo.gd` (`add_rod`, `add_blob`, `helix_path`, `ring_path`, `densify`). Each window is sized to its own hole (`frame_half`, `clear_half`): side ends (`end_style` Hook) bend over the frame ring's outer edge, thinned to `HOOK_RADIUS` to fit the 2 cm gap behind it so the sash still opens; the rear doors (`end_style` Skin) weld flat onto the door skin at `skin_z` out to `skin_reach`. The bars are mostly seen from inside through the glass, so the cabin-facing side carries as much detail (welds, wire, clamp screws) as the street side; nothing crosses the glass. Its curved (side window) meshes must wind clockwise from outside like every hand-built mesh; the vertical tube lofts with x mirrored for that reason.

Outside, `VanLook/Hull` still pushes the liner out 6 cm for the skin; `van_hull_lines.gd` adds the body lines (rub rail, belt line, drip rail broken around every opening, bowed corner posts) at `inner_x_at(y) + 0.06`. `VanLook/MarkerLights` holds the clearance, tail and ID lamps (the amber ID row stands on the roof's rear rim, base sunk 2 cm, rear face 2 cm proud, because the rear lips leave only 4.5 cm of free rear face; heights come from `VanHull.roof_y_at`): each light sits at its fixture on layer 1, with energies tuned against the `*-outside` budget in `art-shots.md`. The skin's night read is a rain-wet sheen in `van_exterior.gdshader` (`wetness`, `wet_specular`): it only pulls roughness down to `roughness_min` 0.78, never below; make it read by adding a source, not by lowering that bound. The roof-rack spot (`van_roof.gd`) wears a visor so its lens is not a white disc from above.

Player height is one number, `FpsPlayer.EYE_HEIGHT` (2.0 m, owner 2026-10-03: "he must feel like a giant"; was 1.65). `FpsPlayer._apply_height` sizes head, capsule (eye + `HEAD_CLEARANCE` 0.2, so it still fits the 2.30 cab door notch) and body mesh from it, and `VanGunPort.EYE_Y` is the eye minus 3 cm. The side and rear windows (centre 1.775) were left where they are on purpose, so the eye now looks slightly down through them; raider heights (1.62 in `rear_doors.gd`, `cabin_nav.gd`, `window_raider_*`) are the raiders', not the player's.

## Seams and the gap light

Every opening is sealed by overlap, never by a tight fit (vangapfix D4, D17): a seal reaches about 5 cm over its neighbour (never more than 7 cm into an opening), stands at least 2 cm clear of a moving leaf in depth, and its edge over a fixed surface is sunk 2 cm into that surface. A new face never sits within 1 cm of a parallel face of another node that looks the same way and overlaps it by more than 1 cm² (the audit's FLICKER rule). The seals: `Ceiling/CoveL` and `CoveR` (`van_ceiling_cove.gd`), `RearWall/Frame` (`rear_door_frame.gd`), `OuterLip` on both rear hinges and `AstragalOuter` on the right one (`rear_door_lips.gd`, layer 1 through `VanLighting.GROUP_EXTERIOR_LAYER`), `SideWalls/DoorStop_L` and `DoorStop_R` (`side_door_stops.gd`). Both door kinds move away from the cabin, so fixed seals stand on the cabin side and only the rear lips and the two astragals ride on a leaf. `gaplight [on|out|off]` in the debug console paints everything that is not van magenta, `on` for a cabin camera and `out` for a street camera: one magenta pixel at a closed seam is a gap. vangapfix2 closed the rest, so `gap_check.py --strict` passes on all 43 views: `SideWalls/RoofEdgeSeal_L` and `_R` (`roof_edge_seal.gd`, the roof-edge band along the whole roof), `DoorStop_*` reaching 5 cm past the bay's rear edge (`side_door_stops.gd`), `WindowLip` with its hole sleeve on each rear hinge (`rear_window_lip.gd`), the side window rings wound for clockwise polys (`van_side_wall_shell.gd` `build_curved_frame_ring_mesh`), reveals whose cabin edge starts 4 mm cabin side of the liner's grid chord (`van_side_wall_panel.gd` `reveal_inner_profile_x`) and side panes cut to `PANE_POLY`, 2 cm under the frame (`side_windows.gd`). `gaplight` paints `ExteriorPane` black like `WindowGlass`.
