# van-exterior-2 · phase 2 audit (2026-09-28)

Source: `py -3 tools/smoke.py --shots` at seed 1337, IDLE. Lit shots v08..v16
(floodlight on), unlit v01..v03 and `03-idle-outside`. Annotated copies were
sent to the owner (`audit-v*.png`, boxes labelled with the IDs below); they are
not committed. Anchors from an Explore pass; line numbers drift, grep the names.

Severity: **high** = reads as broken from the player's usual views (street,
rear doors, combat outside cam); **mid** = visible on a second look;
**low** = only in lit inspection.

## Cab and front → phase 5

| ID | Issue | Shots | Builder / node | Sev |
|---|---|---|---|---|
| C1 | The cab is a free-standing box from `CAB_BACK_Z` -4.72 to `NOSE_Z` -8.2 with no sides or back: from the side you look through it into dark crates, and the body's rounded front end stands exposed behind it. | v08, v11, v12, v13 | `van_cab.gd` `rebuild_look()` (hood, windshield, header, headlights only) | high |
| C2 | No windshield or cab glass reads from the front; the face is bumper planks and two lamp discs. | v13 | `van_cab.gd` | high |
| C3 | A slanted louvred plank panel juts diagonally above the cab, attached to nothing. | v08, v11 | `van_cab.gd` hood or `van_front_kit.gd` seeded ram/cage | high |
| C4 | The front kit's bumper and ram beams lie loose ahead of the nose (rams reach z -9.2), reading as scattered planks on the road. | v08, v11, v13 | `van_front_kit.gd` `build()` (bumper at `NOSE_Z`-0.2, width 5.0, seeded ram) | high |
| C5 | Headlights are bare white discs with no housing or bezel. | v11, v13, v03 | `van_cab.gd` headlight meshes (lights at ±1.75, 0.95, `NOSE_Z`-0.2) | mid |

## Holes and seams → phase 3

| ID | Issue | Shots | Builder / node | Sev |
|---|---|---|---|---|
| S1 | Rear corners: the rust side skin runs past the black rear face as loose flanges with a lit strip between them; the two never meet. | v14, v09, v10 | `van_hull.gd` rear + sides vs `rear_doors.gd` vaulted leaves | high |
| S2 | Front end: the grey corrugated end of the body shows between the hull skin (ends at z -4.72) and the cab; nothing closes it. | v11 | `van_hull.gd` (skin/roof z -4.72..4.78) + `van_front_wall.gd` (interior only, `FACE_Z` -4.55, no exterior face) | high |
| S3 | Lower edge: a lit gap under the skin along the sill; the sill boxes (0.10×0.28×9.5) do not seal to the skin. | v08 | `van_hull.gd` sills | mid |
| S4 | Roof edge: roof and side skin read as separate strips along the length from above. | v16 | `van_hull.gd` roof vs sides | low |
| S5 | Rear step plate lies flat on the road, detached from the van. | v09, v14 | not found by Explore: grep the rear dressing (`VanLook` children) in phase 3 | mid |
| S6 | The side door leaf stands proud of the hull with its curved edges sticking out. | v08, v15 | `side_door_leaf.gd` `fit_door_leaf()` (`OUTER_SKIN` 0.035) vs hull `SKIN_OFFSET_M` 0.06 | mid |

## Windows and door leaf → phase 4

| ID | Issue | Shots | Builder / node | Sev |
|---|---|---|---|---|
| W1 | The side door leaf renders as a glossy black slab: it reuses the interior shell shader outside. | v08, v11, v12, v15 | `side_door_leaf.gd` `door_body_material()` | high |
| W2 | Interior lamps blow out through the side windows as white/amber streaks: the interior pane with its rim recipe is the only glass. | v15, v09 | `side_windows.gd` (`RearWindowGlassMaterial` both sides) | high |
| W3 | No exterior frame or reveal, only a thin black ring. | v15 | `side_windows.gd` / `VanSideWall.build_curved_frame_ring_mesh` | mid |
| W4 | Vertical bars float beside the side window outside, attached to nothing. | v15 | not found by Explore: candidates `van_armour_pieces.gd` `add_bar()`, window guard dressing | mid |
| W5 | Rear door windows read well (iron cross, mesh): the reference for the side windows. | v14 | `rear_doors.gd` | ok |

## Underside and wheels → phase 6

| ID | Issue | Shots | Builder / node | Sev |
|---|---|---|---|---|
| U1 | The front wheels (axle z -7.25, x ±2.8) stand in the open under the sideless cab, ahead of the body; both sides, no arch. | v08, v11, v12 | `van_wheels.gd` `FRONT_AXLE_Z`, `WHEEL_X` | high |
| U2 | Rear wheels cluster mid-body under a bulging plate with no arch or lip. | v09 | `van_wheels.gd` rear axles (4-axle [3.0], 6-axle [2.3, 3.6]) | high |
| U3 | A long pipe runs along the sill past both ends of the body. | v15 | likely `van_wheels.gd` `_build_exhaust()`: confirm in phase 6 | mid |
| U4 | No frame rails, fuel tank, rear bumper or underride bar; the rear underside is empty. | v09, v14 | none yet (D6) | mid |
| U5 | Tread blocks read as cog teeth in silhouette (14 blocks). | v08, v15 | `van_wheels.gd` `TREAD_BLOCKS` | low |
| U6 | A diagonal rod runs from under the side door to the front wheel. | v08 | not found by Explore: candidate `_build_exhaust()` or a cable; locate in phase 6 | mid |

The Carry forward note "passenger rear wheel floats clear of the sill" is U1:
the wheels are symmetric in code; what floats is the front axle ahead of the
body, seen from the passenger side in v08/v12.

## Night read → phase 7

| ID | Issue | Shots | Builder / node | Sev |
|---|---|---|---|---|
| N1 | Unlit, the body is a near-black silhouette; only lamps read. Expected under the budget (D7): the fix is sources and sheen, not brightness. | v01, v02, v03 | `art-style.md` `*-outside` budget | mid |
| N2 | Headlights already throw two pools on the road ahead (SpotLight3D energy 3.0, range 26, 30°): D7's headlights exist; phase 5 must keep them when it rebuilds the cab. | v03 | `van_cab.gd` headlight spots | ok |
| N3 | Tail lamps glow red with a faint ground tint; amber ID lamps on the rear roof. Fine, maybe a touch more ground spill. | v02, v14 | `van_marker_lights.gd` (tail energy 0.45) | low |
| N4 | No sheen: the skin stays matte under street lamps. | v01, v08 | `van_hull.gd` skin material | mid |
| N5 | A bright white disc on the roof front reads from above and ahead (beacon or roof lamp). | v13, v10, `03-idle-outside` | locate in phase 7 (roof dressing or marker lights) | low |

## Run order (D8)

1. **Phase 5 · cab** first: the largest gap (C1–C5), and it fixes where the
   front axle, the body's front end (S2) and the headlights (N2) sit.
2. **Phase 6 · underside and wheels**: arches and rails depend on the cab's
   length; U1 is mostly a cab consequence.
3. **Phase 3 · holes and seams**: patches go last against the final cab and
   chassis so they are not redone (S1–S6).
4. **Phase 4 · windows and door leaf**: independent of the rest; takes W1 too.
5. **Phase 7 · night read**: tunes against the finished body.
